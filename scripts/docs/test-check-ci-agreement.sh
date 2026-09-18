#!/usr/bin/env bash
# Regression tests for check-ci-agreement.sh over scratch copies of the four files it
# reads and, for the exemption cases, of the checker itself. Every case asserts both the
# exit status and the diagnostic, so a checker that started exiting non-zero for the
# wrong reason would not pass. Each mutation #337 names has a case here, and each
# exemption entry has a case that only that entry satisfies, so deleting any one entry
# turns a named case red. Each mutation #347 and #348 name has a case too, including the
# one #347 M3 records as a limit rather than a defect, and the three written lists those
# two issues add are each proved to rot in both directions. Each mutation #353 names has a
# case as well -- one per scope above the step, one per exempt-step key that decides
# whether it runs, and the two limits that issue records rather than closes. All cases
# run; the script exits 1 if any failed.
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

# set_list NAME LITERAL: copy the checker with its `NAME = [...]` line replaced by the
# Python list literal LITERAL, and point the next case at that copy. This is how a scope
# key list is proved to rot: every entry of those names a key the tree carries.
set_list() {
  awk -v name="$1" -v literal="$2" '
    index($0, name " = [") == 1 { print name " = " literal; next }
    { print }
  ' "$SCRIPT_DIR/check-ci-agreement.sh" >"$fixture_dir/checker.sh"
  checker="$fixture_dir/checker.sh"
}

