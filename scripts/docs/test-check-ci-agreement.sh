#!/usr/bin/env bash
# Regression tests for check-ci-agreement.sh over scratch copies of the four files it
# reads and, for the exemption cases, of the checker itself. Every case asserts both the
# exit status and the diagnostic, so a checker that started exiting non-zero for the
# wrong reason would not pass. Each mutation #337 names has a case here, and each
# exemption entry has a case that only that entry satisfies, so deleting any one entry
# turns a named case red. All cases run; the script exits 1 if any failed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/prifly-ci-agreement-tests.XXXXXX")"
# This exact mktemp-owned directory contains only generated fixtures.
trap 'rm -r -- "$fixture_dir"' EXIT
passed=0
failed=0
wf_go="$fixture_dir/.github/workflows/go-checks.yml"
wf_docs="$fixture_dir/.github/workflows/docs-checks.yml"
testing="$fixture_dir/docs/process/testing.md"
manifest="$fixture_dir/docs/doc-manifest.md"
checker="$SCRIPT_DIR/check-ci-agreement.sh"

reset_fixture() {
  checker="$SCRIPT_DIR/check-ci-agreement.sh"
  mkdir -p "$fixture_dir/.github/workflows" "$fixture_dir/docs/process"
  cp "$REPO/.github/workflows/go-checks.yml" "$wf_go"
  cp "$REPO/.github/workflows/docs-checks.yml" "$wf_docs"
  cp "$REPO/docs/process/testing.md" "$testing"
  cp "$REPO/docs/doc-manifest.md" "$manifest"
}

