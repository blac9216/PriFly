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
# Neither a blank line nor a comment line inside a job's steps: block ends its step list
# (#361, #365). Neither ends a block in YAML, so this reader skips both and carries on.
# Until #361 it broke on a blank line and until #365 on a comment, so a step written after
# either was never read. Which guards saw it depends on the tree, so name one. Appended to
# job design-docs in docs-checks.yml at 056bdf0, before #362, a blank line and a comment
# alike were exit 0 at all nine scripts under scripts/docs/ with this checker's summary line
# byte-identical. At c1ab0dc, this change's base, #362 has closed the blank line and added
# its own docs-fixture appends, and on that same append the comment is eight of nine: the
# ninth is this checker's self-test, red for the reason #361 gives for its row C rather than
# for the comment, naming a fixture step and neither the comment nor the step appended to
# the repository's file. That is the vector the issue tables. After a blank line in job go it
# was exit 0 here too at 056bdf0, and was caught only because the self-test's own fixture
# append lands after the same blank line, so what went red named a fixture step rather than
# the workflow.
#   The predicate is now the one mapping_at applies at the two scopes above, at both scopes
#   and here. A comment does not reach it while a block scalar is open, because the branch
#   above takes the line first -- but on this reader's boundary, which is not a loader's.
#   This reader takes any line of nine spaces or more as the open scalar's; a loader takes
#   the scalar's own content indentation, ten in the one block scalar either workflow has,
#   go-checks.yml's toolchain install. So the two part company at exactly nine: yaml.safe_load
#   ends the scalar there and reads a comment, while this reader keeps the line and reports
#   the step as writing it, exit 1, "writes line 9 of run:". At ten and deeper they agree,
#   which is the case measured below. That gap is this reader's own and predates #365 -- the
#   same diagnostic reproduces at c1ab0dc -- so it is recorded here, not closed here.
# Measured after the change: the step list this reader takes for job
# go and for job design-docs is the list yaml.safe_load takes for the same job, name for
# name, on the unmutated tree, under a blank-line append to each job, and under a comment
# append to job design-docs at column 0, at two, at six and at eight spaces -- 14 against
# 14 at every one of those four indents, against 13 against 14 at column 0 and at two
# spaces before this change. A comment with no step after it leaves all nine scripts under
# scripts/docs/ exit 0 with the summary line byte-identical at each of those four indents,
# so this is a skip and not a refusal of a comment.
#   What still ends the list is stated here rather than in the limits at the foot of this
#   header (#353 M3, #358 M2, #365 M3, #369 M3). It is still the break below: the first
#   line that is neither blank nor a comment and does not begin with six spaces. That is
#   not the same as the dedent that ends the block, and this header does not claim it is --
#   that exact over-claim was #362 review round 1's C2. What #369 changed is what this
#   reader does before it can reach that break. A YAML value may close on a later line at
#   any indentation when it opens with a quote or with a flow indicator, and a loader reads
#   the steps written after such a continuation where this reader stopped at it. Until #369
#   a step attribute written that way carried the step list away with it: thirteen shapes
#   were measured silent at 4b6076c, quoted scalars and flow collections alike, each a
#   timeout-minutes: closing two or three spaces in with a further step behind it, on job
#   design-docs and on job go, every one of them exit 0 at all nine scripts under
#   scripts/docs/ but this checker's own self-test, with this checker's summary line
#   byte-identical and its step count one short of yaml.safe_load's. One of the thirteen
#   ends its first line in a backslash, which suppresses the fold, so the value is the
#   string 10 to yaml.safe_load and to psych alike and the hidden step arrives beside a
#   timeout a contributor would plausibly write. timeout-minutes: was the only key silent
#   that way, being the one step key permitted on a paired step and compared against
#   nothing; every other key of the surface was already exit 1 or exit 3, and #369's PR
#   body tables both the key surface and the indent sweep before and after. Thirteen is
#   the count of what was measured there and not of what exists: review round 1 added
#   fourteen further values silent at 4b6076c, twelve of them behind a tag or an anchor.
#   So a step key whose value does not close on the line that opens it is now refused by
#   name, in value_closes below, before the break can be reached, whether the value is
#   written bare or behind a tag or an anchor. As #369 shipped, that sentence was false in
#   two places, both found after its merge and both closed by #376. value_closes had no
#   comment rule, so timeout-minutes: [1, # ] continued two spaces in as 0] read as closed
#   at the bracket inside the comment; and it opened a quoted scalar at every quote, so
#   [a"b, "c] continued as x"] read as closed while a loader read the plain word a"b and
#   then a quoted scalar running onto the next line. Each hid a step behind it with this
#   checker's summary line byte-identical. value_closes now refuses a # anywhere outside a
#   quoted scalar, and refuses a quote met inside what may be a plain scalar rather than
#   opening a quoted scalar there; neither follows a loader's tokens, and each refuses shapes
#   a loader reads. The paragraph on the step band below says what it reads and what was
#   measured. Refusing is a choice with a cost, stated
#   here where the choice is made: this repository now rejects a step layout GitHub
#   accepts, and rejects it whether or not a step is hidden behind it -- a continued
#   value with nothing written after it hides nothing and is refused all the same, which is
#   a case in the self-test rather than a sentence here. The alternative was to read the
#   value through to its close, which would keep that layout and would hold this reader's
#   step count equal to a loader's. It was not taken: resuming after a value needs this
#   reader to know exactly where that value ends, and a resume one character out re-opens
#   the same silence, while a refusal only needs to know the value might not have ended.
#   #369 M2 rules out a YAML parser, so the treatment that needs less parsing to be correct
#   is the one taken.
#   What the rule reads is as narrow as it is written, and each exclusion below was
#   measured on this tree rather than reasoned about. It reads the value on a step key at
#   eight spaces, run: included. A YAML node may carry properties in front of its content
#   -- a tag and an anchor, in either order -- so those are dropped before anything is
#   decided, and the rule then fires where what is left begins with a double quote, a
#   single quote, a [ or a {. Dropping them is safe in the one direction that matters
#   here: neither ! nor & can begin a plain scalar in YAML, so a leading token of either
#   is a property and never content. #369 review round 1 found that rule reading the
#   property as the content instead, and twelve tagged and anchored shapes were exit 0
#   with the summary line byte-identical and a step hidden behind them, the worst of them
#   an !!int "1 ending in a backslash and continued two spaces in as 0", which both
#   loaders read as a well-formed ten-minute timeout. Those four first characters are
#   where this reader treats a value as able to continue, on the argument that a quoted
#   scalar and a flow collection may close on a line less indented than their own key
#   while nothing else may: a plain scalar continues only on a line more indented than its
#   key, so an under-indented plain continuation is not a continuation at all and neither
#   yaml.safe_load nor psych will parse the file. A block indicator, | or >, is the other
#   value that runs on past its own line, and it is deliberately not in that set: a block
#   scalar's content has to be more indented than its key, so it stays inside the
#   six-space band this reader reads. On run: its lines are read as the command. On any
#   other step key they are lines this reader does not read, which it passed over until
#   #376 and refuses by name since -- measured with a block scalar on a step's
#   timeout-minutes: at ten spaces and a step behind it, exit 1 at #369's merge with the
#   whole step list read and the step behind it reported unpaired, and exit 3 naming the
#   block's first line since #376. That argument is how
#   the set was chosen and how round 1's gap was found; it is not a proof that the set is
#   exhaustive, and this header does not claim one.
#   It does not read a step's own - name: line, which STEP_RE takes first: an open name:
#   leaves the step without a run:, which is exit 3, measured at a middle step of job
#   design-docs and at the last one. Until #376 it did not read a sub-key under a step key,
#   and the three such shapes this tree can carry -- a paired step's env:, an exempt step's
#   with:, an exempt step's env: -- were each exit 1 at the comparisons that read those
#   sub-maps, while on a constructed tail exempt step, whose env: is compared by name and
#   not by value, a continued env: value hid a step with the summary byte-identical. Since
#   #376 the rule reads a sub-key's value as it reads a key's, so all four are exit 3 here.
#   It does not read the two scopes above the steps, whose own outcomes are in #369's
#   key-surface table. That is the shapes measured, not a proof that no silent one exists;
#   a YAML parser is out of scope here as it was in #361.
#   What the step band holds besides those keys is the next paragraph's.
#
# A line in the step band that this reader does not read is refused by name (#376). A line
# here is text ended by a line feed, which is the only character this reader splits on.
# YAML also ends a line at a carriage return, and yaml.safe_load and psych end one at NEL,
# LS and PS too (U+0085, U+2028, U+2029, line breaks in YAML 1.1), so one line here could be
# two to a loader, the second read into the first's value and never seen: after a
# timeout-minutes: 5, a carriage return then if: false switched off go build, or a carriage
# return then a - name: and a run: added a step, each exit 0 at b05932b with the summary
# line byte-identical, and the same held at job scope and for each of the other three
# characters. So workflow_lines refuses a workflow whose text holds any of the four,
# anywhere, before either scope or the steps are read. A workflow saved with CRLF line
# endings was refused at b05932b already, since the job lookup misses a job line that ends
# in a carriage return; the refusal now names the carriage return and its line instead.
# What is newly refused, and is the cost, is any of the four where a loader reads the file
# with nothing hidden. Measured on go build's step at b05932b, each of these was exit 0 with
# the summary line byte-identical, and both loaders read the file with its 18 steps: any of
# the four inside a quoted value, where both loaders fold a carriage return or NEL into a
# space and keep LS and PS as text, as YAML 1.2 does; and any of the four at the end of a
# comment. Both loaders end a comment at each of the four, so with comment text after one
# neither loads the file at all. The self-test pins the CRLF file and a carriage return at
# the end of a comment. Whether GitHub
# Actions' own parser breaks a line at any of the four is not known here. The
# band is every line of a job's steps: block that begins with six spaces, and this reader
# reads a line there as one of five things: a step's - name:, a step key at eight spaces, a
# sub-key at ten under a step key that opened a block -- one with nothing after its colon
# -- a line of a run: block scalar, or a blank or comment line. Until #376 any other line
# was passed over while a loader read it, and at b05932b each of these was exit 0 at this
# checker with its summary line byte-identical: "if": false, if : false, a quoted
# continue-on-error: and ? if with : false on a paired step, each of which a loader reads
# as the key it disables or unblocks the step with; a plain run: continued on a deeper line,
# which a loader folds into the command, so go test ./... ran as go test ./... -run XNONE
# beside a row that still documents go test ./...; and a value opened on the line after its
# key, a sub-key's value, a block sequence item or a quoted key, each continued two or three
# spaces in with a step written behind it. Every one of those is exit 3 now, as is an empty
# run: with a sub-map under it, which met a KeyError traceback before, exit 1. This
# reader's own header said the opposite of that until #376 -- the sentence on the
# load-bearing attribute list below, that a key the list does not recognise is an error
# rather than something skipped, was true only of a key this reader could spell.
#   Refuse rather than read through, for the reason given for #369 above: reading a line
#   this reader does not otherwise understand means knowing exactly what a loader makes of
#   it, and refusing only means knowing that it might be something. The cost is stated
#   here where the choice is made. Each of these is refused although a loader reads it and
#   although none of them hides a step, and each is a case in the self-test rather than a
#   sentence only: a continued value with nothing after it; a plain value continued on a
#   deeper line, such as timeout-minutes: 5 then a:b ten spaces in, which a loader reads as
#   the string 5 a:b; a # inside a plain scalar in a flow value, [a#b], which a loader reads
#   as text; a quote inside a plain word in a flow value, [a"b"]; and a quote directly after
#   a colon, {"a":"b"}, which yaml.safe_load and psych both read as a mapping. Also refused,
#   measured and not pinned by a case: a block scalar or a nested mapping on a step key
#   other than run:, and a tag, an anchor or a ? in a flow collection in front of a quoted
#   scalar, such as [!!str "a"]. A block scalar or a nested mapping as a sub-key's value
#   under with: or env: is not a new cost, since the rule under those two keys already
#   refused it, and with: written as a block scalar itself was already exit 1 at the
#   comparison and is exit 3 now.
#   What was measured, and what was not. value_closes was run over every value of up to six
#   characters from [ ] { } , " ' # a : and space that begins with [ or { -- 354,312 values
#   -- and over every such value of up to seven characters, 3,897,434 in all, each written on
#   a step key with a step behind it and a candidate continuation line two spaces in between.
#   None of them is read as closed here while yaml.safe_load reads the continuation into the
#   value and the step behind it as a step. That is agreement with one loader on one
#   alphabet up to one length, measured, and not a proof that the step band is read as a
#   loader reads it; #376's PR body gives the method and the numbers. The two loaders
#   themselves differ on a tab after a colon or at a token start in a flow collection, which
#   psych reads and yaml.safe_load rejects, and value_closes reads it the way psych does.
#
# A step is more than its run: line. Which of its other keys decide whether it runs at
# all, and whether its failure blocks, is written down in the load-bearing attribute list
# below (#348); a paired step carrying one of them disagrees with documents that assert
# it runs, and a key the list does not recognise is an error rather than something
# skipped. Until #376 that was true only of a key this reader could spell: "if": false or
# if : false on a paired step was skipped, with this checker exit 0 and its summary line
# byte-identical while a loader switched the step off. A line in the step band this reader
# cannot read as a key is an error now too, as the paragraph above says.
#
# A step is also less than everything that decides whether it runs (#353). A never-firing
# if: on the job skips every step inside it, continue-on-error: on the job stops the job
# blocking, and an env: block at job or workflow level reaches every run: line beneath it,
# so each of those closes a documented step from a scope outside the step. This checker
# therefore reads three scopes, not one: the workflow mapping at the top of the file, the
# mapping of each job it pairs, and that job's steps. The scope key lists below say which
# keys are permitted at which scope, which are load-bearing there, and -- because a job
# mapping is the one scope where a load-bearing key is live and legitimate -- which
# environment variables a job may set. At every one of the three scopes a key no list
# recognises is an error naming the key and the scope, not something skipped. That is what
# makes the treatment cover the whole mapping rather than three named keys of it, and it is
# why defaults: at job level is an error here rather than a pass. The same rule holds one
# level down inside an env: block, whose variables are compared against a written list: a
# line there that this reader cannot read as a variable is an error too, because an absent
# variable is what a clean scope looks like. Round 1 of this change's review found that gap
# open -- a quoted "GOFLAGS" name in the live block set -mod=mod with the checker green --
# so the shape is the one the reader errors on rather than a precaution.
#
# An exempt step is unpaired, not unread (#353, #358, #361). The documents assert nothing
# about what an exempt step's command is -- that is what exempting it means -- but the paired
# steps run only because it ran, and they run on what it left behind: the toolchain install
# is what puts the pinned go on PATH for the documented go commands, and the checkout is
# what decides which tree those commands read. So an exempt step's keys are read three
# ways, and the ground for each is given here, where the decision is made, rather than
# corrected in the limits at the foot of this header:
#   if: and continue-on-error: are load-bearing, for the reason they are on a paired step.
#   A step the documents rely on must still run, and its failure must still block.
#   uses:, with: and run: are declared rather than permitted (#358). They are compared
#   against the declared exempt content list below, which is what an exempt step carries
#   in place of a documented row. Until #358 they were permitted, on the env: reasoning
#   given next, which does not cover them. A run: line reaches past its own step: by
#   writing $GITHUB_ENV or $GITHUB_PATH, which the install step already does, and by
#   writing files, which is the wider route -- two lines appended to that step overwrite
#   the extracted go binary after the sha256sum -c that covers the archive has passed, and
#   every guard under scripts/docs/ was exit 0 on that, check-go-digest.sh included,
#   because the pinned archive is still downloaded, still checksummed and still extracted.
#   A with: value is no narrower: the checkout step's ref: decides which tree every
#   documented command below it runs against.
#   env: is declared as well, by name and not by value. Which names the block sets decides
#   what the step's own commands see: a PATH added to the install step's block decides which
#   curl, sha256sum and tar its declared run: lines find, and an LD_PRELOAD decides what
#   those binaries do once they run. Each of those, added alone, was exit 0 at all nine
#   scripts under scripts/docs/ with this checker's summary line byte-identical, until this
#   list read the names -- that much is measured here; what a runner does with either
#   variable is the platform's documented behaviour and no run here has exercised it. Round 1
#   of this change's review found it, and was right: the first draft of limit 3 below claimed
#   the digest guard covered the case, and it does not, because nothing that guard or the
#   declared run: text pins has to move for either name to be added.
#   The values are left to the guards that do pin them, named here rather than restated:
#   check-go-digest.sh pins GO_ARCHIVE_SHA256 against docs/reference/source-register.md, and
#   the declared run: above checks GO_ARCHIVE against go.mod's go directive every time the
#   step runs. Restating either value here would put it in a third file. This is what became
#   of the env: reasoning that used to be offered for all six keys: a step's own env: does
#   reach only that step's own unpaired command, and that was never the whole question,
#   because that command is the install.
#   name: and timeout-minutes: are permitted. timeout-minutes: can only make the step fail
#   sooner, never stop it running or stop it blocking, so it cannot weaken what the documents
#   assert; a second name: would need a duplicate eight-space key, which is not valid YAML.
# Where the step sits is read as well (#361), and that is not a key. Both clauses of the
# ground above are claims about order -- on PATH for the documented commands below it, and
# which tree those commands read -- and until #361 neither was checked: the pairing loop
# skips an exempt step and discards its index, so the list it pairs positionally holds
# paired steps only, and order was enforced across the steps this checker pairs and not at
# all across the four it exempts. Moving the install, or the checkout, to the end of
# job go was a pure reorder -- sort over the mutated file is byte-identical to sort over
# the original, so no step's content changed at all -- and it left all nine scripts under
# scripts/docs/ at exit 0 with this checker's summary line byte-identical. So each exempt
# step's position in its job's step list is declared below, by number, in the declared
# exempt position list. The pairing already pins the order of the paired steps among
# themselves, so declaring where each exempt step sits among them pins a job's whole step
# order rather than the paired subsequence of it: a permutation of a job's steps that is
# not the identity either moves an exempt step, which this list reads, or reorders two
# paired steps, which the pairing reads -- and no two paired steps of either job run the
# same command on this tree, so no such reorder is invisible to it. Both measured on
# go-checks.yml: swapping go vet and go test is exit 1 at the pairing, naming both rows,
# and swapping the file-mode probe with the toolchain install beside it is exit 1 here,
# naming the install's declared and observed positions.
# What that proves is where the step is written.
# What a runner does with the order it is written in -- that a job's steps run in file
# order, and that a $GITHUB_PATH write applies to the steps after it -- is the platform's
# documented behaviour, and no run here has exercised it.
#
# The exemption list below is load-bearing in both directions: a step or row that is
# neither paired nor listed is an error, and an entry that names no step or row is an
# error too, so the list cannot decay into a wildcard. A checker that instead skipped
# what it could not pair would be worse than no checker. The documented placeholder list,
# the table boundary list, the declared job environment list, the declared exempt content
# list and the declared exempt position list are load-bearing in both directions for the
# same reason and in the same way:
# every entry of each names something this tree carries, so deleting an entry turns this
# checker red with no other edit -- measured for each, entry by entry, not asserted. The
# conditional step list is empty, having nothing to cover today, so its two directions are
# proved by the self-test filling it instead.
#
# The key lists do not all rot that way, and the sentence they used to share with those
# overstated it (#353 F4). Measured by deleting each entry with nothing else changed:
#   Entries that name a key this tree carries, and so give exit 3 on their own -- every
#   entry of the job permitted list (runs-on, timeout-minutes, steps), of the workflow
#   permitted list (name, on, permissions, jobs) and of the exempt declared list (uses,
#   with, run, env), and env in the job load-bearing list. Twelve of the twenty-five,
#   re-measured entry by entry for #358 and again when env moved into the declared list.
#   Entries that name a class of possible edit rather than a live key, and so cost nothing
#   to delete until a tree carries the key -- all three step load-bearing attributes, all
#   three permitted step attributes, if and continue-on-error at job and exempt-step scope,
#   env at workflow scope, and name and timeout-minutes in the exempt permitted list.
#   These rot only on a tree that carries the key. The self-test proves that shape at the
#   entry #353 F4 named: it adds timeout-minutes to a paired step, deletes the entry from
#   the permitted list and requires exit 3. Every other class entry, run and name aside,
#   has a case that adds the key to the tree and requires what its list says -- a named
#   red for a load-bearing entry, green for a permitted one.
# run and name are in the permitted attribute list to document what a paired step may carry
# rather than as reachable control flow: run never reaches the attribute dictionary, because
# steps_of consumes it on its own branch, and a second name: would need a duplicate
# eight-space key, which is not valid YAML. run in the exempt declared list is live all the
# same, and not through that dictionary: the declared exempt content list declares run: on
# the install step, and an entry declaring a key the exempt declared list does not name is
# exit 3, so deleting the entry is red with nothing else changed.
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
# Three further limits, recorded here where its readers look rather than in a review
# comment (#353 M4, #358):
#   1. The "## CI" manifest check proves that every whitespace token of an entry's code
#      span appears in the paired step's run: as a whole path component. It does not prove
#      that the entry names the step's script. Entry 6 narrowed from test-check-links.sh to
#      the bare interpreter name bash is exit 0, because bash is a whole path component of
#      that step's run:; narrowed to check-links.sh it is still exit 1 naming the entry and
#      the position, which is the outcome #347 M1 asked for. An entry that has stopped
#      naming a script at all is left to a human reader.
#   2. Scopes outside the three above are not read. A reusable workflow (jobs.<id>.uses) and
#      a composite action run steps this checker never sees; neither file uses one today,
#      and a job it pairs that did would exit 3 on the unrecognised uses: key rather than
#      pass. A job of these files that no pairing names is not read at all: it cannot switch
#      off a documented step, but nothing here audits it.
#   3. What the declared exempt content list (#358) does and does not prove. Where this
#      limit used to say that an exempt step's run: was a route to the job environment
#      that the checker did not close, and that whether it should was filed rather than
#      decided, the filing was #358 and this is what it decided: those keys are compared
#      against declared text, and env: against declared names, so an appended $GITHUB_ENV
#      write, an appended line overwriting the extracted toolchain, a changed checkout ref:,
#      and a PATH or LD_PRELOAD added to the install step's env: are each exit 1 naming the
#      step and the key. Each of those five is measured at this checker; what a runner would
#      do with the edit is separate, and marked below where it is not measured. What the comparison proves is that the text has not changed, not
#      what the text does. Nothing here reads what a shell command does, and
#      that general shell analysis is deliberately out of reach of a line-shaped checker.
#      Four things the declaration therefore does not reach, each recorded rather than
#      claimed closed:
#        - whether a value written to $GITHUB_ENV overrides a job-level env: of the same
#          name on a hosted runner is read from the platform's documentation and has never
#          been measured here. The pin makes the question moot for these files rather than
#          answering it.
#        - a with: value is compared as text, so what an expression such as
#          ${{ github.event.pull_request.head.sha || github.sha }} evaluates to on a runner
#          is platform behaviour this checker does not see. It proves the expression is the
#          one declared, which is what #146's second criterion asks of the file.
#        - a uses: value pins the action's ref as written, including the version comment
#          beside it. That the ref names the code GitHub runs is the SHA pin's claim, not
#          this checker's.
#        - an exempt step's env: block is compared by name and not by value, so what the two
#          declared names are set to is not read here. Both values are pinned outside this
#          checker: check-go-digest.sh pins GO_ARCHIVE_SHA256 against source-register.md, and
#          the declared run: text checks GO_ARCHIVE against go.mod, which fails when the step
#          runs rather than here. A toolchain bump moves the workflow and the register
#          together and passes, which is the intended path; a value changed on its own is
#          caught by one of those two guards, not by this list. Declaring the values here as
#          well would put GO_ARCHIVE_SHA256 in a third file, so a bump would be three edits
#          rather than two; that cost is recorded here rather than paid.
#
# Fails closed. Exit 0 everything agrees; 1 a disagreement, reported one line per finding;
# 2 usage error; 3 a file it reads is missing, unreadable or not UTF-8, a table it reads
# has no rows, a key it does not recognise at one of the three scopes, or something else it
# cannot normalise.
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
from typing import NamedTuple

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