# also_reject NAME TEXT: the mirror of also_expect, for a case whose point is that one
# diagnostic is absent from the output a check_case above already required. The blank-line
# case below is why: a reader that stopped at a blank line inside a block scalar would
# report the right finding for the blank line and lose every step after it, so the case
# has to require both the finding and the absence of the losses.
also_reject() {
  local name="$1" text="$2"
  if grep -qF -- "$text" "$fixture_dir/output"; then
    echo "FAIL: $name (the last output contains '$text')" >&2
    cat "$fixture_dir/output" >&2
    failed=$((failed + 1))
    return 0
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

# set_declared_content LITERAL: copy the checker with its declared exempt content dict
# replaced by the Python dict literal LITERAL, and point the next case at that copy. The
# entry side of that list needs this, because a workflow file cannot express an entry
# naming a step or a key it does not carry.
set_declared_content() {
  awk -v literal="$1" '
    index($0, "DECLARED_EXEMPT_CONTENT: ") == 1 { print "DECLARED_EXEMPT_CONTENT = " literal; skipping = 1; next }
    skipping && $0 == "}" { skipping = 0; next }
    skipping { next }
    { print }
  ' "$SCRIPT_DIR/check-ci-agreement.sh" >"$fixture_dir/checker.sh"
  checker="$fixture_dir/checker.sh"
}

# set_declared_env LITERAL: copy the checker with its declared job environment dict
# replaced by the Python dict literal LITERAL, and point the next case at that copy.
set_declared_env() {
  awk -v literal="$1" '
    index($0, "DECLARED_JOB_ENV = {") == 1 { print "DECLARED_JOB_ENV = " literal; skipping = 1; next }
    skipping && $0 == "}" { skipping = 0; next }
    skipping { next }
    { print }
  ' "$SCRIPT_DIR/check-ci-agreement.sh" >"$fixture_dir/checker.sh"
  checker="$fixture_dir/checker.sh"
}

reset_fixture
check_case 'unmodified copies agree' 0 'workflow steps agree with their documented commands'
also_expect 'unmodified copies account for every key of both scopes' '2 job scopes and 2 workflow scopes carry no unaccounted-for key'
also_expect 'unmodified copies use the live job environment declaration' '2 job environment variables are declared and in use'
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

# --- #353 M1: a documented step switched off from the job mapping ---------------------
reset_fixture
sed -i 's@^  go:$@  go:\n    if: ${{ github.event_name == null }}@' "$wf_go"
check_case 'a never-firing if on the go job fails' 1 "go-checks.yml job 'go' carries if: \${{ github.event_name == null }}"
also_expect 'the job condition says what it decides' 'which decides whether the steps beneath it run or whether their failure blocks'
also_expect 'the job condition names the documents it disagrees with' 'while docs/process/testing.md documents them as steps that run'

reset_fixture
sed -i 's@^  design-docs:$@  design-docs:\n    continue-on-error: true@' "$wf_docs"
check_case 'continue-on-error on the design-docs job fails' 1 "docs-checks.yml job 'design-docs' carries continue-on-error: true"

# The live job env block is legitimate, so it is declared rather than banned: the
# declaration pins the value, and widening it is red.
reset_fixture
sed -i 's@^      GOFLAGS: -mod=readonly$@      GOFLAGS: -mod=readonly -tags=skip@' "$wf_go"
check_case 'a widened job environment value fails' 1 "declared job environment entry 'GOFLAGS' of .github/workflows/go-checks.yml job 'go' declares '-mod=readonly'"
also_expect 'the widened value says what the job now sets' "but the job sets '-mod=readonly -tags=skip'"

reset_fixture
sed -i 's@^      GOTOOLCHAIN: local$@      GOTOOLCHAIN: local\n      GOPROXY: off@' "$wf_go"
check_case 'an undeclared job environment variable fails' 1 "job 'go' sets env GOPROXY: off"
also_expect 'the undeclared variable says the list did not cover it' "no entry in the checker's declared job environment list covers it"

# A variable line the reader cannot read is an error, not an absent variable: absent is
# what a clean scope looks like, so dropping it would let a quoted name, an odd indent or a
# merge key set a variable the declaration comparison never sees. Round 1 of review found
# all three green, the quoted name overriding the very GOFLAGS value the list pins.
reset_fixture
sed -i 's@^      GOFLAGS: -mod=readonly$@      GOFLAGS: -mod=readonly\n      "GOFLAGS": -mod=mod@' "$wf_go"
check_case 'a quoted variable name in the declared job env fails' 3 "go-checks.yml job 'go' holds a line under env: that this checker cannot read as a variable"
also_expect 'the unreadable variable says why it is not skipped' 'so it cannot compare it with the list that says which variables the scope may set'
also_expect 'the unreadable variable quotes the line' '"GOFLAGS": -mod=mod'

reset_fixture
sed -i 's@^  design-docs:$@  design-docs:\n    env:\n        PATH: /tmp/shim:/usr/bin:/bin@' "$wf_docs"
check_case 'a job env variable at the wrong indent fails' 3 "docs-checks.yml job 'design-docs' holds a line under env: that this checker cannot read as a variable"

reset_fixture
sed -i 's@^permissions:$@env:\n  "GOPROXY": off\npermissions:@' "$wf_go"
check_case 'a quoted variable name at workflow scope fails' 3 '.github/workflows/go-checks.yml workflow scope holds a line under env: that this checker cannot read as a variable'

# --- #353 M1: and from the workflow mapping, which declares no environment ------------
reset_fixture
sed -i 's@^permissions:$@env:\n  GOPROXY: off\npermissions:@' "$wf_go"
check_case 'a workflow-level env in go-checks fails' 1 '.github/workflows/go-checks.yml workflow scope sets env: GOPROXY: off'
also_expect 'the workflow env says why no declaration covers it' 'this checker declares no environment at that scope'

reset_fixture
sed -i 's@^permissions:$@env:\n  GOFLAGS: -mod=mod\npermissions:@' "$wf_docs"
check_case 'a workflow-level env in docs-checks fails' 1 '.github/workflows/docs-checks.yml workflow scope sets env: GOFLAGS: -mod=mod'

# --- #353 M2: every key of the two mappings is accounted for, not just three ----------
reset_fixture
sed -i 's@^    timeout-minutes: 25$@    timeout-minutes: 25\n    defaults:\n      run:\n        working-directory: .@' "$wf_go"
check_case 'an unrecognised job key fails' 3 "job 'go' carries defaults:, which this checker does not recognise at that scope"
also_expect 'the unrecognised job key says it was not skipped' 'so it is not skipped'
also_expect 'the unrecognised job key names both lists' 'neither permitted (runs-on, timeout-minutes, steps) nor load-bearing (if, continue-on-error, env)'

reset_fixture
sed -i 's@^    timeout-minutes: 10$@    timeout-minutes: 10\n    uses: ./.github/workflows/elsewhere.yml@' "$wf_docs"
check_case 'a paired job turned into a reusable workflow call fails' 3 "job 'design-docs' carries uses:, which this checker does not recognise at that scope"

reset_fixture
sed -i 's@^permissions:$@concurrency: one-at-a-time\npermissions:@' "$wf_go"
check_case 'an unrecognised workflow key fails' 3 'workflow scope carries concurrency:, which this checker does not recognise at that scope'

# --- #353 M3: an exempt step is unpaired, not unread ----------------------------------
reset_fixture
sed -i 's@^      - name: Install pinned Go toolchain (verify SHA-256, then extract)$@      - name: Install pinned Go toolchain (verify SHA-256, then extract)\n        if: ${{ github.event_name == null }}@' "$wf_go"
check_case 'a never-firing if on the exempt toolchain step fails' 1 "exempt step 'Install pinned Go toolchain (verify SHA-256, then extract)' carries if: \${{ github.event_name == null }}"
also_expect 'the exempt condition says why an exempt step is still read' 'while the steps docs/process/testing.md documents run only because this one has'

reset_fixture
sed -i 's@^      - name: Restore Go module cache (keyed by go.sum)$@      - name: Restore Go module cache (keyed by go.sum)\n        continue-on-error: true@' "$wf_go"
check_case 'continue-on-error on an exempt step fails' 1 "exempt step 'Restore Go module cache (keyed by go.sum)' carries continue-on-error: true"

reset_fixture
sed -i 's@^      - name: Check out the PR head commit (not the synthetic merge ref)$@      - name: Check out the PR head commit (not the synthetic merge ref)\n        shell: bash@' "$wf_docs"
check_case 'an unrecognised key on an exempt step fails' 3 'exempt step '"'"'Check out the PR head commit (not the synthetic merge ref)'"'"' carries shell:, which this checker does not recognise on an exempt step'

# The exempt toolchain step's own env: is declared by name; the unmutated tree above proves
# it stays green with the block as written. Its entry in the declared list is live, so
# deleting it is red.
reset_fixture
set_list EXEMPT_DECLARED '["uses", "with", "run"]'
check_case 'dropping env from the exempt declared list fails' 3 "exempt step 'Install pinned Go toolchain (verify SHA-256, then extract)' carries env:"

# timeout-minutes is permitted on an exempt step for the reason it is permitted on a paired
# one: it can only make the step fail sooner, never stop it running or stop it blocking.
reset_fixture
sed -i 's@^      - name: Restore Go module cache (keyed by go.sum)$@      - name: Restore Go module cache (keyed by go.sum)\n        timeout-minutes: 5@' "$wf_go"
check_case 'timeout-minutes on an exempt step still passes' 0 'workflow steps agree with their documented commands'

# --- #358: an exempt step's uses:, with: and run: are declared, not permitted ---------
# Each of the four mutations #358 measured as exit 0 with the summary line byte-identical
# has a case here. A, C and D are lines of the toolchain install step's run:; B is the
# checkout step's ref:, in both files.

# C, the case no document, comment or sibling guard named: the pinned archive is still
# downloaded, still checksummed and still extracted, and two appended lines then replace
# the binary the checksum covered.
reset_fixture
sed -i 's@GITHUB_PATH"$@GITHUB_PATH"\n          echo "#!/bin/sh" > "$RUNNER_TEMP/go/bin/go"\n          echo "exit 0" >> "$RUNNER_TEMP/go/bin/go"@' "$wf_go"
check_case 'a shim written over the extracted toolchain fails' 1 "exempt step 'Install pinned Go toolchain (verify SHA-256, then extract)' writes line 9 of run:"
also_expect 'the shim finding names the line that replaces the extracted binary' 'go/bin/go"'
also_expect 'the shim finding names the second appended line too' 'writes line 10 of run:'

# A, the route the header recorded before this change and left undecided.
reset_fixture
sed -i 's@GITHUB_PATH"$@GITHUB_PATH"\n          echo "GOFLAGS=-mod=mod" >> "$GITHUB_ENV"@' "$wf_go"
check_case 'a GITHUB_ENV write appended to the exempt install step fails' 1 "exempt step 'Install pinned Go toolchain (verify SHA-256, then extract)' writes line 9 of run:"
also_expect 'the GITHUB_ENV finding names the appended write' 'GOFLAGS=-mod=mod'

# D: the whole install replaced by a command that installs nothing, with the env: block
# its sibling guard reads left in place.
reset_fixture
python3 - "$wf_go" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
lines = path.read_text().split("\n")
start = lines.index("        run: |")
end = start + 1
while lines[end].startswith("          "):
    end += 1
path.write_text("\n".join(lines[:start] + ["        run: true"] + lines[end:]))
PY
check_case 'replacing the exempt install run: with a no-op fails' 1 "declared exempt content entry 'Install pinned Go toolchain (verify SHA-256, then extract)' of .github/workflows/go-checks.yml declares line 1 of run:"
also_expect 'the no-op finding names a line the step no longer writes' 'which the step does not write'

# B, in both files. docs-checks.yml is the file #146's second criterion governs, and its
# step name asserts what this mutation defeats.
reset_fixture
sed -i 's@^          ref: .*$@          ref: main@' "$wf_docs"
check_case 'a changed checkout ref in docs-checks.yml fails' 1 "declared exempt content entry 'Check out the PR head commit (not the synthetic merge ref)' of .github/workflows/docs-checks.yml declares with ref:"
also_expect 'the changed ref finding names what the step sets instead' "but the step sets 'main'"

reset_fixture
sed -i 's@^          ref: .*$@          ref: main@' "$wf_go"
check_case 'a changed checkout ref in go-checks.yml fails' 1 "declared exempt content entry 'Check out the PR head commit (not the synthetic merge ref)' of .github/workflows/go-checks.yml declares with ref:"

# The rest of what a declared key covers: the action a step runs, the version comment
# pinned beside it, a with: key added, and a with: key removed.
reset_fixture
sed -i 's|actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1|actions/checkout@0000000000000000000000000000000000000000|' "$wf_docs"
check_case 'a changed checkout action SHA fails' 1 "declares uses:"
reset_fixture
sed -i 's|# v7.0.1|# v7.0.99|' "$wf_docs"
check_case 'a changed version comment beside a pinned action fails' 1 "declares uses:"
reset_fixture
sed -i 's@^          persist-credentials: false$@          persist-credentials: false\n          fetch-depth: 0@' "$wf_docs"
check_case 'a with: key no entry declares fails' 1 "sets with fetch-depth: 0, which no entry in the checker's declared exempt content list covers"
reset_fixture
sed -i '/^          persist-credentials: false$/d' "$wf_docs"
check_case 'a declared with: key the step stops setting fails' 1 "declares with persist-credentials:, which the step does not set"

# A line under with: that the reader cannot read as a key is an error, not an absent key,
# for the reason the same rule holds under env:: absent is what declaring nothing looks
# like, so a quoted key would otherwise set a value the comparison never sees.
reset_fixture
sed -i 's@^          persist-credentials: false$@          persist-credentials: false\n          "ref": main@' "$wf_docs"
check_case 'an unreadable line under with: is an error' 3 "step 'Check out the PR head commit (not the synthetic merge ref)' holds a line under with: that this checker cannot read as a key"

# An exempt step cannot gain a run: without the list moving.
reset_fixture
sed -i 's@^      - name: Restore Go module cache (keyed by go.sum)$@      - name: Restore Go module cache (keyed by go.sum)\n        run: true@' "$wf_go"
check_case 'an exempt step that gains a run: no entry declares fails' 1 "exempt step 'Restore Go module cache (keyed by go.sum)' carries run:, which decides what the step installs"

# A blank line inside a block scalar belongs to it. A reader that stopped there would
# report this finding and lose every step after it, so the case requires both.
reset_fixture
sed -i 's@^          set -euo pipefail$@          set -euo pipefail\n@' "$wf_go"
check_case 'a blank line inside the exempt block scalar fails' 1 "declares line 3 of run:"
also_reject 'the blank line does not cost the reader the steps below it' 'has no step in .github/workflows/go-checks.yml'

# Round 1 of this change's review: a name added to the exempt install step's env: block
# changes which binaries its declared run: lines execute, and was exit 0 at every guard
# under scripts/docs/ while that block was read as a census rather than against a list. The
# names are declared now, so each of these is red.
reset_fixture
sed -i 's@^          GO_ARCHIVE_SHA256: .*$@&\n          PATH: /tmp/shims:/usr/local/bin:/usr/bin:/bin@' "$wf_go"
check_case 'a PATH added to the exempt install env: fails' 1 "exempt step 'Install pinned Go toolchain (verify SHA-256, then extract)' sets env PATH:"
also_expect 'the added-name finding says what an undeclared name reaches' "can change what the step's own commands see"
reset_fixture
sed -i 's@^          GO_ARCHIVE_SHA256: .*$@&\n          LD_PRELOAD: /tmp/shim.so@' "$wf_go"
check_case 'an LD_PRELOAD added to the exempt install env: fails' 1 "exempt step 'Install pinned Go toolchain (verify SHA-256, then extract)' sets env LD_PRELOAD:"
reset_fixture
sed -i '/^          GO_ARCHIVE: go1/d' "$wf_go"
check_case 'a declared env name the step stops setting fails' 1 "names env GO_ARCHIVE:, which the step does not set"

# A name the reader cannot read is an error, not an absent name: the shape PR #355's round 1
# found live at job scope, here at exempt-step scope, where the name list is what it would
# evade.
reset_fixture
sed -i 's@^          GO_ARCHIVE_SHA256: .*$@&\n          "PATH": /tmp/shims@' "$wf_go"
check_case 'an unreadable name under an exempt env: is an error' 3 "step 'Install pinned Go toolchain (verify SHA-256, then extract)' holds a line under env: that this checker cannot read as a key"

# The entry side of the declared exempt content list, which no workflow file can express.
reset_fixture
set_declared_content '{".github/workflows/docs-checks.yml": {"Check out the PR head commit (not the synthetic merge ref)": {"run": "true"}}}'
check_case 'an entry declaring a key the step does not carry fails' 1 "declares run:, which the step does not carry"
reset_fixture
set_declared_content '{".github/workflows/docs-checks.yml": {"Check out the PR head commit (not the synthetic merge ref)": {"shell": "bash"}}}'
check_case 'an entry declaring a key outside the exempt declared list fails' 3 'the declared exempt content list declares shell: on .github/workflows/docs-checks.yml exempt step'
reset_fixture
set_declared_content '{".github/workflows/docs-checks.yml": {"Rationale-index pointers resolve": {"run": "true"}}}'
check_case 'an entry naming a step that is not exempt fails' 3 "the declared exempt content list names .github/workflows/docs-checks.yml step 'Rationale-index pointers resolve', which is not on the exemption list"
reset_fixture
set_declared_content '{".github/workflows/go-checks.yml": {"Restore Go module cache (keyed by go.sum)": {"env": ["GO_ARCHIVE"]}}}'
check_case 'an entry naming env variables on a step with no env: block fails' 1 "declares env:, which the step does not carry"
reset_fixture
set_declared_content '{".github/workflows/absent.yml": {}}'
check_case 'an entry naming a file this checker does not pair fails' 3 'the declared exempt content list names .github/workflows/absent.yml, which this checker does not pair'

# The exempt declared list itself rots in all three directions its entries have: uses and
# with are keys the tree carries, and run is live through the entry side instead.
reset_fixture
set_list EXEMPT_DECLARED '["with", "run", "env"]'
check_case 'dropping uses from the exempt declared list fails' 3 "exempt step 'Check out the PR head commit (not the synthetic merge ref)' carries uses:"
reset_fixture
set_list EXEMPT_DECLARED '["uses", "run", "env"]'
check_case 'dropping with from the exempt declared list fails' 3 "exempt step 'Check out the PR head commit (not the synthetic merge ref)' carries with:"
reset_fixture
set_list EXEMPT_DECLARED '["uses", "with", "env"]'
check_case 'dropping run from the exempt declared list fails' 3 'the declared exempt content list declares run: on .github/workflows/go-checks.yml exempt step'

# --- #353: the declared job environment list is load-bearing in both directions -------
reset_fixture
sed -i '/^      GOTOOLCHAIN: local$/d' "$wf_go"
check_case 'a declared variable the job no longer sets fails' 1 "declared job environment entry 'GOTOOLCHAIN' names a variable .github/workflows/go-checks.yml job 'go' does not set"
reset_fixture
sed -i '/^    env:$/,+2d' "$wf_go"
check_case 'a declared job that drops its env block fails' 1 "declared job environment entry 'GOFLAGS' names .github/workflows/go-checks.yml job 'go', which sets no env: block"
reset_fixture
set_declared_env '{".github/workflows/go-checks.yml": {"absent": {"GOTOOLCHAIN": "local"}}}'
check_case 'a declared environment entry naming an unpaired job fails' 3 'the declared job environment list names .github/workflows/go-checks.yml job absent, which this checker does not pair'

# --- #353 F4: the scope key lists name live keys, so they rot in both directions ------
# Every entry of both permitted lists names a key this tree carries, unlike the step-scope
# attribute lists, whose if, continue-on-error, run and name entries name classes of
# possible edit. Deleting a live entry is exit 3 with no other change to the tree.
reset_fixture
set_list JOB_PERMITTED '["timeout-minutes", "steps"]'
check_case 'dropping runs-on from the job permitted list fails' 3 "job 'design-docs' carries runs-on:, which this checker does not recognise at that scope"
reset_fixture
set_list JOB_LOAD_BEARING '["if", "continue-on-error"]'
check_case 'dropping env from the job load-bearing list fails' 3 "job 'go' carries env:, which this checker does not recognise at that scope"
reset_fixture
set_list WORKFLOW_PERMITTED '["name", "on", "permissions"]'
check_case 'dropping jobs from the workflow permitted list fails' 3 'workflow scope carries jobs:, which this checker does not recognise at that scope'

# The step-scope attribute lists rot only on a tree that carries the key, which is what the
# header now says and what #353 F4 asked to be made exact: timeout-minutes occurs at job
# scope only, so its entry is exercised only once a paired step carries it.
reset_fixture
sed -i 's@^        run: go vet ./...$@        timeout-minutes: 5\n        run: go vet ./...@' "$wf_go"
set_list PERMITTED_ATTRIBUTES '["name", "run"]'
check_case 'dropping timeout-minutes on a tree that carries it fails' 3 "step 'go vet' carries timeout-minutes:, which this checker does not recognise on a paired step"

# --- #353 M4: the manifest limit, pinned rather than closed ---------------------------
# Recorded in the header, not a defect: the check proves an entry's tokens appear in the
# step's run: as whole path components, so an entry narrowed to a bare interpreter name
# passes while one narrowed to a neighbouring script's name (above) fails. If a later
# change starts proving the entry names the step's script, this case turns red and the
# header is what has to be corrected with it.
reset_fixture
sed -i 's@^6. `test-check-links.sh`@6. `bash`@' "$manifest"
check_case 'a manifest entry narrowed to a bare interpreter name passes, as the header records' 0 'workflow steps agree with their documented commands'

reset_fixture
echo "test-check-ci-agreement: $passed cases passed, $failed failed"
((failed == 0))
