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
# D ms, KILL D ms later) in its own session and process group, stdin from /dev/null, stdout
# to a file the runner prints once the call returns. On expiry (timeout exit 124 or 137) the
# runner itself sends KILL to that whole group and waits at most 1s for it to empty, since
# uutils timeout signals only the launcher's pid and GNU timeout the group. So one call ends
# within 2D plus that 1s wait, whichever timeout is on PATH, and leaves no process in its
# group; a descendant that leaves the group (setsid) is the attempt's, for stop and inventory
# to find, and cannot extend the call, since nothing waits on its output. D has no default;
# the trace header records it before the first call, and each STEP line shows timeout's
# arguments. A group signal to the runner (a terminal Ctrl-C or hangup) never reaches the
# launcher; the runner acts on it once the call returns.
# Raw control targets are the manifest's outer engine socket and the private HerdR server
# socket (--herdr-socket; the manifest does not name it); the other workspace is a sibling
# directory this runner creates under --work, whose resolved path must lie inside the
# manifest's workspace root. Stop is stamped when the stop step returns; a sentinel stamped
# later is a writer that outlived stop. A warm-up that does not see every writer twice
# within 5s prints WARM-UP TIMEOUT and continues; result.go then rejects the unseen cadence.
# Exit: result.go's code (0, 1, 2); 20 refused before any step (usage, --observe-ms outside
# 0..999999 or with a leading zero, --step-deadline-ms missing, outside 1..99999999 or with a
# leading zero, preflight non-zero, --work outside the root); 21 aborted with no verdict
# after launch began: a step failed or passed its deadline (exit 124, or 137 once killed),
# an attempt wrote an unparseable sentinel line, or INT/TERM/HUP arrived. On 21 an open run
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
step() {  # one launcher call, see the header; prints its stdout and returns its exit
  echo "STEP $* [timeout -k $D $D]" >&2; ((DRY)) && return
  local out rc=0; out="$(mktemp "$WORK/.step.XXXXXX")"
  # shellcheck disable=SC2016  # $$ is the new session's leader, the call's process group id
  setsid -w sh -c 'echo $$ >"$0"; exec timeout -k "$@"' "$out.pgid" "$D" "$D" "$LAUNCHER" "$@" >"$out" </dev/null || rc=$?
  if ((rc == 124 || rc == 137)); then
    kill -KILL -- "-$(cat "$out.pgid")" 2>/dev/null || :
    for _ in $(seq 20); do kill -0 -- "-$(cat "$out.pgid")" 2>/dev/null || break; sleep 0.05; done
  fi
  cat "$out"; rm -f -- "$out" "$out.pgid"; return "$rc"
}
mapfile -t TUPLES < <(python3 -c 'import json,sys
m = json.load(open(sys.argv[1]))
print(m["isolated_host"]["engine_socket_path"]); print(m["isolated_host"]["workspace_root_path"])
for t in m["subscription_tuples"]: print(t["harness"], t["harness_version"])' "$MANIFEST")
ENGINE="${TUPLES[0]}" ROOT="${TUPLES[1]%/}" WORK="$(realpath -m "$WORK")"
[[ "$WORK/" == "$ROOT"/* ]] || refuse "--work resolves outside isolated_host.workspace_root_path"
mkdir -p "$WORK/other-workspace"
OPEN=""
finish() {  # every exit after this point except exec and 0: stop and inventory the open run
  local rc=$?; trap '' INT TERM HUP; trap - EXIT; ((rc == 0)) && exit 0
  set +e; [[ -z "$OPEN" ]] || ((DRY)) || echo "ABORTED: open run stop exit $(step stop "$OPEN" >&2; echo $?), live $(step inventory "$OPEN" | tail -n1)"
  echo "ABORTED: exit $rc after launch began; no verdict"; exit 21
}
trap finish EXIT; trap 'exit 143' INT TERM HUP
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
    outcome="$(step probe "$run" "$name" "$path" | tail -n1)"
    ((DRY)) || jq -cn --arg r "$run" --arg n "$name" --arg o "$outcome" '{ev:"access",run:$r,target:$n,outcome:$o}' >>"$TRACE"
  done
  res="$(step result "$run" | tail -n1)"  # passed through verbatim so result.go judges its exact keys
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
  live="$(step inventory "$run" | tail -n1)"
  ((DRY)) || jq -cn --arg r "$run" --argjson l "$live" '{ev:"inventory",run:$r,live:$l}' >>"$TRACE"
  OPEN=""
  ((DRY)) || awk -v r="$run" '!/^[a-z]+ (0|[1-9][0-9]*)$/ {bad++; next} {printf "{\"ev\":\"sentinel\",\"run\":\"%s\",\"writer\":\"%s\",\"t\":%s}\n", r, $1, $2} END {exit bad > 0}' "$ws/sentinel" >>"$TRACE" ||
    { echo "ABORTED: unparseable sentinel line(s) written by the attempt"; exit 21; }
done
((DRY)) && exit 0
echo "STEP evaluate $TRACE" >&2
go build -o "$WORK/result" "$SCRIPT_DIR/result.go"
exec "$WORK/result" "$TRACE"
