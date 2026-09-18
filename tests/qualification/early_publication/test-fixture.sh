#!/usr/bin/env bash
# Evaluator-level proof for fixture.go: jq crafts one valid three-run trace from publication.json
# (serial lane, grant renewals as ticketed publications), then each case edits it for one rule and
# asserts the exit code AND one whole output line. No runner, probe, network or object store is used.
# EARLY may name a scratch copy of scripts/qualification/early (mutant pass).
# shellcheck disable=SC2016  # jq filters expand inside jq
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EARLY="${EARLY:-$HERE/../../../scripts/qualification/early}"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-fixture-tests.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
go build -o "$work/fixture" "$EARLY/fixture.go"
good="$work/good.jsonl"
jq -nc --slurpfile p "$EARLY/publication.json" --arg ps "$(sha256sum <"$EARLY/publication.json" | cut -d' ' -f1)" \
  --arg es "$(sha256sum <"$EARLY/fixture.go" | cut -d' ' -f1)" -f /dev/stdin >"$good" <<'JQ'
def hx($s): ("0" * (64 - ($s | length))) + $s;
def lane($t): {ticket: $t, commitStart: ($t + 100), commitEnd: ($t + 200), syncStart: ($t + 200), syncEnd: ($t + 500),
  restoreStart: ($t + 500), restoreEnd: ($t + 800), casStart: ($t + 800), casEnd: ($t + 1000), ack: ($t + 1100), outcome: "published"};
$p[0] as $p | [range(0; $p.warmupMs + $p.durationMs; $p.cadenceMs) as $a
  | $a, (if $a == $p.warmupMs + $p.burst.atMs then range($p.burst.count) | $a else empty end)] as $arr
| {ev: "trace", schema: "prifly/qualification/early-publication-trace/v1", procedureSha256: $ps,
   runnerSha256: ("1" * 64), evaluatorSha256: $es, probeSha256: ("2" * 64), manifestSha256: ("3" * 64), priorBytes: 0, priorRequests: 0},
  (range(1; $p.runs + 1) as $r
  | {ev: "run", run: $r, t0: 1000000, grant: 0, prefix: "q13/run\($r)/", lineage: "lineage-\($r)", generator: "gen-v1",
     seed: $p.seed, litestream: $p.litestream, dbBytes: 52428800, bytes: 52494336, writes: 2, requests: 9},
    {ev: "plan", run: $r, t: 1000000, grant: 0, bytes: 0, writes: 0, requests: 1},
    {ev: "grant", run: $r, t: 1000000, deadline: 1600000},
    foreach range($arr | length) as $i ({free: 0, deadline: 1600000, k: 0};
      ([1000000 + $arr[$i], .free] | max) as $t | (.out = []) | .t = $t
      | if $t + 5000 > .deadline then .k += 1 | (lane($t) + {ev: "grant", run: $r, bytes: 65536, writes: 3, requests: 25,
          reason: "", reservedBytes: 66560, reservedWrites: 4, reservedRequests: 28, restoredSeq: ($i + .k), casSeq: ($i + .k),
          txid: "r\(.k)", lineage: "lineage-\($r)", restoreTxid: "r\(.k)", integrity: "ok", casTxid: "r\(.k)"}) as $g
          | .out = [{ev: "plan", run: $r, t: $t, grant: (.k - 1), bytes: 0, writes: 0, requests: 1}, $g + {t: $g.ack, deadline: ($g.ack + $p.grant.ms)}] | .t = $g.ack | .deadline = $g.ack + $p.grant.ms
        else . end
      | ($i + 1) as $n | $p.mix[$i % ($p.mix | length)] as $m | lane(.t) as $c | .free = $c.ack
      | .out += [{ev: "plan", run: $r, t: .t, grant: .k, bytes: 0, writes: 0, requests: 1}, $c + {ev: "cmd", run: $r, n: $n, kind: $m.kind, arrival: $arr[$i], submit: (1000000 + $arr[$i]),
          reason: "", bytes: ($m.payloadBytes + 66048), writes: 4, requests: 27,
          reservedBytes: ($m.payloadBytes + 67072), reservedWrites: 5, reservedRequests: 30, payloadSha256: hx("\($n)"),
          payloadBytes: $m.payloadBytes, before: "s\($n - 1)", after: "s\($n)", dbBytes: (52428800 + $n * 4096),
          txid: "t\($n)", lineage: "lineage-\($r)", restoreTxid: "t\($n)", restoredSeq: ($n + .k), restoredPayloadSha256: hx("\($n)"),
          integrity: "ok", casSeq: ($n + .k), casTxid: "t\($n)"}]; .out[]))
