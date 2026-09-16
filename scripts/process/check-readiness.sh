#!/usr/bin/env bash
# Readiness-shape checker for Work Item ISSUE bodies (repository workflow check only; not
# a live-input preflight — see docs/process/work-tracking.md "Readiness shape" and
# validation.md). Checks an issue body against: every "## " heading of the committed
# .github/ISSUE_TEMPLATE/work-item.md, an acceptance-criteria checkbox inside that
# body's Acceptance Criteria section, and one type plus one area:* label as listed in
# docs/process/labels.md. PR bodies are not checked here (tracked in #152).
# Exit codes: 0 all checks pass; 1 a check fails; 2 usage error or unreadable body;
# 3 a doc/template file is missing or unreadable, or a rule anchor it relies on is gone.
set -euo pipefail

ROOT=""
BODY=""
LABELS=""

while (($#)); do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { echo "check-readiness: --root requires a value" >&2; exit 2; }
      ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --body)
      [[ $# -ge 2 ]] || { echo "check-readiness: --body requires a value" >&2; exit 2; }
      BODY="$2"; shift 2 ;;
    --body=*) BODY="${1#*=}"; shift ;;
    --labels)
      [[ $# -ge 2 ]] || { echo "check-readiness: --labels requires a value" >&2; exit 2; }
      LABELS="$2"; shift 2 ;;
    --labels=*) LABELS="${1#*=}"; shift ;;
    -h|--help)
      echo "usage: $0 --root R --body FILE|- [--labels a,b,c]"
      exit 0
      ;;
    *) echo "check-readiness: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "check-readiness: --root must name a directory" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"
[[ -n "$BODY" ]] || { echo "check-readiness: --body is required (a file path, or - for stdin)" >&2; exit 2; }

body_file="$BODY"
tmp_body=""
if [[ "$BODY" == "-" ]]; then
  tmp_body="$(mktemp)"
  cat >"$tmp_body"
  body_file="$tmp_body"
fi
trap '[[ -n "$tmp_body" ]] && rm -f "$tmp_body"' EXIT

# Any readable non-directory path is accepted, not only a regular file, so a
# process-substitution path such as <(gh issue view N --json body -q .body) works.
[[ -r "$body_file" && ! -d "$body_file" ]] || {
  echo "check-readiness: body file not found or not readable: $body_file" >&2; exit 2; }

python3 - "$ROOT" "$body_file" "$LABELS" <<'PY'
import re
import sys

root, body_path, labels_arg = sys.argv[1:4]

def read(path):
    # A missing or unreadable doc/template file fails loudly with exit 3, not a Python
    # traceback under the exit 1 that means "a check failed".
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except FileNotFoundError:
        sys.stderr.write(f"check-readiness: FILE_NOT_FOUND: {path} does not exist\n")
        sys.exit(3)
    except OSError as exc:
        sys.stderr.write(f"check-readiness: FILE_UNREADABLE: {path}: {exc.strerror}\n")
        sys.exit(3)

work_tracking = read(f"{root}/docs/process/work-tracking.md")

# The section list comes from the template and the label sets from labels.md, but the
# rules that make them binding are prose in work-tracking.md's "Readiness shape". Fail
# loudly if the exact anchor text of a rule checked below has moved or been deleted,
# rather than silently checking a rule the doc no longer states.
ANCHORS = [
    "## Readiness shape",
    "a Work Item body carries every `## ` heading of",
    "at least one acceptance-criteria checkbox (`- [ ]` or `- [x]`)",
    "one type label from the Type row of [labels.md](labels.md) and at\n"
    "  least one label from its `area:*` table",
]
missing_anchors = [a for a in ANCHORS if a not in work_tracking]
if missing_anchors:
    for a in missing_anchors:
        sys.stderr.write(
            "check-readiness: DOC_ANCHOR_MISSING: "
            f"docs/process/work-tracking.md no longer contains: {a!r}\n"
        )
    sys.exit(3)

FENCE_RE = re.compile(r'^(`{3,}|~{3,})')

