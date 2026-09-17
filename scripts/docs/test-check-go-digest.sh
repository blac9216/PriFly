#!/usr/bin/env bash
# Regression tests for check-go-digest.sh over scratch copies of the two real files.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/prifly-go-digest-tests.XXXXXX")"
# This exact mktemp-owned directory contains only generated fixtures.
trap 'rm -r -- "$fixture_dir"' EXIT
passed=0
wf="$fixture_dir/.github/workflows/go-checks.yml"
reg="$fixture_dir/docs/reference/source-register.md"

reset_fixture() {
  mkdir -p "$(dirname "$wf")" "$(dirname "$reg")"
  cp "$REPO/.github/workflows/go-checks.yml" "$wf"
  cp "$REPO/docs/reference/source-register.md" "$reg"
}

check_case() {
  local name="$1" expected="$2" observed=0
  bash "$SCRIPT_DIR/check-go-digest.sh" --root "$fixture_dir" >"$fixture_dir/output" 2>&1 || observed=$?
  if [[ "$observed" != "$expected" ]]; then
    echo "FAIL: $name (expected exit $expected; observed $observed)" >&2
    cat "$fixture_dir/output" >&2
    exit 1
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

reset_fixture
check_case 'unmodified copies agree' 0

reset_fixture
pin="$(sed -nE 's/^[[:space:]]*GO_ARCHIVE_SHA256:[[:space:]]*([0-9a-f]{64}).*/\1/p' "$wf")"
other="$(tr '0-9a-f' '1-9a-f0' <<<"$pin")"
sed -i "/^| Go toolchain/s/$pin/$other/" "$reg"
check_case 'mutated register digest fails' 1

reset_fixture
sed -i "s/GO_ARCHIVE_SHA256: $pin/GO_ARCHIVE_SHA256: $other/" "$wf"
check_case 'mutated workflow digest fails' 1

reset_fixture
sed -i "/^| Go toolchain/s/SHA-256 \`$pin\`/SHA-256 not recorded/" "$reg"
check_case 'missing register digest fails' 1

reset_fixture
sed -i '/GO_ARCHIVE_SHA256:/d' "$wf"
check_case 'missing workflow value fails' 1

reset_fixture
sed -i "s/GO_ARCHIVE_SHA256: $pin/GO_ARCHIVE_SHA256:/" "$wf"
check_case 'empty workflow value fails' 1

reset_fixture
sed -i 's/^| Go toolchain/| Toolchain/' "$reg"
check_case 'missing Go toolchain row fails' 1

reset_fixture
row="$(grep '^| Go toolchain' "$reg")"
printf '%s\n' "$row" >>"$reg"
check_case 'duplicate Go toolchain row fails' 1

reset_fixture
sed -i "s/^\( *\)GO_ARCHIVE_SHA256: $pin/&\n\1GO_ARCHIVE_SHA256: $pin/" "$wf"
check_case 'repeated workflow value fails' 1

reset_fixture
rm "$reg"
check_case 'missing register file fails' 1

echo "test-check-go-digest: $passed cases passed"
