#!/usr/bin/env bash
# Regression tests for check-go-digest.sh over scratch copies of the two real files.
# Every case asserts both the exit status and the diagnostic, and each guard of the
# checker has a case that only that guard satisfies, so deleting any one guard turns
# a named case red. All cases run; the script exits 1 if any failed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/prifly-go-digest-tests.XXXXXX")"
# This exact mktemp-owned directory contains only generated fixtures.
trap 'rm -r -- "$fixture_dir"' EXIT
passed=0
failed=0
wf="$fixture_dir/.github/workflows/go-checks.yml"
reg="$fixture_dir/docs/reference/source-register.md"

reset_fixture() {
  mkdir -p "$(dirname "$wf")" "$(dirname "$reg")"
  cp "$REPO/.github/workflows/go-checks.yml" "$wf"
  cp "$REPO/docs/reference/source-register.md" "$reg"
}

# check_case NAME EXIT TEXT [ARG...]: run the checker (default args: --root <fixture>)
# and require exit status EXIT and a line of its output containing TEXT verbatim.
check_case() {
  local name="$1" expected="$2" text="$3" observed=0
  shift 3
  (($#)) || set -- --root "$fixture_dir"
  bash "$SCRIPT_DIR/check-go-digest.sh" "$@" >"$fixture_dir/output" 2>&1 || observed=$?
  if [[ "$observed" != "$expected" ]] || ! grep -qF -- "$text" "$fixture_dir/output"; then
    echo "FAIL: $name (expected exit $expected with '$text'; observed exit $observed)" >&2
    cat "$fixture_dir/output" >&2
    failed=$((failed + 1))
    return 0
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

m='GO_DIGEST_MISMATCH:'
reset_fixture
pin="$(sed -nE 's/^[[:space:]]*GO_ARCHIVE_SHA256:[[:space:]]*([0-9a-f]{64}).*/\1/p' "$wf")"
other="$(tr '0-9a-f' '1-9a-f0' <<<"$pin")"
check_case 'unmodified copies agree' 0 "check-go-digest: register Go toolchain row matches GO_ARCHIVE_SHA256 $pin"

check_case 'empty root is a usage error' 2 'usage:' --root ''
check_case 'nonexistent root is a usage error' 2 'usage:' --root "$fixture_dir/absent"
check_case 'unknown argument is a usage error' 2 'usage:' --root "$fixture_dir" --bogus

reset_fixture
sed -i "/^| Go toolchain/s/$pin/$other/" "$reg"
check_case 'mutated register digest fails' 1 "$m register row $other != go-checks.yml GO_ARCHIVE_SHA256 $pin"

reset_fixture
sed -i "s/GO_ARCHIVE_SHA256: $pin/GO_ARCHIVE_SHA256: $other/" "$wf"
check_case 'mutated workflow digest fails' 1 "$m register row $pin != go-checks.yml GO_ARCHIVE_SHA256 $other"

reset_fixture
sed -i "/^| Go toolchain/s/SHA-256 \`$pin\`/SHA-256 not recorded/" "$reg"
check_case 'missing register digest fails' 1 "$m no SHA-256 \`<64 hex>\` in the Go toolchain row"

reset_fixture
sed -i "/^| Go toolchain/s/SHA-256 \`$pin\`/& and SHA-256 \`$pin\`/" "$reg"
check_case 'second digest in the Go toolchain row fails' 1 "$m more than one SHA-256 in the Go toolchain row"

reset_fixture
sed -i '/GO_ARCHIVE_SHA256:/d' "$wf"
check_case 'missing workflow value fails' 1 "$m no GO_ARCHIVE_SHA256 in go-checks.yml"

reset_fixture
sed -i "s/GO_ARCHIVE_SHA256: $pin/GO_ARCHIVE_SHA256:/" "$wf"
check_case 'empty workflow value fails' 1 "$m GO_ARCHIVE_SHA256 in go-checks.yml is not 64 lowercase hex: ''"

reset_fixture
upper="$(tr 'a-f' 'A-F' <<<"$pin")"
sed -i "s/GO_ARCHIVE_SHA256: $pin/GO_ARCHIVE_SHA256: $upper/" "$wf"
check_case 'uppercase workflow value fails' 1 "$m GO_ARCHIVE_SHA256 in go-checks.yml is not 64 lowercase hex: '$upper'"

reset_fixture
sed -i "s/^\( *\)GO_ARCHIVE_SHA256: $pin/&\n\1GO_ARCHIVE_SHA256: $pin/" "$wf"
check_case 'repeated workflow value fails' 1 "$m more than one GO_ARCHIVE_SHA256 in go-checks.yml"

reset_fixture
sed -i "s/^\( *\)GO_ARCHIVE_SHA256: $pin/&\n\1# GO_ARCHIVE_SHA256: $other/" "$wf"
check_case 'commented-out workflow value is ignored' 0 "matches GO_ARCHIVE_SHA256 $pin"

reset_fixture
sed -i 's/^| Go toolchain/| Toolchain/' "$reg"
check_case 'missing Go toolchain row fails' 1 "$m no Go toolchain row in source-register.md"

reset_fixture
row="$(grep '^| Go toolchain' "$reg")"
printf '%s\n' "$row" >>"$reg"
check_case 'duplicate Go toolchain row fails' 1 "$m more than one Go toolchain row in source-register.md"

reset_fixture
printf '%s\n' '| Go toolchain (retired) | SHA-256 not recorded |' >>"$reg"
check_case 'second digestless Go toolchain row fails' 1 "$m more than one Go toolchain row in source-register.md"

reset_fixture
printf '%s\n' '| Other tool | see | Go toolchain row above |' '> | Go toolchain | quoted, not a row |' >>"$reg"
check_case 'mid-line Go toolchain text is not a row' 0 "matches GO_ARCHIVE_SHA256 $pin"

reset_fixture
rm "$wf"
check_case 'missing workflow file fails' 1 "$m missing $wf"

reset_fixture
rm "$reg"
check_case 'missing register file fails' 1 "$m missing $reg"

echo "test-check-go-digest: $passed cases passed, $failed failed"
((failed == 0))
