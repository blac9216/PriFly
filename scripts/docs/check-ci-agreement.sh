#!/usr/bin/env bash
# Makes the agreement rule in docs/process/testing.md mechanical (#337): a change that
# edits a step in .github/workflows/go-checks.yml or .github/workflows/docs-checks.yml
# without updating its Commands-table row, or the reverse, fails here instead of
# shipping. Two files state that rule in prose; nothing used to enforce it, and the rule
# had been widened twice (#197, #213 into PR #232) without ever gaining a checker.
#
# What it pairs. Every step of each job, in file order, against the rows of the Commands
# tables in docs/process/testing.md, in document order:
#   docs-checks.yml, job design-docs  <->  the documentation suite table
#   go-checks.yml,   job go           <->  the Go suite table, then the qualification table
# Both sides are order-bearing, so reordering two adjacent rows is a failure.
#
# The exemption list below is load-bearing in both directions: a step or row that is
# neither paired nor listed is an error, and an entry that names no step or row is an
# error too, so the list cannot decay into a wildcard. A checker that instead skipped
# what it could not pair would be worse than no checker.
#
# Normalisation between a table cell and a run: line, written down because none of it is
# byte-identity. It fails rather than skipping whenever it meets something it cannot
# normalise:
#   1. One row, several commands. Every backtick-quoted span of the Command cell is taken
#      in order and joined with " && ", which is how the Identity row's four commands are
#      written as one run: line. Only ",", "then" and "and" may separate the spans, and
#      no other prose may sit before, between or after them; anything else is a failure.
#      A cell with no backtick-quoted span is a failure.
#   2. A documented placeholder against a concrete CI value. Both sides are split on
#      whitespace and compared token by token, and a cell token holding a <placeholder>
#      matches exactly one run token, whatever it is. That is what lets the Mechanical
#      audit row's --out <scratch-path>/gap.md pair with --out /tmp/prifly-design-doc-gap.md
#      while a changed flag anywhere else still fails. Token counts must match.
#   3. A different vocabulary entirely. doc-manifest.md's "## CI" list names script paths
#      and a spelled-out count rather than commands, so its entries are checked instead by
#      position, by every whitespace token of the entry's code span appearing in the
#      corresponding step's run: line, and by the count word and the numbering matching
#      the job's step count.
# A step whose run: is a block scalar or a quoted scalar, or that has no run: at all, is
# normalised by none of these: it must be on the exemption list or the checker fails.
#
# Fails closed. Exit 0 everything agrees; 1 a disagreement, reported one line per finding;
# 2 usage error; 3 a file it reads is missing, unreadable or not UTF-8, a table it reads
# has no rows, or it met something it cannot normalise.
set -euo pipefail

ROOT=""
while (($#)); do
  case "$1" in
    --root) ROOT="${2:-}"; shift; (($#)) && shift ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    -h|--help) echo "usage: $0 --root R"; exit 0 ;;
    *) echo "check-ci-agreement: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "check-ci-agreement: --root must name a directory" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

python3 - "$ROOT" <<'PY'
from __future__ import annotations
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])

GO = ".github/workflows/go-checks.yml"
DOCS = ".github/workflows/docs-checks.yml"
TESTING = "docs/process/testing.md"
MANIFEST = "docs/doc-manifest.md"

# --- the exemption list -------------------------------------------------------------
# Every entry is a step or row that is deliberately unpaired, with the reason it is.
# Deleting an entry makes its step or row unpaired and turns this checker red; an entry
# that matches nothing turns it red too.
EXEMPT_STEPS = {
    DOCS: [
        "Check out the PR head commit (not the synthetic merge ref)",  # setup, no local command
    ],
    GO: [
        "Check out the PR head commit (not the synthetic merge ref)",  # setup, no local command
        "Install pinned Go toolchain (verify SHA-256, then extract)",  # setup, testing.md Toolchain prose carries the local equivalent
        "Restore Go module cache (keyed by go.sum)",  # setup, CI-only, no local command
    ],
}
EXEMPT_ROWS = {
    "documentation suite": [
        "Sanitize scan",  # gitleaks, run before every push, deliberately not in CI
        "Integration",  # no command exists until a runnable integration surface lands
    ],
}
# --- end of the exemption list ------------------------------------------------------

