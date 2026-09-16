#!/usr/bin/env bash
# Self-test for check-readiness.sh (issue-body mode). Every fixture is synthetic, built in
# a throwaway copy of the repo's own template and docs, so mutating one never touches the
# real files. Each case asserts both the exit code and the line naming WHICH check or
# error fired, so a case cannot pass because some other check failed first. Fixture
# digests (sha256sum) are printed so a reviewer can confirm exactly what was probed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/prifly-readiness-tests.XXXXXX")"
trap 'chmod -R u+rwX -- "$fixture_root"; rm -rf -- "$fixture_root"' EXIT
passed=0
labels='chore,area:workflow'

mk_root() {
  mkdir -p "$1/.github/ISSUE_TEMPLATE" "$1/docs/process"
  cp "$REPO_ROOT/.github/ISSUE_TEMPLATE/work-item.md" "$1/.github/ISSUE_TEMPLATE/work-item.md"
  cp "$REPO_ROOT/docs/process/work-tracking.md" "$REPO_ROOT/docs/process/labels.md" "$1/docs/process/"
}

# replace FILE OLD NEW: literal replacement; fails the setup if OLD is absent.
replace() {
  python3 - "$@" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path, encoding='utf-8').read()
assert old in text, f"fixture setup assumption broken: {old!r} not in {path}"
open(path, 'w', encoding='utf-8').write(text.replace(old, new))
PY
}