JQ
fails=0
verdict() {  # name, want exit, want whole output line, procedure, trace
  local out="$work/${1// /-}.out"
  set +e; "$work/fixture" "$4" "$5" >"$out" 2>&1; rc=$?; set -e
  if [[ "$rc" == "$2" ]] && grep -qxF -- "$3" "$out"; then echo "ok   $1"; else
    echo "FAIL $1: exit $rc (want $2), want line: $3"; grep -E "^(REJECT|RUN|VERDICT|fixture)" "$out" | head -n 8 | sed 's/^/     | /' || true; fails=$((fails + 1)); fi
}
edit() { jq -c "$4 | .[]" -s "$good" >"$work/${1// /-}.jsonl"; verdict "$1" "$2" "$3" "$EARLY/publication.json" "$work/${1// /-}.jsonl"; }
at() { echo "map(if .ev == \"cmd\" and .run == $1 and .n == $2 then $3 else . end)"; }
runfield() { echo "map(if .ev == \"run\" and .run == $1 then $2 else . end)"; }
renewal='(map(select(.ev == "grant" and .run == 1))[1]) as $g | map(if . == $g then '
shift='with_entries(if (.key | test("Start$|End$|^ticket$|^ack$")) then .value += $d else . end)'
cmd() { echo "(map(select(.ev == \"cmd\" and .run == $1 and .n == $2))[0])"; }
unticketed='.ticket = 0 | .commitStart = 0 | .commitEnd = 0 | .syncStart = 0 | .syncEnd = 0 | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | .outcome = "failed" | .reason = "no-ticket" | .bytes = 0 | .writes = 0 | .requests = 0 | .reservedBytes = 0 | .reservedWrites = 0 | .reservedRequests = 0'
charged='.reservedBytes = .bytes | .reservedWrites = .writes | .reservedRequests = .requests'  # a failure keeps its whole charge
failed='.outcome = "failed" | .reason = "cas-conflict" | '"$charged"
PASS="VERDICT: every run meets the fixed publication thresholds; feasibility evidence only, not a Q13 PASS"
MISS="VERDICT: a run misses a fixed publication threshold; feasibility evidence only"
edit "valid trace" 0 "$PASS" '.'
edit "burst drains through the serial lane" 0 "RUN 1 measured 130 failures 0 p95 6600 max 13200 burst 13200 meets true" '.'
"$work/fixture" "$EARLY/publication.json" "$good" >"$work/again.out" 2>&1 || true
if cmp -s "$work/valid-trace.out" "$work/again.out"; then echo "ok   deterministic output"; else echo "FAIL deterministic output"; fails=$((fails + 1)); fi
# Frontier and lane order (C3 step 2: no N+1 before N resolves)
edit "old frontier" 1 "REJECT OLD-FRONTIER run 1 n 7: restore or frontier at sequence 6" "$(at 1 7 '.restoredSeq = 6')"
edit "later frontier" 1 "REJECT LATER-FRONTIER run 2 n 8: restore or frontier at sequence 9" "$(at 2 8 '.casSeq = 9')"
edit "command runs after its successor" 1 "REJECT OLD-FRONTIER run 1 n 30: command entered the lane after command 31; the frontier moved backwards" \
  "($(cmd 1 31).ack - $(cmd 1 30).ticket) as \$d | $(at 1 30 "$shift")"
edit "burst commands swapped" 1 "REJECT OLD-FRONTIER run 1 n 84: command entered the lane after command 85; the frontier moved backwards" \
  "($(cmd 1 85).ticket - $(cmd 1 84).ticket) as \$d | $(at 1 84 "$shift") | (-\$d) as \$d | $(at 1 85 "$shift")"
edit "burst lane overlap" 1 "REJECT LANE run 1 n 84: step clock out of lane order; commands run one at a time" "$(at 1 84 '(.submit - .ticket) as $d | '"$shift")"
edit "ticket before the previous ack" 1 "REJECT LANE run 1 n 31: step clock out of lane order; commands run one at a time" "$(at 1 30 '.ack += 20000')"
edit "step clock 1 ms early" 1 "REJECT LANE run 1 n 30: step clock out of lane order; commands run one at a time" "$(at 1 30 '.commitStart = .ticket - 1')"
edit "published step not reached" 1 "REJECT LANE run 1 n 30: step clock out of lane order; commands run one at a time" "$(at 1 30 '.casEnd = 0')"
edit "failed entry clock after a step not reached" 1 "REJECT LANE run 2 n 150: step clock out of lane order; commands run one at a time" \
  "$(at 2 150 '.outcome = "failed" | .reason = "restore-exit1" | .restoreEnd = 0 | '"$charged")"
edit "ticket inside a failed predecessor step" 1 "REJECT LANE run 1 n 6: step clock out of lane order; commands run one at a time" \
  "$(at 1 5 '.outcome = "failed" | .reason = "sync-exit1" | .syncStart = 1080000 | .syncEnd = 0 | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | '"$charged")"
edit "commands swapped across a renewal" 1 "REJECT OLD-FRONTIER run 1 n 40: command entered the lane after command 41; the frontier moved backwards" \
  "($(cmd 1 41).ticket - $(cmd 1 40).ticket) as \$d | $(at 1 40 "$shift") | (-\$d) as \$d | $(at 1 41 "$shift")"
edit "renewal CAS not numbered as a published command" 1 "REJECT OLD-FRONTIER run 1 n 0: restore or frontier at sequence 40" "$renewal"'.casSeq = 40 else . end)'
edit "renewal restore past its sequence" 1 "REJECT LATER-FRONTIER run 1 n 0: restore or frontier at sequence 42" "$renewal"'.restoredSeq = 42 else . end)'
edit "renewal T differs" 1 "REJECT WRONG-T run 1 n 0: grant 1: renewal restore or frontier T/lineage is not the synced T" "$renewal"'.casTxid = "r0" else . end)'
edit "renewal restores another T" 1 "REJECT WRONG-T run 1 n 0: grant 1: renewal restore or frontier T/lineage is not the synced T" "$renewal"'.restoreTxid = "r0" else . end)'
edit "renewal lineage differs" 1 "REJECT WRONG-T run 1 n 0: grant 1: renewal restore or frontier T/lineage is not the synced T" "$renewal"'.lineage = "lineage-2" else . end)'
edit "renewal integrity failed" 1 "REJECT WRONG-RESULT run 1 n 0: grant 1: renewal restore integrity is not ok" "$renewal"'.integrity = "corrupt" else . end)'
edit "command numbered as if no renewal came before it" 1 "REJECT OLD-FRONTIER run 1 n 41: restore or frontier at sequence 41" "$(at 1 41 '.casSeq = 41')"
edit "failed command keeps its sequence number" 0 "$PASS" "$(at 1 10 "$failed") | $(at 1 11 '.before = "s9"')"  # #252 ruling 5714969372 item 3: n is never reused
edit "command after a failed command reuses its sequence number" 1 "REJECT OLD-FRONTIER run 1 n 11: restore or frontier at sequence 10" \
  "$(at 1 10 "$failed") | $(at 1 11 '.before = "s9" | .restoredSeq -= 1 | .casSeq -= 1')"