TABLES = ["documentation suite", "Go suite", "qualification local proofs"]
PAIRINGS = [
    (DOCS, "design-docs", ["documentation suite"]),
    (GO, "go", ["Go suite", "qualification local proofs"]),
]

NUMBER_WORDS = [
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
    "seventeen", "eighteen", "nineteen", "twenty", "twenty-one", "twenty-two",
    "twenty-three", "twenty-four", "twenty-five", "twenty-six", "twenty-seven",
    "twenty-eight", "twenty-nine", "thirty",
]

findings: list[str] = []


def unparsable(message: str) -> None:
    print("CI_AGREEMENT_UNPARSABLE: " + message, file=sys.stderr)
    raise SystemExit(3)


def disagree(message: str) -> None:
    findings.append(message)


def read(relative: str) -> str:
    path = root / relative
    try:
        data = path.read_bytes()
    except FileNotFoundError:
        unparsable("missing %s" % path)
    except OSError as exc:
        unparsable("cannot read %s: %s" % (path, exc.strerror))
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        unparsable("%s is not UTF-8: %s at byte %d" % (path, exc.reason, exc.start))


# --- workflow steps -----------------------------------------------------------------
STEP_RE = re.compile(r"^      - name: (\S.*)$")
KEY_RE = re.compile(r"^        ([A-Za-z0-9_-]+):(.*)$")


def steps_of(relative: str, job: str) -> list[tuple[str, str | None]]:
    lines = read(relative).split("\n")
    try:
        start = lines.index("  %s:" % job)
    except ValueError:
        unparsable("%s has no job named %s" % (relative, job))
    index = start + 1
    while index < len(lines) and not re.match(r"^  \S", lines[index]):
        if lines[index] == "    steps:":
            break
        index += 1
    else:
        index = len(lines)
    if index >= len(lines) or lines[index] != "    steps:":
        unparsable("%s job %s has no steps: block" % (relative, job))
    steps: list[tuple[str, str | None]] = []
    for line in lines[index + 1:]:
        if line.strip() == "":
            break
        if not line.startswith("      "):
            break
        named = STEP_RE.match(line)
        if named:
            steps.append((named.group(1).strip(), None))
            continue
        if line.startswith("      - "):
            unparsable("%s job %s has a step whose first key is not name:: %r" % (relative, job, line))
        key = KEY_RE.match(line)
        if key and key.group(1) == "run":
            if not steps:
                unparsable("%s job %s has a run: before any step name" % (relative, job))
            name, existing = steps[-1]
            if existing is not None:
                unparsable("%s job %s step %r has more than one run:" % (relative, job, name))
            steps[-1] = (name, key.group(2).strip())
    if not steps:
        unparsable("%s job %s has no steps" % (relative, job))
    names = [name for name, _ in steps]
    for name in names:
        if names.count(name) > 1:
            unparsable("%s job %s has more than one step named %r" % (relative, job, name))
    return steps


def command_of(relative: str, name: str, run: str | None) -> str:
    where = "%s step %r" % (relative, name)
    if run is None:
        unparsable("%s has no run: line, so it cannot be paired with a documented command; exempt it by name or give it one" % where)
    if run == "" or run[0] in "|>":
        unparsable("%s uses a block scalar run:, which this checker does not normalise; exempt it by name or write the command on one line" % where)
    if run[0] in "'\"":
        unparsable("%s uses a quoted run: scalar, which this checker does not normalise" % where)
    return run


# --- testing.md tables --------------------------------------------------------------
TABLE_HEADER = "| Suite | Command | Environment |"