# run_case NAME EXPECTED_EXIT EXPECTED_LINE ARGS...: stdin comes from $CASE_STDIN if set.
run_case() {
  local name="$1" expected="$2" line="$3"; shift 3
  local observed=0
  bash "$SCRIPT_DIR/check-readiness.sh" "$@" <"${CASE_STDIN:-/dev/null}" \
    >"$fixture_root/output" 2>&1 || observed=$?
  if [[ "$observed" != "$expected" ]] || ! grep -qF -- "$line" "$fixture_root/output"; then
    echo "FAIL: $name (expected exit $expected and a line containing '$line'; observed exit $observed)" >&2
    cat "$fixture_root/output" >&2
    exit 1
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

root="$fixture_root/valid-root"
mk_root "$root"
tmpl="$root/.github/ISSUE_TEMPLATE/work-item.md"

# Valid body: every template heading with prose, plus a checkbox under Acceptance Criteria.
body="$fixture_root/valid-body.md"
python3 - "$tmpl" "$body" <<'PY'
import sys
heads = [l[3:].rstrip() for l in open(sys.argv[1], encoding='utf-8') if l.startswith('## ')]
with open(sys.argv[2], 'w', encoding='utf-8') as fh:
    for h in heads:
        fh.write(f"## {h}\n\nBody text for {h}.\n\n")
        if h.startswith('Acceptance Criteria'):
            fh.write("- [ ] A criterion a reviewer can prove at merge.\n\n")
PY
sha256sum "$body" "$tmpl" "$root/docs/process/work-tracking.md" "$root/docs/process/labels.md"

run_case 'valid body + valid labels passes' 0 'check-readiness: 5/5 as expected' \
  --root "$root" --body "$body" --labels "$labels"
run_case 'body via process substitution passes' 0 'check-readiness: 5/5 as expected' \
  --root "$root" --body <(cat "$body") --labels "$labels"
CASE_STDIN="$body" run_case 'body via stdin (--body -) passes' 0 'check-readiness: 5/5 as expected' \
  --root "$root" --body - --labels "$labels"
run_case 'missing type label fails' 1 'MISSING: carries one type label' \
  --root "$root" --body "$body" --labels 'area:workflow'
run_case 'missing area:* label fails' 1 'MISSING: carries one area:* label' \
  --root "$root" --body "$body" --labels 'chore,priority:low'

# Template heading derivation: a heading added to the template is required of the body;
# all headings removed is TEMPLATE_EMPTY; only the AC heading removed is named.
add_root="$fixture_root/heading-added-root"; mk_root "$add_root"
printf '\n## Extra Template Section\nText.\n' >>"$add_root/.github/ISSUE_TEMPLATE/work-item.md"
none_root="$fixture_root/headings-removed-root"; mk_root "$none_root"
sed -i '/^## /d' "$none_root/.github/ISSUE_TEMPLATE/work-item.md"
ac_root="$fixture_root/ac-removed-root"; mk_root "$ac_root"
sed -i '/^## Acceptance Criteria/d' "$ac_root/.github/ISSUE_TEMPLATE/work-item.md"
sha256sum "$add_root/.github/ISSUE_TEMPLATE/work-item.md" \
  "$none_root/.github/ISSUE_TEMPLATE/work-item.md" "$ac_root/.github/ISSUE_TEMPLATE/work-item.md"
run_case 'heading added to template is required of the body' 1 'missing: Extra Template Section' \
  --root "$add_root" --body "$body" --labels "$labels"
run_case 'all "## " headings removed from template fails' 3 'TEMPLATE_EMPTY' \
  --root "$none_root" --body "$body" --labels "$labels"
run_case 'only the Acceptance Criteria heading removed fails' 1 \
  'MISSING: template names an Acceptance Criteria heading' \
  --root "$ac_root" --body "$body" --labels "$labels"

# AC scoping: the only checkbox sits in another section.
elsewhere="$fixture_root/checkbox-elsewhere-body.md"
cp "$body" "$elsewhere"
replace "$elsewhere" $'- [ ] A criterion a reviewer can prove at merge.\n' ''
replace "$elsewhere" $'## Summary / Goal\n' $'## Summary / Goal\n- [ ] Not an acceptance criterion.\n'
# Fence handling: the AC checkbox sits inside a ~~~ fence whose ``` lines must not close it.
fenced="$fixture_root/nested-fence-body.md"
cp "$body" "$fenced"
replace "$fenced" $'- [ ] A criterion a reviewer can prove at merge.\n' \
  $'~~~\n```\n- [ ] Quoted inside a fence, not a criterion.\n```\n~~~\n'
sha256sum "$elsewhere" "$fenced"
run_case 'checkbox only outside the Acceptance Criteria section fails' 1 \
  'MISSING: acceptance-criteria checkbox present' --root "$root" --body "$elsewhere" --labels "$labels"
run_case 'checkbox only inside a ~~~ fence holding ``` lines fails' 1 \
  'MISSING: acceptance-criteria checkbox present' --root "$root" --body "$fenced" --labels "$labels"

# Doc anchors: rewording each rule the checker relies on fails loudly, one case per anchor.
i=0
# shellcheck disable=SC2016 # the backticks are literal anchor text, not expansions
for anchor in '## Readiness shape' \
  'a Work Item body carries every `## ` heading of' \
  'at least one acceptance-criteria checkbox (`- [ ]` or `- [x]`)' \
  $'one type label from the Type row of [labels.md](labels.md) and at\n  least one label from its `area:*` table'; do
  i=$((i + 1)); a_root="$fixture_root/anchor-$i-root"; mk_root "$a_root"
  replace "$a_root/docs/process/work-tracking.md" "$anchor" 'REWORDED RULE'
  sha256sum "$a_root/docs/process/work-tracking.md"
  run_case "doc anchor $i reworded fails loudly" 3 "no longer contains: '${anchor%%$'\n'*}" \
    --root "$a_root" --body "$body" --labels "$labels"
done

# Missing/unreadable doc files and usage errors.
gone_root="$fixture_root/missing-file-root"; mk_root "$gone_root"
rm -f "$gone_root/docs/process/labels.md"
run_case 'missing docs/process/labels.md fails loudly' 3 'FILE_NOT_FOUND' \
  --root "$gone_root" --body "$body" --labels "$labels"
locked_root="$fixture_root/unreadable-file-root"; mk_root "$locked_root"
chmod 000 "$locked_root/docs/process/labels.md"
if [[ -r "$locked_root/docs/process/labels.md" ]]; then
  echo "SKIP: unreadable docs/process/labels.md (running with privileges that bypass chmod)"
else
  run_case 'unreadable docs/process/labels.md fails loudly' 3 'FILE_UNREADABLE' \
    --root "$locked_root" --body "$body" --labels "$labels"
fi
run_case 'missing body file is a usage error' 2 'body file not found or not readable' \
  --root "$root" --body "$fixture_root/no-such-body.md"
run_case '--root with no value is a usage error' 2 '--root requires a value' --root

echo "test-check-readiness: $passed cases passed"
