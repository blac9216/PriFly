#!/usr/bin/env bash
set -euo pipefail
ROOT=""; OUT=""
while (($#)); do case "$1" in --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;; --out) OUT="$2"; shift 2;; --out=*) OUT="${1#*=}"; shift;; *) echo "usage: $0 --root R --out PATH" >&2; exit 2;; esac; done
[[ -n "$ROOT" && -d "$ROOT" && -n "$OUT" ]] || exit 2
ROOT="$(cd "$ROOT" && pwd)"; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
[[ -f "$ROOT/docs/doc-manifest.md" ]] || { echo 'docs/doc-manifest.md MANIFEST_MISSING' > "$tmp"; }
bash "$(dirname "$0")/check-pointers.sh" --root "$ROOT" >>"$tmp" 2>/dev/null || true
bash "$(dirname "$0")/adr-index.sh" --root "$ROOT" --check >>/dev/null 2>"$tmp.adr" || cat "$tmp.adr" >> "$tmp"; rm -f "$tmp.adr"
for f in "$ROOT"/docs/{tutorials,how-to,reference,explanation}/*.md; do [[ -e "$f" ]] || continue; kind="$(basename "$(dirname "$f")")"; grep -q "^Kind: $kind$" "$f" || echo "${f#$ROOT/} DOC_KIND_MISMATCH" >> "$tmp"; done
arch="$ROOT/docs/explanation/architecture.md"; if [[ -f "$arch" ]]; then for h in Context Container Component; do grep -q "^## $h$" "$arch" || echo "docs/explanation/architecture.md ARCH_MISSING_LEVEL $h" >> "$tmp"; done; fi
count="$(grep -c . "$tmp" || true)"; { echo "# design-docs gap report — $(basename "$ROOT") — $(date +%F)"; echo; echo 'Ephemeral. Lives in scratch; never committed.'; echo; echo '## Summary'; echo "Tier 1 findings: $count"; echo; echo '## Tier 1 — mechanical'; cat "$tmp"; echo; echo '## Tier 2 — cross-reference (agent tasks)'; echo '- Dead citations'; echo '- Layout table vs tree'; echo '- Container names vs topology'; echo '- Superseded ADR cited as authority'; echo '- Glossary synonyms in use'; } > "$OUT"
echo "$OUT"; echo "audit: Tier 1 findings: $count"; ((count==0))
