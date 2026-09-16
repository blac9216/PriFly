#!/usr/bin/env bash
# Readiness-shape checker (repository workflow check only; not a live-input preflight —
# see docs/process/work-tracking.md "Readiness shape" and validation.md). Checks a Work
# Item issue body (or PR body) against the "## " headings of the committed
# .github/ISSUE_TEMPLATE/work-item.md (or PULL_REQUEST_TEMPLATE.md for --mode pr), an
# acceptance-criteria checkbox, and the type/area:* label rule from labels.md.
set -euo pipefail

ROOT=""
MODE=""
BODY=""
LABELS=""

while (($#)); do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    --body) BODY="${2:-}"; shift 2 ;;
    --body=*) BODY="${1#*=}"; shift ;;
    --labels) LABELS="${2:-}"; shift 2 ;;
    --labels=*) LABELS="${1#*=}"; shift ;;
    -h|--help)
      echo "usage: $0 --root R --mode issue|pr --body FILE|- [--labels a,b,c]"
      exit 0
      ;;
    *) echo "check-readiness: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "check-readiness: --root must name a directory" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"
[[ "$MODE" == "issue" || "$MODE" == "pr" ]] || { echo "check-readiness: --mode must be issue or pr" >&2; exit 2; }
[[ -n "$BODY" ]] || { echo "check-readiness: --body is required (a file path, or - for stdin)" >&2; exit 2; }

body_file="$BODY"
tmp_body=""
if [[ "$BODY" == "-" ]]; then
  tmp_body="$(mktemp)"
  cat >"$tmp_body"
  body_file="$tmp_body"
fi
trap '[[ -n "$tmp_body" ]] && rm -f "$tmp_body"' EXIT

[[ -f "$body_file" ]] || { echo "check-readiness: body file not found: $body_file" >&2; exit 2; }

python3 - "$ROOT" "$MODE" "$body_file" "$LABELS" <<'PY'
import re
import sys

root, mode, body_path, labels_arg = sys.argv[1:5]

def read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()

work_tracking = read(f"{root}/docs/process/work-tracking.md")

# The section lists below come from the templates, but the rules that make them
# binding are prose in work-tracking.md's "Readiness shape". Where that prose must be
# hard-coded (no machine-readable equivalent exists), fail loudly if the exact anchor
# text has moved or been deleted, rather than silently checking a rule the doc no
# longer states.
ANCHORS = [
    "## Readiness shape",
    "at least one acceptance-criteria checkbox (`- [ ]` or `- [x]`)",
    "one type label from the Type row of [labels.md](labels.md) and at\n"
    "  least one label from its `area:*` table",
    "and either\n  a `Closes #<N>` line or the partial-delivery form below",
    "the body carries a `Refs #<N>` line, names the exact\n"
    "remainder not delivered by this PR, and names the issue whose PR will close #<N>",
]
missing_anchors = [a for a in ANCHORS if a not in work_tracking]
if missing_anchors:
    for a in missing_anchors:
        sys.stderr.write(
            "check-readiness: DOC_ANCHOR_MISSING: "
            f"docs/process/work-tracking.md no longer contains: {a!r}\n"
        )
    sys.exit(3)

def clean_lines(text):
    # Lines outside HTML comments and fenced code, in document order.
    out, in_comment, in_fence = [], False, False
    for line in text.splitlines():
        stripped = line.strip()
        if in_comment:
            if '-->' in line:
                in_comment = False
            continue
        if stripped.startswith('<!--') and '-->' not in stripped:
            in_comment = True
            continue
        if stripped.startswith('```') or stripped.startswith('~~~'):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        out.append(line)
    return out

def heading_list(text):
    # "## " level headings, verbatim, in document order (templates do not repeat them).
    return [l[3:].rstrip() for l in clean_lines(text) if l.startswith('## ')]

def strip_noise(text):
    return '\n'.join(clean_lines(text))

results = []  # (ok: bool, name: str, detail: str)

