#!/usr/bin/env bash
# Readiness-shape checker (repository workflow check only; not a live-input preflight —
# see docs/process/work-tracking.md "Readiness shape" and validation.md).
# --mode issue (default): a Work Item issue body against every "## " heading of the
# committed .github/ISSUE_TEMPLATE/work-item.md, an acceptance-criteria checkbox inside
# the body's Acceptance Criteria section(s), and one type plus one area:* label as listed
# in docs/process/labels.md.
# --mode pr --repo OWNER/NAME: a PR body against every "## " heading of
# .github/PULL_REQUEST_TEMPLATE.md, a "Closes #<N>" or "Refs #<N>" line, no closing
# keyword for any Refs'd #<N>, and directly after each Refs line a "Remainder: <text>"
# line and a "Closing issue: #<M>" line (M != N) with no closing keyword directly before
# an issue reference in those two lines (#157). Each label is matched as written, colon
# and space included (#168); a check that depends on a missing line is skipped, and the
# missing line's message says so (#168). --labels is a usage error in PR mode, and --repo
# is one in issue mode (#163).
# Exit codes: 0 all checks pass; 1 a check fails; 2 usage error, or a missing, unreadable
# or non-UTF-8 body; 3 a doc/template file is missing, unreadable or not UTF-8, or a rule
# anchor it relies on is gone.
set -euo pipefail

ROOT=""
BODY=""
LABELS=""
LABELS_SET=""
MODE="issue"
REPO=""
REPO_SET=""

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
      LABELS="$2"; LABELS_SET=1; shift 2 ;;
    --labels=*) LABELS="${1#*=}"; LABELS_SET=1; shift ;;
    --mode)
      [[ $# -ge 2 ]] || { echo "check-readiness: --mode requires a value" >&2; exit 2; }
      MODE="$2"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    --repo)
      [[ $# -ge 2 ]] || { echo "check-readiness: --repo requires a value" >&2; exit 2; }
      REPO="$2"; REPO_SET=1; shift 2 ;;
    --repo=*) REPO="${1#*=}"; REPO_SET=1; shift ;;
    -h|--help)
      echo "usage: $0 --root R --body FILE|- [--labels a,b,c | --mode pr --repo OWNER/NAME]"
      exit 0
      ;;
    *) echo "check-readiness: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "check-readiness: --root must name a directory" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"