# --- the scope key lists (#353) -----------------------------------------------------
# Keys of the workflow mapping, and of a paired job's mapping, classified the way a paired
# step's keys are. Load-bearing means the key decides whether the documented steps beneath
# it run, or whether their failure blocks; permitted means it cannot. A key in neither list
# is unrecognised at that scope and exits 3 naming it, so these lists account for the whole
# mapping rather than for three keys of it -- defaults: at job level is the worked example.
# Job scope, load-bearing:
#   if                 a condition that never fires skips every step of the job, the
#                      file-mode enforcement probe (#341) among them, which is one level
#                      above where #348 closed the same door.
#   continue-on-error  the job still runs, and its failure stops blocking.
#   env                reaches every run: line in the job, so it can change what a
#                      documented command does while the command stays byte-identical. It
#                      is the one load-bearing key that is live and legitimate here, so it
#                      has the declaration list below rather than a ban.
# Job scope, permitted, recorded here rather than left unsaid:
#   runs-on            names the machine. A label no runner matches leaves the job queued,
#                      so the required check never reports, rather than reporting green
#                      with a documented step unrun.
#   timeout-minutes    the same reason as at step scope: it can only make the job fail
#                      sooner, never stop it running or stop it blocking.
#   steps              the pairing above reads it.
# Workflow scope, load-bearing:
#   env                reaches every run: line of every job. Neither workflow file sets one
#                      today, so it is banned outright rather than declared: there is
#                      nothing live to accommodate. One that ever becomes legitimate needs
#                      the declaration treatment job scope has, decided here.
# Workflow scope, permitted:
#   name, on           renaming the workflow or narrowing on: withholds the required check
#                      rather than reporting it green, so branch protection blocks instead.
#   permissions        can only take capability away from the token, which fails a step
#                      loudly; it cannot stop one running or stop its failure blocking.
#   jobs               holds the job mappings this checker reads.
# Every "permitted" reason above about what GitHub does with a queued job, a renamed
# workflow, a narrowed on: or a reduced token is read from the platform's documented
# behaviour and from the required-check configuration, not from a live run made for this
# checker: no run here has exercised them. What it proves about a permitted key is only
# that the key is one the lists account for; the key's value is not read, so a changed
# runs-on: or a narrowed on: is exit 0 here and is left to the reasons above.
JOB_LOAD_BEARING = ["if", "continue-on-error", "env"]
JOB_PERMITTED = ["runs-on", "timeout-minutes", "steps"]
WORKFLOW_LOAD_BEARING = ["env"]
WORKFLOW_PERMITTED = ["name", "on", "permissions", "jobs"]
# The environment a job may set: workflow file, then job, then the exact variables and
# values. Load-bearing in both directions like the exemption list, so a live block cannot
# become a way to wave a job through: an entry naming a job with no env: block, or without
# that variable, or setting another value, is an error, and a variable no entry names is an
# error too. The two below are what go-checks.yml sets today, and testing.md's local Go
# recipe exports exactly them, so the documented commands and the CI commands run under the
# same environment.
DECLARED_JOB_ENV = {
    GO: {
        "go": {
            # No toolchain is fetched on demand: the archive pinned on the install step is
            # the only Go, and a go.mod directive it does not satisfy is an error rather
            # than a silent download.
            "GOTOOLCHAIN": "local",
            # go.mod and go.sum are inputs, never outputs, so no documented command can
            # quietly rewrite them.
            "GOFLAGS": "-mod=readonly",
        },
    },
}
# --- end of the scope key lists ------------------------------------------------------

