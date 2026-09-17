#!/usr/bin/env bash
# Local proof for harness.sh with the fake launcher and a placeholder manifest; no harness,
# provider, credential, network or engine is used. Every trace the runner completes is
# judged by result.go from the same tree (exec'd by the runner), so an exit 1 case also
# proves the runner wrote result.go's grammar (a grammar break is exit 2). Each case asserts
# its exit code AND that one output line equals the wanted line exactly (grep -xF). Before
# the next case starts, the previous one's writers left by design are killed and every
# process still carrying that case's FAKE_STATE is counted, which must be none.
# HARNESS / FAKE may point at copies so mutants run without touching this tree; KEEP=1 keeps
# the work directory (writers are still killed). Paths: preflight's secret heuristic
# rejects a 32+ character run mixing case and digits in manifest paths (#240), so the work
# directory is lowercase hex under TMPDIR and TMPDIR itself must hold no upper case. The
# --observe-ms and --step-deadline-ms refusals run under en_US.UTF-8, where a bracket range
# matches non-ASCII digits; a control check fails the suite if that locale is missing, so
# they cannot pass vacuously.
# Runs get --step-deadline-ms 10000 (PROBE_DL overrides; "missing" drops the flag). A hung
# VERB case (probe, result, writers, stop, inventory) gets D = 1000 and a fake call whose
# child ignores TERM and would outlive 2D by 18s, plus a sleep outside the call's group
# holding its stdout. Each hung call must end within 2D + 1000ms (the runner's 1s group wait
# and its own work), timed from the call's start to the next call's start or the runner's
# exit (written to <case>/steps), and no process may carry the case's FAKE_STATE when the
# runner exits (counted into <case>/left). The suite passes with uutils or GNU timeout first
# on PATH.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS="${HARNESS:-$HERE/../../../scripts/qualification/early/harness.sh}" FAKE="${FAKE:-$HERE/fake-launcher.sh}"
work="${TMPDIR:-/tmp}/prifly-early-harness-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
[[ "$work" != *[A-Z]* ]] || { echo "FAIL: $work holds upper case, which preflight refuses (#240); set TMPDIR"; exit 1; }
mkdir -m 700 "$work"
# shellcheck disable=SC2086  # $1 and $2 are glob patterns
reap() {  # count, then kill (a writer with its process group), still-live pids recorded in state files $2 whose cmdline holds $3
  cat "$work"/$1/state/$2 2>/dev/null | while read -r p; do grep -qs "$3" "/proc/$p/cmdline" && { kill -- "-$p" || kill "$p"; } 2>/dev/null && echo "$p"; done | wc -l
}
left() {  # processes still carrying case $1's FAKE_STATE, after at most 1s for a killed writer's last sleep 0.1
  local n; for _ in $(seq 10); do n="$(grep -lxzsF "FAKE_STATE=$work/$1/state" /proc/[0-9]*/environ | wc -l)"; ((n)) || break; sleep 0.1; done; echo "$n"
}
prev=""
settle() {  # the previous case left no process once its by-design survivors are killed
  [[ -z "$prev" ]] || check "$prev left no process" 0 "$(reap "$prev" '*.pids' sentinel >/dev/null; left "$prev")" "" /dev/null
  prev="${1:-}"
}
cleanup() {  # kill only writer and launcher pids this test's fake launcher recorded, if still ours
  set +e
  reap '*' launchers fake-launcher >/dev/null; reap '*' '*.pids' sentinel >/dev/null
  if [[ -n "${KEEP:-}" ]]; then echo "kept: $work"; else rm -rf -- "$work"; fi
}
trap cleanup EXIT
fails=0
mkdir "$work/stub" && printf '#!/bin/sh\nexit 1\n' >"$work/stub/unshare" && chmod +x "$work/stub/unshare"
check() {  # name, want exit, got exit, want line ("" skips the line), output file
  if [[ "$3" == "$2" ]] && { [[ -z "$4" ]] || grep -qxF -- "$4" "$5"; }; then echo "ok   $1"; else
    echo "FAIL $1: exit $3 (want $2), want line: $4"; sed 's/^/     | /' "$5"; fails=$((fails + 1)); fi
}
probe() {  # name, mode, observe-ms, want exit, want line [, python on manifest m in dir d, extra args]
  # the runner leads its own session and process group, so a group signal never reaches this suite
  local d="$work/${1// /-}" dl=(--step-deadline-ms "${PROBE_DL-10000}") t; settle "${1// /-}"; mkdir -p "$d/state" "$d/control"; : >"$d/control/engine.sock"; : >"$d/control/herdr.sock"
  python3 - "$HERE/manifest.json" "$d" "${6:-pass}" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])); d = sys.argv[2]
