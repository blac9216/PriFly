#!/usr/bin/env bash
# Local proof for publication.sh with the fake probe and a placeholder manifest: no Litestream, R2, network,
# credential or real run. Every completed trace is judged by fixture.go from the same tree (the runner execs
# it), so a verdict line also proves the runner wrote fixture.go's grammar (a grammar break is exit 2). The
# fixed P13 schedule runs on a virtual clock: PATH shims for date and sleep move a counter file, and a timeout
# shim requires "-k 1 120" and execs the probe. Group "real" runs the real date, sleep and timeout over a copy
# whose procedure is scaled to 4 commands and a 1 s step bound; fixture.go refuses that procedure (exit 2), so
# its trace is checked directly. Each case asserts an exit code and a whole output line, or a jq condition.
# EARLY may name a scratch copy of scripts/qualification/early with schemas/ three levels up (mutant pass);
# ONLY may list the groups to run (envelope needs accept); MAN and PRB override the manifest and probe.
# shellcheck disable=SC2016  # jq filters and shim bodies expand later
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EARLY="${EARLY:-$HERE/../../../scripts/qualification/early}"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-publication.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/vclock" "$work/badclock"
printf '#!/usr/bin/env bash\n%s\n' 'read -r c <"$VCLOCK"; c=$((c + ${VSTEP:-7})); echo "$c" >"$VCLOCK"; printf "%d.%03d000000\n" $((c / 1000)) $((c % 1000))' >"$work/vclock/date"
printf '#!/usr/bin/env bash\n%s\n' 'read -r c <"$VCLOCK"; s="${1/./}"; echo $((c + 10#$s)) >"$VCLOCK"' >"$work/vclock/sleep"
printf '#!/usr/bin/env bash\n%s\n' '[[ "$1 $2 $3" == "-k 1 120" ]] || exit 125; shift 3; exec "$@"' >"$work/vclock/timeout"
printf '#!/bin/sh\necho 1789634570348164755\n' >"$work/badclock/date"  # date +%%s%%3N on uutils coreutils 0.8.0
chmod +x "$work"/vclock/* "$work/badclock/date"
EB=8589934592 fails=0
PASS="VERDICT: every run meets the fixed publication thresholds; feasibility evidence only, not a Q13 PASS"
MISS="VERDICT: a run misses a fixed publication threshold; feasibility evidence only"
group() { [[ -z "${ONLY:-}" || " $ONLY " == *" $1 "* ]]; }
runner() {  # group, ledger JSON ("" none), FAKE_MODE [, env assignments]: one runner invocation in $work/<group>, bounded by BOUND s
  local d="$work/$1" path="$work/vclock:$PATH"; mkdir -p "$d/state"; [[ -z "$2" ]] || echo "$2" >"$d/ledger.json"
  echo 1789000000000 >"$d/clock"; [[ "${CLOCK:-}" == real ]] && path="$PATH"; [[ "${CLOCK:-}" == bad ]] && path="$work/badclock:$PATH"
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
  cp "$HERE/fake-probe.sh" "$work/probe.sh" && chmod -x "$work/probe.sh" && PRB="$work/probe.sh" runner not-executable '{"bytes":0,"requests":0}' ""
  LEDGER='REFUSED: --ledger must hold the prior cumulative P12a use as {"bytes":N,"requests":N}; no probe step ran'
  line "no prior P12a usage input refuses" no-ledger 20 "$LEDGER"
  line "malformed prior P12a usage refuses" malformed-ledger 20 "$LEDGER"
  line "prior P12a bytes at the envelope refuse" bytes-at-bound 20 "REFUSED: prior P12a use of 8589934592 bytes and 0 requests is at the 8589934592-byte or 100000-request envelope; no probe step ran"
  line "prior P12a requests at the envelope refuse" requests-at-bound 20 "REFUSED: prior P12a use of 0 bytes and 100000 requests is at the 8589934592-byte or 100000-request envelope; no probe step ran"
  line "ledger with another key refuses" extra-key 20 "$LEDGER"
  line "ledger of two JSON documents refuses" two-documents 20 "$LEDGER"
  line "preflight hold refuses" preflight-hold 20 "REFUSED: preflight exit 10; no probe step ran"
  line "probe that is not executable refuses" not-executable 20 "REFUSED: usage: publication.sh --manifest FILE --probe EXECUTABLE --ledger FILE --work DIR; no probe step ran"
  line "clock of the wrong shape refuses" bad-clock 20 "REFUSED: clock read '1789634570348164755' is not seconds.nanoseconds, or ran backwards; no probe step ran"
  if find "$work"/{no-ledger,malformed-ledger,bytes-at-bound,requests-at-bound,bad-clock,extra-key,two-documents,preflight-hold}/state -name calls | grep -q .; then echo "FAIL refusals called the probe"; fails=$((fails + 1)); else echo "ok   refusals never called the probe"; fi
  runner backwards '{"bytes":0,"requests":0}' "" VSTEP=-5
  line "clock running backwards aborts" backwards 21 "ABORTED: clock read '1788999999.990000000' is not seconds.nanoseconds, or ran backwards; no verdict"
  runner fixture-envelope "{\"bytes\":$((EB - 52494336 + 1)),\"requests\":0}" ""
  line "P12a stop before a fixture upload" fixture-envelope 21 "ABORTED: run 1 fixture would pass the P12a envelope; no verdict"
  runner ledger-denied '{"bytes":0,"requests":0}' "ledger@1:3"
  line "ledger write failure aborts before the next send" ledger-denied 21 "ABORTED: ledger write failed; no verdict"
  cond "ledger file holds what the LEDGER line reports after a failed write" grep -qxF "LEDGER: prior 0 bytes 0 requests; after this invocation $(jq -r '"\(.bytes) bytes \(.requests)"' "$work/ledger-denied/ledger.json") requests" "$work/ledger-denied/out"
  cond "no probe call after the ledger write failed" grep -q '^cas 1 3 ' <(tail -n1 "$work/ledger-denied/state/calls")
  for f in "ledger-dir@1:3|ledger write failed" "trace@1:0|exit 1" "term@1:3|signal" "no-lineage@1:0|run 1 fixture reported no lineage" "fixture-over@1:0|run 1 fixture: fixture-over-ticket"; do
    runner "${f%%@*}" '{"bytes":0,"requests":0}' "${f%|*}"
    line "abort: ${f%|*}" "${f%%@*}" 21 "ABORTED: ${f#*|}; no verdict"
  done
  runner plan-envelope '{"bytes":0,"requests":99989}' ""  # run 1's fixture plan and fixture leave one request, which its hold plan uses
  line "P12a stop before a plan call" plan-envelope 21 "ABORTED: run 2 fixture plan: envelope; no verdict"
  cond "no plan call past the P12a envelope" awk '/^plan 1 package-revision / {exit 1}' "$work/plan-envelope/state/calls"
fi
if group real; then
  real="$work/scaled/scripts/qualification/early"; mkdir -p "$real" && cp -r "$EARLY/." "$real" && cp -r "$EARLY/../../../schemas" "$work/scaled/"
  jq '.runs = 1 | .warmupMs = 1000 | .durationMs = 2000 | .cadenceMs = 1000 | .burst = {atMs: 0, count: 1} | .stepTimeoutS = 1' "$EARLY/publication.json" >"$real/publication.json"
  t0=$(($(date +%s%N) / 1000000)); CLOCK=real RUNNER="$real" runner real '{"bytes":0,"requests":0}' "hang@1:4"; t1=$(($(date +%s%N) / 1000000))
  line "real clock run reaches the evaluator" real 2 "fixture: procedure is not the fixed P4/P12a/P12b/P13 procedure"
  holds "real clock: epoch-ms step clocks inside the run, in lane order" real "map(select(.ev == \"cmd\")) | length == 4 and all(.[]; .ticket > 0 and ($lane | map(select(. > 0)) | . == sort and all(.[]; . >= \$t0 and . <= \$t1)))" --argjson t0 "$t0" --argjson t1 "$t1"
  holds "real clock: burst CAS paced 1100 ms" real 'map(select(.ev == "cmd")) | .[2].casStart - .[1].casStart >= 1100'
  holds "real timeout -k ends a TERM-ignoring step" real 'map(select(.ev == "cmd"))[3] | .reason == "sync-exit137" and .syncEnd - .syncStart < 2900'
fi
if group accept; then
  runner accept '{"bytes":1000,"requests":10}' "heavy@1:10"
  line "runner trace accepted by the evaluator" accept 0 "$PASS"
  holds "renewals are ticketed publications numbered in the command sequence" accept \
    'map(select(.ev == "cmd" or .ticket)) | group_by(.run) | all(sort_by(.ticket) | (map(select(.ev == "grant")) | length >= 2) and all(.[]; .outcome == "published") and map(.casSeq) == [range(1; length + 1)])'
  holds "renewal held beside the ticket: grant headroom renews run 1 before command 5" accept \
    'map(select(.run == 1)) | (map(select(.ev == "cmd"))[3:5]) as [$c4, $c5] | any(.[]; .ticket and .ticket > $c4.ack and .ack <= $c5.ticket) and $c5.ticket < map(select(.ev == "grant"))[0].deadline - 30000'
  holds "CAS writes at least 1100 ms apart, the burst at that bound" accept \
    'map(select(.casStart > 0)) | group_by(.run) | all(sort_by(.casStart) | [range(1; length) as $i | .[$i].casStart - .[$i - 1].casStart] | min >= 1100 and min < 1200)'
  holds "no ack before its CAS result" accept 'all(.[] | select(.outcome == "published"); .ack > .casEnd and .casEnd > .casStart)'
  cond "tickets and plan calls in the ledger file before they are sent" awk '{split($NF, j, /[:,}]/)} $1 == "plan" {b = j[2]; r = j[4]}
    $1 == "artifact" {n++; if (j[2] != b + $6 || j[4] != r + $8) bad = 1} END {exit bad || !n}' "$work/accept/state/calls"
  holds "ledger is the prior use plus every charge" accept '.[0].priorBytes == 1000 and $l[0] == {bytes: (1000 + (map(.bytes // 0) | add)), requests: (10 + (map(.requests // 0) | add))}'
fi
if group envelope; then  # prior use one byte short of letting the accepted run's whole use fit
  used=$(($(jq .bytes "$work/accept/ledger.json") - 1000))
  runner envelope "{\"bytes\":$((EB - used + 1)),\"requests\":0}" "heavy@1:10"
  line "cumulative P12a stop keeps the run inside the envelope" envelope 3 "$MISS"
  holds "P12a stop fails one command before its ticket, then blocks the lane" envelope \
    "map(select(.ev == \"cmd\" and .outcome == \"failed\")) | .[0].reason == \"envelope\" and .[0].ticket == 0 and .[0].run == 3 and all(.[1:][]; .reason == \"lane-blocked\") and \$l[0].bytes <= $EB"
fi
if group faults; then
  runner faults '{"bytes":0,"requests":0}' "lineage@1:5 cas-seq@2:6 cas-lost@3:7"
  line "lineage mismatch fails the command before restore" faults 3 "FAILURE run 1 n 5 kind package-revision arrival 60000 reason sync-lineage"
  line "lane blocked after a lineage mismatch" faults 3 "FAILURE run 1 n 6 kind attempt-result arrival 75000 reason lane-blocked"
  line "CAS readback of another sequence fails the command" faults 3 "FAILURE run 2 n 6 kind attempt-result arrival 75000 reason cas-mismatch"
  line "ambiguous CAS fails the command" faults 3 "FAILURE run 3 n 7 kind finding-review arrival 90000 reason cas-exit1"
  holds "a failed command is charged its whole reservation" faults 'map(select(.reason == "cas-exit1"))[0] | .bytes == .payloadBytes + 65536 and .writes == 8 and .requests == 40'
  runner checks1 '{"bytes":0,"requests":0}' "cas-txid@1:5 restore-txid@2:5 integrity@3:5"
  runner checks2 '{"bytes":0,"requests":0}' "payload@1:5 restore-seq@2:5 short-txid@3:5"
  runner checks3 '{"bytes":0,"requests":0}' "over-use@1:5 exit1@2:5 huge@3:finding-review"
  runner checks4 '{"bytes":0,"requests":0}' "stall@1:attempt-result huge@2:renewal greedy@3:package-revision"
  runner held-envelope '{"bytes":0,"requests":99929}' ""  # 100000 - 71: run 1's first ticket fits P12a only without the held one
  holds "a failed plan call is charged its declared use" checks4 'map(select(.ev == "plan" and .run == 3))[2].requests == 1'
  for f in checks1:1:5:cas-mismatch checks1:2:5:restore-mismatch checks1:3:5:restore-mismatch checks2:1:5:restore-mismatch checks2:2:5:restore-mismatch \
    checks2:3:5:sync-lineage checks3:1:5:sync-over-ticket checks3:2:5:commit-exit1 checks3:3:3:plan-over-maxima checks4:1:2:renewal-grant-expired \
    checks4:2:1:lane-blocked checks4:3:1:plan-over-ticket held-envelope:1:1:envelope; do
    IFS=: read -r g r n why <<<"$f"; read -r kind arrival < <(jq -r --argjson n "$n" '"\(.mix[($n - 1) % 4].kind) \(($n - 1) * .cadenceMs)"' "$EARLY/publication.json")
    line "$g: run $r n $n fails $why" "$g" 3 "FAILURE run $r n $n kind $kind arrival $arrival reason $why"
  done
  if grep -q '^cas 3 7 ' "$work/faults/state/calls" && ! grep -qE '^(restore|cas) 1 5 ' "$work/faults/state/calls" && ! awk '/^cas 3 7 /{f=1; next} f' "$work/faults/state/calls" | grep -q .; then
    echo "ok   no restore after a lineage mismatch and no successor after an ambiguous CAS"; else echo "FAIL no restore after a lineage mismatch and no successor after an ambiguous CAS"; fails=$((fails + 1)); fi
fi
if group renewals; then
  runner renewals '{"bytes":0,"requests":0}' "heavy@1:10 cas-lost@1:5 heavy@2:10 hold-fail@2:2 heavy@3:10 cas-txid@3:5"
  unsent=".outcome == \"failed\" and .ticket == 0 and .bytes == 0 and .writes == 0 and .requests == 0 and ($lane | all(. == 0))"
  holds "a failed renewal leaves the next command failed with no ticket, use or clock" renewals "map(select(.run == 1 and .n == 5))[0] | $unsent and .reason == \"renewal-cas-exit1\""
  holds "a published renewal whose re-hold fails never marks the command published" renewals \
    "(map(select(.run == 2 and .ev == \"grant\"))[1].outcome == \"published\") and (map(select(.run == 2 and .n == 5))[0] | $unsent and .reason == \"renewal-plan\")"
  holds "a renewal whose CAS reads back another T fails" renewals \
    'map(select(.run == 3 and .ev == "grant"))[1].outcome == "failed" and map(select(.run == 3 and .n == 5))[0].reason == "renewal-cas-mismatch"'
fi
echo "$fails failed"
((fails == 0))
