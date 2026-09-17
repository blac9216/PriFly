#!/usr/bin/env bash
# Fails unless the Go toolchain row of the dependency inventory restates exactly the
# GO_ARCHIVE_SHA256 pinned in go-checks.yml. Fails closed: a missing file, a missing,
# repeated or malformed value on either side is a failure, not a pass.
set -euo pipefail
ROOT=""
while (($#)); do case "$1" in --root) ROOT="${2:-}"; shift; (($#)) && shift;; --root=*) ROOT="${1#*=}"; shift;; *) echo "usage: $0 --root R" >&2; exit 2;; esac; done
[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "usage: $0 --root R" >&2; exit 2; }
WORKFLOW="$ROOT/.github/workflows/go-checks.yml"
REGISTER="$ROOT/docs/reference/source-register.md"
fail() { echo "GO_DIGEST_MISMATCH: $*" >&2; exit 1; }
[[ -f "$WORKFLOW" ]] || fail "missing $WORKFLOW"
[[ -f "$REGISTER" ]] || fail "missing $REGISTER"

pins="$(grep -E '^[[:space:]]*GO_ARCHIVE_SHA256:' "$WORKFLOW" || true)"
[[ -n "$pins" ]] || fail "no GO_ARCHIVE_SHA256 in go-checks.yml"
(( $(wc -l <<<"$pins") == 1 )) || fail "more than one GO_ARCHIVE_SHA256 in go-checks.yml"
pin="$(sed -E 's/^[[:space:]]*GO_ARCHIVE_SHA256:[[:space:]]*//; s/[[:space:]]+$//' <<<"$pins")"
[[ "$pin" =~ ^[0-9a-f]{64}$ ]] || fail "GO_ARCHIVE_SHA256 in go-checks.yml is not 64 lowercase hex: '$pin'"

rows="$(grep -E '^\| Go toolchain' "$REGISTER" || true)"
[[ -n "$rows" ]] || fail "no Go toolchain row in source-register.md"
(( $(wc -l <<<"$rows") == 1 )) || fail "more than one Go toolchain row in source-register.md"
# shellcheck disable=SC2016 # literal backticks, not command substitution
digests="$(grep -oE 'SHA-256 `[0-9a-f]{64}`' <<<"$rows" || true)"
[[ -n "$digests" ]] || fail "no SHA-256 \`<64 hex>\` in the Go toolchain row"
(( $(wc -l <<<"$digests") == 1 )) || fail "more than one SHA-256 in the Go toolchain row"
row="$(tr -d '`' <<<"${digests#SHA-256 }")"

[[ "$row" == "$pin" ]] || fail "register row $row != go-checks.yml GO_ARCHIVE_SHA256 $pin"
echo "check-go-digest: register Go toolchain row matches GO_ARCHIVE_SHA256 $pin"
