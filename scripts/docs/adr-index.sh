#!/usr/bin/env bash
set -euo pipefail
ROOT=""; ADR_DIR="docs/adr"; MODE=print
while (($#)); do case "$1" in --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;; --adr-dir) ADR_DIR="$2"; shift 2;; --adr-dir=*) ADR_DIR="${1#*=}"; shift;; --check) MODE=check; shift;; --write) MODE=write; shift;; *) echo "usage: $0 --root R [--adr-dir D] [--check|--write]" >&2; exit 2;; esac; done
[[ -n "$ROOT" && -d "$ROOT" ]] || exit 2
ROOT="$(cd "$ROOT" && pwd)"; DIR="$ROOT/$ADR_DIR"; README="$DIR/README.md"
rows='| # | Title | Status | Supersedes | Superseded by | Amends | Amended by | Decision |\n|---|---|---|---|---|---|---|---|'
findings=0
shopt -s nullglob
for f in "$DIR"/[0-9][0-9][0-9][0-9]-*.md; do
  b="$(basename "$f")"; n="${b%%-*}"
  title="$(grep -m1 '^# ' "$f" | sed -E 's/^# ADR-[0-9]+: //')"
  status="$(head -n15 "$f" | sed -nE 's/^Status: ([A-Za-z]+)$/\1/p' | head -n1)"
  [[ "$status" =~ ^(Proposed|Accepted|Superseded|Deprecated)$ ]] || { echo "$b: ADR_BAD_STATUS invalid/missing Status" >&2; findings=1; }
  get(){ head -n15 "$f" | sed -nE "s/^$1: (.*)$/\\1/p" | head -n1; }
  sup="$(get Supersedes)"; sby="$(get Superseded-by)"; am="$(get Amends)"; aby="$(get Amended-by)"
  [[ -n "$sup" ]] || sup='-'; [[ -n "$sby" ]] || sby='-'; [[ -n "$am" ]] || am='-'; [[ -n "$aby" ]] || aby='-'
  decision="$(awk '/^## Decision$/{p=1;next} p&&/^## /{exit} p&&NF{print;exit}' "$f")"
  if ((${#decision}>100)); then cut="${decision:0:100}"; [[ "$cut" == *' '* ]] && cut="${cut% *}"; decision="$cut…"; fi
  decision="${decision//|/\\|}"
  rows+=$'\n'"| [$n]($b) | $title | $status | $sup | $sby | $am | $aby | $decision |"
done
shopt -u nullglob
((findings==0)) || [[ "$MODE" == write ]] || exit 1
case "$MODE" in
 print) printf '%b\n' "$rows";;
 check)
   [[ -f "$README" ]] || { echo "README.md: ADR_INDEX_DRIFT missing" >&2; exit 1; }
   body="$(sed -n '/<!-- adr-index:start -->/,/<!-- adr-index:end -->/p' "$README" | sed '1d;$d')"
   [[ "$body" == "$(printf '%b' "$rows")" ]] || { echo "README.md: ADR_INDEX_DRIFT generated table differs" >&2; exit 1; }
   echo "ADR index up to date";;
 write)
   tmp="$(mktemp)"; awk -v block="$(printf '%b' "$rows")" 'BEGIN{p=1} /<!-- adr-index:start -->/{print; print block; p=0; next} /<!-- adr-index:end -->/{p=1; print; next} p{print}' "$README" > "$tmp"; mv "$tmp" "$README";;
esac