# --- the exempt step key list (#353, #358) -------------------------------------------
# An exempt step has no documented command, so its keys are read for whether it runs, for
# whether its failure blocks, and -- since #358 -- for what it installs and which tree it
# leaves the documented commands to run on; the exempt-step paragraph in the header gives
# the ground for each of the three treatments. No exempt step carries either load-bearing
# key today and there is no declaration shape for one: an exempt step that needs a
# condition is a decision to take here, in this list, rather than in a workflow file.
EXEMPT_LOAD_BEARING = ["if", "continue-on-error"]
EXEMPT_PERMITTED = ["name", "timeout-minutes"]
EXEMPT_DECLARED = ["uses", "with", "run", "env"]
# The content of an exempt step: workflow file, then step name, then what each
# EXEMPT_DECLARED key it carries may be. Three shapes, one per kind of key:
#   a string  the key's exact text. run: is the scalar on the key line and the lines of its
#             block beneath it, joined by newlines and written here exactly as the file
#             writes them; uses: is the value as written, version comment included.
#   a mapping the key's exact sub-map, name by name and value by value, which is what with:
#             gets, because a with: value is what the action does.
#   a list    the names the key's sub-map may set, with the values left to the guards named
#             for them. env: gets this, and only this, for the reason given in the
#             exempt-step paragraph above.
# Load-bearing in both directions, like the exemption list: an entry naming a step that is
# absent or not exempt is an error, an entry declaring a key the step does not carry is an
# error, an entry declaring a key EXEMPT_DECLARED does not name is an error, and one of
# those keys on an exempt step that no entry declares is an error. So the list cannot
# decay into a wildcard, and an exempt step cannot gain a run: without this list moving.
DECLARED_EXEMPT_CONTENT: dict[str, dict[str, dict[str, object]]] = {
    DOCS: {
        "Check out the PR head commit (not the synthetic merge ref)": {
            "uses": "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1",
            # #146's second criterion: the tested ref is chosen explicitly rather than
            # taken from the synthetic merge commit. Declared here so changing it to a
            # branch name, which reads the tip of that branch instead of the tree under
            # review, is a finding rather than a step name that still claims otherwise.
            "with": {
                "ref": "${{ github.event.pull_request.head.sha || github.sha }}",
                "persist-credentials": "false",
            },
        },
    },
    GO: {
        "Check out the PR head commit (not the synthetic merge ref)": {
            "uses": "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1",
            "with": {
                "ref": "${{ github.event.pull_request.head.sha || github.sha }}",
                "persist-credentials": "false",
            },
        },
        "Install pinned Go toolchain (verify SHA-256, then extract)": {
            # Every line of the install is declared, not just the download: the checksum
            # covers the archive at the moment it is verified, and a line after the
            # extraction can replace what was extracted with the digest still matching.
            # A line added, removed or changed anywhere in this block is a finding naming
            # the line. The leading and trailing newlines below frame the literal and are
            # stripped; nothing else about either side is normalised.
            # A name here, not a value. Which names the step sets decides what its own
            # commands see -- a PATH or an LD_PRELOAD added to this block changes which
            # curl, sha256sum and tar the lines below run, with the digest and the run:
            # text both untouched, which is exit 0 at every guard under scripts/docs/ and
            # was until this list read the names (round 1 of this change's review). The two
            # values are pinned outside this checker, so restating them here would put
            # GO_ARCHIVE_SHA256 in a third file; the exempt-step paragraph says which guard
            # pins which.
            "env": ["GO_ARCHIVE", "GO_ARCHIVE_SHA256"],
            "run": r"""
|
          set -euo pipefail
          test "$(uname -s)-$(uname -m)" = Linux-x86_64
          test "$GO_ARCHIVE" = "go$(awk '$1 == "go" { print $2 }' go.mod).linux-amd64.tar.gz"
          curl -fsSL --proto '=https' --proto-redir '=https' -o "$RUNNER_TEMP/$GO_ARCHIVE" "https://go.dev/dl/$GO_ARCHIVE"
          (cd "$RUNNER_TEMP" && echo "$GO_ARCHIVE_SHA256  $GO_ARCHIVE" | sha256sum -c -)
          tar -C "$RUNNER_TEMP" -xzf "$RUNNER_TEMP/$GO_ARCHIVE"
          echo "$RUNNER_TEMP/go/bin" >> "$GITHUB_PATH"
""".strip("\n"),
        },
        "Restore Go module cache (keyed by go.sum)": {
            "uses": "actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0",
            "with": {
                "path": "~/go/pkg/mod",
                "key": "go-mod-${{ runner.os }}-${{ hashFiles('go.sum') }}",
            },
        },
    },
}
# --- end of the exempt step key list --------------------------------------------------

