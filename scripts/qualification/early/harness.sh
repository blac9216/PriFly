#!/usr/bin/env bash
# Bounded E1/E4 early probe runner for both exact harness candidates (Q12). It refuses to
# run any step unless its inputs are valid and preflight.sh exits 0 on the operator-held
# manifest, then drives a launcher executable through a fixed step list per subscription
# tuple, writes a trace in result.go's grammar and hands it to result.go (built with the
# pinned Go toolchain). A local run with a fake launcher is never a live PASS.
# Covers, per candidate: bounded launch at the exact pinned version into its own attempt
# workspace; E1 denial of raw control (outer engine socket, private HerdR socket) and of
# another workspace; one typed fixed result inside launch..stop; E4 stop with loop,
# detached-child and docker-mounted writers each seen twice before stop, absent for the
# declared window after it (at least their cadence), and an empty inventory. Not covered,
# left to R01-R05/Q03, and not certified by a Q12 PASS: E1 terminal-to-process mapping and
# native identity; E4 HerdR disconnect/restart with observer attach, late-result rejection,
# no native resume, and unresolved cleanup holding the next lease.
# Usage: harness.sh --manifest FILE --launcher EXE --herdr-socket PATH --work DIR --observe-ms N
#        --step-deadline-ms D [--dry-run]
# Launcher contract (argv; stdout's last line as noted; a non-zero exit aborts the run):
#   launch HARNESS VERSION RUN WORKSPACE  start one interactive session in its own attempt
#   probe RUN engine|herdr|other-workspace PATH  try that access from inside the attempt; print denied|allowed
#   result RUN      print the typed result the attempt submitted, one JSON object: run, schema, status, t
#   writers RUN     start loop, detached-child and docker-mounted writers appending "<writer> <epoch-ms>"
#                   lines to WORKSPACE/sentinel
#   stop RUN        cancel the attempt; return only after the launcher's own stop verification
#   inventory RUN   print the count of attempt-owned processes and containers still live
# Every call, the abort cleanup's stop and inventory included, runs as timeout -k D D (TERM at
# D ms, KILL D ms later), started in the background as the leader of its own session and
# process group (setsid), stdin from /dev/null, stdout to a file that the runner reads and
# echoes to stderr once the call ends. The runner waits on it with the wait builtin, so an
# INT, TERM or HUP reaches the runner's trap at once, not when the call returns. A call ends
# only with its process group empty, whichever timeout is on PATH (uutils timeout signals only
# the launcher's pid, GNU timeout the group, and neither waits for the group): on expiry
# (timeout exit 124 or 137), and when a signal ends the run during the call, the runner sends
# KILL to the whole group (to the call's pid while it does not lead a group yet) and waits for
# the group to empty before anything else, the abort cleanup's stop included. A call that
# returns on its own gets the same wait for its group to empty; one that still holds a process
# is reported (ABORTED: VERB call returned leaving a process in its process group PGID), gets
# KILL and the second wait, and fails with exit 21. Each wait checks the group every 50ms and
# gives up at the first check at or after 1000ms, so it lasts at most 1000ms plus one check
# (sleep 0.05); a group that is still not empty then, as when a zombie whose parent sits outside
# the group keeps it, is reported (ABORTED: VERB call's process group PGID still had a process
# Nms after KILL) and the run aborts. One call so ends within 2D plus one wait (two for a call
# that returned leaving a process), and the abort line's live count, the last line of the
# cleanup inventory, is taken only after the interrupted call's group is gone.
# The group is all the runner sees: a process that leaves it, by setsid or by moving into a new
# process group of the same session (setpgid, as set -m or a nested timeout does), is neither
# tracked nor killed by the runner. It is the attempt's, for stop and inventory to find, and it
# cannot extend the call, since nothing waits on its output. This runner is not a containment
# mechanism: the real launcher contract (#221) puts writers behind the container boundary.
# A SIGKILL to the runner runs no cleanup at all: the writers and an in-flight call's group can
# survive, as they could before step deadlines existed. Recover by calling the launcher's stop
# RUN, then inventory RUN, for the last run launched in the trace (its last launch line), and
# only once inventory prints 0 start a fresh run.
# D has no default; the trace header records it before the first call, and each STEP line shows
# timeout's arguments. A group signal to the runner (a terminal Ctrl-C or hangup) never reaches
# a launcher call, which leads its own session.
# Raw control targets are the manifest's outer engine socket and the private HerdR server
# socket (--herdr-socket; the manifest does not name it); the other workspace is a sibling
# directory this runner creates under --work, whose resolved path must lie inside the
# manifest's workspace root. Stop is stamped when the stop step returns; a sentinel stamped
# later is a writer that outlived stop. A warm-up that does not see every writer twice
# within 5s prints WARM-UP TIMEOUT and continues; result.go then rejects the unseen cadence.
# Exit: result.go's code (0, 1, 2); 20 refused before any step (usage, --observe-ms outside
# 0..999999 or with a leading zero, --step-deadline-ms missing, outside 1..99999999 or with a
# leading zero, preflight non-zero, --work outside the root); 21 aborted with no verdict
# after launch began: a step failed or passed its deadline (exit 124, or 137 once killed), a
# call that returned left a process in its group (exit 21), an attempt wrote an unparseable
# sentinel line, or INT/TERM/HUP arrived (exit 143). On 21 an open run
# gets stop and inventory first; the cleanup ignores further INT/TERM/HUP, so a repeated
# Ctrl-C cannot cut it short. Both numbers' digits are ASCII only, whatever the locale.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="" LAUNCHER="" HERDR="" WORK="" OBSERVE="" DEADLINE="" DRY=0
refuse() { echo "REFUSED: $*; no probe step ran"; exit 20; }
while (($#)); do
  case "$1" in
    --manifest|--launcher|--herdr-socket|--work|--observe-ms|--step-deadline-ms)
      [[ $# -ge 2 ]] || refuse "$1 requires a value"
      case "$1" in --manifest) MANIFEST="$2" ;; --launcher) LAUNCHER="$2" ;; --herdr-socket) HERDR="$2" ;; --work) WORK="$2" ;; --observe-ms) OBSERVE="$2" ;; *) DEADLINE="$2" ;; esac
      shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) refuse "unknown argument $1" ;;
  esac