# check_case NAME EXIT TEXT [ARG...]: run the checker (default args: --root <fixture>)
# and require exit status EXIT and a line of its output containing TEXT verbatim.
check_case() {
  local name="$1" expected="$2" text="$3" observed=0
  shift 3
  (($#)) || set -- --root "$fixture_dir"
  bash "$checker" "$@" >"$fixture_dir/output" 2>&1 || observed=$?
  if [[ "$observed" != "$expected" ]] || ! grep -qF -- "$text" "$fixture_dir/output"; then
    echo "FAIL: $name (expected exit $expected with '$text'; observed exit $observed)" >&2
    cat "$fixture_dir/output" >&2
    failed=$((failed + 1))
    return 0
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

# also_expect NAME TEXT: a second assertion on the output the last check_case captured.
also_expect() {
  local name="$1" text="$2"
  if grep -qF -- "$text" "$fixture_dir/output"; then
    echo "PASS: $name"
    passed=$((passed + 1))
    return 0
  fi
  echo "FAIL: $name (the last output does not contain '$text')" >&2
  cat "$fixture_dir/output" >&2
  failed=$((failed + 1))
}

# drop_exemption N: copy the checker with its Nth exemption entry deleted, and point the
# next case at that copy.
drop_exemption() {
  awk -v n="$1" '
    /^# --- the exemption list/ { inblock = 1 }
    /^# --- end of the exemption list/ { inblock = 0 }
    inblock && /^        "/ { count++; if (count == n) next }
    { print }
  ' "$SCRIPT_DIR/check-ci-agreement.sh" >"$fixture_dir/checker.sh"
  checker="$fixture_dir/checker.sh"
}

reset_fixture
check_case 'unmodified copies agree' 0 'workflow steps agree with their documented commands'
also_expect 'unmodified copies use every exemption' 'exemptions are all in use'
also_expect 'unmodified copies match the manifest CI list' "CI list of twelve matches"

check_case 'empty root is a usage error' 2 '--root must name a directory' --root ''
check_case 'nonexistent root is a usage error' 2 '--root must name a directory' --root "$fixture_dir/absent"
check_case 'unknown argument is a usage error' 2 'unknown argument' --root "$fixture_dir" --bogus

# A step deleted without its row, and a row deleted without its step.
reset_fixture
sed -i '/^      - name: Early publication runner local proof (fake probe, virtual clock)$/,+1d' "$wf_go"
check_case 'a deleted workflow step orphans its row' 1 "row 'Publication runner proof'"
also_expect 'the orphaned row names the workflow it lost' 'has no step in .github/workflows/go-checks.yml'

reset_fixture
sed -i '/^| Publication runner proof |/d' "$testing"
check_case 'a deleted documentation row orphans its step' 1 "step 'Early publication runner local proof (fake probe, virtual clock)'"
also_expect 'the orphaned step names the file it lost its row in' 'has no row in docs/process/testing.md'

# Both sides are order-bearing.
reset_fixture
awk '
  /^\| Publication input proof \|/ { held = $0; next }
  /^\| Publication evaluator proof \|/ { print; print held; next }
  { print }
' "$testing" >"$testing.reordered" && mv "$testing.reordered" "$testing"
check_case 'two reordered adjacent rows fail' 1 "runs 'bash tests/qualification/early_publication/test-input.sh'"
also_expect 'the reordering names the row it was paired against' "documents 'bash tests/qualification/early_publication/test-fixture.sh'"

# One changed flag.
reset_fixture
sed -i 's@run: go test -count=1 -race -v ./...@run: go test -count=1 -race ./...@' "$wf_go"
check_case 'a changed flag in a run line fails' 1 "documents 'go test -count=1 -race -v ./...'"

# A docs-checks step deleted: red for the table and for the manifest list and its count.
reset_fixture
sed -i '/^      - name: CI agreement checker regression tests$/,+1d' "$wf_docs"
check_case 'a deleted docs-checks step orphans its row' 1 "row 'Agreement checker regression tests'"
also_expect 'the same deletion moves the manifest count' "runs 11"
also_expect 'the same deletion moves the manifest list length' "lists 12 steps"

# The exemption list is not a wildcard.
reset_fixture
printf '%s\n' '      - name: Undocumented new step' '        run: true' >>"$wf_go"
check_case 'a new step with no row and no exemption fails' 1 "step 'Undocumented new step'"
also_expect 'the unpaired step says the list is not a wildcard' 'no exemption entry'

reset_fixture
sed -i '/^| Publication runner proof |/a | Undocumented proof | `bash tests/qualification/nowhere.sh` | Scratch. |' "$testing"
check_case 'a new row with no step fails' 1 "row 'Undocumented proof'"

# Each exemption entry, deleted on its own, turns its now-unmatched step or row red.
reset_fixture
drop_exemption 1
check_case 'dropping the docs-checks checkout exemption fails' 3 'docs-checks.yml step '"'"'Check out the PR head commit (not the synthetic merge ref)'"'"' has no run: line'
reset_fixture
drop_exemption 2
check_case 'dropping the go-checks checkout exemption fails' 3 'go-checks.yml step '"'"'Check out the PR head commit (not the synthetic merge ref)'"'"' has no run: line'
reset_fixture
drop_exemption 3
check_case 'dropping the toolchain-install exemption fails' 3 "step 'Install pinned Go toolchain (verify SHA-256, then extract)' uses a block scalar run:"
reset_fixture
drop_exemption 4
check_case 'dropping the module-cache exemption fails' 3 "step 'Restore Go module cache (keyed by go.sum)' has no run: line"
reset_fixture
drop_exemption 5
check_case 'dropping the sanitize-scan exemption fails' 1 "row 'Sanitize scan'"
reset_fixture
drop_exemption 6
check_case 'dropping the integration exemption fails' 3 "row 'Integration' in the documentation suite table: the Command cell holds no backtick-quoted command"

# Files it cannot read, and structure it cannot normalise.
reset_fixture
rm "$testing"
check_case 'a missing documentation file fails' 3 "missing $testing"
reset_fixture
python3 -c 'import sys; open(sys.argv[1], "ab").write(bytes([255]))' "$manifest"
check_case 'a non-UTF-8 file fails' 3 'is not UTF-8'
reset_fixture
printf '%s\n' '' '| Suite | Command | Environment |' '|---|---|---|' >>"$testing"
check_case 'a Commands table with no rows fails' 3 'Commands table with no rows'
reset_fixture
printf '%s\n' '' '| Suite | Command | Environment |' '|---|---|---|' '| Extra | `true` | Scratch. |' >>"$testing"
check_case 'a fourth Commands table fails' 3 'tables, not the 3 this checker pairs'
reset_fixture
sed -i 's@^| Vet | .*@| Vet | run go vet over the tree | Same. |@' "$testing"
check_case 'a Command cell with no command fails' 3 'the Command cell holds no backtick-quoted command'
reset_fixture
sed -i 's@`git rev-parse HEAD`, then `command -v go`@`git rev-parse HEAD` or `command -v go`@' "$testing"
check_case 'an unnormalisable separator fails' 3 'which this checker does not normalise'
reset_fixture
sed -i 's@run: go build ./...@run: |@' "$wf_go"
check_case 'a block scalar run on a paired step fails' 3 "step 'go build' uses a block scalar run:"

# The three normalisation classes, proved to hold and proved not to be a wildcard.
reset_fixture
sed -i 's@/tmp/prifly-design-doc-gap.md@/tmp/somewhere-else-gap.md@' "$wf_docs"
check_case 'a changed scratch path still pairs' 0 'workflow steps agree with their documented commands'
reset_fixture
sed -i 's@--out /tmp/prifly-design-doc-gap.md@--output /tmp/prifly-design-doc-gap.md@' "$wf_docs"
check_case 'a changed flag beside a placeholder fails' 1 'Design-doc mechanical audit'

# The manifest list, its numbering and its spelled-out count.
reset_fixture
sed -i 's@runs these twelve steps@runs these eleven steps@' "$manifest"
check_case 'a wrong manifest count word fails' 1 "says the job runs 'eleven' steps"
reset_fixture
sed -i 's@^2. `check-pointers.sh`@3. `check-pointers.sh`@' "$manifest"
check_case 'a misnumbered manifest entry fails' 1 'entry at position 2 is numbered 3'
reset_fixture
sed -i 's@^4. `audit.sh`@4. `audit-renamed.sh`@' "$manifest"
check_case 'a manifest entry naming another script fails' 1 'does not appear in the run:'
reset_fixture
sed -i 's@^## CI$@## CI steps@' "$manifest"
check_case 'a missing CI section fails' 3 "has no '## CI' section"

reset_fixture
echo "test-check-ci-agreement: $passed cases passed, $failed failed"
((failed == 0))
