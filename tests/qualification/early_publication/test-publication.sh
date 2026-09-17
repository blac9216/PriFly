#!/usr/bin/env bash
# Local proof for publication.sh with the fake probe and a placeholder manifest: no Litestream, R2, network,
# credential or real run. Every completed trace is judged by fixture.go from the same tree (the runner execs
# it), so a verdict line also proves the runner wrote fixture.go's grammar (a grammar break is exit 2). The
# fixed P13 schedule runs on a virtual clock: PATH shims for date and sleep move a counter file, and a timeout
# shim requires "-k 1 120" and execs the probe. Group "real" runs the real date, sleep and timeout over a copy
# whose procedure is scaled to 4 commands and a 1 s step bound; fixture.go refuses that procedure (exit 2), so
# its trace is checked directly. Each case asserts an exit code and a whole output line, or a jq condition.
# EARLY may name a scratch copy of scripts/qualification/early with schemas/ three levels up (mutant pass);
# ONLY may list the groups to run (envelope needs accept).
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
runner() {  # group, ledger JSON ("" none), FAKE_MODE [, env assignments]: one runner invocation in $work/<group>
  local d="$work/$1" path="$work/vclock:$PATH"; mkdir -p "$d/state"; [[ -z "$2" ]] || echo "$2" >"$d/ledger.json"
  echo 1789000000000 >"$d/clock"; [[ "${CLOCK:-}" == real ]] && path="$PATH"; [[ "${CLOCK:-}" == bad ]] && path="$work/badclock:$PATH"
  set +e; env PATH="$path" VCLOCK="$d/clock" FAKE_STATE="$d/state" FAKE_MODE="$3" "${@:4}" bash "${RUNNER:-$EARLY}/publication.sh" \
    --manifest "$HERE/manifest.json" --probe "$HERE/fake-probe.sh" --ledger "$d/ledger.json" --work "$d/work" >"$d/out" 2>"$d/err"; echo $? >"$d/rc"; set -e
}
line() {  # name, group, want exit, want whole output line
  if [[ "$(cat "$work/$2/rc")" == "$3" ]] && grep -qxF -- "$4" "$work/$2/out" "$work/$2/err"; then echo "ok   $1"; else
    echo "FAIL $1: exit $(cat "$work/$2/rc") (want $3), want line: $4"; grep -E '^(REJECT|RUN|FAILURE|VERDICT|REFUSED|ABORTED|fixture)' "$work/$2/out" | head -n 8 | sed 's/^/     | /' || true; fails=$((fails + 1)); fi
}
holds() {  # name, group, jq -e condition over the slurped trace ($l: the ledger after the run)
  if jq -se --slurpfile l "$work/$2/ledger.json" "${@:4}" "$3" "$work/$2/work/trace.jsonl" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}
lane='[.ticket, .commitStart, .commitEnd, .syncStart, .syncEnd, .restoreStart, .restoreEnd, .casStart, .casEnd, .ack]'
if group refusals; then
  runner no-ledger "" ""
  runner malformed-ledger '{"bytes":1}' ""
  runner bytes-at-bound '{"bytes":8589934592,"requests":0}' ""
  runner requests-at-bound '{"bytes":0,"requests":100000}' ""
  CLOCK=bad runner bad-clock '{"bytes":0,"requests":0}' ""
  LEDGER='REFUSED: --ledger must hold the prior cumulative P12a use as {"bytes":N,"requests":N}; no probe step ran'
  line "no prior P12a usage input refuses" no-ledger 20 "$LEDGER"
  line "malformed prior P12a usage refuses" malformed-ledger 20 "$LEDGER"
  line "prior P12a bytes at the envelope refuse" bytes-at-bound 20 "REFUSED: prior P12a use of 8589934592 bytes and 0 requests is at the 8589934592-byte or 100000-request envelope; no probe step ran"
  line "prior P12a requests at the envelope refuse" requests-at-bound 20 "REFUSED: prior P12a use of 0 bytes and 100000 requests is at the 8589934592-byte or 100000-request envelope; no probe step ran"
  line "clock of the wrong shape refuses" bad-clock 20 "REFUSED: clock read '1789634570348164755' is not seconds.nanoseconds, or ran backwards; no probe step ran"
  if find "$work"/{no-ledger,malformed-ledger,bytes-at-bound,requests-at-bound,bad-clock}/state -name calls | grep -q .; then echo "FAIL refusals called the probe"; fails=$((fails + 1)); else echo "ok   refusals never called the probe"; fi
  runner backwards '{"bytes":0,"requests":0}' "" VSTEP=-5
  line "clock running backwards aborts" backwards 21 "ABORTED: clock read '1788999999.990000000' is not seconds.nanoseconds, or ran backwards; no verdict"
  runner fixture-envelope "{\"bytes\":$((EB - 52494336 + 1)),\"requests\":0}" ""
  line "P12a stop before a fixture upload" fixture-envelope 21 "ABORTED: run 1 fixture would pass the P12a envelope; no verdict"