done
[[ -n "$MANIFEST" && -n "$LAUNCHER" && -n "$HERDR" && -n "$WORK" ]] || refuse "--manifest, --launcher, --herdr-socket and --work are required"
[[ "$OBSERVE" =~ ^(0|[123456789][0123456789]{0,5})$ ]] || refuse "--observe-ms must be 0..999999 without a leading zero"
[[ "$DEADLINE" =~ ^[123456789][0123456789]{0,7}$ ]] || refuse "--step-deadline-ms must be 1..99999999 without a leading zero"
if bash "$SCRIPT_DIR/preflight.sh" --manifest "$MANIFEST"; then :; else refuse "preflight exit $?"; fi

now() { echo $(($(date +%s%N) / 1000000)); }
D="$((DEADLINE / 1000)).$(printf %03d $((DEADLINE % 1000)))"
CALL="" VERB="" HOLD=0 SIG=0
gone() {  # waits for the in-flight call's process group to empty: 0 once it is, 1 at the first check at or after 1000ms (W holds the ms waited)
  local t=$((${EPOCHREALTIME//[!0-9]/} / 1000))
  while kill -0 -- "-$CALL" 2>/dev/null; do
    W=$((${EPOCHREALTIME//[!0-9]/} / 1000 - t)); ((W < 1000)) || return 1; sleep 0.05
  done
}
reap() {  # KILL the in-flight call's process group, wait for it to empty, and report a group that does not
  kill -KILL -- "-$CALL" 2>/dev/null || :; gone || echo "ABORTED: $VERB call's process group $CALL still had a process ${W}ms after KILL"
}
step() {  # one launcher call, see the header; its stdout goes to $OUT, and it returns the call's exit
  echo "STEP $* [timeout -k $D $D]" >&2; : >"$OUT"; ((DRY)) && return
  local rc=0; VERB="$1"
  HOLD=1; setsid sh -c 'exec timeout -k "$@"' _ "$D" "$D" "$LAUNCHER" "$@" >"$OUT" </dev/null & CALL=$!
  # shellcheck disable=SC2034  # HOLD is read by the INT/TERM/HUP trap: a signal that arrives before CALL is set acts here, with the call known to finish
  HOLD=0; ((SIG == 0)) || exit "$SIG"
  wait "$CALL" 2>/dev/null || rc=$?  # 2>/dev/null: bash would report a call that GNU timeout ends with KILL
  if ((rc == 124 || rc == 137)); then reap
  elif ! gone; then echo "ABORTED: $1 call returned leaving a process in its process group $CALL"; reap; rc=21; fi
  CALL=""; cat "$OUT" >&2; return "$rc"
}
mapfile -t TUPLES < <(python3 -c 'import json,sys
m = json.load(open(sys.argv[1]))
print(m["isolated_host"]["engine_socket_path"]); print(m["isolated_host"]["workspace_root_path"])
for t in m["subscription_tuples"]: print(t["harness"], t["harness_version"])' "$MANIFEST")
ENGINE="${TUPLES[0]}" ROOT="${TUPLES[1]%/}" WORK="$(realpath -m "$WORK")"
[[ "$WORK/" == "$ROOT"/* ]] || refuse "--work resolves outside isolated_host.workspace_root_path"
mkdir -p "$WORK/other-workspace"
OPEN="" OUT="$WORK/.step.out"
finish() {  # every exit after this point except exec and 0: end an in-flight call, then stop and inventory the open run
  local rc=$? s; trap '' INT TERM HUP; trap - EXIT; SIG=0; ((rc == 0)) && exit 0
  set +e
  if [[ -n "$CALL" ]]; then  # a signal arrived during a call: KILL it (by pid until it leads its group) and reap it before any cleanup call
    kill -KILL -- "-$CALL" 2>/dev/null || kill -KILL "$CALL" 2>/dev/null; wait "$CALL" 2>/dev/null; reap; CALL=""
  fi
  if [[ -n "$OPEN" ]] && ! ((DRY)); then
    step stop "$OPEN"; s=$?; step inventory "$OPEN"; echo "ABORTED: open run stop exit $s, live $(tail -n1 "$OUT")"
  fi
  echo "ABORTED: exit $rc after launch began; no verdict"; exit 21
}
trap finish EXIT; trap '((HOLD)) && SIG=143 || exit 143' INT TERM HUP
TRACE="$WORK/trace.jsonl"
printf '{"ev":"trace","schema":"prifly/qualification/early-trace/v2","observe_ms":%s,"step_deadline_ms":%s}\n' "$OBSERVE" "$DEADLINE" >"$TRACE"
for tuple in "${TUPLES[@]:2}"; do
  read -r harness version <<<"$tuple"
  run="$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  ws="$WORK/$harness-$run"
  mkdir -p "$ws"; : >"$ws/sentinel"; OPEN="$run"
  printf '{"ev":"launch","harness":"%s","version":"%s","run":"%s","t":%s}\n' "$harness" "$version" "$run" "$(now)" >>"$TRACE"
  step launch "$harness" "$version" "$run" "$ws"
  for target in "engine $ENGINE" "herdr $HERDR" "other-workspace $WORK/other-workspace"; do
    read -r name path <<<"$target"
    step probe "$run" "$name" "$path"
    ((DRY)) || jq -cn --arg r "$run" --arg n "$name" --arg o "$(tail -n1 "$OUT")" '{ev:"access",run:$r,target:$n,outcome:$o}' >>"$TRACE"
  done
  step result "$run"; res="$(tail -n1 "$OUT")"  # passed through verbatim so result.go judges its exact keys
  ((DRY)) || printf '{"ev":"result",%s\n' "${res#\{}" >>"$TRACE"
  step writers "$run"
  echo "STEP warm-up: wait for two sentinels per writer (at most 5s)" >&2
  for i in $(seq 50); do
    ((DRY)) || [[ "$(awk '{n[$1]++} END {print (n["loop"] >= 2 && n["detached"] >= 2 && n["docker"] >= 2)}' "$ws/sentinel")" == 1 ]] && break
    ((i < 50)) || echo "WARM-UP TIMEOUT: run $run: a writer was seen fewer than twice in 5s" >&2
    sleep 0.1
  done
  step stop "$run"
  printf '{"ev":"stop","run":"%s","t":%s}\n' "$run" "$(now)" >>"$TRACE"
  echo "STEP observe sentinel for ${OBSERVE}ms after stop" >&2
  ((DRY)) || sleep "$(awk -v ms="$OBSERVE" 'BEGIN {print ms / 1000}')"
  printf '{"ev":"observed","run":"%s","t":%s}\n' "$run" "$(now)" >>"$TRACE"
  step inventory "$run"; live="$(tail -n1 "$OUT")"
  ((DRY)) || jq -cn --arg r "$run" --argjson l "$live" '{ev:"inventory",run:$r,live:$l}' >>"$TRACE"
  OPEN=""
  ((DRY)) || awk -v r="$run" '!/^[a-z]+ (0|[1-9][0-9]*)$/ {bad++; next} {printf "{\"ev\":\"sentinel\",\"run\":\"%s\",\"writer\":\"%s\",\"t\":%s}\n", r, $1, $2} END {exit bad > 0}' "$ws/sentinel" >>"$TRACE" ||
    { echo "ABORTED: unparseable sentinel line(s) written by the attempt"; exit 21; }
done
((DRY)) && exit 0
echo "STEP evaluate $TRACE" >&2
go build -o "$WORK/result" "$SCRIPT_DIR/result.go"
exec "$WORK/result" "$TRACE"