# --- the declared exempt position list (#361) ---------------------------------------
# Where each exempt step sits in its job's step list, counting every step of the job from
# one, exempt steps included. The exempt-step paragraph in the header gives the ground:
# both clauses of it are claims about order, and the pairing reads order across paired
# steps only. Load-bearing in both directions, like the lists above: an entry naming a
# step that is not on the exemption list is an error, an entry naming no step of that file
# is an error, and an exempt step no entry covers is an error, so the list cannot decay
# into a wildcard and an exempt step cannot be moved without this list moving.
DECLARED_EXEMPT_POSITION: dict[str, dict[str, int]] = {
    DOCS: {
        "Check out the PR head commit (not the synthetic merge ref)": 1,
    },
    GO: {
        "Check out the PR head commit (not the synthetic merge ref)": 1,
        "Install pinned Go toolchain (verify SHA-256, then extract)": 3,
        "Restore Go module cache (keyed by go.sum)": 4,
    },
}
# --- end of the declared exempt position list ----------------------------------------

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
SUB_RE = re.compile(r"^          ([A-Za-z0-9_-]+):(.*)$")
# The sub-map of these step keys is compared against the declared exempt content list
# above, so a line under one of them that this reader cannot read as a key is an error
# rather than an absent key -- the rule mapping_at applies under env:, for the same reason:
# absent is what a step that declares nothing there looks like, so a quoted key or an odd
# indent would otherwise set a variable the comparison never sees. That is not a precaution:
# round 1 of PR #355 found exactly that shape live at job scope. Under every other step key
# the sub-map is a census the caller does not compare.
STEP_READ_THROUGH = ("with", "env")