m['isolated_host']['engine_socket_path'] = d + '/control/engine.sock'; m['isolated_host']['workspace_root_path'] = d
exec(sys.argv[3])
json.dump(m, open(d + '/manifest.json', 'w'))
PY
  [[ "${PROBE_DL-}" != missing ]] || dl=(); t="$(date +%s%N)"
  set +e; PATH="${PROBE_PATH:-$PATH}" LC_ALL="${PROBE_LC:-${LC_ALL:-}}" FAKE_MODE="$2" FAKE_STATE="$d/state" setsid -w bash "$HARNESS" --manifest "$d/manifest.json" \
    --launcher "$FAKE" --herdr-socket "$d/control/herdr.sock" --work "$d" --observe-ms "$3" "${dl[@]}" "${@:7}" >"$d/out" 2>&1; rc=$?; set -e
  echo $((($(date +%s%N) - t) / 1000000)) >"$d/ms"; echo $(($(date +%s%N) / 1000000)) >"$d/end"
  check "$1" "$4" "$rc" "$5" "$d/out"
}
probe "success trace" ok 300 0 "VERDICT: expected observations for both candidates (local trace only; not a live PASS)"
check "success trace recorded the step deadline before any launcher call" '{"ev":"trace","schema":"prifly/qualification/early-trace/v2","observe_ms":300,"step_deadline_ms":10000}' "$(head -n1 "$work/success-trace/trace.jsonl")" "" /dev/null
t="engine $work/success-trace/control/engine.sock|herdr $work/success-trace/control/herdr.sock|other-workspace $work/success-trace/other-workspace"
check "success trace probed each target at its own path" "$t|$t" "$(paste -sd'|' "$work/success-trace/state/probes")" "" /dev/null
probe "stop-only writers survive" stop-only 300 1 "VERDICT: rejected"
check "stop-only detached and docker writers wrote after stop" 4 "$(grep -Ec '^REJECT DETACHED-WRITER (codex-cli|claude-code): (detached|docker) writer wrote [0-9]+ sentinel\(s\) after stop$' "$work/stop-only-writers-survive/out")" "" /dev/null
probe "engine socket reachable" engine 300 1 "REJECT CONTROL-ACCESS codex-cli: engine was reachable from the attempt"
probe "herdr socket reachable" herdr 300 1 "REJECT CONTROL-ACCESS claude-code: herdr was reachable from the attempt"
probe "other workspace reachable" other-workspace 300 1 "REJECT OTHER-WORKSPACE claude-code: other-workspace was reachable from the attempt"
probe "result from another run" stale 300 1 "REJECT STALE-RESULT -: result for run 00000000000000ff before or without its launch"
probe "untyped result" untyped 300 1 "REJECT UNTYPED-RESULT claude-code: result is not the fixed typed result"
probe "detached writer never started" no-detached 300 1 "REJECT FALSE-SUCCESS codex-cli: detached writer never observed before stop"
probe "slow writer" stop-only-slow 10 1 "REJECT FALSE-SUCCESS codex-cli: detached writer seen once before stop; its cadence is unknown"
check "slow writer warm-up timeout is visible" 2 "$(grep -c '^WARM-UP TIMEOUT: run [0-9a-f]\{16\}: a writer was seen fewer than twice in 5s$' "$work/slow-writer/out")" "" /dev/null
probe "unparseable sentinel line" garbage 300 21 "ABORTED: unparseable sentinel line(s) written by the attempt"
probe "mid-run stop failure" stop-fails-once 300 21 "ABORTED: exit 7 after launch began; no verdict"
check "mid-run stop failure left no writer" 0 "$(reap mid-run-stop-failure '*.pids' sentinel)" "" /dev/null
for sig in term int hup twice group group-twice; do  # lower case: upper case in the work path trips #240
  d="signal-$sig-during-a-run"
  probe "signal $sig during a run" "signal-$sig" 300 21 "ABORTED: exit 143 after launch began; no verdict"
  check "signal $sig stopped and inventoried the open run" "writers stop inventory|1" "$(tail -n3 "$work/$d/state/calls" | paste -sd' ')|$(grep -cxF 'ABORTED: open run stop exit 0, live 0' "$work/$d/out")" "" /dev/null
  check "signal $sig left no writer, launcher or other process" "0 0 0" "$(reap "$d" '*.pids' sentinel) $(reap "$d" launchers fake-launcher) $(left "$d")" "" /dev/null
