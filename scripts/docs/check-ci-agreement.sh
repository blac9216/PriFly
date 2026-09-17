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
# Both sides are order-bearing, so reordering two adjacent rows is a failure, and the
# boundary between two tables paired against one job is order-bearing too: see the table
# boundary list below.
#
# A step is more than its run: line. Which of its other keys decide whether it runs at
# all, and whether its failure blocks, is written down in the load-bearing attribute list
# below (#348); a paired step carrying one of them disagrees with documents that assert
# it runs, and a key the list does not recognise is an error rather than something
# skipped.
#
# The exemption list below is load-bearing in both directions: a step or row that is
# neither paired nor listed is an error, and an entry that names no step or row is an
# error too, so the list cannot decay into a wildcard. A checker that instead skipped
# what it could not pair would be worse than no checker. The three other written lists
# here -- load-bearing attributes, documented placeholders and table boundaries -- are
# load-bearing in both directions for the same reason and in the same way.
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
#      while a changed flag anywhere else still fails. Token counts must match. Because a
#      placeholder stops this checker watching a position, and does so from the document
#      side alone, the rows allowed to hold one are written down in the documented
#      placeholder list below and counted in the summary line the way exemptions are.
#   3. A different vocabulary entirely. doc-manifest.md's "## CI" list names script paths
#      and a spelled-out count rather than commands, so its entries are checked instead by
#      position, by every whitespace token of the entry's code span appearing in the
#      corresponding step's run: line as a whole path component, and by the count word and
#      the numbering matching the job's step count. Whole path component, not substring:
#      the list holds three X.sh / test-X.sh pairs, so containment would let an entry
#      naming check-links.sh pass against a step running test-check-links.sh.
# A step whose run: is a block scalar or a quoted scalar, or that has no run: at all, is
# normalised by none of these: it must be on the exemption list or the checker fails.
#
# What is deliberately not checked: a step's name against its row's Suite label. The two
# are prose in different voices on purpose -- the workflow names a step in a sentence
# ("Workflow steps and their documentation rows agree") where the table labels a suite in
# a noun phrase ("Workflow/documentation agreement") and doc-manifest.md glosses it in a
# third -- so there is no convention to compare them under, and inventing one would mean
# renaming every step or every row to satisfy the checker rather than the reader. A step
# name is therefore used only for the exemption census, the duplicate check and the
# written lists here, and renaming a paired step passes. The cost is that a stale gloss
# or a stale Suite label is not caught mechanically; adopting a naming convention
# document-wide is the only thing that would catch it, and it is not this checker's to
# impose.
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

# --- the load-bearing attribute list (#348) -----------------------------------------
# Keys of a paired step that decide whether it runs, or whether its failure blocks. The
# documents assert that every paired step runs and blocks, so one of these on a paired
# step is a disagreement with them unless CONDITIONAL_STEPS below says the documents
# cover it. Nothing else under scripts/ or docs/process/ reads them.
#   if                 a condition that never fires switches the step off entirely.
#   continue-on-error  the step still runs, and its failure stops blocking the job.
#   env                an environment variable can change what the run: line does while
#                      the documented command stays byte-identical, which is the same
#                      evasion by another route.
# Considered and permitted, recorded here rather than left unsaid:
#   timeout-minutes    bounds a step. It can only make a documented step fail sooner,
#                      never make it stop running or stop blocking, so it cannot weaken
#                      what the documents assert and needs no documented counterpart.
# Any other key on a paired step is unrecognised and exits 3 naming it, rather than
# being skipped, in keeping with the rule above.
LOAD_BEARING_ATTRIBUTES = ["if", "continue-on-error", "env"]
PERMITTED_ATTRIBUTES = ["name", "run", "timeout-minutes"]
# A paired step whose documentation covers its condition goes here: workflow file, then
# step name, then the exact load-bearing attributes the documents cover. Load-bearing in
# both directions like the exemption list, so it cannot become a way to wave a step
# through: an entry naming a step that is absent or unpaired is an error, and so is one
# naming an attribute that step does not carry. No documented step is conditional today,
# so the list is empty and every load-bearing attribute is a failure.
CONDITIONAL_STEPS: dict[str, dict[str, list[str]]] = {}
# --- end of the load-bearing attribute list -----------------------------------------

# --- the documented placeholder list (#347) -----------------------------------------
# Rows whose Command cell may hold a <placeholder> token under normalisation 2 above.
# Each entry is a table, a row's Suite label, and the exact placeholder-bearing tokens of
# that row's normalised command, in order. Load-bearing in both directions: an entry
# whose row is absent, exempt or no longer holds exactly these tokens is an error, and a
# placeholder token on a row no entry covers is an error, so a row cannot be widened into
# a wildcard from the document side alone.
PLACEHOLDER_ROWS = {
    "documentation suite": {
        # audit.sh writes its gap report outside the repository tree, so the documented
        # command cannot name CI's concrete path.
        "Mechanical audit": ["<scratch-path>/gap.md"],
    },
}
# --- end of the documented placeholder list -----------------------------------------