fi
if group real; then
  real="$work/scaled/scripts/qualification/early"; mkdir -p "$real" && cp -r "$EARLY/." "$real" && cp -r "$EARLY/../../../schemas" "$work/scaled/"
  jq '.runs = 1 | .warmupMs = 1000 | .durationMs = 2000 | .cadenceMs = 1000 | .burst = {atMs: 0, count: 1} | .stepTimeoutS = 1' "$EARLY/publication.json" >"$real/publication.json"
  t0=$(($(date +%s%N) / 1000000)); CLOCK=real RUNNER="$real" runner real '{"bytes":0,"requests":0}' "hang@1:4"; t1=$(($(date +%s%N) / 1000000))
  line "real clock run reaches the evaluator" real 2 "fixture: procedure is not the fixed P4/P12a/P12b/P13 procedure"
  holds "real clock: epoch-ms step clocks inside the run, in lane order" real "map(select(.ev == \"cmd\")) | length == 4 and all(.[]; $lane | map(select(. > 0)) | . == sort and all(.[]; . >= \$t0 and . <= \$t1))" --argjson t0 "$t0" --argjson t1 "$t1"
  holds "real clock: burst CAS paced 1100 ms" real 'map(select(.ev == "cmd")) | .[2].casStart - .[1].casStart >= 1100'
  holds "real timeout -k ends a TERM-ignoring step" real 'map(select(.ev == "cmd"))[3] | .reason == "sync-exit137" and .syncEnd - .syncStart < 2900'
fi
if group accept; then
  runner accept '{"bytes":1000,"requests":10}' "heavy@1:10"
  line "runner trace accepted by the evaluator" accept 0 "$PASS"
  holds "renewals are ticketed publications numbered in the command sequence" accept \
    'map(select(.ev == "cmd" or .ticket)) | group_by(.run) | all(sort_by(.ticket) | (map(select(.ev == "grant")) | length >= 2) and all(.[]; .outcome == "published") and map(.casSeq) == [range(1; length + 1)])'
  holds "renewal held beside the ticket: grant headroom renews run 1 before command 5" accept \
    'map(select(.run == 1)) | (map(select(.ev == "cmd"))[3:5]) as [$c4, $c5] | any(.[]; .ticket and .ticket > $c4.ack and .ack < $c5.ticket) and $c5.ticket < map(select(.ev == "grant"))[0].deadline - 30000'
  holds "CAS writes at least 1100 ms apart, the burst at that bound" accept \
    'map(select(.casStart > 0)) | group_by(.run) | all(sort_by(.casStart) | [range(1; length) as $i | .[$i].casStart - .[$i - 1].casStart] | min >= 1100 and min < 1200)'
  holds "no ack before its CAS result" accept 'all(.[] | select(.outcome == "published"); .ack > .casEnd and .casEnd > .casStart)'
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
  if grep -q '^cas 3 7 ' "$work/faults/state/calls" && ! grep -qE '^(restore|cas) 1 5 ' "$work/faults/state/calls" && ! awk '/^cas 3 7 /{f=1; next} f' "$work/faults/state/calls" | grep -q .; then
    echo "ok   no restore after a lineage mismatch and no successor after an ambiguous CAS"; else echo "FAIL no restore after a lineage mismatch and no successor after an ambiguous CAS"; fails=$((fails + 1)); fi
fi
echo "$fails failed"
((fails == 0))