edit "renewal after a failed command takes the next sequence number" 3 "$MISS" "$(at 1 40 "$failed") | $(at 1 41 '.before = "s39"')"
edit "ack before CAS result" 1 "REJECT EARLY-ACK run 1 n 30: acknowledged before the frontier CAS result" "$(at 1 30 '.ack = .casEnd - 1')"
edit "zero latency everywhere" 1 "REJECT EARLY-ACK run 1 n 1: acknowledged before the frontier CAS result" 'map(if .ev == "cmd" then .ack = .submit else . end)'
edit "CAS pacing under 1.1 s" 1 "REJECT PACING run 1 n 83: CAS write under 1100ms after the previous one" \
  "$(at 1 83 '.ticket as $t | .commitStart = $t | .commitEnd = $t | .syncStart = $t | .syncEnd = $t | .restoreStart = $t | .restoreEnd = $t | .casStart = $t')"
edit "CAS pacing 1099 ms" 1 "REJECT PACING run 1 n 83: CAS write under 1100ms after the previous one" "$(at 1 83 '.restoreEnd -= 1 | .casStart -= 1')"
edit "renewal CAS paced after a command" 1 "REJECT PACING run 1 n 0: CAS write under 1100ms after the previous one" \
  "(map(select(.ev == \"grant\" and .run == 1))[1].casStart) as \$c | $(at 1 40 '.casStart = $c - 1099 | .casEnd = $c - 1000 | .ack = $c - 900')"
edit "published step over the step timeout" 1 "REJECT STEP-TIMEOUT run 3 n 150: a published step lasted over 120s" "$(at 3 150 '.syncEnd += 119701 | .restoreStart += 119701 | .restoreEnd += 119701 | .casStart += 119701 | .casEnd += 119701 | .ack += 119701')"
edit "published step of exactly the step timeout" 3 "$MISS" "$(at 3 150 '.syncEnd += 119700 | .restoreStart += 119700 | .restoreEnd += 119700 | .casStart += 119700 | .casEnd += 119700 | .ack += 119700')"
edit "timeout retained as failure" 3 "FAILURE run 2 n 150 kind attempt-result arrival 2085000 reason sync-exit124" \
  "$(at 2 150 '.outcome = "failed" | .reason = "sync-exit124" | .syncEnd += 125000 | .after = "" | .txid = "" | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | '"$charged")"
# Permits, renewals and the P12a/P12b ledger
edit "expired permit without renewal" 1 "REJECT EXPIRED-PERMIT run 1 n 41: remote use or publication without a ticket inside a live grant of at most 600000ms" 'map(select(.ev != "grant" or .run != 1 or .ticket == null))'
edit "over-long grant" 1 "REJECT EXPIRED-PERMIT run 1 n 0: grant 0 ends before it starts or lasts over 600000ms" 'map(if .ev == "grant" and .ticket == null then .deadline += 1 else . end)'
edit "grant ends before it starts" 1 "REJECT EXPIRED-PERMIT run 1 n 0: grant 0 ends before it starts or lasts over 600000ms" 'map(if .ev == "grant" and .ticket == null and .run == 1 then .deadline = .t - 1 else . end)'
edit "ticket at clock zero" 1 "REJECT EXPIRED-PERMIT run 1 n 1: remote use or publication without a ticket inside a live grant of at most 600000ms" \
  'map(if .run == 1 then with_entries(if (.key | test("^(t0|t|deadline|submit|ticket|ack)$|Start$|End$")) then .value -= 1000000 else . end) else . end)'
edit "unticketed publication" 1 "REJECT EXPIRED-PERMIT run 1 n 43: remote use or publication without a ticket inside a live grant of at most 600000ms" "$(at 1 43 "$unticketed"' | .outcome = "published" | .reason = ""')"
edit "unticketed clock" 1 "REJECT EXPIRED-PERMIT run 1 n 44: remote use or publication without a ticket inside a live grant of at most 600000ms" "$(at 1 44 "$unticketed"' | .casStart = 1650000')"
for f in bytes writes requests reservedBytes reservedWrites reservedRequests; do
  edit "unticketed $f" 1 "REJECT EXPIRED-PERMIT run 1 n 44: remote use or publication without a ticket inside a live grant of at most 600000ms" "$(at 1 44 "$unticketed | .$f = 1")"
  [[ $f == reserved* ]] && continue
  edit "publication without $f" 1 "REJECT LEDGER run 1 n 45: publication records no remote use" "$(at 1 45 ".$f = 0")"
  edit "fixture step without $f" 1 "REJECT LEDGER run 2 n 0: fixture step records no remote use" "$(runfield 2 ".$f = 0")"