class Step(NamedTuple):
    """One step of a job: its name, its run:, and the keys and sub-maps beside it.

    `run` is the scalar on the run: key, so it is "|" for a block scalar, and `body` holds
    that block's lines exactly as the file writes them, indentation included. `attributes`
    holds the step's other keys at their own indent and `blocks` the mapping one level
    under each of them, which is empty for a key whose value is a scalar.
    """
    name: str
    run: str | None
    body: list[str]
    attributes: dict[str, str]
    blocks: dict[str, dict[str, str]]


def written_run(step: Step) -> str:
    """A step's run: as the file writes it: the scalar, then its block's lines."""
    return "\n".join([step.run or ""] + step.body)


def value_closes(value: str) -> bool:
    """Whether a step attribute's value is finished on the line that opens it (#369).

    A YAML node may carry properties -- a tag and an anchor, in either order, separated
    from each other and from the content by whitespace -- and those are written in front
    of the content without being it. They are dropped first. Neither indicator can begin
    a plain scalar in YAML, so dropping a leading ! or & token cannot swallow content.
    A value that is only properties leaves nothing on this line, so nothing here is open.
    Its content, if it has any, begins on a later line, and that line is steps_of's to read
    as a sub-key or to refuse. Until #376 steps_of passed it over, so timeout-minutes: !!str
    with its content on the next line and a step behind it was exit 0 here.
    Reading an indicator as the content answers "closed" for every tagged and anchored
    value there is; the header above records what that cost and how it was measured.

    What is left decides on its first character. A double or single quote opens a quoted
    scalar and a [ or { opens a flow collection; either may close on a later line at any
    indentation, and a loader reads on through it. Anything else -- a plain scalar, a
    block indicator, an alias -- either ends on this line or continues only on a line
    more indented than its own key, so an under-indented continuation of one is not a
    continuation at all and neither yaml.safe_load nor psych will parse the file.
    Quotes are tracked inside a flow collection too, so a bracket written inside one of
    its scalars is text rather than nesting, and a backslash escape inside a double-quoted
    scalar and a doubled quote inside a single-quoted one do not close it.

    Inside a flow collection two more things decide, both where a loader's own tokens
    begin (#376). A # outside a quoted scalar is not closed: a loader starts a comment at a
    # wherever it would start its next token, after whitespace and directly after [, {, ,
    or a quoted key's :, and a bracket in that comment closes nothing. A # inside a plain
    word, [a#b], is text to a loader and is refused here all the same, which is the cost of
    not tracking the difference. And a quote opens a quoted scalar only where a loader
    starts a token. Inside a plain scalar it is text -- a"b is one word, and so is a "b,
    because a space does not end a plain scalar in a flow collection, and a:"b, because a
    colon ends one only before a space or a tab -- so a quote met while `plain` is set is
    not closed. `plain` is cleared by [, {, a comma, and a colon followed by a space or a
    tab; whitespace leaves it as it is; any other character outside a quoted scalar sets
    it. That keeps `plain` set in places a loader starts a token -- after a ] or a }, after
    a ? or a tag -- which only refuses more.
    """
    while value[:1] in ("!", "&"):
        parts = value.split(None, 1)
        value = parts[1] if len(parts) > 1 else ""
    if value[:1] not in ('"', "'", "[", "{"):
        return True
    depth = 0
    quote = ""
    plain = False
    index = 0
    while index < len(value):
        char = value[index]
        if quote == '"':
            if char == "\\":
                index += 2
                continue
            if char == '"':
                quote = ""
                if not depth:
                    return True
        elif quote == "'":
            if char == "'":
                if value[index + 1:index + 2] == "'":
                    index += 2
                    continue
                quote = ""
                if not depth:
                    return True
        elif char == "#":
            return False
        elif char in ('"', "'"):
            if plain:
                return False
            quote = char
        elif char in "[{":
            depth += 1
            plain = False
        elif char in "]}":
            depth -= 1
            if not depth:
                return True
        elif char == ",":
            plain = False
        elif char == ":" and value[index + 1:index + 2] in (" ", "\t"):
            plain = False
        elif char not in " \t":
            plain = True
        index += 1
    return False


