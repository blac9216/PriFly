#!/usr/bin/env bash
# Self-test for check-readiness.sh. Every fixture is synthetic, in a throwaway copy of
# the repo's own templates/docs, so mutating one never touches the real files. Fixture
# digests (sha256sum) are printed so a reviewer can confirm exactly what was probed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/prifly-readiness-tests.XXXXXX")"
trap 'rm -rf -- "$fixture_root"' EXIT
passed=0

mk_root() {
  local dst="$1"
  mkdir -p "$dst/.github/ISSUE_TEMPLATE" "$dst/docs/process"
  cp "$REPO_ROOT/.github/ISSUE_TEMPLATE/work-item.md" "$dst/.github/ISSUE_TEMPLATE/work-item.md"
  cp "$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md" "$dst/.github/PULL_REQUEST_TEMPLATE.md"
  cp "$REPO_ROOT/docs/process/work-tracking.md" "$dst/docs/process/work-tracking.md"
  cp "$REPO_ROOT/docs/process/labels.md" "$dst/docs/process/labels.md"
}

# gen_body TEMPLATE OUT PREFIX MODE: writes PREFIX then every "## " heading from
# TEMPLATE, each with prose body text (MODE=full) or bare (MODE=bare, no prose, used to
# reproduce the "Refs but no remainder" regression).
gen_body() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys
template_path, out_path, prefix, hmode = sys.argv[1:5]
headings = [l[3:].rstrip() for l in open(template_path, encoding='utf-8')
            if l.startswith('## ')]
with open(out_path, 'w', encoding='utf-8') as fh:
    fh.write(prefix)
    for h in headings:
        fh.write(f"## {h}\n" if hmode == 'bare' else f"## {h}\n\nBody text for {h}.\n\n")
PY
}

run_case() {
  local name="$1" expected="$2"; shift 2
  local observed=0
  bash "$SCRIPT_DIR/check-readiness.sh" "$@" >"$fixture_root/output" 2>"$fixture_root/output.err" || observed=$?
  if [[ "$observed" != "$expected" ]]; then
    echo "FAIL: $name (expected exit $expected; observed $observed)" >&2
    cat "$fixture_root/output" "$fixture_root/output.err" >&2
    exit 1
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

# Valid Work Item body: every work-item.md heading, plus a checkbox under Acceptance
# Criteria (gen_body's plain prose does not supply one, so add it after).
valid_root="$fixture_root/valid-root"
mk_root "$valid_root"
valid_body="$fixture_root/valid-body.md"
gen_body "$valid_root/.github/ISSUE_TEMPLATE/work-item.md" "$valid_body" '' full
sed -i '/^## Acceptance Criteria/a \\n- [ ] A criterion a reviewer can prove at merge.' "$valid_body"
sha256sum "$valid_body" "$valid_root/.github/ISSUE_TEMPLATE/work-item.md" \
  "$valid_root/docs/process/work-tracking.md" "$valid_root/docs/process/labels.md"

run_case 'valid body + valid labels passes' 0 \
  --root "$valid_root" --mode issue --body "$valid_body" --labels 'chore,area:workflow'
run_case 'missing type/area labels fails' 1 \
  --root "$valid_root" --mode issue --body "$valid_body" --labels 'priority:low'

# Mutation: delete every "## " heading from the template copy -> TEMPLATE_EMPTY (exit 3),
# not a trivial pass.
headings_removed_root="$fixture_root/headings-removed-root"
mk_root "$headings_removed_root"
sed -i '/^## /d' "$headings_removed_root/.github/ISSUE_TEMPLATE/work-item.md"
sha256sum "$headings_removed_root/.github/ISSUE_TEMPLATE/work-item.md"
run_case 'all "## " headings removed from template fails' 3 \
  --root "$headings_removed_root" --mode issue --body "$valid_body" --labels 'chore,area:workflow'

# Mutation: delete only the Acceptance Criteria heading.
ac_removed_root="$fixture_root/ac-removed-root"
mk_root "$ac_removed_root"
sed -i '/^## Acceptance Criteria/d' "$ac_removed_root/.github/ISSUE_TEMPLATE/work-item.md"
sha256sum "$ac_removed_root/.github/ISSUE_TEMPLATE/work-item.md"
run_case 'only the Acceptance Criteria heading removed fails' 1 \
  --root "$ac_removed_root" --mode issue --body "$valid_body" --labels 'chore,area:workflow'

# Mutation: delete the doc anchor the checker depends on.
anchor_removed_root="$fixture_root/anchor-removed-root"
mk_root "$anchor_removed_root"
python3 - "$anchor_removed_root/docs/process/work-tracking.md" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
anchor = "at least one acceptance-criteria checkbox (`- [ ]` or `- [x]`)"
assert anchor in text, "fixture setup assumption broken: anchor text not found"
open(path, 'w', encoding='utf-8').write(text.replace(anchor, "at least one acceptance-criteria item"))
PY
sha256sum "$anchor_removed_root/docs/process/work-tracking.md"
run_case 'doc anchor removed from work-tracking.md fails loudly' 3 \
  --root "$anchor_removed_root" --mode issue --body "$valid_body" --labels 'chore,area:workflow'

# PR bodies: Closes form (positive), bare Refs (negative), Refs + remainder (positive).
pr_root="$fixture_root/pr-root"
mk_root "$pr_root"
pr_template="$pr_root/.github/PULL_REQUEST_TEMPLATE.md"

pr_closes_body="$fixture_root/pr-closes-body.md"
gen_body "$pr_template" "$pr_closes_body" $'Closes #126\n\n' full
sha256sum "$pr_closes_body"
run_case 'PR body with Closes #<N> passes' 0 --root "$pr_root" --mode pr --body "$pr_closes_body"

pr_refs_bare_body="$fixture_root/pr-refs-bare-body.md"
gen_body "$pr_template" "$pr_refs_bare_body" $'Refs #126\n\n' bare
sha256sum "$pr_refs_bare_body"
run_case 'PR body with Refs but no remainder fails' 1 --root "$pr_root" --mode pr --body "$pr_refs_bare_body"

pr_refs_full_body="$fixture_root/pr-refs-full-body.md"
gen_body "$pr_template" "$pr_refs_full_body" \
  $'Refs #126\n\nThis PR delivers only checker AC1 of #126; AC2 (the CI wiring) is the\nexact remainder, deferred to a follow-up issue whose PR will close issue #126.\n\n' \
  full
sha256sum "$pr_refs_full_body"
run_case 'PR body with Refs and a named remainder passes' 0 --root "$pr_root" --mode pr --body "$pr_refs_full_body"

echo "test-check-readiness: $passed cases passed"