# --- the table boundary list (#347) -------------------------------------------------
# A job paired against more than one table would otherwise see the tables' rows as one
# sequence, and the boundary between them would be invisible: a row moved from the Go
# suite table into the first slot of the qualification table leaves that sequence
# unchanged, while testing.md prefaces the qualification table with the statement that
# none of its entries is a live PASS. So the first paired step of each table is written
# down here and checked against the position the preceding tables' row counts put it at.
# Load-bearing in both directions: an entry naming a step that is absent or unpaired is
# an error, and a table whose first step is not the one named is an error.
TABLE_FIRST_STEP = {
    DOCS: {
        "documentation suite": "File-mode enforcement probe (a run that bypasses modes fails here)",
    },
    GO: {
        "Go suite": "File-mode enforcement probe (a run that bypasses modes fails here)",
        "qualification local proofs": "Allow unprivileged user namespaces (hosted runner AppArmor)",
    },
}
# --- end of the table boundary list --------------------------------------------------

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


def plural(count: int, singular: str, many: str) -> str:
    return "%d %s" % (count, singular if count == 1 else many)


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


def steps_of(relative: str, job: str) -> list[tuple[str, str | None, dict[str, str]]]:
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
    steps: list[tuple[str, str | None, dict[str, str]]] = []
    for line in lines[index + 1:]:
        if line.strip() == "":
            break
        if not line.startswith("      "):
            break
        named = STEP_RE.match(line)
        if named:
            steps.append((named.group(1).strip(), None, {}))
            continue
        if line.startswith("      - "):
            unparsable("%s job %s has a step whose first key is not name:: %r" % (relative, job, line))
        key = KEY_RE.match(line)
        if not key:
            continue
        if key.group(1) == "run":
            if not steps:
                unparsable("%s job %s has a run: before any step name" % (relative, job))
            name, existing, attributes = steps[-1]
            if existing is not None:
                unparsable("%s job %s step %r has more than one run:" % (relative, job, name))
            steps[-1] = (name, key.group(2).strip(), attributes)
            continue
        if not steps:
            unparsable("%s job %s has a %s: before any step name" % (relative, job, key.group(1)))
        name, _, attributes = steps[-1]
        if key.group(1) in attributes:
            unparsable("%s job %s step %r has more than one %s:" % (relative, job, name, key.group(1)))
        attributes[key.group(1)] = key.group(2).strip()
    if not steps:
        unparsable("%s job %s has no steps" % (relative, job))
    names = [name for name, _, _ in steps]
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


def check_attributes(relative: str, name: str, attributes: dict[str, str]) -> None:
    """Every key of a paired step is permitted, declared, or an error naming it."""
    declared = CONDITIONAL_STEPS.get(relative, {}).get(name, [])
    for attribute in sorted(attributes):
        if attribute in PERMITTED_ATTRIBUTES:
            continue
        if attribute not in LOAD_BEARING_ATTRIBUTES:
            unparsable("%s step %r carries %s:, which this checker does not recognise on a paired step; "
                       "it is neither permitted (%s) nor load-bearing (%s), so it is not skipped"
                       % (relative, name, attribute, ", ".join(PERMITTED_ATTRIBUTES), ", ".join(LOAD_BEARING_ATTRIBUTES)))
        if attribute not in declared:
            disagree("%s step %r carries %s: %s, which decides whether the step runs or whether its failure blocks, "
                     "while %s documents it as a step that runs; no entry in the checker's conditional-step list covers it"
                     % (relative, name, attribute, attributes[attribute] or "(a block)", TESTING))


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


def placeholders_of(documented: str) -> list[str]:
    return [token for token in documented.split() if PLACEHOLDER_RE.search(token)]


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
placeholder_rows_seen: set[tuple[str, str]] = set()