done
edit "renewal without use" 1 "REJECT LEDGER run 1 n 0: publication records no remote use" "$renewal"'.writes = 0 else . end)'
# A ticket is charged in full before the first step and a failure keeps that charge (P12b L75), so a failed
# entry that took a ticket records that reservation exactly, whether or not its clocks show it reached the
# remote. Command 5 is a warm-up command, so its failure alone leaves the run meeting the thresholds: with
# the reservation rule removed each case below is the trace of #333, which passes at ≥1 unit apiece. chain5
# re-chains command 6 over it, the one check a failure does drop, so the recorded use is the only rule these
# cases rest on.
FAILUSE="failed ticketed entry does not record its reservation, which is charged in full"
chain5="$(at 1 6 '.before = "s4"')"
reached='.outcome = "failed" | .reason = "sync-exit1" | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | '"$charged"
ticketed='.outcome = "failed" | .reason = "artifact-exit1" | .commitStart = 0 | .commitEnd = 0 | .syncStart = 0 | .syncEnd = 0 | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | '"$charged"
zero='.bytes = 0 | .writes = 0 | .requests = 0'
one='.bytes = 1 | .writes = 1 | .requests = 1'
edit "failed entry charged its reservation" 0 "$PASS" "$(at 1 5 "$reached") | $chain5"
for f in bytes writes requests; do
  edit "failed entry reached the remote without $f" 1 "REJECT LEDGER run 1 n 5: $FAILUSE" "$(at 1 5 "$reached | .$f = 0") | $chain5"
  edit "failed entry short of its reservation ($f)" 1 "REJECT LEDGER run 1 n 5: $FAILUSE" "$(at 1 5 "$reached | .$f -= 1") | $chain5"
done
edit "failed entry reached the remote without use" 1 "REJECT LEDGER run 1 n 5: $FAILUSE" "$(at 1 5 "$reached | $zero") | $chain5"
edit "failed entry held to one byte, write and request" 1 "REJECT LEDGER run 1 n 5: $FAILUSE" "$(at 1 5 "$reached | $one") | $chain5"
edit "failed entry only reserved its ticket" 1 "REJECT LEDGER run 1 n 5: $FAILUSE" "$(at 1 5 "$ticketed | $zero") | $chain5"
edit "failed entry only reserved its ticket, held to one unit" 1 "REJECT LEDGER run 1 n 5: $FAILUSE" "$(at 1 5 "$ticketed | $one") | $chain5"
edit "failed renewal without use" 1 "REJECT LEDGER run 1 n 0: $FAILUSE" \
  "$renewal"'.outcome = "failed" | .reason = "cas-conflict" | .t = 0 | .deadline = 0 | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | '"$zero"' else . end)'
edit "failed renewal held to one byte, write and request" 1 "REJECT LEDGER run 1 n 0: $FAILUSE" \
  "$renewal"'.outcome = "failed" | .reason = "cas-conflict" | .t = 0 | .deadline = 0 | .restoreStart = 0 | .restoreEnd = 0 | .casStart = 0 | .casEnd = 0 | .ack = 0 | '"$one"' else . end)'
# An entry that never took a ticket records none, so the rule above must not reach it: command 6 fails
# before its ticket, its plan call goes with it, and command 7 chains over it.
edit "unticketed failure records no use" 0 "$PASS" \
  "$(cmd 1 6).ticket as \$t | map(select(.ev != \"plan\" or .run != 1 or .t != \$t)) | $(at 1 6 "$unticketed") | $(at 1 7 '.before = "s5"')"
edit "first grant is a renewal" 1 "REJECT RENEWAL run 2 n 0: grant 0: only a grant after the first is a renewal" \
  '(map(select(.ev == "grant" and .run == 2))[0]) as $g0 | (map(select(.ev == "grant" and .run == 2))[1]) as $g1 | map(select(. != $g0) | if . == $g1 then .t = 1000000 | .deadline = 1600000 else . end)'