LINE_BREAKS = {"\r": "a carriage return", "\x85": "NEL (U+0085)", "\u2028": "LS (U+2028)", "\u2029": "PS (U+2029)"}


def workflow_lines(relative: str) -> list[str]:
    """A workflow's lines, split at each line feed, and refused if it holds another character a loader may break at."""
    text = read(relative)
    for char, name in LINE_BREAKS.items():
        if char in text:
            unparsable("%s holds %s on line %d, which a YAML loader may read as a line break while this reader reads "
                       "on to the next line feed, so a loader could read a line here that this reader never sees"
                       % (relative, name, text.count("\n", 0, text.index(char)) + 1))
    return text.split("\n")


def steps_of(relative: str, job: str) -> list[Step]:
    lines = workflow_lines(relative)
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
    steps: list[Step] = []
    current = ""            # the step key whose sub-map is being read
    body: list[str] | None = None   # the block scalar being read, or None outside one
    pending: list[str] = []         # blank lines held until the block resumes
    for line in lines[index + 1:]:
        if body is not None:
            # A block scalar's lines are more indented than the run: key that opens it, and
            # a blank line inside one belongs to it. Blanks are held rather than appended
            # so that a blank line after the block's last line does not join the block.
            if line.strip() == "":
                pending.append(line)
                continue
            if line.startswith(" " * 9):
                body.extend(pending)
                body.append(line)
                pending = []
                continue
            body = None
            pending = []
        if line.strip() == "" or line.lstrip(" ").startswith("#"):
            # Insignificant YAML, not the end of the list: a blank line (#361), and a comment
            # line at any indentation (#365). Neither ends a block, so neither ends this list;
            # the break below is what ends it. Breaking on either left a step written after
            # one unread while a YAML loader still ran it. This is the predicate mapping_at
            # applies at the workflow and job scopes, now applied here too. A comment does
            # not reach this line while a block scalar is open: the branch above takes any
            # line of nine spaces or more as that scalar's. Nine is this reader's boundary,
            # not a loader's, and the header says where the two part company.
            continue
        if not line.startswith("      "):
            break
        named = STEP_RE.match(line)
        if named:
            steps.append(Step(named.group(1).strip(), None, [], {}, {}))
            current = ""
            continue
        if line.startswith("      - "):
            unparsable("%s job %s has a step whose first key is not name:: %r" % (relative, job, line))
        key = KEY_RE.match(line)
        if key:
            current = key.group(1)
            value = key.group(2).strip()
            if not steps:
                unparsable("%s job %s has a %s: before any step name" % (relative, job, current))
            if not value_closes(value):
                unparsable("%s job %s step %r has a %s: whose value does not close on the line that opens it, so this "
                           "reader would stop at the continuation line and miss every step written below it while a "
                           "YAML loader ran them: %r"
                           % (relative, job, steps[-1].name, current, value))
            if current == "run":
                if steps[-1].run is not None:
                    unparsable("%s job %s step %r has more than one run:" % (relative, job, steps[-1].name))
                if value[:1] in ("|", ">"):
                    body = []
                    steps[-1] = steps[-1]._replace(run=value, body=body)
                else:
                    steps[-1] = steps[-1]._replace(run=value)
                continue
            if current in steps[-1].attributes:
                unparsable("%s job %s step %r has more than one %s:" % (relative, job, steps[-1].name, current))
            steps[-1].attributes[current] = value
            steps[-1].blocks[current] = {}
            continue
        sub = SUB_RE.match(line)
        if sub and steps and current in steps[-1].blocks and steps[-1].attributes[current] == "":
            value = sub.group(2).strip()
            if not value_closes(value):
                unparsable("%s job %s step %r has a sub-key %s: under %s: whose value does not close on the line that opens it, so "
                           "this reader would stop at the continuation line and miss every step written below it while a "
                           "YAML loader ran them: %r"
                           % (relative, job, steps[-1].name, sub.group(1), current, value))
            steps[-1].blocks[current][sub.group(1)] = value
            continue
        if current in STEP_READ_THROUGH and steps and line.startswith(" " * 9):
            unparsable("%s job %s step %r holds a line under %s: that this checker cannot read as a key, so it cannot "
                       "compare it with the list that declares what the step may carry there: %r"
                       % (relative, job, steps[-1].name, current, line))
        unparsable("%s job %s %s holds a line this reader does not read, so it cannot say what a YAML loader makes of "
                   "it: %r" % (relative, job, "step %r" % steps[-1].name if steps else "steps: block", line))
    if not steps:
        unparsable("%s job %s has no steps" % (relative, job))
    names = [step.name for step in steps]
    for name in names:
        if names.count(name) > 1:
            unparsable("%s job %s has more than one step named %r" % (relative, job, name))
    return steps


def mapping_at(lines: list[str], start: int, indent: int, where: str,
               read_through: tuple[str, ...] = ()) -> tuple[dict[str, str], dict[str, dict[str, str]]]:
    """The keys of one YAML mapping, each with the one-level-deeper sub-map under it.

    Reads the mapping whose keys sit at exactly `indent` spaces, from line `start` until
    the file dedents out of it. A line at the mapping's own indent that is not a key is an
    error rather than something skipped, so an unread shape cannot pass as an empty one.

    Under a key named in `read_through` the same rule holds one level down, because the
    caller compares that sub-map against a written list: a line there that this reader
    cannot read as a variable is an error, not an absent variable. Absent is what a clean
    scope looks like, so dropping an unreadable line would let a quoted name, an odd
    indent or a merge key set a variable the comparison never sees. Under every other key
    the sub-map is a census the caller does not compare, and deeper lines are that key's
    own block -- a step list among them -- so they are not read here.
    """
    keys: dict[str, str] = {}
    blocks: dict[str, dict[str, str]] = {}
    key_re = re.compile(r"^%s([A-Za-z0-9_-]+):(.*)$" % (" " * indent))
    sub_re = re.compile(r"^%s([A-Za-z0-9_-]+):(.*)$" % (" " * (indent + 2)))
    current = ""
    for line in lines[start:]:
        if line.strip() == "" or line.lstrip(" ").startswith("#"):
            continue
        if indent and re.match(r"^ {0,%d}\S" % (indent - 1), line):
            break
        key = key_re.match(line)
        if key:
            current = key.group(1)
            if current in keys:
                unparsable("%s has more than one %s: key" % (where, current))
            keys[current] = key.group(2).strip()
            blocks[current] = {}
            continue
        sub = sub_re.match(line)
        if sub and current:
            blocks[current][sub.group(1)] = sub.group(2).strip()
            continue
        if current in read_through and line.startswith(" " * (indent + 1)):
            unparsable("%s holds a line under %s: that this checker cannot read as a variable, so it cannot compare it "
                       "with the list that says which variables the scope may set: %r" % (where, current, line))
        if line.startswith(" " * (indent + 2)):
            continue
        unparsable("%s holds a line this checker cannot read as a key of that mapping: %r" % (where, line))
    return keys, blocks