for relative, job, table_names in PAIRINGS:
    steps = steps_of(relative, job)
    exempt = EXEMPT_STEPS[relative]
    names = [name for name, _, _ in steps]
    for entry in exempt:
        if names.count(entry) != 1:
            disagree("exemption entry %r names %d steps of %s, not exactly one" % (entry, names.count(entry), relative))
    live: list[tuple[str, str]] = []
    for name, run, attributes in steps:
        if name in exempt:
            continue
        command = command_of(relative, name, run)
        check_attributes(relative, name, attributes)
        live.append((name, command))
    kept_steps[relative] = live
    step_counts[relative] = len(live)
    live_names = [name for name, _ in live]
    for entry, declared in CONDITIONAL_STEPS.get(relative, {}).items():
        if live_names.count(entry) != 1:
            disagree("conditional-step entry %r names %d paired steps of %s, not exactly one" % (entry, live_names.count(entry), relative))
            continue
        carried = dict(steps[names.index(entry)][2])
        for attribute in declared:
            if attribute not in carried:
                disagree("conditional-step entry %r declares %s:, which %s step %r does not carry" % (entry, attribute, relative, entry))

    rows: list[tuple[str, str, str]] = []
    boundaries: list[tuple[str, int]] = []
    for table_name in table_names:
        boundaries.append((table_name, len(rows)))
        exempt_rows = EXEMPT_ROWS.get(table_name, [])
        suites = [suite for suite, _ in tables[table_name]]
        for entry in exempt_rows:
            if suites.count(entry) != 1:
                disagree("exemption entry %r names %d rows of the %s table, not exactly one" % (entry, suites.count(entry), table_name))
        declared_placeholders = PLACEHOLDER_ROWS.get(table_name, {})
        for entry in declared_placeholders:
            # An entry naming no paired row is caught once, after the pairing, by the
            # seen-set below; only a repeated Suite label needs saying here.
            if suites.count(entry) > 1:
                disagree("documented-placeholder entry %r names %d rows of the %s table, not exactly one" % (entry, suites.count(entry), table_name))
        for suite, cell in tables[table_name]:
            if suite in exempt_rows:
                continue
            documented = cell_command(table_name, suite, cell)
            held = placeholders_of(documented)
            allowed = declared_placeholders.get(suite)
            if allowed is None:
                if held:
                    disagree("%s row %r in the %s table documents %s as a placeholder, which stops this checker comparing that position, "
                             "and no entry in the checker's documented-placeholder list covers the row"
                             % (TESTING, suite, table_name, " ".join(repr(token) for token in held)))
            else:
                placeholder_rows_seen.add((table_name, suite))
                if held != allowed:
                    disagree("documented-placeholder entry %r in the %s table declares %s, but the row documents %s"
                             % (suite, table_name, " ".join(repr(token) for token in allowed) or "no placeholder",
                                " ".join(repr(token) for token in held) or "no placeholder"))
            rows.append((table_name, suite, documented))

    for table_name, boundary in boundaries:
        expected_first = TABLE_FIRST_STEP.get(relative, {}).get(table_name)
        if expected_first is None:
            unparsable("no table boundary entry names the first step of the %s table in %s" % (table_name, relative))
        if boundary >= len(live):
            disagree("the %s table starts at position %d of %s, which runs only %d paired steps, so its boundary step %r is absent"
                     % (table_name, boundary + 1, relative, len(live), expected_first))
            continue
        if live[boundary][0] != expected_first:
            disagree("the %s table starts at position %d, where %s runs %r, but the checker's table boundary list names %r; "
                     "a row moved across the boundary between two tables leaves their concatenated order unchanged"
                     % (table_name, boundary + 1, relative, live[boundary][0], expected_first))

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

for table_name, declared_rows in PLACEHOLDER_ROWS.items():
    for suite in declared_rows:
        if (table_name, suite) not in placeholder_rows_seen:
            disagree("documented-placeholder entry %r names no paired row of the %s table" % (suite, table_name))

for relative, declared_steps in TABLE_FIRST_STEP.items():
    paired_tables = [names for path, _, names in PAIRINGS if path == relative]
    known = paired_tables[0] if paired_tables else []
    for table_name in declared_steps:
        if table_name not in known:
            unparsable("table boundary entry names the %s table, which %s is not paired against" % (table_name, relative))

# --- doc-manifest.md's "## CI" list --------------------------------------------------
COUNT_RE = re.compile(r"^After checkout, the `design-docs` job runs these ([a-z-]+) steps, in this order, in:$")
# The list separates an entry from its gloss with an em dash, built here by code point
# so this file stays ASCII.
ENTRY_RE = re.compile(r"^(\d+)\.\s+`([^`]+)`\s*" + chr(0x2014) + r"\s*\S.*$")


def names_path_component(token: str, run: str) -> bool:
    """An entry token names a run token whole, or as a trailing path component of it.

    doc-manifest.md's list writes a script as a bare basename when it is under
    scripts/docs/ and as a path otherwise, so an entry cannot be compared for equality
    with a run: token. Containment would be looser than the rule: 'check-links.sh' is a
    substring of 'scripts/docs/test-check-links.sh', and the list holds three
    X.sh / test-X.sh pairs.
    """
    for candidate in run.split():
        if candidate == token or candidate.endswith("/" + token):
            return True
    return False


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
    missing = [token for token in match.group(2).split() if not names_path_component(token, run)]
    if missing:
        disagree("%s '## CI' entry %d names %r, which does not appear in the run: of the step at that position as a whole path component (%r runs %r)"
                 % (MANIFEST, position + 1, " ".join(missing), name, run))

if findings:
    for finding in findings:
        print("CI_AGREEMENT_MISMATCH: " + finding, file=sys.stderr)
    raise SystemExit(1)

print("check-ci-agreement: %d workflow steps agree with their documented commands (%s %d, %s %d), "
      "%d exemptions are all in use, %s and %s are declared and in use, "
      "%s hold, and %s's CI list of %s matches"
      % (paired_total, DOCS, step_counts[DOCS], GO, step_counts[GO],
         sum(len(v) for v in EXEMPT_STEPS.values()) + sum(len(v) for v in EXEMPT_ROWS.values()),
         plural(sum(len(v) for v in PLACEHOLDER_ROWS.values()), "placeholder row", "placeholder rows"),
         plural(sum(len(v) for v in CONDITIONAL_STEPS.values()), "conditional step", "conditional steps"),
         plural(sum(len(v) for v in TABLE_FIRST_STEP.values()), "table boundary", "table boundaries"),
         MANIFEST, count_word))
PY
