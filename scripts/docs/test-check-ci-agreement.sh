#!/usr/bin/env bash
# Regression tests for check-ci-agreement.sh over scratch copies of the four files it
# reads and, for the exemption cases, of the checker itself. Every case asserts both the
# exit status and the diagnostic, so a checker that started exiting non-zero for the
# wrong reason would not pass. Each mutation #337 names has a case here, and each
# exemption entry has a case that only that entry satisfies, so deleting any one entry
# turns a named case red. Each mutation #347 and #348 name has a case too, including the
# one #347 M3 records as a limit rather than a defect, and the three written lists those
# two issues add are each proved to rot in both directions. All cases run; the script
# exits 1 if any failed.
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

# set_conditional LITERAL: copy the checker with its conditional-step list replaced by
# the Python dict literal LITERAL, and point the next case at that copy. The list is
# empty in the tree, so this is how its two directions are proved.
set_conditional() {
  awk -v literal="$1" '
    /^CONDITIONAL_STEPS: / { print "CONDITIONAL_STEPS = " literal; next }
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

# --- #347 M1: the manifest list is matched by whole path component, not by substring ---
# The "## CI" list holds three X.sh / test-X.sh pairs, so a narrowed entry is one
# adjacent entry away from naming a script that is a substring of its neighbour's.
reset_fixture
sed -i 's@^6. `test-check-links.sh`@6. `check-links.sh`@' "$manifest"
check_case 'a manifest entry narrowed to a substring fails' 1 "entry 6 names 'check-links.sh'"
also_expect 'the narrowed entry says what it failed to match' 'as a whole path component'
also_expect 'the narrowed entry names the step it was checked against' "runs 'bash scripts/docs/test-check-links.sh'"

# --- #347 M2: a placeholder may only widen a row the checker's list names -------------
reset_fixture
sed -i 's@^| Vet | `go vet ./...` |@| Vet | `go <anything> ./...` |@' "$testing"
check_case 'a placeholder on an undeclared row fails' 1 "row 'Vet' in the Go suite table documents '<anything>' as a placeholder"
also_expect 'the undeclared placeholder says the list did not cover it' 'no entry in the checker'"'"'s documented-placeholder list covers the row'

# The declared row is load-bearing in both directions: its entry names a row that must
# exist and must still hold exactly the placeholder tokens the entry declares.
reset_fixture
sed -i 's@^| Mechanical audit | `bash scripts/docs/audit.sh --root . --out <scratch-path>/gap.md` |@| Mechanical audit | `bash scripts/docs/audit.sh --root . --out <scratch-path>/<name>.md` |@' "$testing"
check_case 'a declared row that gains a placeholder token fails' 1 "entry 'Mechanical audit' in the documentation suite table declares '<scratch-path>/gap.md'"
also_expect 'the changed declaration names what the row now documents' "but the row documents '<scratch-path>/<name>.md'"
reset_fixture
sed -i 's@^| Mechanical audit | @| Audit, renamed | @' "$testing"
check_case 'a declared placeholder row that no longer exists fails' 1 "entry 'Mechanical audit' names no paired row of the documentation suite table"

# --- #347 M3: a paired step name is deliberately unchecked ---------------------------
# Pinned, not overlooked: the checker's header records that step names, Suite labels and
# manifest glosses are prose in three different voices with no convention to compare them
# under. If a later change starts checking them, this case turns red and the header is
# what has to be corrected with it.
reset_fixture
sed -i 's@^      - name: Rationale-index pointers resolve$@      - name: Totally different name@' "$wf_docs"
check_case 'renaming a paired step still passes, as the header records' 0 'workflow steps agree with their documented commands'

# --- #347 M4: the boundary between two tables paired against one job ------------------
reset_fixture
python3 - "$testing" <<'INNER'
import sys, pathlib
path = pathlib.Path(sys.argv[1])
lines = path.read_text().split("\n")
row = next(line for line in lines if line.startswith("| Build |"))
lines.remove(row)
lines.insert(next(i for i, line in enumerate(lines) if line.startswith("| Runner namespace setting |")), row)
path.write_text("\n".join(lines))
INNER
check_case 'a row moved across the table boundary fails' 1 'the qualification local proofs table starts at position 7'
also_expect 'the moved row names the step the boundary fell on' "runs 'go build'"
also_expect 'the moved row names the step the boundary list declares' "but the checker's table boundary list names 'Allow unprivileged user namespaces (hosted runner AppArmor)'"

reset_fixture
sed -i 's@^      - name: Allow unprivileged user namespaces (hosted runner AppArmor)$@      - name: Renamed boundary step@' "$wf_go"
check_case 'renaming the step a boundary names fails' 1 "table boundary list names 'Allow unprivileged user namespaces (hosted runner AppArmor)'"

# --- #348: the attributes that decide whether a paired step runs and blocks -----------
reset_fixture
sed -i 's@^        run: bash scripts/ci/check-mode-enforcement.sh$@        if: ${{ github.event_name == null }}\n        run: bash scripts/ci/check-mode-enforcement.sh@' "$wf_go"
check_case 'a never-firing if on a paired go-checks step fails' 1 'carries if: ${{ github.event_name == null }}'
also_expect 'the condition names the step it switches off' "go-checks.yml step 'File-mode enforcement probe (a run that bypasses modes fails here)'"
also_expect 'the condition says no entry covers it' "no entry in the checker's conditional-step list covers it"

reset_fixture
sed -i 's@^        run: bash scripts/ci/check-mode-enforcement.sh$@        continue-on-error: true\n        run: bash scripts/ci/check-mode-enforcement.sh@' "$wf_docs"
check_case 'continue-on-error on a paired docs-checks step fails' 1 'carries continue-on-error: true'
also_expect 'the non-blocking step is named' "docs-checks.yml step 'File-mode enforcement probe (a run that bypasses modes fails here)'"

reset_fixture
sed -i 's@^        run: go vet ./...$@        env:\n          GOFLAGS: -tags=skip\n        run: go vet ./...@' "$wf_go"
check_case 'env on a paired step fails' 1 'carries env:'
also_expect 'the env step is named' "step 'go vet'"

# An attribute the treatment does not recognise is an error naming it, not a skip.
reset_fixture
sed -i 's@^        run: go vet ./...$@        shell: bash\n        run: go vet ./...@' "$wf_go"
check_case 'an unrecognised attribute on a paired step fails' 3 'carries shell:, which this checker does not recognise on a paired step'
also_expect 'the unrecognised attribute says it was not skipped' 'so it is not skipped'

# timeout-minutes is permitted, and the header records why: it can only make a documented
# step fail sooner, never stop running or stop blocking.
reset_fixture
sed -i 's@^        run: go vet ./...$@        timeout-minutes: 5\n        run: go vet ./...@' "$wf_go"
check_case 'timeout-minutes on a paired step still passes' 0 'workflow steps agree with their documented commands'

# The conditional-step list is load-bearing in both directions, like the exemption list.
reset_fixture
sed -i 's@^        run: bash scripts/ci/check-mode-enforcement.sh$@        if: ${{ github.event_name == null }}\n        run: bash scripts/ci/check-mode-enforcement.sh@' "$wf_go"
set_conditional '{".github/workflows/go-checks.yml": {"File-mode enforcement probe (a run that bypasses modes fails here)": ["if"]}}'
check_case 'a declared conditional step passes and is counted' 0 '1 conditional step'
reset_fixture
set_conditional '{".github/workflows/go-checks.yml": {"File-mode enforcement probe (a run that bypasses modes fails here)": ["if"]}}'
check_case 'a conditional entry for an attribute the step lacks fails' 1 'declares if:, which .github/workflows/go-checks.yml step '"'"'File-mode enforcement probe (a run that bypasses modes fails here)'"'"' does not carry'
reset_fixture
set_conditional '{".github/workflows/go-checks.yml": {"No such step": ["if"]}}'
check_case 'a conditional entry naming no step fails' 1 "entry 'No such step' names 0 paired steps"
reset_fixture
set_conditional '{".github/workflows/go-checks.yml": {"Check out the PR head commit (not the synthetic merge ref)": ["if"]}}'
check_case 'a conditional entry naming an exempt step fails' 1 "entry 'Check out the PR head commit (not the synthetic merge ref)' names 0 paired steps"

reset_fixture
echo "test-check-ci-agreement: $passed cases passed, $failed failed"
((failed == 0))
