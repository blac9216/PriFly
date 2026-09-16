#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/prifly-link-tests.XXXXXX")"
# This exact mktemp-owned directory contains only generated fixtures.
trap 'rm -r -- "$fixture_dir"' EXIT
passed=0

check_case() {
  local name="$1" expected="$2" observed=0
  bash "$SCRIPT_DIR/check-links.sh" --root "$fixture_dir" >"$fixture_dir/output" 2>&1 || observed=$?
  if [[ "$observed" != "$expected" ]]; then
    echo "FAIL: $name (expected exit $expected; observed $observed)" >&2
    cat "$fixture_dir/output" >&2
    exit 1
  fi
  echo "PASS: $name"
  passed=$((passed + 1))
}

printf '%s\n' '# Target' '<a id="section-1"></a>' "<a name='figure-01'></a>" '# Repeated' '# Repeated' >"$fixture_dir/target.md"
printf '%s\n' '[ID](target.md#section-1)' '[name](target.md#figure-01)' '[heading](target.md#target)' '[repeat](target.md#repeated-1)' >"$fixture_dir/README.md"
check_case 'custom IDs/names and generated heading anchors resolve' 0

printf '%s\n' '[local](#local-id)' '<a id="local-id"></a>' >"$fixture_dir/README.md"
check_case 'same-file custom anchor resolves' 0

printf '%s\n' '[missing](target.md#unknown)' >"$fixture_dir/README.md"
check_case 'missing fragment remains an error' 1

printf '%s\n' '[missing](missing.md)' >"$fixture_dir/README.md"
check_case 'missing file remains an error' 1

printf '%s\n' '[example](#example)' '```html' '<a id="example"></a>' '```' >"$fixture_dir/README.md"
check_case 'fenced anchor example does not create a target' 1

printf '%s\n' '[example](#example)' '`<a id="example"></a>`' >"$fixture_dir/README.md"
check_case 'inline anchor example does not create a target' 1

printf '%s\n' '[case](target.md#SECTION-1)' >"$fixture_dir/README.md"
check_case 'custom anchor case must match' 1

printf '%s\n' '[bad](#bad)' '<a id="bad></a>' >"$fixture_dir/README.md"
check_case 'malformed anchor does not create a target' 1

echo "test-check-links: $passed cases passed"
