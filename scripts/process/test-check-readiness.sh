#!/usr/bin/env bash
# Self-test for check-readiness.sh (issue and PR modes). Every fixture is synthetic, built in
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
  cp "$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md" "$1/.github/"
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

# run_case NAME EXPECTED_EXIT EXPECTED_LINE ARGS...: stdin comes from $CASE_STDIN if set;
# if $CASE_ABSENT is set, no output line may contain it (#168: no cascading MISSING lines).
run_case() {
  local name="$1" expected="$2" line="$3"; shift 3
  local observed=0 absent="${CASE_ABSENT:-}"
  bash "$SCRIPT_DIR/check-readiness.sh" "$@" <"${CASE_STDIN:-/dev/null}" \
    >"$fixture_root/output" 2>&1 || observed=$?
  if [[ "$observed" != "$expected" ]] || ! grep -qF -- "$line" "$fixture_root/output" \
    || { [[ -n "$absent" ]] && grep -qF -- "$absent" "$fixture_root/output"; }; then
    [[ -z "$absent" ]] || line="$line' and no line containing '$absent"
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
# A non-type label must not satisfy the type check; an area: label outside labels.md's set
# (area:docs is excluded there by name) must not satisfy the area check.
run_case 'missing type label fails' 1 'MISSING: carries one type label' \
  --root "$root" --body "$body" --labels 'priority:high,area:workflow'
run_case 'missing area:* label fails' 1 'MISSING: carries one area:* label' \
  --root "$root" --body "$body" --labels 'chore,priority:low,area:docs'

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

# AC scoping, fences and comments: the body's only checkbox is moved out of the Acceptance
# Criteria section's own text (checkbox_case NAME AFTER_LINE INSERT CASE-NAME).
ac_h="$(grep -m1 '^## Acceptance Criteria' "$tmpl")"
next_h="$(grep '^## ' "$tmpl" | grep -A1 -xF "$ac_h" | tail -1)"
checkbox_case() {
  local out="$fixture_root/$1-body.md"; cp "$body" "$out"
  replace "$out" $'- [ ] A criterion a reviewer can prove at merge.\n' ''
  replace "$out" "$2"$'\n' "$2"$'\n'"$3"
  sha256sum "$out"
  run_case "$4" 1 'MISSING: acceptance-criteria checkbox present' --root "$root" --body "$out" --labels "$labels"
}
checkbox_case before-ac '## Summary / Goal' $'- [ ] Not an acceptance criterion.\n' \
  'checkbox only outside the Acceptance Criteria section fails'
checkbox_case after-ac "$next_h" $'- [ ] Not an acceptance criterion.\n' \
  'checkbox only in the section after Acceptance Criteria fails'
checkbox_case nested-fence "$ac_h" $'~~~\n```\n- [ ] Quoted inside a fence.\n```\n~~~\n' \
  'checkbox only inside a ~~~ fence holding ``` lines fails'
checkbox_case short-fence "$ac_h" $'````\n```\n- [ ] Quoted inside a fence.\n````\n' \
  'checkbox only inside a 4-backtick fence holding a shorter 3-backtick line fails'
checkbox_case html-comment "$ac_h" $'<!--\n- [ ] Commented out.\n-->\n' \
  'checkbox only inside a multi-line HTML comment fails'
# #155: a repeated Acceptance Criteria heading is checked in every copy, not only the first.
dup_body="$fixture_root/dup-ac-body.md"; cp "$body" "$dup_body"
replace "$dup_body" "$ac_h"$'\n' "$ac_h"$'\n\nEmpty first copy.\n\n'"$ac_h"$'\n'
sha256sum "$dup_body"
run_case 'repeated Acceptance Criteria heading: checkbox in a later copy passes' 0 \
  'check-readiness: 5/5 as expected' --root "$root" --body "$dup_body" --labels "$labels"

# labels.md anchors: rewording the Type row, the area:* heading or every area:* row fails loudly.
# shellcheck disable=SC2016 # the backticks are literal labels.md text, not expansions
lab_old=('| Type. |' '## Repo-specific `area:*` set' '| `area:')
# shellcheck disable=SC2016
lab_msg=("no labels.md row ending '| Type. |'" "no '## Repo-specific \`area:*\` set' heading" "no 'area:*' rows found")
for j in 0 1 2; do
  l_root="$fixture_root/labels-anchor-$j-root"; mk_root "$l_root"
  replace "$l_root/docs/process/labels.md" "${lab_old[$j]}" '| REWORDED'
  sha256sum "$l_root/docs/process/labels.md"
  run_case "labels.md anchor $((j + 1)) reworded fails loudly" 3 "LABELS_ANCHOR_MISSING: ${lab_msg[$j]}" \
    --root "$l_root" --body "$body" --labels "$labels"
done

# Doc anchors: rewording each rule the checker relies on fails loudly, one case per anchor.
i=0
# shellcheck disable=SC2016 # the backticks are literal anchor text, not expansions
for anchor in '## Readiness shape' \
  'a Work Item body carries every `## ` heading of' \
  'at least one acceptance-criteria checkbox (`- [ ]` or `- [x]`)' \
  $'one type label from the Type row of [labels.md](labels.md) and at\n  least one label from its `area:*` table' \
  'a PR body carries every `## ` heading of' \
  'a `Closes #<N>` line or the partial-delivery form below' \
  'the body carries a `Refs #<N>` line' 'body then carries no closing keyword anywhere' \
  'directly after it a `Remainder: <text>` line and then a `Closing issue: #<M>` line' \
  'No closing keyword comes directly before an issue reference in those two lines' \
  'Each of the two lines starts with its label exactly as written above'; do
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
# #154: a non-UTF-8 body is a named exit 2; a non-UTF-8 doc file is a named exit 3.
printf '## Summary\n\xff\xfe bad\n' >"$fixture_root/not-utf8-body.md"
run_case 'non-UTF-8 body fails with exit 2, named' 2 'FILE_NOT_UTF8' \
  --root "$root" --body "$fixture_root/not-utf8-body.md" --labels "$labels"
# #161: a non-UTF-8 stdin body names stdin, not the temp file the EXIT trap deletes.
CASE_STDIN="$fixture_root/not-utf8-body.md" run_case 'non-UTF-8 stdin body is named body (stdin)' 2 \
  'FILE_NOT_UTF8: body (stdin): invalid start byte' --root "$root" --body - --labels "$labels"
enc_root="$fixture_root/not-utf8-doc-root"; mk_root "$enc_root"
printf '\xff\n' >>"$enc_root/docs/process/labels.md"
run_case 'non-UTF-8 docs/process/labels.md fails with exit 3, named' 3 'FILE_NOT_UTF8' \
  --root "$enc_root" --body "$body" --labels "$labels"
run_case 'missing body file is a usage error' 2 'body file not found or not readable' \
  --root "$root" --body "$fixture_root/no-such-body.md"
run_case '--root with no value is a usage error' 2 '--root requires a value' --root
run_case '--mode with no value is a usage error' 2 '--mode requires a value' --root "$root" --mode
run_case '--repo with no value is a usage error' 2 '--repo requires a value' --root "$root" --repo
run_case '--mode other than issue or pr is a usage error' 2 '--mode must be issue or pr' \
  --root "$root" --body "$body" --mode bogus
run_case '--mode pr without --repo is a usage error' 2 '--mode pr requires --repo' \
  --root "$root" --body "$body" --mode pr
run_case '--labels with --mode pr is a usage error' 2 '--labels is not accepted with --mode pr' \
  --root "$root" --body "$body" --labels x --mode pr --repo blac9216/PriFly
# #163: --repo is the mirror case, a usage error in issue mode in both flag forms.
run_case '--repo with --mode issue is a usage error' 2 '--repo is not accepted with --mode issue' \
  --root "$root" --body "$body" --labels "$labels" --repo blac9216/PriFly
run_case '--repo=OWNER/NAME with the default issue mode is a usage error' 2 \
  '--repo is not accepted with --mode issue' --root "$root" --body "$body" --labels "$labels" --repo=blac9216/PriFly

# PR mode (#152). pr_body NAME PREAMBLE: PREAMBLE, then every PR template heading with prose.
pr_body() {
  python3 - "$root/.github/PULL_REQUEST_TEMPLATE.md" "$fixture_root/pr-$1.md" "$2" <<'PY'
import sys
heads = [l[3:].rstrip() for l in open(sys.argv[1], encoding='utf-8') if l.startswith('## ')]
with open(sys.argv[2], 'w', encoding='utf-8') as fh:
    fh.write(sys.argv[3] + '\n' + ''.join(f"## {h}\n\nBody text for {h}.\n\n" for h in heads))
PY
  sha256sum "$fixture_root/pr-$1.md"
}
pr=(--mode pr --repo blac9216/PriFly)
pr_body closes $'Closes #154\nCloses #155\n'
run_case 'PR: Closes lines pass' 0 'check-readiness: 2/2 as expected' \
  --root "$root" --body "$fixture_root/pr-closes.md" "${pr[@]}"
run_case 'PR: --mode=pr and --repo=OWNER/NAME forms are accepted' 0 'check-readiness: 2/2 as expected' \
  --root "$root" --body "$fixture_root/pr-closes.md" --mode=pr --repo=blac9216/PriFly
pr_refs=$'Refs #57\nRemainder: the retry path and its tests\nClosing issue: #133\n'
pr_body refs "$pr_refs"
run_case 'PR: Refs form passes' 0 'check-readiness: 8/8 as expected' \
  --root "$root" --body "$fixture_root/pr-refs.md" "${pr[@]}"
# #157 form: each part dropped or misplaced fails at its own named check.
f=0
form_case() {  # form_case NAME PREAMBLE EXPECTED_MISSING_LINE
  f=$((f + 1)); pr_body "form-$f" "$2"
  run_case "PR form: $1 fails" 1 "MISSING: Refs #57: $3" --root "$root" --body "$fixture_root/pr-form-$f.md" "${pr[@]}"
}
form_case 'missing Remainder line' $'Refs #57\nClosing issue: #133\n' "a 'Remainder: <text>' line directly after it"
form_case 'empty Remainder text' $'Refs #57\nRemainder:  \nClosing issue: #133\n' 'the Remainder text is non-empty'
form_case 'missing Closing issue line' $'Refs #57\nRemainder: the retry path\n' \
  "a 'Closing issue: #<M>' line directly after the Remainder line"
form_case 'Closing issue equal to the Refs issue' $'Refs #57\nRemainder: the retry path\nClosing issue: #57\n' \
  'the Closing issue is not #57 itself'
form_case 'Remainder not directly after Refs' $'Refs #57\n\nRemainder: the retry path\nClosing issue: #133\n' \
  "a 'Remainder: <text>' line directly after it"
form_case 'Closing issue not directly after Remainder' $'Refs #57\nRemainder: the retry path\n\nClosing issue: #133\n' \
  "a 'Closing issue: #<M>' line directly after the Remainder line"
# #168: labels match as written (colon, space, case); the Closing issue line ends at #M.
form_case 'Remainder label with no space' $'Refs #57\nRemainder:the retry path\nClosing issue: #133\n' \
  "a 'Remainder: <text>' line directly after it"
form_case 'lowercase Remainder label' $'Refs #57\nremainder: the retry path\nClosing issue: #133\n' \
  "a 'Remainder: <text>' line directly after it"
form_case 'lowercase Closing issue label' $'Refs #57\nRemainder: the retry path\nclosing issue: #133\n' \
  "a 'Closing issue: #<M>' line directly after the Remainder line"
form_case 'trailing text after the Closing issue #M' $'Refs #57\nRemainder: the retry path\nClosing issue: #133 and more\n' \
  "a 'Closing issue: #<M>' line directly after the Remainder line"
# #177: the Closing issue label's space is part of the label, as the Remainder label's is.
form_case 'Closing issue label with no space' $'Refs #57\nRemainder: the retry path\nClosing issue:#133\n' \
  "a 'Closing issue: #<M>' line directly after the Remainder line"
# #168: a check that depends on a failed line is skipped, not reported as a second MISSING line.
CASE_ABSENT='the Remainder text is non-empty' form_case 'missing Remainder line without a cascade' \
  $'Refs #57\nClosing issue: #133\n' "a 'Remainder: <text>' line directly after it (next line is 'Closing issue: #133'; its text"
CASE_ABSENT='the Closing issue is not #57 itself' form_case 'malformed Closing issue line without a cascade' \
  $'Refs #57\nRemainder: the retry path\nClosing issue: other-org/other-repo#12\n' \
  "a 'Closing issue: #<M>' line directly after the Remainder line (line after that is 'Closing issue: other-org/other-repo#12'; the M != N check is skipped)"
# #168: every Refs line's form is checked, not only the first one's.
pr_body second-refs "$pr_refs"$'Refs #58\nClosing issue: #133\n'
run_case 'PR form: second Refs line with an incomplete form fails' 1 \
  "MISSING: Refs #58: a 'Remainder: <text>' line directly after it" \
  --root "$root" --body "$fixture_root/pr-second-refs.md" "${pr[@]}"
for kw in 'fixes #99' 'resolves other-org/other-repo#99'; do
  form_case "'$kw' in the Remainder line" $'Refs #57\nRemainder: a follow-up that '"$kw"$'\nClosing issue: #133\n' \
    'no closing keyword before an issue reference in its Remainder and Closing issue lines'
done
pr_body neither $'Part of #42\n'
run_case 'PR: neither a Closes nor a Refs line fails' 1 \
  'MISSING: a Closes #<N> line or a Refs #<N> line present' \
  --root "$root" --body "$fixture_root/pr-neither.md" "${pr[@]}"
pr_add_root="$fixture_root/pr-heading-added-root"; mk_root "$pr_add_root"
printf '\n## Extra PR Section\nText.\n' >>"$pr_add_root/.github/PULL_REQUEST_TEMPLATE.md"
run_case 'PR: heading added to the PR template is required of the body' 1 'missing: Extra PR Section' \
  --root "$pr_add_root" --body "$fixture_root/pr-closes.md" "${pr[@]}"
# Every GitHub closing-keyword form for the Refs'd #57 is flagged, inside fenced code too.
k=0
fence=$'quoted below\n```\nfixes #57\n```'
for kw in 'close #57' 'closes #57' 'closed #57' 'fix #57' 'fixes #57' 'fixed #57' 'resolve #57' \
  'resolves #57' 'resolved #57' 'CLOSES #57' 'Closes: #57' 'resolves blac9216/PriFly#57' \
  'Fixes BLAC9216/prifly#57' 'fixes:#57' "$fence"; do
  k=$((k + 1)); found="${kw#*$'```\n'}"; found="${found%$'\n```'}"
  pr_body "kw-$k" "$pr_refs"$'\nNote: '"$kw"$'\n'
  run_case "PR: '${kw//$'\n'/ }' for a Refs'd issue fails" 1 \
    "MISSING: no closing keyword for Refs #57 anywhere in the body (found: ['$found'])" \
    --root "$root" --body "$fixture_root/pr-kw-$k.md" "${pr[@]}"
done
# Not a closing reference to #57: another repository (owner, name or both differ), another
# number, a longer word.
for kw in 'resolves other-org/other-repo#57' 'fixes other-org/PriFly#57' 'fixes blac9216/other-repo#57' \
  'fixes #570' 'hotfixes #57'; do
  k=$((k + 1)); pr_body "kw-$k" "$pr_refs"$'\nNote: '"$kw"$'\n'
  run_case "PR: '$kw' is not a closing keyword for #57" 0 'check-readiness: 8/8 as expected' \
    --root "$root" --body "$fixture_root/pr-kw-$k.md" "${pr[@]}"
done

# #176: a fence opened on a list-item line ("1. ```sh") is a fence, and its indented closing
# line closes it rather than opening a new one, whatever the number of such steps.
step() { printf '%s %s%s\n   echo %s\n   %s\n' "$1" "$2" "$3" "$4" "$2"; }  # MARKER FENCE INFO TEXT
fence_case() {  # fence_case NAME PREAMBLE EXPECTED_EXIT EXPECTED_LINE
  pr_body "fence-$1" "$2"
  run_case "PR fence: $1" "$3" "$4" --root "$root" --body "$fixture_root/pr-fence-$1.md" "${pr[@]}"
}
fence_case 'odd count of 1. ```sh steps keeps later headings' \
  "Closes #154"$'\n'"$(step 1. '```' sh one)"$'\n'"$(step 2. '```' sh two)"$'\n'"$(step 3. '```' sh three)" \
  0 'check-readiness: 2/2 as expected'
fence_case 'even count of 1. ```sh steps keeps the prose between them' \
  "$(step 1. '```' sh one)"$'\nCloses #154\n'"$(step 2. '```' sh two)" 0 'check-readiness: 2/2 as expected'
fence_case 'odd count of - ~~~text steps keeps later headings' \
  "Closes #154"$'\n'"$(step - '~~~' text one)" 0 'check-readiness: 2/2 as expected'
fence_case 'closing line with an info string does not close the fence' \
  $'Closes #154\n* ```sh\n  echo one\n  ```text\n  ```' 0 'check-readiness: 2/2 as expected'
fence_case 'a ```-run with a backtick after it is a code span, not a fence' \
  $'Closes #154\n```inline``` code, not a fence' 0 'check-readiness: 2/2 as expected'
fence_case 'unclosed list fence ends at the next less-indented line' \
  "Closes #154"$'\n1. ```sh\n   echo one\n' 0 'check-readiness: 2/2 as expected'
pr_body fence-heading-like "Closes #154"$'\n'"$(step 1. '```' sh one)"
replace "$fixture_root/pr-fence-heading-like.md" $'\n## Verified expectation\n' $'\n'
replace "$fixture_root/pr-fence-heading-like.md" $'   echo one\n' $'   echo one\n   ## Verified expectation\n'
run_case 'PR fence: heading-like line inside a list-item fence is not a heading' 1 \
  'MISSING: all template sections present (missing: Verified expectation)' \
  --root "$root" --body "$fixture_root/pr-fence-heading-like.md" "${pr[@]}"
checkbox_case list-fence "$ac_h" $'1. ```text\n   - [ ] Quoted inside a list-item fence.\n   ```\n' \
  'checkbox only inside a fence opened on a list-item line fails'

echo "test-check-readiness: $passed cases passed"