[[ "$MODE" == issue || "$MODE" == pr ]] || { echo "check-readiness: --mode must be issue or pr" >&2; exit 2; }
[[ "$MODE" == issue || "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "check-readiness: --mode pr requires --repo OWNER/NAME" >&2; exit 2; }
[[ "$MODE" == issue || -z "$LABELS_SET" ]] || {
  echo "check-readiness: --labels is not accepted with --mode pr" >&2; exit 2; }
[[ "$MODE" == pr || -z "$REPO_SET" ]] || {
  echo "check-readiness: --repo is not accepted with --mode issue" >&2; exit 2; }
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

python3 - "$ROOT" "$body_file" "$LABELS" "$MODE" "$REPO" "$BODY" <<'PY'
import re
import sys

root, body_path, labels_arg, mode, repo, body_arg = sys.argv[1:7]

def read(path, code=3, name=None):
    # A missing, unreadable or non-UTF-8 file fails loudly with a named message: exit 3
    # for a doc/template file, exit 2 for the body — never a Python traceback under the
    # exit 1 that means "a check failed". `name` replaces the path in messages (#161: a
    # stdin body is a temp file the EXIT trap deletes, so it is named "body (stdin)").
    name = name or path
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except FileNotFoundError:
        sys.stderr.write(f"check-readiness: FILE_NOT_FOUND: {name} does not exist\n")
    except UnicodeDecodeError as exc:
        sys.stderr.write(f"check-readiness: FILE_NOT_UTF8: {name}: {exc.reason} at byte {exc.start}\n")
    except OSError as exc:
        sys.stderr.write(f"check-readiness: FILE_UNREADABLE: {name}: {exc.strerror}\n")
    sys.exit(code)

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
    "a PR body carries every `## ` heading of",
    "a `Closes #<N>` line or the partial-delivery form below",
    "the body carries a `Refs #<N>` line",
    "body then carries no closing keyword anywhere",
    "directly after it a `Remainder: <text>` line and then a `Closing issue: #<M>` line",
    "No closing keyword comes directly before an issue reference in those two lines",
    "Each of the two lines starts with its label exactly as written above",
]
missing_anchors = [a for a in ANCHORS if a not in work_tracking]
if missing_anchors:
    for a in missing_anchors:
        sys.stderr.write(
            "check-readiness: DOC_ANCHOR_MISSING: "
            f"docs/process/work-tracking.md no longer contains: {a!r}\n"
        )
    sys.exit(3)

# A list-item prefix is indentation then one or more markers ("1. ", "1) ", "- ", "* ",
# "+ "), each followed by a space or the end of the line; a fence may open after it. A
# backtick fence's info string holds no backtick. As far as CommonMark goes here: a tab
# advances to the next multiple of 4 columns; an ordered marker other than 1, or a marker
# with nothing after it, cannot interrupt a paragraph, so directly after a paragraph line
# in the same container it is text, not an item; a line that opens no block (item, fence,
# ATX heading, thematic break, "> " quote, "<!--") continues an open paragraph, and a lazy
# one keeps the list items it is less indented than; a setext underline, and every block
# above, ends a paragraph; an empty item followed by a line blank to column 0 ends there,
# while a whitespace-only line reaching its content column keeps it open (as GitHub renders
# it); a fence belongs to the innermost open list item whose content column its line
# reaches, and a non-blank line indented less than that column ends the item and the fence
# with it; a line indented 4 or more columns past its container is indented code, or text
# in an open paragraph, never a fence or heading; outside a list a heading may be indented
# up to 3 columns; a closing fence is the opening character, at least as long, with
# nothing after it, indented at most 3 columns past that content column. No check reads a
# "> " line, so of a quote only this is modelled: whether it leaves a paragraph open, and a
# quoted fence running on over "> " lines. Not modelled: a marker followed by 5 or more
# columns, nesting inside a quote, HTML blocks other than comments, an HTML comment ending
# with the list item or quote it opened in, and setext headings or headings inside list
# items counting as "## " headings.
MARKER_RE = re.compile(r'(?:[-*+]|(\d{1,9})[.)])(?:[ \t]+|$)')
FENCE_OPEN_RE = re.compile(r'(`{3,}|~{3,})(.*)$')
FENCE_CLOSE_RE = re.compile(r'^(`{3,}|~{3,})\s*$')
HEADING_RE = re.compile(r'#{1,6}(?:[ \t]|$)')
SETEXT_RE = re.compile(r'(?:=+|-+)$')
BREAK_RE = re.compile(r'(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$')
QUOTE_PREFIX_RE = re.compile(r'(?:\s*(?:>|(?:[+*-]|\d{1,9}[.)])(?=\s|$)))+\s*')

def clean_lines(text):
    return [line for _, line in clean_numbered(text)]

def fence_at(line, pos):
    f = FENCE_OPEN_RE.match(line, pos)
    return f if f and not (f.group(1)[0] == '`' and '`' in f.group(2)) else None

def starts_block(s):
    # s is a line with its indentation removed: does it open a block other than a paragraph?
    return bool(fence_at(s, 0) or HEADING_RE.match(s) or BREAK_RE.match(s)
                or s.startswith('>') or s.startswith('<!--'))

def clean_numbered(text):
    # (index, line) for lines outside HTML comments and fenced or indented code, in document
    # order, where index is the line's position in text.splitlines(). A closing fence uses
    # the opening fence's character, so a ``` line inside an open ~~~ fence is content.
    out, in_comment = [], False
    fence_char, fence_len, fence_col = None, 0, 0
    items, in_para, para_depth = [], False, 0  # content columns of the open list items
    empty_item = False  # the previous line opened an item with no content
    quote_fence = None  # the fence character of a fence open inside a "> " quote
    for i, raw in enumerate(text.splitlines()):
        line = raw.expandtabs(4)
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        if in_comment:
            if '-->' in line:
                in_comment = False
            continue
        was_empty, empty_item = empty_item, False
        was_quoted, quote_fence = quote_fence, None
        if fence_char is not None and stripped and indent < fence_col:
            fence_char = None
        if fence_char is not None:
            m = FENCE_CLOSE_RE.match(stripped)
            if m and m.group(1)[0] == fence_char and len(m.group(1)) >= fence_len \
                    and indent <= fence_col + 3:
                fence_char = None
            continue
        depth = sum(1 for col in items if col <= indent)  # the open items this line continues
        rel = indent - (items[depth - 1] if depth else 0)
        if not stripped:
            if was_empty:
                if indent < items[-1]:
                    items.pop()
                else:
                    empty_item = True
            in_para = False
        elif rel > 3:
            if not in_para:  # indented code
                del items[depth:]
                continue
        else:
            m = None if BREAK_RE.match(stripped) else MARKER_RE.match(line, indent)
            if m and in_para and para_depth == depth and (not line[m.end():].strip()
                                                          or (m.group(1) and int(m.group(1)) != 1)):
                m = None
            if in_para and not m and not starts_block(stripped):
                # a paragraph continuation line (lazy if depth < len(items)), or its setext underline
                in_para = not (para_depth == depth and SETEXT_RE.match(stripped))
                out.append((i, raw))
                continue
            del items[depth:]
            if stripped.startswith('<!--'):
                in_para = False
                if '-->' not in stripped:
                    in_comment = True
                    continue
            elif stripped.startswith('>'):
                rest = QUOTE_PREFIX_RE.sub('', stripped, count=1)
                if was_quoted:  # a quoted fence goes on only over "> " lines
                    closes = FENCE_CLOSE_RE.match(rest) and rest[0] == was_quoted
                    quote_fence, in_para = None if closes else was_quoted, False
                else:
                    f = fence_at(rest, 0)
                    quote_fence = f.group(1)[0] if f else None
                    in_para, para_depth = bool(rest) and not starts_block(rest), -1
            else:
                pos = indent
                while m:
                    pos = m.end()
                    if not line[pos:].strip():  # an empty item's content column is marker width + 1
                        pos, empty_item = m.start() + len(m.group(0).rstrip()) + 1, True
                    items.append(pos)
                    m = MARKER_RE.match(line, pos)
                f = fence_at(line, pos)
                if f:
                    fence_char, fence_len = f.group(1)[0], len(f.group(1))
                    fence_col, in_para = (items[-1] if items else 0), False
                    continue
                if HEADING_RE.match(line, pos) and not items:
                    in_para, raw = False, raw.lstrip(' ')
                elif HEADING_RE.match(line, pos) or BREAK_RE.match(stripped) or empty_item:
                    in_para = False
                elif not in_para or pos > indent:
                    in_para, para_depth = True, len(items)
        out.append((i, raw))
    return out

def heading_list(text):
    # "## " level headings, verbatim, in document order.
    return [l[3:].rstrip() for l in clean_lines(text) if l.startswith('## ')]

def section_text(text, heading):
    # Cleaned lines under EVERY "## " heading named `heading`, each up to the next "## "
    # heading: a body that repeats a template heading is checked in all copies (#155).
    out, inside = [], False
    for l in clean_lines(text):
        if l.startswith('## '):
            inside = l[3:].rstrip() == heading
        elif inside:
            out.append(l)
    return '\n'.join(out)

results = []  # (ok: bool, name: str, detail: str)

def check(ok, name, detail=""):
    results.append((ok, name, detail))

body = read(body_path, code=2, name='body (stdin)' if body_arg == '-' else None)

template_path = f"{root}/.github/{'PULL_REQUEST_TEMPLATE.md' if mode == 'pr' else 'ISSUE_TEMPLATE/work-item.md'}"
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

def finish():
    passed = sum(1 for ok, _, _ in results if ok)
    for ok, name, detail in results:
        print(f"{'OK' if ok else 'MISSING'}: {name}" + (f" ({detail})" if detail else ""))
    print(f"check-readiness: {passed}/{len(results)} as expected")
    sys.exit(0 if passed == len(results) else 1)

if mode == 'pr':
    raw = [l.rstrip() for l in body.splitlines()]
    lines = [(i, l.rstrip()) for i, l in clean_numbered(body)]
    closes = [m.group(1) for _, l in lines if (m := re.fullmatch(r'Closes #(\d+)', l))]
    refs = [(i, m.group(1)) for i, l in lines if (m := re.fullmatch(r'Refs #(\d+)', l))]
    check(bool(closes or refs), "a Closes #<N> line or a Refs #<N> line present",
          "" if closes or refs else "no line is exactly 'Closes #<N>' or 'Refs #<N>'")
    # GitHub's "Linking a pull request to an issue" names these nine keywords, says they
    # "can be followed by colons or in uppercase", and gives the forms KEYWORD #N and
    # KEYWORD OWNER/REPOSITORY#N. Any case is matched. The page says nothing about code
    # spans, fenced code or HTML comments, so the RAW body is searched: a keyword quoted
    # in code is flagged even if GitHub would ignore it (unverified; fails loud, never
    # silent). Its only colon example is "Closes: #10"; whether "Closes:#10" (no space)
    # links is not stated, so it is flagged too (unverified, #161). An OWNER/REPOSITORY
    # other than --repo names another repository's issue.
    kw = r'\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)(?::\s*|\s+)'
    keyword_re = re.compile(kw + r'(?:([\w.-]+)/([\w.-]+))?#(\d+)\b', re.IGNORECASE)
    hits = [m for m in keyword_re.finditer(body) if m.group(1) is None
            or f"{m.group(1)}/{m.group(2)}".lower() == repo.lower()]
    for i, n in refs:
        found = [m.group(0) for m in hits if m.group(3) == n]
        check(not found, f"no closing keyword for Refs #{n} anywhere in the body",
              f"found: {found}" if found else "")
        # The #157 form: the next raw line is "Remainder: <text>", the one after it is
        # "Closing issue: #<M>" with M != N, and neither puts a keyword before a reference.
        rem = raw[i + 1] if i + 1 < len(raw) else ''
        clo = raw[i + 2] if i + 2 < len(raw) else ''
        # Labels match case-sensitively, colon and space included (#168). "Remainder:" alone
        # is the label with empty text: raw lines are rstripped, so its space is gone. A
        # check that depends on a failed line is skipped rather than reported as a second
        # MISSING line for the same cause, and the failed line's detail says so (#168).
        rm = re.fullmatch(r'Remainder:(?: (.*))?', rem)
        cm = re.fullmatch(r'Closing issue: #(\d+)', clo)
        check(rm is not None, f"Refs #{n}: a 'Remainder: <text>' line directly after it",
              "" if rm else f"next line is {rem!r}; its text and Closing issue checks are skipped")
        text_ok = rm is not None and bool((rm.group(1) or '').strip())
        if rm:
            check(text_ok, f"Refs #{n}: the Remainder text is non-empty",
                  "" if text_ok else "no Remainder text")
            check(cm is not None, f"Refs #{n}: a 'Closing issue: #<M>' line directly after the Remainder line",
                  "" if cm else f"line after that is {clo!r}; the M != N check is skipped")
        differs = cm is not None and cm.group(1) != n
        if rm and cm:
            check(differs, f"Refs #{n}: the Closing issue is not #{n} itself",
                  "" if differs else f"Closing issue is #{n}")
        form = [l for l, p in ((rem, 'Remainder:'), (clo, 'Closing issue:')) if l.startswith(p)]
        kw_found = [m.group(0) for l in form for m in keyword_re.finditer(l)]
        check(not kw_found, f"Refs #{n}: no closing keyword before an issue reference in its Remainder and Closing issue lines",
              f"found: {kw_found}" if kw_found else "")
    finish()

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

finish()
PY
