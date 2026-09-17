#!/usr/bin/env bash
# Local fake launcher for test-harness.sh: no harness, provider, network, engine or R2.
# FAKE_MODE: ok | stop-only | stop-only-slow | engine | herdr | other-workspace | stale |
# untyped | no-detached | garbage | stop-fails-once | signal; a mode named like a probe
# target leaks that target. Access probes run in a private user+mount namespace that hides
# the target unless the mode leaks it; if unshare or mount fails the probe exits non-zero,
# never "denied". Writers are real local processes (the "docker" one is a labelled
# stand-in, no engine); their pids go to $FAKE_STATE/<run>.pids so the test kills exactly
# what it started. stop-only stops only the loop writer; -slow writes every 20s, so the
# warm-up times out; signal sends TERM to the runner once the writers run.
# shellcheck disable=SC2016  # the sh -c bodies expand inside the child shell
set -euo pipefail
st="$FAKE_STATE" mode="$FAKE_MODE" verb="$1"
echo "$verb" >>"$st/calls"
case "$verb" in
  launch) echo "$5" >"$st/$4.ws" ;;
  probe)
    if [[ "$mode" == "$3" ]]; then
      test -e "$4" && echo allowed || echo denied
    else
      unshare -rm sh -c 'mount -t tmpfs none "$(dirname "$1")" || exit 90; test -e "$1" && echo allowed || echo denied' _ "$4"
    fi ;;
  result)
    run="$2" status=fixed
    [[ "$mode" == stale ]] && run=00000000000000ff
    [[ "$mode" == untyped ]] && status='done'
    printf '{"run":"%s","schema":"prifly/qualification/early-result/v1","status":"%s","t":%s}\n' "$run" "$status" "$(($(date +%s%N) / 1000000))" ;;
  writers)
    ws="$(cat "$st/$2.ws")" gap=0.1; [[ "$mode" == *slow ]] && gap=20
    [[ "$mode" == garbage ]] && echo "loop 12x" >>"$ws/sentinel"
    for w in loop detached docker; do
      [[ "$mode" == no-detached && "$w" == detached ]] && continue
      launch=(); [[ "$w" == loop ]] || launch=(setsid)
      "${launch[@]}" sh -c 'while :; do echo "$1 $(($(date +%s%N) / 1000000))" >>"$2/sentinel"; sleep "$3"; done' _ "$w" "$ws" "$gap" </dev/null >/dev/null 2>&1 &
      echo $! >>"$st/$2.pids"
    done
    if [[ "$mode" == signal ]]; then kill -TERM "$PPID"; fi ;;
  stop|inventory)
    [[ "$mode$verb" == stop-fails-oncestop && ! -e "$st/stop-failed" ]] && { : >"$st/stop-failed"; exit 7; }
    mapfile -t pids <"$st/$2.pids"
    [[ "$mode" == stop-only* ]] && pids=("${pids[0]}")
    if [[ "$verb" == stop ]]; then
      kill "${pids[@]}" 2>/dev/null || true
      for _ in $(seq 20); do alive=0; for p in "${pids[@]}"; do [[ -d /proc/$p ]] && alive=1; done; ((alive)) || break; sleep 0.05; done
    else
      n=0; for p in "${pids[@]}"; do [[ -d /proc/$p ]] && n=$((n + 1)); done; echo "$n"
    fi ;;
esac