def check(ok, name, detail=""):
    results.append((ok, name, detail))

body = read(body_path)

if mode == "issue":
    template_path = f"{root}/.github/ISSUE_TEMPLATE/work-item.md"
    template = read(template_path)
    required_headings = heading_list(template)
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
    has_checkbox = bool(checkbox_re.search(strip_noise(body)))
    check(has_checkbox, "acceptance-criteria checkbox list present",
          "" if has_checkbox else "no '- [ ]' / '- [x]' checkbox line found in body")

    labels_path = f"{root}/docs/process/labels.md"
    labels_doc = read(labels_path)

    def backtick_tokens(row_text):
        return re.findall(r'`([^`]+)`', row_text)

    type_row = None
    for line in labels_doc.splitlines():
        if line.startswith('|') and line.rstrip().endswith('| Type. |'):
            type_row = line
            break
    if type_row is None:
        sys.stderr.write(
            f"check-readiness: LABELS_ANCHOR_MISSING: no labels.md row ending '| Type. |'\n"
        )
        sys.exit(3)
    type_labels = set(backtick_tokens(type_row))

    area_section = labels_doc.split('## Repo-specific `area:*` set', 1)
    if len(area_section) != 2:
        sys.stderr.write(
            "check-readiness: LABELS_ANCHOR_MISSING: no "
            "'## Repo-specific `area:*` set' heading in labels.md\n"
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

elif mode == "pr":
    template_path = f"{root}/.github/PULL_REQUEST_TEMPLATE.md"
    template = read(template_path)
    required_headings = heading_list(template)
    if not required_headings:
        sys.stderr.write(
            f"check-readiness: TEMPLATE_EMPTY: {template_path} has no '## ' headings\n"
        )
        sys.exit(3)

    body_headings = set(heading_list(body))
    missing = [h for h in required_headings if h not in body_headings]
    check(not missing, "all PR template sections present",
          "missing: " + ", ".join(missing) if missing else "")

    closes_re = re.compile(r'^Closes #\d+\s*$', re.MULTILINE)
    refs_re = re.compile(r'^Refs #(\d+)\s*$', re.MULTILINE)
    closes_matches = closes_re.findall(strip_noise(body))
    refs_matches = refs_re.findall(strip_noise(body))

    if closes_matches and not refs_matches:
        check(True, "Closes #<N> line present", "")
    elif refs_matches and not closes_matches:
        n = refs_matches[0]
        cleaned = strip_noise(body)
        cleaned = re.sub(r'^Refs #\d+\s*$', '', cleaned, flags=re.MULTILINE)
        cleaned = re.sub(r'^#{1,6}\s.*$', '', cleaned, flags=re.MULTILINE)
        remainder_prose = ' '.join(cleaned.split())
        has_remainder = len(remainder_prose) >= 40
        check(has_remainder, f"Refs #{n} partial-delivery form names a remainder",
              "" if has_remainder
              else f"Refs #{n} present but no remainder/closing-issue prose found beyond template headings")
        # The closing keyword must not appear anywhere else, including in prose.
        stray_close = re.search(r'\bcloses?\s+#\d+\b', cleaned, re.IGNORECASE)
        check(not stray_close, f"no stray closing keyword for #{n} outside the Refs form",
              "" if not stray_close else f"found: {stray_close.group(0)!r}")
    else:
        check(False, "exactly one of Closes #<N> or Refs #<N> partial-delivery form present",
              f"Closes matches={closes_matches!r} Refs matches={refs_matches!r}")

else:
    raise AssertionError("unreachable")

passed = sum(1 for ok, _, _ in results if ok)
total = len(results)
for ok, name, detail in results:
    status = "OK" if ok else "MISSING"
    line = f"{status}: {name}"
    if detail:
        line += f" ({detail})"
    print(line)

print(f"check-readiness: {passed}/{total} as expected")
sys.exit(0 if passed == total else 1)
PY
