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
  $'Refs #126\n\nThis PR delivers only checker AC1 of #126; AC2 (the CI wiring) is the\nexact remainder, delivered by #133, whose PR will close issue #126.\n\n' \
  full
sha256sum "$pr_refs_full_body"
run_case 'PR body with Refs, a named remainder and closing issue passes' 0 \
  --root "$pr_root" --mode pr --body "$pr_refs_full_body"

# F1 self-test negatives: closer named but no remainder wording, remainder wording but
# no closer, and neither (the reviewer's stripped-PR-#134 shape).
pr_refs_closer_only_body="$fixture_root/pr-refs-closer-only-body.md"
gen_body "$pr_template" "$pr_refs_closer_only_body" \
  $'Refs #126\n\nSee #133 for the follow-up.\n\n' full
sha256sum "$pr_refs_closer_only_body"
run_case 'PR body naming a closing issue but no remainder wording fails' 1 \
  --root "$pr_root" --mode pr --body "$pr_refs_closer_only_body"

pr_refs_remainder_only_body="$fixture_root/pr-refs-remainder-only-body.md"
gen_body "$pr_template" "$pr_refs_remainder_only_body" \
  $'Refs #126\n\nAC2 is the exact remainder, not delivered by this PR.\n\n' full
sha256sum "$pr_refs_remainder_only_body"
run_case 'PR body naming a remainder but no closing issue fails' 1 \
  --root "$pr_root" --mode pr --body "$pr_refs_remainder_only_body"

pr_refs_stripped_body="$fixture_root/pr-refs-stripped-body.md"
gen_body "$pr_template" "$pr_refs_stripped_body" \
  $'Refs #126\n\nThis PR delivers only checker AC1 of #126; AC2 is the CI wiring.\n\n' full
sha256sum "$pr_refs_stripped_body"
run_case 'PR body with neither remainder wording nor a closing issue (stripped PR #134 shape) fails' 1 \
  --root "$pr_root" --mode pr --body "$pr_refs_stripped_body"

# F2 self-test: every GitHub closing-keyword variant, case-insensitive, colon-optional,
# must be caught as a stray closing reference to the Refs'd issue.
for variant in 'Fixes #126' 'Resolves #126' 'closed #126' 'fixed #126' 'Closes: #126' 'FIXES #126'; do
  variant_body="$fixture_root/pr-refs-keyword-$(echo "$variant" | tr -cd 'A-Za-z').md"
  gen_body "$pr_template" "$variant_body" \
    $"Refs #126\n\nAC2 is the exact remainder, delivered by #133. ${variant} in the release notes.\n\n" \
    full
  sha256sum "$variant_body"
  run_case "PR body with stray closing keyword variant '$variant' fails" 1 \
    --root "$pr_root" --mode pr --body "$variant_body"
done

# F2 false-positive guard: the same keyword+#N pattern inside a fenced code block must
# not be flagged (documented limit: fenced code is not parsed for closing keywords,
# matching GitHub's own behaviour).
pr_refs_fenced_keyword_body="$fixture_root/pr-refs-fenced-keyword-body.md"
gen_body "$pr_template" "$pr_refs_fenced_keyword_body" \
  $'Refs #126\n\nAC2 is the exact remainder, delivered by #133.\n\n```\nFixes #126\n```\n\n' \
  full
sha256sum "$pr_refs_fenced_keyword_body"
run_case 'PR body with a closing keyword only inside a fenced code block passes' 0 \
  --root "$pr_root" --mode pr --body "$pr_refs_fenced_keyword_body"

# Note 3 self-test: a checkbox outside the Acceptance Criteria section must not count.
ac_checkbox_elsewhere_body="$fixture_root/ac-checkbox-elsewhere-body.md"
gen_body "$valid_root/.github/ISSUE_TEMPLATE/work-item.md" "$ac_checkbox_elsewhere_body" '' full
python3 - "$ac_checkbox_elsewhere_body" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
# Acceptance Criteria section: plain bullets, no checkbox.
text = re.sub(
    r'## Acceptance Criteria\n\n[^\n]*\n',
    '## Acceptance Criteria\n\n- A criterion, as plain prose with no checkbox.\n',
    text, count=1,
)
# A different heading's section gets the only checkbox in the body.
text, n = re.subn(
    r'(## (?!Acceptance Criteria)[^\n]+\n\n)([^\n]*\n)',
    r'\1- [ ] Not an acceptance criterion.\n\2',
    text, count=1,
)
assert n == 1, "fixture setup assumption broken: no other heading found"
open(path, 'w', encoding='utf-8').write(text)
PY
sha256sum "$ac_checkbox_elsewhere_body"
run_case 'checkbox present only outside the Acceptance Criteria section fails' 1 \
  --root "$valid_root" --mode issue --body "$ac_checkbox_elsewhere_body" --labels 'chore,area:workflow'

# Note 6 self-test: a ``` fence line nested inside an open ~~~ fence must not close it
# (CommonMark: closing fence needs the same character, at least as long).
nested_fence_body="$fixture_root/nested-fence-body.md"
gen_body "$pr_template" "$nested_fence_body" \
  $'Refs #126\n\nAC2 is the exact remainder, delivered by #133.\n\n~~~\n```\nFixes #126\n```\n~~~\n\n' \
  full
sha256sum "$nested_fence_body"
run_case 'a ``` line inside an open ~~~ fence does not flip fence state' 0 \
  --root "$pr_root" --mode pr --body "$nested_fence_body"

# Note 4 self-test: a missing doc file fails loudly with exit 3, not a traceback/exit 1;
# --root with no value is a usage error, exit 2.
missing_file_root="$fixture_root/missing-file-root"
mk_root "$missing_file_root"
rm -f "$missing_file_root/docs/process/work-tracking.md"
run_case 'missing docs/process/work-tracking.md fails loudly (FILE_NOT_FOUND, exit 3)' 3 \
  --root "$missing_file_root" --mode issue --body "$valid_body" --labels 'chore,area:workflow'

run_case '--root with no value is a usage error (exit 2)' 2 --root

echo "test-check-readiness: $passed cases passed"