def scopes_of(relative: str, job: str) -> tuple[dict[str, str], dict[str, str], dict[str, str], dict[str, str]]:
    """The workflow mapping and the job mapping above a job's steps, each with its env."""
    lines = workflow_lines(relative)
    workflow_keys, workflow_blocks = mapping_at(lines, 0, 0, "%s workflow scope" % relative, ("env",))
    try:
        start = lines.index("  %s:" % job)
    except ValueError:
        unparsable("%s has no job named %s" % (relative, job))
    job_keys, job_blocks = mapping_at(lines, start + 1, 4, "%s job %r" % (relative, job), ("env",))
    return workflow_keys, workflow_blocks.get("env", {}), job_keys, job_blocks.get("env", {})


def check_scope(where: str, keys: dict[str, str], env: dict[str, str],
                permitted: list[str], load_bearing: list[str],
                declared: dict[str, str] | None) -> None:
    """Every key of a scope above the steps is permitted, declared, or an error naming it.

    `declared` is the environment this scope may set, or None where the scope has no
    declaration shape at all, which is workflow scope today.
    """
    for key in sorted(keys):
        if key in permitted:
            continue
        if key not in load_bearing:
            unparsable("%s carries %s:, which this checker does not recognise at that scope; "
                       "it is neither permitted (%s) nor load-bearing (%s), so it is not skipped"
                       % (where, key, ", ".join(permitted), ", ".join(load_bearing)))
        if key != "env":
            disagree("%s carries %s: %s, which decides whether the steps beneath it run or whether their failure blocks, "
                     "while %s documents them as steps that run"
                     % (where, key, keys[key] or "(a block)", TESTING))
            continue
        if keys[key]:
            unparsable("%s writes env: as an inline mapping (%s), which this checker does not normalise" % (where, keys[key]))
        if declared is None:
            disagree("%s sets env: %s, which reaches every run: line beneath it and can change what a documented command does "
                     "while the command stays byte-identical; this checker declares no environment at that scope"
                     % (where, ", ".join("%s: %s" % (name, env[name]) for name in sorted(env)) or "(an empty block)"))
            continue
        for name in sorted(env):
            if name not in declared:
                disagree("%s sets env %s: %s, which reaches every run: line beneath it and can change what a documented command "
                         "does while the command stays byte-identical; no entry in the checker's declared job environment list covers it"
                         % (where, name, env[name]))
            elif env[name] != declared[name]:
                disagree("declared job environment entry %r of %s declares %r, but the job sets %r"
                         % (name, where, declared[name], env[name]))
    for name in sorted(declared or {}):
        if "env" not in keys:
            disagree("declared job environment entry %r names %s, which sets no env: block" % (name, where))
        elif name not in env:
            disagree("declared job environment entry %r names a variable %s does not set" % (name, where))


def check_exempt_attributes(relative: str, name: str, attributes: dict[str, str]) -> None:
    """An exempt step is unpaired, not unread: it must still run, and still block."""
    for attribute in sorted(attributes):
        if attribute in EXEMPT_PERMITTED or attribute in EXEMPT_DECLARED:
            continue
        if attribute not in EXEMPT_LOAD_BEARING:
            unparsable("%s exempt step %r carries %s:, which this checker does not recognise on an exempt step; "
                       "it is neither permitted (%s), declared (%s) nor load-bearing (%s), so it is not skipped"
                       % (relative, name, attribute, ", ".join(EXEMPT_PERMITTED), ", ".join(EXEMPT_DECLARED),
                          ", ".join(EXEMPT_LOAD_BEARING)))
        disagree("%s exempt step %r carries %s: %s, which decides whether the step runs or whether its failure blocks, "
                 "while the steps %s documents run only because this one has; no exempt step may carry it"
                 % (relative, name, attribute, attributes[attribute] or "(a block)", TESTING))


def carried_content(step: Step) -> dict[str, object]:
    """The EXEMPT_DECLARED keys this step carries, each as the value to compare.

    A key written as a block is carried as the mapping under it, a key written as a scalar
    as that scalar, and run: as the text the file writes for it. run: is fetched from the
    step's own field rather than from its attributes, because steps_of consumes it on its
    own branch; every other declared key is a key beside it.
    """
    carried: dict[str, object] = {}
    for key in EXEMPT_DECLARED:
        if key == "run":
            if step.run is not None:
                carried[key] = written_run(step)
            continue
        if key not in step.attributes:
            continue
        carried[key] = step.blocks.get(key, {}) if step.attributes[key] == "" else step.attributes[key]
    return carried


def check_exempt_content(relative: str, step: Step) -> None:
    """What an exempt step installs, and which tree it leaves behind, is declared (#358).

    The declared exempt content list is what an exempt step carries in place of a
    documented row, so it is compared in both directions: a declared key the step no longer
    carries is a finding, and a declared key the list does not cover is one too.
    """
    declared = DECLARED_EXEMPT_CONTENT.get(relative, {}).get(step.name, {})
    carried = carried_content(step)
    where = "%s exempt step %r" % (relative, step.name)
    for key in sorted(carried):
        if key not in declared:
            disagree("%s carries %s:, which decides what the step installs or which tree the documented commands below "
                     "it run on, and no entry in the checker's declared exempt content list covers it" % (where, key))
    for key in sorted(declared):
        if key not in EXEMPT_DECLARED:
            unparsable("the declared exempt content list declares %s: on %s, which is not one of the keys it declares (%s)"
                       % (key, where, ", ".join(EXEMPT_DECLARED)))
        if key not in carried:
            disagree("declared exempt content entry %r of %s declares %s:, which the step does not carry"
                     % (step.name, relative, key))
            continue
        want, got = declared[key], carried[key]
        if isinstance(want, list):
            if not isinstance(got, dict):
                disagree("declared exempt content entry %r of %s declares the names %s: may set, but the step writes it "
                         "as a scalar this checker cannot read as a mapping of names" % (step.name, relative, key))
                continue
            for name in sorted(got):
                if name not in want:
                    disagree("%s sets %s %s: %s, which no entry in the checker's declared exempt content list names; a "
                             "name it does not declare can change what the step's own commands see without moving any "
                             "value those commands are pinned against" % (where, key, name, got[name]))
            for name in want:
                if name not in got:
                    disagree("declared exempt content entry %r of %s names %s %s:, which the step does not set"
                             % (step.name, relative, key, name))
            continue
        if isinstance(want, dict) != isinstance(got, dict):
            disagree("declared exempt content entry %r of %s declares %s: as %s, but the step writes it as %s"
                     % (step.name, relative, key, "a block" if isinstance(want, dict) else "a scalar",
                        "a block" if isinstance(got, dict) else "a scalar"))
            continue
        if isinstance(want, dict):
            for name in sorted(got):
                if name not in want:
                    disagree("%s sets %s %s: %s, which no entry in the checker's declared exempt content list covers"
                             % (where, key, name, got[name]))
            for name in sorted(want):
                if name not in got:
                    disagree("declared exempt content entry %r of %s declares %s %s:, which the step does not set"
                             % (step.name, relative, key, name))
                elif got[name] != want[name]:
                    disagree("declared exempt content entry %r of %s declares %s %s: %r, but the step sets %r"
                             % (step.name, relative, key, name, want[name], got[name]))
            continue
        want_lines, got_lines = str(want).split("\n"), str(got).split("\n")
        if len(want_lines) == 1 and len(got_lines) == 1:
            # A one-line value is reported whole; only a block is worth naming by line.
            if want_lines != got_lines:
                disagree("declared exempt content entry %r of %s declares %s: %r, but the step writes %r"
                         % (step.name, relative, key, want_lines[0], got_lines[0]))
            continue
        for position in range(max(len(want_lines), len(got_lines))):
            if position >= len(got_lines):
                disagree("declared exempt content entry %r of %s declares line %d of %s: as %r, which the step does not write"
                         % (step.name, relative, position + 1, key, want_lines[position]))
            elif position >= len(want_lines):
                disagree("%s writes line %d of %s:, %r, which no entry in the checker's declared exempt content list covers"
                         % (where, position + 1, key, got_lines[position]))
            elif got_lines[position] != want_lines[position]:
                disagree("declared exempt content entry %r of %s declares line %d of %s: as %r, but the step writes %r"
                         % (step.name, relative, position + 1, key, want_lines[position], got_lines[position]))


