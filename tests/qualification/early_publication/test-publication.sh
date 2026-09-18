#!/usr/bin/env bash
# Local proof for publication.sh with the fake probe and a placeholder manifest: no Litestream, R2, network,
# credential or real run. Every completed trace is judged by fixture.go from the same tree (the runner execs
# it), so a verdict line also proves the runner wrote fixture.go's grammar (a grammar break is exit 2). The
# fixed P13 schedule runs on a virtual clock: PATH shims for date and sleep move a counter file. Group "real"
# runs the real date and sleep over a copy whose procedure is scaled to 4 commands and a 1 s step bound, with a
# PATH "timeout" that keeps the real one's semantics and adds the 100 ms poll of uutils coreutils 0.8.0: the
# runner bounds its own steps, so that shim must never run and the measured steps must not carry its floor.
# fixture.go refuses that procedure (exit 2), so its trace is checked directly. Each case asserts an exit code
# and a whole output line, or a jq condition.
# EARLY may name a scratch copy of scripts/qualification/early with schemas/ three levels up (mutant pass);
# ONLY may list the groups to run (envelope needs accept); MAN and PRB override the manifest and probe.
# shellcheck disable=SC2016  # jq filters and shim bodies expand later
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EARLY="${EARLY:-$HERE/../../../scripts/qualification/early}"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-publication.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/vclock" "$work/badclock" "$work/polled"
printf '#!/usr/bin/env bash\n%s\n' 'read -r c <"$VCLOCK"; c=$((c + ${VSTEP:-7})); echo "$c" >"$VCLOCK"; printf "%d.%03d000000\n" $((c / 1000)) $((c % 1000))' >"$work/vclock/date"
printf '#!/usr/bin/env bash\n%s\n' 'read -r c <"$VCLOCK"; s="${1/./}"; echo $((c + 10#$s)) >"$VCLOCK"' >"$work/vclock/sleep"
printf '#!/bin/sh\necho 1789634570348164755\n' >"$work/badclock/date"  # date +%%s%%3N on uutils coreutils 0.8.0
printf '#!/usr/bin/env bash\n%s\n' ': >"${0%/*}/called"; command -p timeout "$@"; rc=$?; sleep 0.105; exit $rc' >"$work/polled/timeout"
chmod +x "$work"/vclock/* "$work/badclock/date" "$work/polled/timeout"
EB=8589934592 fails=0
PASS="VERDICT: every run meets the fixed publication thresholds; feasibility evidence only, not a Q13 PASS"
MISS="VERDICT: a run misses a fixed publication threshold; feasibility evidence only"
group() { [[ -z "${ONLY:-}" || " $ONLY " == *" $1 "* ]]; }
runner() {  # group, ledger JSON ("" none), FAKE_MODE [, env assignments]: one runner invocation in $work/<group>, bounded by BOUND s
  local d="$work/$1" path="$work/vclock:$PATH"; mkdir -p "$d/state"; [[ -z "$2" ]] || echo "$2" >"$d/ledger.json"
  echo 1789000000000 >"$d/clock"; [[ "${CLOCK:-}" == real ]] && path="${SHIM:+$SHIM:}$PATH"; [[ "${CLOCK:-}" == bad ]] && path="$work/badclock:$PATH"
  set +e; timeout -k 5 "${BOUND:-900}" env PATH="$path" VCLOCK="$d/clock" FAKE_STATE="$d/state" FAKE_MODE="$3" "${@:4}" bash "${RUNNER:-$EARLY}/publication.sh" \
    --manifest "${MAN:-$HERE/manifest.json}" --probe "${PRB:-$HERE/fake-probe.sh}" --ledger "$d/ledger.json" --work "$d/work" >"$d/out" 2>"$d/err"; echo $? >"$d/rc"; set -e
}
line() {  # name, group, want exit, want whole output line
  if [[ "$(cat "$work/$2/rc")" == "$3" ]] && grep -qxF -- "$4" "$work/$2/out" "$work/$2/err"; then echo "ok   $1"; else
    echo "FAIL $1: exit $(cat "$work/$2/rc") (want $3), want line: $4"; grep -E '^(REJECT|RUN|FAILURE|VERDICT|REFUSED|ABORTED|fixture)' "$work/$2/out" | head -n 8 | sed 's/^/     | /' || true; fails=$((fails + 1)); fi
}
holds() {  # name, group, jq -e condition over the slurped trace ($l: the ledger after the run)
  if jq -se --slurpfile l "$work/$2/ledger.json" "${@:4}" "$3" "$work/$2/work/trace.jsonl" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}
cond() { if "${@:2}" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }  # name, command
lane='[.ticket, .commitStart, .commitEnd, .syncStart, .syncEnd, .restoreStart, .restoreEnd, .casStart, .casEnd, .ack]'
if group refusals; then
  runner no-ledger "" ""
  runner malformed-ledger '{"bytes":1}' ""
  runner bytes-at-bound '{"bytes":8589934592,"requests":0}' ""
  runner requests-at-bound '{"bytes":0,"requests":100000}' ""
  BOUND=30 CLOCK=bad runner bad-clock '{"bytes":0,"requests":0}' ""
  runner extra-key '{"bytes":0,"requests":0,"writes":0}' ""
  runner two-documents '{"bytes":0,"requests":0} {"bytes":8589934592,"requests":100000}' ""
  jq 'del(.host_reservation_ref)' "$HERE/manifest.json" >"$work/held.json" && MAN="$work/held.json" runner preflight-hold '{"bytes":0,"requests":0}' ""
  runner no-build '{"bytes":0,"requests":0}' "" GOFLAGS=-mod=bogus
  cp "$HERE/fake-probe.sh" "$work/probe.sh" && chmod -x "$work/probe.sh" && PRB="$work/probe.sh" runner not-executable '{"bytes":0,"requests":0}' ""
  LEDGER='REFUSED: --ledger must hold the prior cumulative P12a use as {"bytes":N,"requests":N}; no probe step ran'
  line "no prior P12a usage input refuses" no-ledger 20 "$LEDGER"
  line "malformed prior P12a usage refuses" malformed-ledger 20 "$LEDGER"
  line "prior P12a bytes at the envelope refuse" bytes-at-bound 20 "REFUSED: prior P12a use of 8589934592 bytes and 0 requests is at the 8589934592-byte or 100000-request envelope; no probe step ran"
  line "prior P12a requests at the envelope refuse" requests-at-bound 20 "REFUSED: prior P12a use of 0 bytes and 100000 requests is at the 8589934592-byte or 100000-request envelope; no probe step ran"
  line "ledger with another key refuses" extra-key 20 "$LEDGER"
  line "ledger of two JSON documents refuses" two-documents 20 "$LEDGER"
  line "preflight hold refuses" preflight-hold 20 "REFUSED: preflight exit 10; no probe step ran"
  line "evaluator build failure refuses" no-build 20 "REFUSED: evaluator build failed; no probe step ran"
  line "probe that is not executable refuses" not-executable 20 "REFUSED: usage: publication.sh --manifest FILE --probe EXECUTABLE --ledger FILE --work DIR; no probe step ran"
  line "clock of the wrong shape refuses" bad-clock 20 "REFUSED: clock read '1789634570348164755' is not seconds.nanoseconds, or ran backwards; no probe step ran"
  if find "$work"/{no-ledger,malformed-ledger,bytes-at-bound,requests-at-bound,bad-clock,extra-key,two-documents,preflight-hold,no-build}/state -name calls | grep -q .; then echo "FAIL refusals called the probe"; fails=$((fails + 1)); else echo "ok   refusals never called the probe"; fi
  runner backwards '{"bytes":0,"requests":0}' "" VSTEP=-5
  line "clock running backwards aborts" backwards 21 "ABORTED: clock read '1788999999.990000000' is not seconds.nanoseconds, or ran backwards; no verdict"
  runner fixture-envelope "{\"bytes\":$((EB - 268435456 + 1)),\"requests\":0}" ""  # one byte short of a maximal fixture ticket
  line "P12a stop before a fixture plan" fixture-envelope 21 "ABORTED: run 1 fixture: envelope; no verdict"
  cond "no plan call past the P12a envelope" awk '$1 == "plan" {exit 1}' "$work/fixture-envelope/state/calls"
  runner ledger-denied '{"bytes":0,"requests":0}' "ledger@1:3"
  line "ledger write failure aborts before the next send" ledger-denied 21 "ABORTED: ledger write failed; no verdict"
  cond "ledger file holds what the LEDGER line reports after a failed write" grep -qxF "LEDGER: prior 0 bytes 0 requests; after this invocation $(jq -r '"\(.bytes) bytes \(.requests)"' "$work/ledger-denied/ledger.json") requests" "$work/ledger-denied/out"
  cond "no probe call after the ledger write failed" grep -q '^cas 1 3 ' <(tail -n1 "$work/ledger-denied/state/calls")
  for f in "ledger-dir@1:3|ledger write failed" "trace@1:0|exit 1" "term@1:3|signal" "no-lineage@1:0|run 1 fixture reported no lineage" "fixture-over@1:0|run 1 fixture: fixture-over-ticket" \
    "huge@1:fixture|run 1 fixture: plan-over-maxima" "plan-writes@0:declare|the probe declares no write-free plan use that leaves a grant two tickets: 0 bytes 1 writes 1 requests" \
    "bigplan@0:declare|the probe declares no write-free plan use that leaves a grant two tickets: 209715200 bytes 0 writes 1 requests"; do
    runner "${f%%@*}" '{"bytes":0,"requests":0}' "${f%|*}"
    line "abort: ${f%|*}" "${f%%@*}" 21 "ABORTED: ${f#*|}; no verdict"
  done
fi
if group real; then
  real="$work/scaled/scripts/qualification/early"; mkdir -p "$real" && cp -r "$EARLY/." "$real" && cp -r "$EARLY/../../../schemas" "$work/scaled/"
  jq '.runs = 1 | .warmupMs = 1000 | .durationMs = 2000 | .cadenceMs = 1000 | .burst = {atMs: 0, count: 1} | .stepTimeoutS = 1' "$EARLY/publication.json" >"$real/publication.json"
  t0=$(($(date +%s%N) / 1000000)); SHIM="$work/polled" CLOCK=real RUNNER="$real" runner real '{"bytes":0,"requests":0}' "hang@1:4"; t1=$(($(date +%s%N) / 1000000))
  line "real clock run reaches the evaluator" real 2 "fixture: procedure is not the fixed P4/P12a/P12b/P13 procedure"
  holds "real clock: epoch-ms step clocks inside the run, in lane order" real "map(select(.ev == \"cmd\")) | length == 4 and all(.[]; .ticket > 0 and ($lane | map(select(. > 0)) | . == sort and all(.[]; . >= \$t0 and . <= \$t1)))" --argjson t0 "$t0" --argjson t1 "$t1"
  holds "real clock: burst CAS paced 1100 ms" real 'map(select(.ev == "cmd")) | .[2].casStart - .[1].casStart >= 1100'
  holds "the step bound ends a TERM-ignoring step" real 'map(select(.ev == "cmd"))[3] | .reason == "sync-exit137" and .syncEnd - .syncStart < 2900'
  holds "no step bound polls a finished probe: a measured step is under the 100 ms poll floor" real \
    'map(select(.ev == "cmd" and .outcome == "published")) | [.[] | .commitEnd - .commitStart, .syncEnd - .syncStart, .restoreEnd - .restoreStart, .casEnd - .casStart]
     | length == 12 and min < 100'
  cond "the polling step bound on PATH is never called" test ! -e "$work/polled/called"
fi
if group accept; then
  runner accept '{"bytes":1000,"requests":10}' "heavy@1:10 bulk@2:4"
  line "runner trace accepted by the evaluator" accept 0 "$PASS"
  holds "renewals are ticketed publications numbered in the command sequence" accept \
    'map(select(.ev == "cmd" or .ticket)) | group_by(.run) | all(sort_by(.ticket) | (map(select(.ev == "grant")) | length >= 2) and all(.[]; .outcome == "published") and map(.casSeq) == [range(1; length + 1)])'
  holds "renewal held beside the ticket: fixture, plan (run 1) and ticket (run 2) use renew before commands 1-5 (run 3: 1)" accept \
    'map(select(.ticket > 0)) | group_by(.run) | map(sort_by(.ticket) | map(.ev)[0:11]) | .[0] == .[1] and .[2][0:3] == ["grant", "cmd", "cmd"] and
      .[0] == ["grant", "cmd", "grant", "cmd", "grant", "cmd", "grant", "cmd", "grant", "cmd", "cmd"]'
  holds "grant opens before t0; the fixture plan is sent at t0 under that grant" accept \
    'group_by(.run) | map(select(.[0].run)) | length == 3 and all(map(select(.ev != "cmd"))[0:3] | map(.ev) == ["grant", "plan", "run"] and .[0].t < .[1].t and .[1].t == .[2].t0 and .[1].grant == 0 and .[2].grant == 0)'
  holds "CAS writes at least 1100 ms apart, the burst at that bound" accept \
    'map(select(.casStart > 0)) | group_by(.run) | all(sort_by(.casStart) | [range(1; length) as $i | .[$i].casStart - .[$i - 1].casStart] | min >= 1100 and min < 1200)'
  holds "no ack before its CAS result" accept 'all(.[] | select(.outcome == "published"); .ack > .casEnd and .casEnd > .casStart)'
  holds "a published command settles under the reservation it was charged" accept 'map(select(.ev == "cmd" and .outcome == "published"))[0] |
    .bytes < .reservedBytes and .writes < .reservedWrites and .requests < .reservedRequests'
  holds "ledger is the prior use plus every charge" accept '.[0].priorBytes == 1000 and $l[0] == {bytes: (1000 + (map(.bytes // 0) | add)), requests: (10 + (map(.requests // 0) | add))}'
fi
if group envelope; then  # prior use leaving run 3 800 MiB: its fixture fits, and a later command lacks the 732 MiB two-ticket room
  used=$(jq -s 'map(select(.run < 3) | .bytes // 0) | add' "$work/accept/work/trace.jsonl")
  runner envelope "{\"bytes\":$((EB - used - (800 << 20))),\"requests\":0}" "heavy@1:10 bulk@2:4"
  line "cumulative P12a stop keeps the run inside the envelope" envelope 3 "$MISS"
  holds "P12a stop fails one command before its ticket, then blocks the lane" envelope \
    "map(select(.ev == \"cmd\" and .outcome == \"failed\")) | .[0].reason == \"envelope\" and .[0].ticket == 0 and .[0].run == 3 and .[0].n > 1 and all(.[1:][]; .reason == \"lane-blocked\") and \$l[0].bytes <= $EB"
fi
if group faults; then
  runner faults '{"bytes":0,"requests":0}' "lineage@1:5 cas-seq@2:6 cas-lost@3:7" &
  runner checks1 '{"bytes":0,"requests":0}' "cas-txid@1:5 restore-txid@2:5 integrity@3:5" &
  runner checks2 '{"bytes":0,"requests":0}' "payload@1:5 restore-seq@2:5 short-txid@3:5" &
  runner checks3 '{"bytes":0,"requests":0}' "over-use@1:5 exit1@2:5 huge@3:finding-review" &
  runner checks4 '{"bytes":0,"requests":0}' "stall@1:attempt-result huge@2:renewal greedy@3:package-revision" &
  runner checks5 '{"bytes":0,"requests":0}' "stall@1:renewal stall@2:5 plan-write@3:package-revision" &
  runner checks6 '{"bytes":0,"requests":0}' "garbage@1:5 badplan@2:attempt-result" &
  runner held-envelope '{"bytes":0,"requests":90000}' "" & wait  # held-envelope: run 1's first command has P12a room for one maximal ticket, not the held second
  line "lineage mismatch fails the command before restore" faults 3 "FAILURE run 1 n 5 kind package-revision arrival 60000 reason sync-lineage"
  line "lane blocked after a lineage mismatch" faults 3 "FAILURE run 1 n 6 kind attempt-result arrival 75000 reason lane-blocked"
  line "CAS readback of another sequence fails the command" faults 3 "FAILURE run 2 n 6 kind attempt-result arrival 75000 reason cas-mismatch"
  line "ambiguous CAS fails the command" faults 3 "FAILURE run 3 n 7 kind finding-review arrival 90000 reason cas-exit1"
  cond "tickets and plan calls in the ledger file before they are sent" awk '{split($NF, j, /[:,}]/)} $1 == "plan" {b = j[2]; r = j[4]}
    $1 == "artifact" {n++; if (j[2] != b + $6 || j[4] != r + $8) bad = 1} END {exit bad || !n}' "$work/faults/state/calls"  # declared plan use is its use here
  holds "a failed command is charged its whole reservation" faults 'map(select(.reason == "cas-exit1"))[0] |
    .bytes == .payloadBytes + 65536 and .writes == 8 and .requests == 40 and
    [.bytes, .writes, .requests] == [.reservedBytes, .reservedWrites, .reservedRequests]'
  holds "a failed plan call is charged its declared use" checks4 'map(select(.ev == "plan" and .run == 3))[1].requests == 1'
  line "a plan call left without a ticket stops the run" checks3 1 "REJECT PLAN run 3 n 0: plan call serves no entry: after the run's last ticketed entry, or a second plan for it"
  cond "no plan call after the one left without a ticket" grep -q '^plan 3 finding-review ' <(grep '^plan 3 ' "$work/checks3/state/calls" | tail -n1)
  holds "no plan call sent past its grant's deadline" checks5 'map(select(.run == 2)) | .[0].deadline as $d | all(.[] | select(.ev == "plan"); .t <= $d)'
  for f in checks1:1:5:cas-mismatch checks1:2:5:restore-mismatch checks1:3:5:restore-mismatch checks2:1:5:restore-mismatch checks2:2:5:restore-mismatch \
    checks2:3:5:sync-lineage checks3:1:5:sync-over-ticket checks3:2:5:commit-exit1 checks3:3:3:plan-over-maxima checks4:1:2:grant-expired \
    checks4:2:39:renewal-plan-over-maxima checks4:3:1:plan-over-ticket \
    checks5:1:39:renewal-grant-expired checks5:2:6:renewal-grant-expired checks5:3:1:plan-over-ticket checks6:1:5:sync-output checks6:2:2:plan-output held-envelope:1:1:envelope; do
    IFS=: read -r g r n why <<<"$f"; read -r kind arrival < <(jq -r --argjson n "$n" '"\(.mix[($n - 1) % 4].kind) \(($n - 1) * .cadenceMs)"' "$EARLY/publication.json")
    rc=3; [[ $g != checks[3-6] ]] || rc=1  # a plan call left without a ticket: REJECT PLAN
    line "$g: run $r n $n fails $why" "$g" "$rc" "FAILURE run $r n $n kind $kind arrival $arrival reason $why"
  done
  if grep -q '^cas 3 7 ' "$work/faults/state/calls" && ! grep -qE '^(restore|cas) 1 5 ' "$work/faults/state/calls" && ! awk '/^cas 3 7 /{f=1; next} f' "$work/faults/state/calls" | grep -q .; then
    echo "ok   no restore after a lineage mismatch and no successor after an ambiguous CAS"; else echo "FAIL no restore after a lineage mismatch and no successor after an ambiguous CAS"; fails=$((fails + 1)); fi
fi
if group renewals; then
  runner renewals '{"bytes":0,"requests":0}' "heavy@1:10 cas-lost@1:1 heavy@2:10 exit1@2:4 heavy@3:10 greedy@3:attempt-result" &
  runner lost-renewal '{"bytes":0,"requests":0}' "heavy@1:10 cas-lost@1:1" & wait  # lost-renewal: run 1's renewal alone fails
  line "a failed renewal is a failed run, not a rejected trace" lost-renewal 3 "$MISS"
  line "the failed renewal is retained as the failure it is" lost-renewal 3 "FAILURE run 1 grant 1 kind renewal reason cas-exit1"
  holds "the failed renewal opens no grant and blocks run 1's lane" lost-renewal \
    'map(select(.run == 1)) | (map(select(.ev == "grant" and .outcome == "failed")) | length == 1 and all(.[]; .t == 0 and .deadline == 0))
     and all(.[] | select(.ev == "cmd"); .outcome == "failed")'
  unsent=".outcome == \"failed\" and .ticket == 0 and .bytes == 0 and .writes == 0 and .requests == 0 and
    .reservedBytes == 0 and .reservedWrites == 0 and .reservedRequests == 0 and ($lane | all(. == 0))"
  holds "a failed renewal leaves the next command failed with no ticket, use or clock" renewals "map(select(.run == 1 and .n == 1))[0] | $unsent and .reason == \"renewal-cas-exit1\""
  holds "a command failing its plan after a published renewal is never published" renewals \
    "(map(select(.run == 3 and .ev == \"grant\"))[2].outcome == \"published\") and (map(select(.run == 3 and .n == 2))[0] | $unsent and .reason == \"plan-over-ticket\")"
  holds "a failed command keeps sequence n plus the renewals before it" renewals 'map(select(.run == 2 and .n == 2))[0] | .reason == "commit-exit1" and .ticket > 0'
  cond "its steps ran at that sequence" grep -q '^commit 2 4 2 ' "$work/renewals/state/calls"
fi
echo "$fails failed"
((fails == 0))