def tables_of(relative: str) -> dict[str, list[tuple[str, str]]]:
    lines = read(relative).split("\n")
    found: list[list[tuple[str, str]]] = []
    index = 0
    while index < len(lines):
        if lines[index].strip() != TABLE_HEADER:
            index += 1
            continue
        if index + 1 >= len(lines) or not re.match(r"^\|[\s:|-]+\|$", lines[index + 1].strip()):
            unparsable("%s has a Suite/Command/Environment header with no delimiter row at line %d" % (relative, index + 1))
        rows: list[tuple[str, str]] = []
        index += 2
        while index < len(lines) and lines[index].startswith("|"):
            fields = lines[index].split("|")
            if len(fields) != 5 or fields[0].strip() or fields[4].strip():
                unparsable("%s line %d is not a three-column row: %r" % (relative, index + 1, lines[index]))
            rows.append((fields[1].strip(), fields[2].strip()))
            index += 1
        if not rows:
            unparsable("%s has a Commands table with no rows, at line %d" % (relative, index))
        found.append(rows)
    if len(found) != len(TABLES):
        unparsable("%s holds %d Suite/Command/Environment tables, not the %d this checker pairs (%s)"
                   % (relative, len(found), len(TABLES), ", ".join(TABLES)))
    return dict(zip(TABLES, found))


SPAN_RE = re.compile(r"`([^`]+)`")
SEPARATOR_RE = re.compile(r"^,?\s*(?:then|and)?\s*$")
PLACEHOLDER_RE = re.compile(r"<[^<>]+>")


def cell_command(table: str, suite: str, cell: str) -> str:
    where = "%s row %r in the %s table" % (TESTING, suite, table)
    spans: list[str] = []
    between: list[str] = []
    end = 0
    for match in SPAN_RE.finditer(cell):
        between.append(cell[end:match.start()])
        spans.append(match.group(1))
        end = match.end()
    if not spans:
        unparsable("%s: the Command cell holds no backtick-quoted command: %r" % (where, cell))
    if between[0].strip():
        unparsable("%s: the Command cell holds prose before its first command: %r" % (where, cell))
    for text in between[1:]:
        if not SEPARATOR_RE.match(text.strip()):
            unparsable("%s: the Command cell separates two commands with %r, which this checker does not normalise" % (where, text))
    if cell[end:].strip():
        unparsable("%s: the Command cell holds prose after its last command: %r" % (where, cell))
    return " && ".join(spans)


def agree(documented: str, run: str) -> bool:
    left, right = documented.split(), run.split()
    if len(left) != len(right):
        return False
    for want, got in zip(left, right):
        if PLACEHOLDER_RE.search(want):
            continue
        if want != got:
            return False
    return True


# --- the pairing --------------------------------------------------------------------
tables = tables_of(TESTING)
paired_total = 0
step_counts: dict[str, int] = {}
kept_steps: dict[str, list[tuple[str, str]]] = {}

for relative, job, table_names in PAIRINGS:
    steps = steps_of(relative, job)
    exempt = EXEMPT_STEPS[relative]
    names = [name for name, _ in steps]
    for entry in exempt:
        if names.count(entry) != 1:
            disagree("exemption entry %r names %d steps of %s, not exactly one" % (entry, names.count(entry), relative))
    live = [(name, command_of(relative, name, run)) for name, run in steps if name not in exempt]
    kept_steps[relative] = live
    step_counts[relative] = len(live)

    rows: list[tuple[str, str, str]] = []
    for table_name in table_names:
        exempt_rows = EXEMPT_ROWS.get(table_name, [])
        suites = [suite for suite, _ in tables[table_name]]
        for entry in exempt_rows:
            if suites.count(entry) != 1:
                disagree("exemption entry %r names %d rows of the %s table, not exactly one" % (entry, suites.count(entry), table_name))
        for suite, cell in tables[table_name]:
            if suite in exempt_rows:
                continue
            rows.append((table_name, suite, cell_command(table_name, suite, cell)))

    for position in range(max(len(live), len(rows))):
        if position >= len(rows):
            name, run = live[position]
            disagree("%s step %r (position %d) has no row in %s and no exemption entry" % (relative, name, position + 1, TESTING))
            continue
        if position >= len(live):
            table_name, suite, documented = rows[position]
            disagree("%s row %r in the %s table (position %d) has no step in %s and no exemption entry" % (TESTING, suite, table_name, position + 1, relative))
            continue
        name, run = live[position]
        table_name, suite, documented = rows[position]
        if not agree(documented, run):
            disagree("%s step %r runs %r, but the row it pairs with (%r in the %s table, position %d) documents %r"
                     % (relative, name, run, suite, table_name, position + 1, documented))
        else:
            paired_total += 1