exempt_positions_seen: set[tuple[str, str]] = set()


def check_exempt_position(relative: str, name: str, position: int) -> None:
    """An exempt step is read for where it sits as well as for what it carries (#361).

    `position` counts the job's steps from one, exempt steps included. Moving an exempt
    step changes none of its bytes, so nothing the declared exempt content list compares
    moves with it; what moves is which documented steps it runs before.
    """
    declared = DECLARED_EXEMPT_POSITION.get(relative, {})
    if name not in declared:
        disagree("%s exempt step %r runs at position %d of its job, and no entry in the checker's declared exempt "
                 "position list covers it; the documented steps below an exempt step run on what it left behind, so "
                 "where it sits is read as well as what it carries" % (relative, name, position))
        return
    exempt_positions_seen.add((relative, name))
    if declared[name] != position:
        disagree("declared exempt position entry %r of %s declares position %d, but the step runs at position %d; "
                 "moving an exempt step changes none of its bytes and changes which documented steps it runs before"
                 % (name, relative, declared[name], position))


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
    workflow_keys, workflow_env, job_keys, job_env = scopes_of(relative, job)
    check_scope("%s workflow scope" % relative, workflow_keys, workflow_env,
                WORKFLOW_PERMITTED, WORKFLOW_LOAD_BEARING, None)
    check_scope("%s job %r" % (relative, job), job_keys, job_env,
                JOB_PERMITTED, JOB_LOAD_BEARING, DECLARED_JOB_ENV.get(relative, {}).get(job, {}))
    steps = steps_of(relative, job)
    exempt = EXEMPT_STEPS[relative]
    names = [step.name for step in steps]
    for entry in exempt:
        if names.count(entry) != 1:
            disagree("exemption entry %r names %d steps of %s, not exactly one" % (entry, names.count(entry), relative))
    live: list[tuple[str, str]] = []
    for position, step in enumerate(steps, start=1):
        if step.name in exempt:
            check_exempt_attributes(relative, step.name, step.attributes)
            check_exempt_content(relative, step)
            check_exempt_position(relative, step.name, position)
            continue
        command = command_of(relative, step.name, step.run)
        check_attributes(relative, step.name, step.attributes)
        live.append((step.name, command))
    kept_steps[relative] = live
    step_counts[relative] = len(live)
    live_names = [name for name, _ in live]
    for entry, declared in CONDITIONAL_STEPS.get(relative, {}).items():
        if live_names.count(entry) != 1:
            disagree("conditional-step entry %r names %d paired steps of %s, not exactly one" % (entry, live_names.count(entry), relative))
            continue
        carried = dict(steps[names.index(entry)].attributes)
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
            disagree("%s job %s step %r (position %d) has no row in %s and no exemption entry" % (relative, job, name, position + 1, TESTING))
            continue
        if position >= len(live):
            table_name, suite, documented = rows[position]
            disagree("%s row %r in the %s table (position %d) has no step in %s job %s and no exemption entry" % (TESTING, suite, table_name, position + 1, relative, job))
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

# Checked here rather than beside the pairing so that a dropped exemption entry still
# reports the unpaired step it left behind, which is that entry's own case, before this
# list reports the same edit from its side.
for relative, declared_steps in DECLARED_EXEMPT_CONTENT.items():
    if relative not in [path for path, _, _ in PAIRINGS]:
        unparsable("the declared exempt content list names %s, which this checker does not pair" % relative)
    for entry in declared_steps:
        if entry not in EXEMPT_STEPS[relative]:
            unparsable("the declared exempt content list names %s step %r, which is not on the exemption list"
                       % (relative, entry))

for relative, declared_steps in DECLARED_EXEMPT_POSITION.items():
    if relative not in [path for path, _, _ in PAIRINGS]:
        unparsable("the declared exempt position list names %s, which this checker does not pair" % relative)
    for entry in declared_steps:
        if entry not in EXEMPT_STEPS[relative]:
            unparsable("the declared exempt position list names %s step %r, which is not on the exemption list"
                       % (relative, entry))
        if (relative, entry) not in exempt_positions_seen:
            disagree("declared exempt position entry %r names no exempt step of %s" % (entry, relative))

for relative, declared_jobs in DECLARED_JOB_ENV.items():
    paired_jobs = [job for path, job, _ in PAIRINGS if path == relative]
    for job in declared_jobs:
        if job not in paired_jobs:
            unparsable("the declared job environment list names %s job %s, which this checker does not pair" % (relative, job))

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
      "%d exemptions are all in use, %s on %s agree with what those steps carry, "
      "%s are declared and hold, "
      "%s and %s are declared and in use, "
      "%s hold, %s and %s carry no unaccounted-for key and %s are declared and in use, "
      "and %s's CI list of %s matches"
      % (paired_total, DOCS, step_counts[DOCS], GO, step_counts[GO],
         sum(len(v) for v in EXEMPT_STEPS.values()) + sum(len(v) for v in EXEMPT_ROWS.values()),
         plural(sum(len(keys) for entries in DECLARED_EXEMPT_CONTENT.values() for keys in entries.values()),
                "declared key", "declared keys"),
         plural(sum(len(entries) for entries in DECLARED_EXEMPT_CONTENT.values()), "exempt step", "exempt steps"),
         plural(sum(len(entries) for entries in DECLARED_EXEMPT_POSITION.values()),
                "exempt step position", "exempt step positions"),
         plural(sum(len(v) for v in PLACEHOLDER_ROWS.values()), "placeholder row", "placeholder rows"),
         plural(sum(len(v) for v in CONDITIONAL_STEPS.values()), "conditional step", "conditional steps"),
         plural(sum(len(v) for v in TABLE_FIRST_STEP.values()), "table boundary", "table boundaries"),
         plural(len(PAIRINGS), "job scope", "job scopes"),
         plural(len(PAIRINGS), "workflow scope", "workflow scopes"),
         plural(sum(len(variables) for jobs in DECLARED_JOB_ENV.values() for variables in jobs.values()),
                "job environment variable", "job environment variables"),
         MANIFEST, count_word))
PY