def clean_lines(text):
    # Lines outside HTML comments and fenced code, in document order. Fence open/close
    # follows CommonMark: a closing fence uses the opening fence's character and is at
    # least as long, so a ``` line inside an open ~~~ fence is content, not a delimiter.
    out, in_comment = [], False
    fence_char, fence_len = None, 0
    for line in text.splitlines():
        stripped = line.strip()
        if in_comment:
            if '-->' in line:
                in_comment = False
            continue
        if fence_char is None and stripped.startswith('<!--') and '-->' not in stripped:
            in_comment = True
            continue
        m = FENCE_RE.match(stripped)
        if m:
            char, length = m.group(1)[0], len(m.group(1))
            if fence_char is None:
                fence_char, fence_len = char, length
                continue
            if char == fence_char and length >= fence_len:
                fence_char, fence_len = None, 0
                continue
        if fence_char is not None:
            continue
        out.append(line)
    return out

def heading_list(text):
    # "## " level headings, verbatim, in document order.
    return [l[3:].rstrip() for l in clean_lines(text) if l.startswith('## ')]

def section_text(text, heading):
    # Cleaned lines after the named "## " heading, up to the next "## " heading.
    lines = clean_lines(text)
    start = next((i + 1 for i, l in enumerate(lines)
                  if l.startswith('## ') and l[3:].rstrip() == heading), None)
    if start is None:
        return ''
    end = next((j for j in range(start, len(lines)) if lines[j].startswith('## ')), len(lines))
    return '\n'.join(lines[start:end])

results = []  # (ok: bool, name: str, detail: str)

def check(ok, name, detail=""):
    results.append((ok, name, detail))

body = read(body_path)

template_path = f"{root}/.github/ISSUE_TEMPLATE/work-item.md"
required_headings = heading_list(read(template_path))
if not required_headings:
    sys.stderr.write(
        f"check-readiness: TEMPLATE_EMPTY: {template_path} has no '## ' headings "
        "to derive requirements from\n"
    )
    sys.exit(3)

body_headings = set(heading_list(body))
missing = [h for h in required_headings if h not in body_headings]
check(not missing, "all template sections present",
      "missing: " + ", ".join(missing) if missing else "")

ac_heading = next((h for h in required_headings if h.lower().startswith('acceptance criteria')), None)
check(ac_heading is not None, "template names an Acceptance Criteria heading",
      "" if ac_heading else "no '## Acceptance Criteria*' heading in work-item.md")

checkbox_re = re.compile(r'^\s*-\s\[[ xX]\]\s+\S', re.MULTILINE)
ac_section = section_text(body, ac_heading) if ac_heading else ''
has_checkbox = bool(checkbox_re.search(ac_section))
check(has_checkbox, "acceptance-criteria checkbox present in the Acceptance Criteria section",
      "" if has_checkbox
      else f"no '- [ ]' / '- [x]' checkbox line found under '## {ac_heading}'" if ac_heading
      else "no Acceptance Criteria heading to scope the search to")

labels_doc = read(f"{root}/docs/process/labels.md")

type_row = next((l for l in labels_doc.splitlines()
                 if l.startswith('|') and l.rstrip().endswith('| Type. |')), None)
if type_row is None:
    sys.stderr.write("check-readiness: LABELS_ANCHOR_MISSING: no labels.md row ending '| Type. |'\n")
    sys.exit(3)
type_labels = set(re.findall(r'`([^`]+)`', type_row))

area_section = labels_doc.split('## Repo-specific `area:*` set', 1)
if len(area_section) != 2:
    sys.stderr.write(
        "check-readiness: LABELS_ANCHOR_MISSING: no '## Repo-specific `area:*` set' heading in labels.md\n"
    )
    sys.exit(3)
area_labels = set(re.findall(r'^\|\s*`(area:[^`]+)`', area_section[1], re.MULTILINE))
if not area_labels:
    sys.stderr.write("check-readiness: LABELS_ANCHOR_MISSING: no 'area:*' rows found\n")
    sys.exit(3)

given_labels = {tok.strip() for tok in labels_arg.split(',') if tok.strip()}
has_type = bool(given_labels & type_labels)
check(has_type, "carries one type label",
      "" if has_type else f"no label in {sorted(given_labels)} is one of {sorted(type_labels)}")
has_area = bool(given_labels & area_labels)
check(has_area, "carries one area:* label",
      "" if has_area else f"no label in {sorted(given_labels)} is one of {sorted(area_labels)}")

passed = sum(1 for ok, _, _ in results if ok)
for ok, name, detail in results:
    print(f"{'OK' if ok else 'MISSING'}: {name}" + (f" ({detail})" if detail else ""))

print(f"check-readiness: {passed}/{len(results)} as expected")
sys.exit(0 if passed == len(results) else 1)
PY