done
for c in "probe|probe stop inventory|0" "result|result stop inventory|0" "writers|writers stop inventory|0" "stop|stop stop inventory|137" "inventory|inventory stop inventory|0"; do
  IFS='|' read -r v calls sx <<<"$c"; d="$work/hung-$v-step"  # the run's call hangs, then (stop, inventory) the cleanup's too
  PROBE_DL=1000 probe "hung $v step" "hang-$v" 300 21 "ABORTED: exit 137 after launch began; no verdict"
  { grep -lxzsF "FAKE_STATE=$d/state" /proc/[0-9]*/environ || :; } | wc -l >"$d/left"
  check "hung $v step left no process at runner exit" 0 "$(cat "$d/left")" "" /dev/null
  awk -v v="$v" -v end="$(cat "$d/end")" '{n[NR] = $1; t[NR] = $2} END {t[NR + 1] = end; for (i = 1; i <= NR; i++) if (n[i] == v) print v, t[i + 1] - t[i]}' "$d/state/t" >"$d/steps"
  check "hung $v step ended within its deadlines after a stop and an inventory" "$calls|1|in bound" "$(tail -n3 "$d/state/calls" | paste -sd' ')|$(grep -cxF "ABORTED: open run stop exit $sx, live 0" "$d/out")|$(awk '$2 > 3000 {bad = 1} END {print bad ? "over 3000ms" : NR ? "in bound" : "no call"}' "$d/steps")" "" /dev/null
done
PROBE_PATH="$work/stub:$PATH" probe "no unshare" ok 300 21 "ABORTED: exit 1 after launch began; no verdict"
probe "held manifest" ok 300 20 "REFUSED: preflight exit 10; no probe step ran" "del m['host_reservation_ref']"
probe "work outside the root" ok 300 20 "REFUSED: --work resolves outside isolated_host.workspace_root_path; no probe step ran" "m['isolated_host']['workspace_root_path'] = '/elsewhere'"
probe "work sharing a prefix with the root" ok 300 20 "REFUSED: --work resolves outside isolated_host.workspace_root_path; no probe step ran" "m['isolated_host']['workspace_root_path'] = d[:-3]"
probe "work escaping the root through dotdot" ok 300 20 "REFUSED: --work resolves outside isolated_host.workspace_root_path; no probe step ran" "m['isolated_host']['workspace_root_path'] = d + '/root'" --work "$work/work-escaping-the-root-through-dotdot/root/../escape"
mkdir -p "$work/work-escaping-the-root-through-a-symlink/root" && ln -s "$work/stub" "$work/work-escaping-the-root-through-a-symlink/root/link"
probe "work escaping the root through a symlink" ok 300 20 "REFUSED: --work resolves outside isolated_host.workspace_root_path; no probe step ran" "m['isolated_host']['workspace_root_path'] = d + '/root'" --work "$work/work-escaping-the-root-through-a-symlink/root/link"
UTF8=en_US.UTF-8 ARABIC300=$'\xd9\xa3\xd9\xa0\xd9\xa0' ARABIC1000=$'\xd9\xa1\xd9\xa0\xd9\xa0\xd9\xa0'
check "locale control: $UTF8 bracket range matches non-ASCII digits" 0 "$(LC_ALL=$UTF8 bash -c '[[ $1 =~ ^[1-9][0-9]{2}$ && $2 =~ ^[1-9][0-9]{0,7}$ ]]' _ "$ARABIC300" "$ARABIC1000" 2>&1; echo $?)" "" /dev/null
for dl in missing "" 0 01000 1e3 100000000 "$ARABIC1000"; do  # names hold no quote or non-ASCII digit, so preflight would pass
  PROBE_LC=$UTF8 PROBE_DL=$dl probe "step-deadline-ms ${dl/#$ARABIC1000/arabic-indic-1000}" ok 300 20 "REFUSED: --step-deadline-ms must be 1..99999999 without a leading zero; no probe step ran"
done
for c in 1:0.001 1050:1.050 99999999:99999.999; do  # accepted at both ends; every call gets D in seconds with all three decimals
  PROBE_DL=${c%:*} probe "dry-run step-deadline-ms ${c%:*}" ok 300 0 "" "pass" --dry-run
  check "dry-run step-deadline-ms ${c%:*} gives timeout ${c#*:}s" 16 "$(grep -cF " [timeout -k ${c#*:} ${c#*:}]" "$work/dry-run-step-deadline-ms-${c%:*}/out")" "" /dev/null
done
for ms in 0300 3e2 1000000 "" "$ARABIC300"; do
  PROBE_LC=$UTF8 probe "observe-ms '$ms'" ok "$ms" 20 "REFUSED: --observe-ms must be 0..999999 without a leading zero; no probe step ran"
  check "observe-ms '$ms' refused before preflight" 0 "$(grep -c VERDICT "$work/observe-ms-'$ms'/out")" "" /dev/null
done
check "refusals never called the launcher" 0 "$(find "$work"/held-manifest "$work"/work-* "$work"/observe-ms-* "$work"/step-deadline-ms-* -name calls | wc -l)" "" /dev/null
probe "dry-run procedure" ok 300 0 "STEP observe sentinel for 300ms after stop" "pass" --dry-run
check "dry-run lists both candidates without calling the launcher" "0 2" "$(find "$work/dry-run-procedure" -name calls | wc -l) $(grep -c '^STEP launch \(codex-cli 0.154.0\|claude-code 2.1.268\) ' "$work/dry-run-procedure/out")" "" /dev/null
settle
echo "failures: $fails"
((fails == 0))