# --- doc-manifest.md's "## CI" list --------------------------------------------------
COUNT_RE = re.compile(r"^After checkout, the `design-docs` job runs these ([a-z-]+) steps, in this order, in:$")
# The list separates an entry from its gloss with an em dash, built here by code point
# so this file stays ASCII.
ENTRY_RE = re.compile(r"^(\d+)\.\s+`([^`]+)`\s*" + chr(0x2014) + r"\s*\S.*$")

manifest = read(MANIFEST).split("\n")
try:
    start = manifest.index("## CI")
except ValueError:
    unparsable("%s has no '## CI' section" % MANIFEST)
section: list[str] = []
for line in manifest[start + 1:]:
    if line.startswith("## "):
        break
    section.append(line)

counts = [COUNT_RE.match(line) for line in section]
counts = [match for match in counts if match]
if len(counts) != 1:
    unparsable("%s '## CI' holds %d lines naming the step count in the expected form, not one" % (MANIFEST, len(counts)))
count_word = counts[0].group(1)
if not any(DOCS in line for line in section):
    unparsable("%s '## CI' does not name %s" % (MANIFEST, DOCS))

entries = [match for match in (ENTRY_RE.match(line) for line in section) if match]
if not entries:
    unparsable("%s '## CI' holds no numbered step entries" % MANIFEST)

docs_steps = kept_steps[DOCS]
expected = step_counts[DOCS]
for position, match in enumerate(entries):
    if int(match.group(1)) != position + 1:
        disagree("%s '## CI' entry at position %d is numbered %s" % (MANIFEST, position + 1, match.group(1)))
if len(entries) != expected:
    disagree("%s '## CI' lists %d steps, but %s job design-docs runs %d after checkout" % (MANIFEST, len(entries), DOCS, expected))
if expected < len(NUMBER_WORDS) and count_word != NUMBER_WORDS[expected]:
    disagree("%s '## CI' says the job runs '%s' steps, but it runs %d (%s)" % (MANIFEST, count_word, expected, NUMBER_WORDS[expected]))
for position, match in enumerate(entries):
    if position >= len(docs_steps):
        disagree("%s '## CI' entry %d (%s) has no step at that position in %s" % (MANIFEST, position + 1, match.group(2), DOCS))
        continue
    name, run = docs_steps[position]
    missing = [token for token in match.group(2).split() if token not in run]
    if missing:
        disagree("%s '## CI' entry %d names %r, which does not appear in the run: of the step at that position (%r runs %r)"
                 % (MANIFEST, position + 1, " ".join(missing), name, run))

if findings:
    for finding in findings:
        print("CI_AGREEMENT_MISMATCH: " + finding, file=sys.stderr)
    raise SystemExit(1)

print("check-ci-agreement: %d workflow steps agree with their documented commands (%s %d, %s %d), "
      "%d exemptions are all in use, and %s's CI list of %s matches"
      % (paired_total, DOCS, step_counts[DOCS], GO, step_counts[GO],
         sum(len(v) for v in EXEMPT_STEPS.values()) + sum(len(v) for v in EXEMPT_ROWS.values()),
         MANIFEST, count_word))
PY