edit "renewal not a ticketed publication" 1 "REJECT RENEWAL run 1 n 0: grant 1: only a grant after the first is a renewal" "$renewal"'{ev, run, t, deadline} else . end)'
edit "renewal reserved after expiry" 1 "REJECT RENEWAL run 1 n 0: grant 1 is not a ticketed publication reserved inside the grant it renews" "$renewal"'.ticket = 1600001 else . end)'
edit "renewal reserved before the grant it renews" 1 "REJECT RENEWAL run 1 n 0: grant 1 is not a ticketed publication reserved inside the grant it renews" "$renewal"'.ticket = 999999 else . end)'
# A renewal may fail (#309). It opens no grant, blocks the lane and makes its run miss, but the trace is an
# honest failed run rather than a forgery. failren appends one to run 3 after its last command, where nothing
# follows it; blockren inserts one before run 3's last command, which then must not be published.
failren() {  # jq filter further applied to the appended renewal
  echo '(map(select(.ev == "grant" and .run == 3)) | last) as $g | (map(select(.ev == "cmd" and .run == 3)) | max_by(.ticket)) as $c
    | . + [{ev: "plan", run: 3, t: ($c.ack + 50), grant: 3, bytes: 0, writes: 0, requests: 1},
      ($g + {ticket: ($c.ack + 100), commitStart: ($c.ack + 200), commitEnd: ($c.ack + 300), syncStart: ($c.ack + 300), syncEnd: ($c.ack + 400),
        restoreStart: 0, restoreEnd: 0, casStart: 0, casEnd: 0, ack: 0, t: 0, deadline: 0, outcome: "failed", reason: "cas-conflict"}
       | '"$charged"' | '"${1:-.}"')]'
}
blockren="$(cmd 3 149).ack as \$a | (map(select(.ev == \"grant\" and .run == 3)) | last) as \$g
  | map(if .run == 3 and (.ev == \"cmd\" or .ticket) and .ticket > \$a then .restoredSeq += 1 | .casSeq += 1 else . end)
  | map(if .ev == \"cmd\" and .run == 3 and .n == 149 then ., {ev: \"plan\", run: 3, t: (\$a + 50), grant: 3, bytes: 0, writes: 0, requests: 1},
      (\$g + {ticket: (\$a + 100), commitStart: (\$a + 200), commitEnd: (\$a + 300), syncStart: (\$a + 300), syncEnd: (\$a + 400),
        restoreStart: 0, restoreEnd: 0, casStart: 0, casEnd: 0, ack: 0, t: 0, deadline: 0, outcome: \"failed\", reason: \"cas-conflict\"} | $charged)
    else . end)"
edit "failed renewal is a failed run, not a rejected trace" 3 "$MISS" "$(failren)"
edit "failed renewal is retained as the failure it is" 3 "FAILURE run 3 grant 4 kind renewal reason cas-conflict" "$(failren)"
edit "failed renewal alone misses its run" 3 "RUN 3 measured 130 failures 0 p95 6600 max 13200 burst 13200 meets false" "$(failren)"
edit "failed renewal opening a grant" 1 "REJECT RENEWAL run 3 n 0: grant 4: a failed renewal opens no grant" "$(failren '.t = .syncEnd | .deadline = .syncEnd + 600000')"
edit "failed renewal reserved after the grant it renews" 1 "REJECT RENEWAL run 3 n 0: grant 4 is not a ticketed publication reserved inside the grant it renews" \
  "$(failren '.ticket = $g.deadline + 1')"
edit "publication after a failed renewal" 1 "REJECT RENEWAL run 3 n 150: entry published after a failed renewal blocked the lane" "$blockren"
edit "grant active before its renewal ack" 1 "REJECT RENEWAL run 1 n 0: grant 1 is not a ticketed publication reserved inside the grant it renews" "$renewal"'.t = .ack - 1 | .deadline -= 1 else . end)'
GRANT0="REJECT LEDGER run 1 n 0: grant 0 ticket and plan use exceeds the P12b control/recovery grant maxima"
grant() {  # field, maximum, excess, plan share[, fixture use]: run 1's fixture step, commands 1-40, renewal and grant-0 plan calls (the renewal's holding the share) sum to maximum + excess
  echo "(${5:-null} // (map(select(.ev == \"run\" and .run == 1))[0].$1)) as \$f | (($2 - $4 - \$f - 1) / 40 | floor) as \$c | $renewal.$1 = $2 - $4 - \$f - 40 * \$c + $3 elif .ev == \"plan\" and .run == 1 and .grant == 0 then .$1 = (if .t == \$g.ticket then $4 else 0 end) elif .ev == \"cmd\" and .run == 1 and .n <= 40 then .$1 = \$c elif .ev == \"run\" and .run == 1 then .$1 = \$f else . end)"; }
for f in bytes:805306368 writes:3072 requests:24576; do  # P12b control/recovery grant: tickets are charged to it
  edit "grant ${f%:*} at the maximum" 0 "$PASS" "$(grant "${f%:*}" "${f#*:}" 0 0)"
  edit "grant maxima exceeded (${f%:*})" 1 "$GRANT0" "$(grant "${f%:*}" "${f#*:}" 1 0)"
done
for f in bytes:805306368:65536 requests:24576:100; do  # plan calls share the live control grant with tickets (#252 ruling 5714969372 items 1, 2)
  IFS=: read -r k max share <<<"$f"
  edit "plan and ticket $k at the control maximum" 0 "$PASS" "$(grant "$k" "$max" 0 "$share")"
  edit "plan use counts in control maxima ($k)" 1 "$GRANT0" "$(grant "$k" "$max" 1 "$share")"
done
edit "failed entry use counts in grant maxima" 1 "$GRANT0" "$(grant writes 3072 1 0) | $(at 1 40 "$failed")"
# The fixture upload is one ticket charged to the control grant live at t0, named on the run line (#252 ruling 5716255116 item 1)
FIXTICKET="REJECT LEDGER run 1 n 0: fixture step exceeds the pre-send ticket" FIXGRANT="REJECT EXPIRED-PERMIT run 1 n 0: fixture step outside the grant it names, live at t0"
for f in bytes:268435456:805306368 writes:1024:3072 requests:8192:24576; do
  IFS=: read -r k tmax cmax <<<"$f"
  edit "fixture $k at the ticket maximum" 0 "$PASS" "$(runfield 1 ".$k = $tmax")"
  edit "fixture $k over the ticket" 1 "$FIXTICKET" "$(runfield 1 ".$k = $tmax + 1")"
  edit "fixture and ticket $k at the control maximum" 0 "$PASS" "$(grant "$k" "$cmax" 0 0 "$tmax")"
  edit "fixture use counts in control maxima ($k)" 1 "$GRANT0" "$(grant "$k" "$cmax" 1 0 "$tmax")"
done
edit "fixture step with 2^53-1 writes" 1 "$FIXTICKET" "$(runfield 1 '.writes = 9007199254740991')"  # the round-2 reviewer's three probes
edit "fixture step with 1 GiB" 1 "$FIXTICKET" "$(runfield 1 '.bytes = 1073741824')"
edit "fixture step with 30000 requests" 1 "$FIXTICKET" "$(runfield 1 '.requests = 30000')"
edit "fixture step naming a later grant" 1 "$FIXGRANT" "$(runfield 1 '.grant = 1')"
edit "fixture step before its grant" 1 "$FIXGRANT" 'map(if .ev == "grant" and .run == 1 and .ticket == null then .t += 1 else . end)'
edit "fixture step after its grant ends" 1 "$FIXGRANT" 'map(if .ev == "grant" and .run == 1 and .ticket == null then .t -= 600001 | .deadline = .t + 600000 else . end)'
# grant 0 ends exactly at t0 (inclusive): a renewal ticketed at t0, beside the fixture step, opens grant 1 for command 1 onwards,
# so every run-1 sequence number moves up one and every later plan names the next grant
edit "fixture step at its grant's deadline" 0 "$PASS" "$renewal"'. else . end) | (1000000 - $g.ticket) as $d | ($g | '"$shift"' | .t = .ack | .deadline = .ack + 600000 | .txid = "r-t0" | .restoreTxid = .txid | .casTxid = .txid | .restoredSeq = 1 | .casSeq = 1) as $r0 | map(if .run != 1 then . elif .ev == "grant" and .ticket == null then (.t -= 600000 | .deadline -= 600000), $r0 elif .ev == "grant" or .ev == "cmd" then .restoredSeq += 1 | .casSeq += 1 | (if .n == 1 then (1100 as $d | '"$shift"') else . end) elif .ev == "plan" and .t > 1000000 then .grant += 1 else . end) + [{ev: "plan", run: 1, t: 1001100, grant: 1, bytes: 0, writes: 0, requests: 1}]'
# Plan calls (#252 ruling 5714969372 items 1 and 4): no writes, charged to the live grant they name, one before each ticketed entry
PLAN1='(map(.ev == "plan" and .run == 1) | index(true)) as $i | .[$i]' PLANGRANT="REJECT EXPIRED-PERMIT run 1 n 0: plan call outside the live grant it names"
edit "plan call with one write" 1 "REJECT LEDGER run 1 n 0: plan call records writes" "$PLAN1.writes = 1"
edit "plan call with 2^53-1 writes" 1 "REJECT LEDGER run 1 n 0: plan call records writes" "$PLAN1.writes = 9007199254740991"
edit "plan call before its grant" 1 "$PLANGRANT" "$PLAN1.t = 999999"
edit "plan call after its grant ends" 1 "$PLANGRANT" \
  '(map(select(.ev == "grant" and .run == 1)) | last) as $g | (map(.ev == "plan" and .run == 1) | rindex(true)) as $i | .[$i].t = $g.deadline + 1'
edit "plan call naming a later grant" 1 "$PLANGRANT" "$PLAN1.grant = 1"
edit "plan call naming an ended grant" 1 "$PLANGRANT" '(map(.ev == "plan" and .run == 1 and .grant == 1) | index(true)) as $i | .[$i].grant = 0'
# One plan call of its own per ticketed entry, inside its window: previous entry's ack (or t0) up to its ticket (ruling 5716255116 item 2)
NOPLAN="no plan call of its own from the previous entry's ack (or t0) up to its ticket" SPARE="plan call serves no entry: before this entry's window, or a second plan for the entry before"
plan30() { echo "$(cmd 1 29).ack as \$a | $(cmd 1 30).ticket as \$t | map(if .ev == \"plan\" and .run == 1 and .t == \$t then $1 else . end)"; }  # command 30's plan; window [ack 29, ticket 30]
edit "plan call at its window's start" 0 "$PASS" "$(plan30 '.t = $a')"
edit "plan call at its window's end" 0 "$PASS" "$(plan30 '.t = $t')"
edit "plan call before its window" 1 "REJECT PLAN run 1 n 30: $SPARE" "$(plan30 '.t = $a - 1')"
edit "command without a plan call" 1 "REJECT PLAN run 1 n 30: $NOPLAN" "$(cmd 1 30).ticket as \$t | map(select(.ev != \"plan\" or .run != 1 or .t != \$t))"
edit "plan call after its ticket" 1 "REJECT PLAN run 1 n 30: $NOPLAN" "$(plan30 '.t = $t + 1')"
edit "two plan calls for one entry" 1 "REJECT PLAN run 1 n 31: $SPARE" "$(plan30 '., .')"
edit "one plan call shared by two entries" 1 "REJECT PLAN run 1 n 30: $NOPLAN" \
  "$(at 1 29 '.ticket as $t | .commitStart = $t | .commitEnd = $t | .syncStart = $t | .syncEnd = $t | .restoreStart = $t | .restoreEnd = $t | .casStart = $t | .casEnd = $t | .ack = $t') | $(plan30 'empty')"
edit "run's plan calls all at t0" 1 "REJECT PLAN run 1 n 2: $SPARE" 'map(if .ev == "plan" and .run == 1 and .grant == 0 then .t = 1000000 else . end)'
edit "plan call after the run's last entry" 1 "REJECT PLAN run 3 n 0: plan call serves no entry: after the run's last ticketed entry, or a second plan for it" \
  '. + [(map(select(.ev == "plan" and .run == 3)) | last) | .t += 1]'
edit "plan lines out of file order" 0 "$PASS" '(map(select(.ev == "plan" and .run == 1)) | reverse) as $p | map(select(.ev != "plan" or .run != 1)) + $p'
edit "renewal without a plan call" 1 "REJECT PLAN run 1 n 0: $NOPLAN" '(map(select(.ev == "grant" and .run == 1))[1]) as $g | map(select(.ev != "plan" or .run != 1 or .t != $g.ticket))'
# the fixture step's window is t0 alone; grant 0 also opens at t0, so the moved plan is outside its grant too
edit "fixture step's plan call before t0" 1 "REJECT PLAN run 1 n 0: $SPARE" '(map(.ev == "plan" and .run == 1) | index(true)) as $i | .[$i].t -= 1'
# the fixture step's window ends at t0 too: with command 1 ticketed 5 s later (its plan at its ticket), a fixture plan at t0+1 serves no fixture step
edit "fixture step's plan call after t0" 1 "REJECT PLAN run 1 n 0: $NOPLAN" \
  "(map(.ev == \"plan\" and .run == 1) | indices(true)) as \$p | .[\$p[0]].t += 1 | .[\$p[1]].t += 5000 | 5000 as \$d | $(at 1 1 "$shift")"
# the fixture plan and command 1's share clock t0, so the one left serves the fixture step and command 1 has none
edit "fixture step without a plan call" 1 "REJECT PLAN run 2 n 1: $NOPLAN" '(map(.ev == "plan" and .run == 2) | index(true)) as $i | del(.[$i])'
for f in bytes:268435457 writes:1025 requests:8193; do
  k="${f%:*}"
  edit "ticket exceeded ($k)" 1 "REJECT LEDGER run 1 n 3: remote use exceeds the pre-send ticket" "$(at 1 3 ".$k = ${f#*:}")"
  edit "reservation at the ticket maximum ($k)" 0 "$PASS" "$(at 1 3 ".reserved${k^} = $((${f#*:} - 1))")"
  edit "reservation over the ticket ($k)" 1 "REJECT LEDGER run 1 n 3: reservation exceeds the pre-send ticket" "$(at 1 3 ".reserved${k^} = ${f#*:}")"
done
edit "renewal use counts in grant maxima" 1 "$GRANT0" "$renewal"'.writes = 33 else . end) | map(if .ev == "cmd" and .run == 1 and .n <= 40 then .writes = 76 else . end)'
edit "renewal ticket exceeded" 1 "REJECT LEDGER run 1 n 0: remote use exceeds the pre-send ticket" "$renewal"'.bytes = 268435457 else . end)'
edit "renewal reservation over the ticket" 1 "REJECT LEDGER run 1 n 0: reservation exceeds the pre-send ticket" "$renewal"'.reservedBytes = 268435457 else . end)'
P12A="REJECT LEDGER run 0 n 0: trace exceeds the P12a envelope (prior use, plan calls, fixture steps, commands and renewals)"
envelope() { echo "(map(.$1 // 0) | add) as \$s | map(if .ev == \"trace\" then .prior${1^} = $2 - \$s else . end) | $(at 2 1 ".$1 += $3")"; }  # field, limit, excess: prior use fills the rest
for f in bytes:8589934592 requests:100000; do
  edit "envelope ${f%:*} at the limit" 0 "$PASS" "$(envelope "${f%:*}" "${f#*:}" 0)"
  edit "envelope ${f%:*} exceeded" 1 "$P12A" "$(envelope "${f%:*}" "${f#*:}" 1)"
done
for f in Bytes:8589934592 Requests:100000; do  # the header's prior usage: with the trace's own use, at the limit, then one over
  k="${f%:*}" && prior="(map(.${k,} // 0) | add) as \$s | map(if .ev == \"trace\" then .prior$k = ${f#*:} - \$s"
  edit "prior ${k,} at the limit" 0 "$PASS" "$prior else . end)"
  edit "prior ${k,} counts in P12a" 1 "$P12A" "$prior + 1 else . end)"
done
for f in Bytes:8589934592 Requests:100000; do  # one plan call's use beside prior use filling the rest of P12a: at the limit, then one over
  k="${f%:*}" && plan="(map(.ev == \"plan\" and .run == 2) | index(true)) as \$i | .[\$i].${k,} = 4096 | (map(.${k,} // 0) | add) as \$s | map(if .ev == \"trace\" then .prior$k = ${f#*:} - \$s else . end)"
  edit "plan ${k,} at the limit" 0 "$PASS" "$plan"
  edit "plan ${k,} counts in P12a" 1 "$P12A" "$plan | .[\$i].${k,} += 1"
done
edit "failed command use counts in P12a" 1 "$P12A" "$(envelope bytes 8589934592 1) | $(at 1 40 "$failed")"
edit "renewal use counts in P12a" 1 "$P12A" 'map(if .ev == "cmd" then .bytes = 16777216 elif .ev == "grant" and .ticket then .bytes = 209715200 else . end)'
for f in bytes:8589934592 requests:100000; do  # one over P12a on the fixture step, prior use filling the rest (a fixture step is held to one ticket)
  k="${f%:*}" && edit "fixture $k count in P12a" 1 "$P12A" "(map(.$k // 0) | add) as \$s | map(if .ev == \"trace\" then .prior${k^} = ${f#*:} - \$s else . end) | $(runfield 1 ".$k += 1")"
done
edit "prior use and plan calls saturate" 1 "$P12A" 'map(if .ev == "trace" then .priorBytes = 9007199254740991 else . end) + [range(1100) | {ev: "plan", run: 1, t: 1000000, grant: 0, bytes: 9007199254740991, writes: 0, requests: 0}]'
edit "usage sums saturate" 1 "$P12A" "$renewal"'. else . end) | map(if .ev == "cmd" then .bytes = 9007199254740991 else . end) + [range(600) | $g | .bytes = 9007199254740991]'
# Workload, results and schedule
edit "wrong T" 1 "REJECT WRONG-T run 1 n 9: restore or frontier T/lineage is not the synced T" "$(at 1 9 '.restoreTxid = "t0"')"
edit "frontier T differs" 1 "REJECT WRONG-T run 2 n 9: restore or frontier T/lineage is not the synced T" "$(at 2 9 '.casTxid = "t0"')"
edit "wrong lineage" 1 "REJECT WRONG-T run 3 n 2: restore or frontier T/lineage is not the synced T" "$(at 3 2 '.lineage = "lineage-other"')"
edit "wrong command result" 1 "REJECT WRONG-RESULT run 1 n 10: restored database does not hold the exact command result" "$(at 1 10 '.restoredPayloadSha256 = "0"')"
edit "failed integrity" 1 "REJECT WRONG-RESULT run 2 n 10: restored database does not hold the exact command result" "$(at 2 10 '.integrity = "corrupt"')"
NOOP="no state change, replayed or resized payload, or broken state chain"
edit "no-op state" 1 "REJECT NO-OP run 1 n 11: $NOOP" "$(at 1 11 '.after = .before')"
edit "replayed payload" 1 "REJECT NO-OP run 1 n 12: $NOOP" "$(at 1 12 '.payloadSha256 = .payloadSha256[:-2] + "11" | .restoredPayloadSha256 = .payloadSha256')"
edit "payload not a SHA-256" 1 "REJECT NO-OP run 1 n 12: $NOOP" "$(at 1 12 '.payloadSha256 = "p12" | .restoredPayloadSha256 = "p12"')"
edit "resized payload" 1 "REJECT NO-OP run 1 n 13: $NOOP" "$(at 1 13 '.payloadBytes = 1')"
edit "broken state chain" 1 "REJECT NO-OP run 1 n 14: $NOOP" "$(at 1 14 '.before = "stale"')"
edit "oversize database" 1 "REJECT IDENTITY run 1 n 15: database size missing or over 67108864 bytes" "$(at 1 15 '.dbBytes = 67108865')"
edit "database size zero" 1 "REJECT IDENTITY run 1 n 15: database size missing or over 67108864 bytes" "$(at 1 15 '.dbBytes = 0')"
edit "omitted command" 1 "REJECT DROPPED run 1 n 5: command missing; every latency, failure and timeout is retained" 'map(select(.ev != "cmd" or .run != 1 or .n != 5))'
edit "no measured commands" 1 "REJECT DROPPED run 2 n 0: no measured command" 'map(select(.ev != "cmd" or .run != 2))'
edit "header-only trace" 1 "REJECT IDENTITY run 1 n 0: run missing, reused prefix/lineage, or fixture identity/size differs from the procedure" '.[:1]'
edit "extra run" 1 "REJECT SEQUENCE run 4 n 0: event outside runs 1..3" '. + [(map(select(.ev == "run"))[0] | .run = 4 | .prefix = "x" | .lineage = "y")]'
edit "run 0 event" 1 "REJECT SEQUENCE run 0 n 0: event outside runs 1..3" '. + [(map(select(.ev == "run"))[0] | .run = 0 | .prefix = "x" | .lineage = "y")]'
edit "duplicate run" 1 "REJECT IDENTITY run 1 n 0: run recorded twice" '. + [map(select(.ev == "run"))[0]]'
edit "duplicate command" 1 "REJECT SEQUENCE run 1 n 18: command recorded twice" 'map(if .ev == "cmd" and .run == 1 and .n == 18 then ., . else . end)'
edit "command outside schedule" 1 "REJECT SEQUENCE run 3 n 151: command outside the fixed schedule" '. + [last | .n = 151]'
edit "command 0" 1 "REJECT SEQUENCE run 3 n 0: command outside the fixed schedule" '. + [last | .n = 0]'
SCHED="kind, arrival or submission clock is not the fixed schedule"
edit "submission off schedule" 1 "REJECT SCHEDULE run 1 n 19: $SCHED" "$(at 1 19 '.submit -= 700')"
edit "kind out of mix order" 1 "REJECT SCHEDULE run 1 n 20: $SCHED" "$(at 1 20 '.kind = "package-revision"')"
edit "arrival off schedule" 1 "REJECT SCHEDULE run 1 n 21: $SCHED" "$(at 1 21 '.arrival += 1')"
edit "ticket before submission" 1 "REJECT SCHEDULE run 1 n 22: $SCHED" "$(at 1 22 '.ticket = .submit - 1')"
edit "slow publication misses" 3 "$MISS" "$(at 2 150 '.ack += 40000')"
edit "p95 misses" 3 "RUN 2 measured 130 failures 0 p95 13100 max 13200 burst 13200 meets false" 'map(if .ev == "cmd" and .run == 2 and .n >= 100 and .n <= 106 then .ack += 12000 else . end)'
# Identity
BOUND="REJECT IDENTITY run 0 n 0: trace is not bound to this procedure file and evaluator source"
edit "procedure not bound" 1 "$BOUND" 'map(if .ev == "trace" then .procedureSha256 = ("0" * 64) else . end)'
edit "evaluator not bound" 1 "$BOUND" 'map(if .ev == "trace" then .evaluatorSha256 = ("0" * 64) else . end)'
mkdir "$work/no-source" && cp "$EARLY/publication.json" "$work/no-source/"  # no fixture.go beside it: the trace claims the empty file
jq -c '(if .ev == "trace" then .evaluatorSha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" else . end)' "$good" >"$work/no-source.jsonl"
verdict "evaluator source missing" 1 "$BOUND" "$work/no-source/publication.json" "$work/no-source.jsonl"
edit "trace schema" 1 "$BOUND" 'map(if .ev == "trace" then .schema = "other" else . end)'
edit "runner identity not a SHA-256" 1 "REJECT IDENTITY run 0 n 0: subject identity is not a SHA-256" 'map(if .ev == "trace" then .runnerSha256 = ("1" * 63) else . end)'
RUNID="run missing, reused prefix/lineage, or fixture identity/size differs from the procedure"
edit "missing run" 1 "REJECT IDENTITY run 3 n 0: $RUNID" 'map(select(.ev != "run" or .run != 3))'
edit "reused prefix" 1 "REJECT IDENTITY run 2 n 0: $RUNID" "$(runfield 2 '.prefix = "q13/run1/"')"
edit "reused lineage" 1 "REJECT IDENTITY run 3 n 0: $RUNID" "$(runfield 3 '.lineage = "lineage-1"')"
edit "generator differs" 1 "REJECT IDENTITY run 2 n 0: $RUNID" "$(runfield 2 '.generator = "other"')"
edit "seed differs" 1 "REJECT IDENTITY run 1 n 0: $RUNID" "$(runfield 1 '.seed = 1')"
edit "litestream differs" 1 "REJECT IDENTITY run 1 n 0: $RUNID" "$(runfield 1 '.litestream = "0.5.16"')"
edit "undersized database" 1 "REJECT IDENTITY run 1 n 0: $RUNID" "$(runfield 1 '.dbBytes = 41943040')"
edit "oversized initial database" 1 "REJECT IDENTITY run 1 n 0: $RUNID" "$(runfield 1 '.dbBytes = 54525953')"
echo "$fails failed"
((fails == 0))
