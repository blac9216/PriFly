#!/usr/bin/env bash
set -euo pipefail
ROOT=""; FORMAT=text
while (($#)); do case "$1" in --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;; --format) FORMAT="$2"; shift 2;; --format=*) FORMAT="${1#*=}"; shift;; *) echo "usage: $0 --root R [--format text|json]" >&2; exit 2;; esac; done
[[ -n "$ROOT" && -d "$ROOT" ]] || exit 2
ROOT="$(cd "$ROOT" && pwd)"; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
cd "$ROOT"
while IFS=: read -r file line rest; do
  [[ -n "$file" ]] || continue
  ptr="$(grep -oE 'docs/rationale/[^ )]+\.md#[a-z0-9-]+' <<<"$rest" | head -n1 || true)"; [[ -n "$ptr" ]] || continue
  path="${ptr%%#*}"; slug="${ptr#*#}"
  [[ -f "$path" ]] || { echo "$file:$line: POINTER_BAD_FILE $path" >> "$tmp"; continue; }
  grep -qxF "### $slug" "$path" || echo "$file:$line: POINTER_UNRESOLVED $ptr" >> "$tmp"
done < <(grep -rInE '(#|//|<!--)[[:space:]]*why:[[:space:]]*docs/rationale/[^ )]+\.md#[a-z0-9-]+' . --exclude-dir=.git || true)
for f in docs/rationale/*.md; do [[ -e "$f" ]] || continue; awk -v file="$f" '
/^### /{if(active)finish(); slug=$0; sub(/^### /,"",slug); if(seen[slug]++) print file ":" NR ": SLUG_DUPLICATE " slug; active=1; body=0; refs=0; next}
/^## /{if(active)finish(); active=0; next}
active&&/^Refs:/{refs=1;next} active&&NF{body++}
END{if(active)finish()}
function finish(){if(body<2||body>6) print file ": ENTRY_LENGTH " slug " has " body " body lines"; if(!refs) print file ": ENTRY_NO_REFS " slug}
' "$f" >> "$tmp"; done
count="$(wc -l < "$tmp" | tr -d ' ')"; cat "$tmp"; echo "check-pointers: $count findings" >&2; ((count==0))
