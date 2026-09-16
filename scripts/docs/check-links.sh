#!/usr/bin/env bash
set -euo pipefail

ROOT=""
while (($#)); do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    -h|--help) echo "usage: $0 --root R"; exit 0 ;;
    *) echo "check-links: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "check-links: --root must name a directory" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

python3 - "$ROOT" <<'PY'
from __future__ import annotations
import functools, pathlib, re, sys, urllib.parse

root = pathlib.Path(sys.argv[1])
findings: list[str] = []
link_re = re.compile(r'(?<!!)\[[^\]]*\]\(([^)]+)\)')
heading_re = re.compile(r'^(#{1,6})\s+(.+?)\s*$')
# Stable custom anchors are used by the accepted PRD's section/figure/source IDs.
# Match standalone empty anchors, not examples inside prose or inline code.
custom_anchor_re = re.compile(r'''^ {0,3}<a\s+(?:id|name)=(['"])([^'"]+)\1\s*>\s*</a>\s*$''')
fence_re = re.compile(r'^ {0,3}(`{3,}|~{3,})(.*)$')

def slugify(text: str) -> str:
    text = re.sub(r'\s+#+\s*$', '', text.strip()).lower()
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'[`*_~]', '', text)
    text = re.sub(r'[^\w\- ]', '', text, flags=re.UNICODE)
    text = re.sub(r'\s+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')

@functools.lru_cache(maxsize=None)
def anchors(path: pathlib.Path) -> set[str]:
    result: set[str] = set()
    counts: dict[str, int] = {}
    fence: tuple[str, int] | None = None
    try:
        lines = path.read_text(encoding='utf-8').splitlines()
    except UnicodeDecodeError:
        return result
    for line in lines:
        marker = fence_re.match(line)
        if fence:
            if (marker and marker.group(1)[0] == fence[0]
                    and len(marker.group(1)) >= fence[1] and not marker.group(2).strip()):
                fence = None
            continue
        if marker:
            fence = (marker.group(1)[0], len(marker.group(1)))
            continue
        custom = custom_anchor_re.match(line)
        if custom:
            result.add(custom.group(2))
            continue
        m = heading_re.match(line)
        if not m:
            continue
        base = slugify(m.group(2))
        if not base:
            continue
        n = counts.get(base, 0)
        counts[base] = n + 1
        result.add(base if n == 0 else f'{base}-{n}')
    return result

for md in sorted(root.rglob('*.md')):
    if '.git' in md.parts:
        continue
    rel = md.relative_to(root)
    text = md.read_text(encoding='utf-8')
    for line_no, line in enumerate(text.splitlines(), 1):
        for raw in link_re.findall(line):
            target = raw.strip()
            if target.startswith('<') and target.endswith('>'):
                target = target[1:-1]
            if not target or target.startswith(('http://','https://','mailto:')):
                continue
            target = urllib.parse.unquote(target)
            path_part, sep, frag = target.partition('#')
            if path_part:
                resolved = (md.parent / path_part).resolve()
                try:
                    resolved.relative_to(root)
                except ValueError:
                    findings.append(f'{rel}:{line_no}: LINK_OUTSIDE_ROOT {target}')
                    continue
                if not resolved.exists():
                    findings.append(f'{rel}:{line_no}: LINK_MISSING_FILE {target}')
                    continue
                target_file = resolved
                if target_file.is_dir():
                    target_file = target_file / 'README.md'
                    if not target_file.exists():
                        # Directory links are allowed when they are intentionally navigational.
                        if not frag:
                            continue
                        findings.append(f'{rel}:{line_no}: LINK_MISSING_FILE {target}')
                        continue
            else:
                target_file = md
            if sep and frag:
                if frag not in anchors(target_file):
                    findings.append(f'{rel}:{line_no}: LINK_MISSING_FRAGMENT {target}')

for item in findings:
    print(item)
print(f'check-links: {len(findings)} findings', file=sys.stderr)
sys.exit(1 if findings else 0)
PY
