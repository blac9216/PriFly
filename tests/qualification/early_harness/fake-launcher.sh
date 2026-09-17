#!/usr/bin/env bash
# Local fake launcher for test-harness.sh: no harness, provider, network, engine or R2.
# FAKE_MODE: ok | stop-only | stop-only-slow | engine | herdr | other-workspace | stale |
# untyped | no-detached | garbage | stop-fails-once | signal-term | signal-int | signal-hup |
# signal-twice | signal-group | signal-group-twice; a mode named like a probe target leaks
# that target. Access probes run in a private user+mount namespace that hides the target
# unless the mode leaks it; if unshare or mount fails the probe exits non-zero,
# never "denied". Writers are real local processes (the "docker" one is a labelled
# stand-in, no engine); their pids go to $FAKE_STATE/<run>.pids so the test kills exactly
# what it started. stop-only stops only the loop writer; -slow writes every 20s, so the
# warm-up times out; signal-sig sends SIG to the runner once the writers run; signal-twice
# sends TERM there, then its stop sends INT and HUP to the runner (only while that pid is
# still the runner) and takes 3s before stopping. signal-group[-twice] sends TERM there, then
# its stop sends INT once [twice] to its own process group, the runner's (refused unless the
# runner leads that group, so the suite is never hit), 1.5s apart. Every call appends its pid to
# $FAKE_STATE/launchers so the test can find a launcher left behind.
# shellcheck disable=SC2016  # the sh -c bodies expand inside the child shell
set -euo pipefail
st="$FAKE_STATE" mode="$FAKE_MODE" verb="$1"
echo "$verb" >>"$st/calls"; echo $$ >>"$st/launchers"
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
    sig="${mode#signal-}"; [[ "$sig" == twice || "$sig" == group* ]] && sig=term
    if [[ "$mode" == signal-* ]]; then echo "$PPID" >"$st/runner"; kill -"${sig^^}" "$PPID"; fi ;;
  stop|inventory)
    [[ "$mode$verb" == stop-fails-oncestop && ! -e "$st/stop-failed" ]] && { : >"$st/stop-failed"; exit 7; }
    if [[ "$mode$verb" == signal-twicestop ]]; then
      for sig in INT HUP; do
        grep -qs harness "/proc/$(cat "$st/runner")/cmdline" && kill -"$sig" "$(cat "$st/runner")"
        for _ in $(seq 15); do sleep 0.1; done
      done
    fi
    if [[ "$mode$verb" == signal-group*stop ]]; then
      [[ "$(ps -o pgid= -p "$(cat "$st/runner")" | tr -d ' ')" == "$(cat "$st/runner")" ]] || exit 9
      for _ in $([[ "$mode" == *twice ]] && echo 1 2 || echo 1); do kill -INT 0; for _ in $(seq 15); do sleep 0.1; done; done
    fi
    mapfile -t pids <"$st/$2.pids"
    [[ "$mode" == stop-only* ]] && pids=("${pids[0]}")
    if [[ "$verb" == stop ]]; then
      kill "${pids[@]}" 2>/dev/null || true
      for _ in $(seq 20); do alive=0; for p in "${pids[@]}"; do [[ -d /proc/$p ]] && alive=1; done; ((alive)) || break; sleep 0.05; done
    else
      n=0; for p in "${pids[@]}"; do [[ -d /proc/$p ]] && n=$((n + 1)); done; echo "$n"
    fi ;;
esac
