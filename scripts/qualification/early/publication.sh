#!/usr/bin/env bash
# Q13 early remote-publication runner: drives an operator probe (the Litestream/R2 client) through the
# fixed P13 schedule in publication.json, writes a trace in fixture.go's grammar and execs fixture.go on it.
# A run with a fake probe is never a live PASS; this script itself contacts nothing remote.
# Usage: publication.sh --manifest FILE --probe EXECUTABLE --ledger FILE --work DIR
# The ledger is the operator-held record {"bytes":N,"requests":N} of use already charged to the shared
# cumulative P12a envelope. It is required as exactly one such document, read before any probe call, and
# rewritten and read back after every debit and settlement, before anything more is sent; a failed write or
# readback aborts, so the file never shows less than may have been sent or than the LEDGER line reports.
# The trace header carries the prior values. Probe contract: argv, then (except declare) the remaining
# reservation BYTES WRITES REQUESTS, which its use must stay within; its last stdout line is one JSON object
# with the fields below and the bytes, writes and requests it used:
#   declare                                     → (no remote use) the most one plan call may use; no writes
#   plan RUN fixture|renewal|KIND PAYLOAD_BYTES → the entry's finite bound: planBytes planWrites planRequests
#   fixture RUN BUCKET_REF PREFIX SEED DIR      → generator seed litestream dbBytes lineage
#   artifact RUN N KIND PAYLOAD_BYTES           → payloadSha256 payloadBytes (upload and read-verify)
#   commit RUN SEQ N (N 0: renewal)             → before after dbBytes
#   sync RUN SEQ → txid lineage | restore RUN SEQ TXID → restoreTxid restoredSeq restoredPayloadSha256 integrity
#   cas RUN SEQ TXID                            → casSeq casTxid
# Grants are P12b control/recovery grants of grant.ms, each with its own control maxima, never refilled. Per
# run: open a grant; send the fixture's plan at t0, the fixture step's ticket; the fixture as one ticket; then
# each command at its submission clock. While the lane is free, before its plan call, P12a and the live grant
# must hold a declared plan call and a maximal ticket for the fixture, and for a command a second such pair for
# the renewal beside it (P12b; the declared plan use must leave a fresh grant that room); a command renews
# first, on that held pair, when its grant lacks the room or ends within thresholds.maxMs. So each entry's one
# plan call falls between the previous ack and its own ticket, charged to the grant live at its send. A renewal
# is a published command (C3); a command n and a renewal before it take sequence n plus the renewals before
# them. If a renewal fails, the command is recorded failed with no ticket, use or clock. Every plan call is
# debited at the declared use before send, and its bound must be within the ticket maxima; no plan or ticket is
# sent after its grant's deadline. Each entry: reserve the whole ticket; artifact; commit; sync, requiring a
# 16-hex TXID and the run's lineage before restore; restore that T, requiring its sequence, T, integrity and
# result; pace the CAS casMinSpacingMs after the last (P4); require the CAS readback of sequence and T; only
# then ack. Each probe call runs under timeout -k 1 stepTimeoutS. A failure charges the whole reservation and
# blocks the lane for the rest of the run, so an ambiguous CAS never admits a successor, and a plan call left
# without a ticket stops the run (its trace cannot pass); blocked commands are recorded failed, never dropped.
# Exit: fixture.go's code; 20 refused before any probe call (usage; ledger missing, malformed or at the
# envelope; clock; preflight non-zero; evaluator build); 21 aborted with no verdict (no write-free plan use, a
# fixture step failed or lacked room, a ledger write, the clock ran backwards, a signal, or any other failure).
# shellcheck disable=SC2015,SC2016  # A && B || C is the fail-closed form here; jq filters expand inside jq
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROC="$HERE/publication.json" STOP=20 NOW=0
halt() { if ((STOP == 20)); then echo "REFUSED: $*; no probe step ran"; else echo "ABORTED: $*; no verdict"; fi; exit "$STOP"; }
[[ $# -eq 8 && "$1 $3 $5 $7" == "--manifest --probe --ledger --work" && -x "$4" ]] ||
  halt "usage: publication.sh --manifest FILE --probe EXECUTABLE --ledger FILE --work DIR"
MANIFEST="$2" PROBE="$4" LEDGER="$6" WORK="$8"
USE='select(type == "object" and all(.bytes, .writes, .requests; type == "number" and . >= 0 and . < 9007199254740992 and . == floor))'
read -r RUNS SEED STEP SPACING MAXMS GMS GB GW GR TB TW TR EB ER < <(jq -r '[.runs, .seed, .stepTimeoutS, .casMinSpacingMs,
  .thresholds.maxMs, .grant.ms, (.control | .bytes, .writes, .requests), (.ticket | .bytes, .writes, .requests), .envelope.bytes, .envelope.requests] | @tsv' "$PROC")
read -r PB PR < <(jq -rs "select(length == 1) | .[0] | select(type == \"object\" and keys == [\"bytes\", \"requests\"]) | .writes = 0 | $USE | \"\(.bytes) \(.requests)\"" "$LEDGER" 2>/dev/null) ||
  halt "--ledger must hold the prior cumulative P12a use as {\"bytes\":N,\"requests\":N}"
((PB < EB && PR < ER)) || halt "prior P12a use of $PB bytes and $PR requests is at the $EB-byte or $ER-request envelope"
now() {  # NOW: epoch ms from date's full-width nanoseconds; another shape, or a clock running backwards, halts
  local v; v="$(date +%s.%N)" || true
  [[ "$v" =~ ^([1-9][0-9]{9})\.([0-9]{3})[0-9]{6}$ ]] && ((${BASH_REMATCH[1]}${BASH_REMATCH[2]} >= NOW)) ||
    halt "clock read '$v' is not seconds.nanoseconds, or ran backwards"
  NOW=$((${BASH_REMATCH[1]}${BASH_REMATCH[2]}))
}
now
if bash "$HERE/preflight.sh" --manifest "$MANIFEST"; then :; else halt "preflight exit $?"; fi
mkdir -p "$WORK" && go build -o "$WORK/fixture" "$HERE/fixture.go" || halt "evaluator build failed"
mapfile -t ARR < <(jq -r '.warmupMs as $w | .burst as $b | range(0; $w + .durationMs; .cadenceMs) as $a
  | $a, (if $a == $w + $b.atMs then range($b.count) | $a else empty end)' "$PROC")
mapfile -t MIX < <(jq -r '.mix[] | "\(.kind) \(.payloadBytes)"' "$PROC")
read -r BUCKET PREFIX < <(jq -r '[.r2.bucket_ref, .r2.prefix] | @tsv' "$MANIFEST")
TRACE="$WORK/trace.jsonl" CALLS=0 UB=0 UR=0 STOP=21
declare -A CLK=()
report() { echo "LEDGER: prior $PB bytes $PR requests; after this invocation $((PB + UB)) bytes $((PR + UR)) requests"; }
finish() { local rc=$?; trap '' INT TERM HUP; trap - EXIT; report; ((rc == 21)) || echo "ABORTED: exit $rc; no verdict"; exit 21; }  # every exit but exec
trap finish EXIT
trap 'halt "signal"' INT TERM HUP
ledger() {  # BYTES REQUESTS: this invocation's charge UB UR once the ledger file holds it and reads back
  local j; j="$(printf '{"bytes":%d,"requests":%d}' $((PB + $1)) $((PR + $2)))"
  { echo "$j" >"$LEDGER.new" && mv "$LEDGER.new" "$LEDGER" && [[ "$(cat "$LEDGER")" == "$j" ]]; } 2>/dev/null || halt "ledger write failed"
  UB=$1 UR=$2
}
charge() { QB=$((QB + $1)) QW=$((QW + $2)) QR=$((QR + $3)); ledger $((UB + $1)) $((UR + $3)); }  # BYTES WRITES REQUESTS: grant and P12a
ms() { printf '%d.%03d' $(($1 / 1000)) $(($1 % 1000)); }
sha() { sha256sum "$1" | cut -d' ' -f1; }
call() {  # KEYS VERB ARGS...: one bounded probe call, its output in its own file; b w r = its use, PICK = KEYS of it
  local keys="$1" f="$WORK/probe.$((++CALLS))" rc=0; shift
  echo "STEP $*" >&2
  timeout -k 1 "$STEP" "$PROBE" "$@" >"$f" || rc=$?
  read -r b w r PICK < <(tail -n1 "$f" | jq -rc --arg k "$keys" "$USE"' | "\(.bytes) \(.writes) \(.requests) \(with_entries(select(.key | IN($k | split(" ")[]))))"' 2>/dev/null) &&
    ((rc == 0)) || { REASON="$1-exit$rc"; ((rc)) || REASON="$1-output"; return 1; }
}
live() { now; ((NOW <= DEADLINE)) || { REASON=grant-expired; return 1; }; }  # NOW is inside the live grant
room() {  # HELD: P12a, then the live grant's control maxima, hold a declared plan call and a maximal ticket, 1 + HELD times
  local k=$((1 + $1))
  ((PB + UB + k * (DB + TB) <= EB && PR + UR + k * (DR + TR) <= ER)) || { REASON=envelope; return 1; }
  ((QB + k * (DB + TB) <= GB && QW + k * TW <= GW && QR + k * (DR + TR) <= GR)) || { REASON=grant-headroom; return 1; }
}
plan() {  # WHAT PAYLOAD_BYTES: sent at PT under grant GI, charged at the declared use; RB RW RR = its bound, within the ticket maxima
  live || return 1
  local rc=0; PT=$NOW LB=$DB LW=0 LR=$DR PART=""; charge "$DB" 0 "$DR"
  step "planBytes planWrites planRequests" plan "$run" "$@" || rc=1 LB=0 LR=0
  charge $((-LB)) 0 $((-LR))
  printf '{"ev":"plan","run":%d,"t":%d,"grant":%d,"bytes":%d,"writes":0,"requests":%d}\n' "$run" "$PT" "$GI" $((DB - LB)) $((DR - LR)) >>"$TRACE"
  ((rc == 0)) && read -r RB RW RR < <(printf '%s' "$PART" | jq -r "{bytes: .planBytes, writes: .planWrites, requests: .planRequests} | $USE | \"\(.bytes) \(.writes) \(.requests)\"") ||
    { ((rc)) || REASON=plan-output; return 1; }
  ((RB <= TB && RW <= TW && RR <= TR)) || { REASON=plan-over-maxima; return 1; }
}
step() {  # KEYS VERB ARGS...: a probe step within the remaining reservation LB LW LR; KEYS of its output join PART
  call "$@" "$LB" "$LW" "$LR" || return 1
  ((b <= LB && w <= LW && r <= LR)) || { REASON="$2-over-ticket"; return 1; }
  LB=$((LB - b)) LW=$((LW - w)) LR=$((LR - r)) PART+="$PICK"$'\n'
}
timed() {  # STEP KEYS ARGS...: STEPStart, probe step STEP RUN SEQ ARGS..., STEPEnd
  local s="$1" k="$2" rc=0; shift 2
  now; CLK[${s}Start]=$NOW; [[ $s != cas ]] || LASTCAS=$NOW
  step "$k" "$s" "$run" "$SEQ" "$@" || rc=$?
  now; CLK[${s}End]=$NOW; return $rc
}
check() { printf '%s' "$PART" | jq -se --arg t "$TXID" --arg l "$LINEAGE" --argjson s "$SEQ" --arg k "$KIND" "add | $1" >/dev/null; }
clocks() { local k; for k in ticket commitStart commitEnd syncStart syncEnd restoreStart restoreEnd casStart casEnd ack; do printf ',"%s":%d' "$k" "${CLK[$k]:-0}"; done; }
emit() {  # JSON: one trace line: JSON plus the PART fields it names (probe use and other fields dropped)
  printf '%s' "$PART" | jq -cs --argjson b "$1" '$b + (add // {} | with_entries(select(.key as $k | $b | has($k) and ($k | IN("bytes", "writes", "requests") | not))))' >>"$TRACE"
}
publish() {  # N PAYLOAD_BYTES: entry KIND at sequence SEQ, ticketed at the NOW its checks read; debits RB RW RR before sending
  CLK=([ticket]=$NOW) LB=$RB LW=$RW LR=$RR PART="" TXID=""; charge "$RB" "$RW" "$RR"
  [[ $KIND == renewal ]] || step "payloadSha256 payloadBytes" artifact "$run" "$1" "$KIND" "$2" || return 1
  timed commit "before after dbBytes" "$1" && timed sync "txid lineage" || return 1
  TXID="$(printf '%s' "$PART" | jq -rs 'add.txid | strings')"
  [[ "$TXID" =~ ^[0-9a-f]{16}$ ]] && check '.lineage == $l' || { REASON=sync-lineage; return 1; }
  timed restore "restoreTxid restoredSeq restoredPayloadSha256 integrity" "$TXID" || return 1
  check '.restoreTxid == $t and .restoredSeq == $s and .integrity == "ok" and ($k == "renewal" or .restoredPayloadSha256 == .payloadSha256)' ||
    { REASON=restore-mismatch; return 1; }
  now; ((NOW - LASTCAS >= SPACING)) || sleep "$(ms $((LASTCAS + SPACING - NOW)))"
  timed cas "casSeq casTxid" "$TXID" || return 1
  check '.casSeq == $s and .casTxid == $t' || { REASON=cas-mismatch; return 1; }
  now; CLK[ack]=$NOW
}
entry() {  # N PAYLOAD_BYTES: publish as sequence n + renewals, then settle: a published entry's charge becomes its use, a failure keeps all
  SEQ=$((n + REN)) OUTCOME=published REASON=""
  publish "$@" || OUTCOME=failed LB=0 LW=0 LR=0
  charge $((-LB)) $((-LW)) $((-LR))
  SB=$((RB - LB)) SW=$((RW - LW)) SR=$((RR - LR))
}
renew() {  # a renewal before command n, as a published command; its grant opens at its ack
  plan renewal 0 && live || return 1
  KIND=renewal; entry 0 0; REN=$((REN + 1))
  local t=0; [[ $OUTCOME != published ]] || t=${CLK[ack]}
  emit "{\"ev\":\"grant\",\"run\":$run,\"t\":$t,\"deadline\":$((t ? t + GMS : 0)),\"outcome\":\"$OUTCOME\",\"bytes\":$SB,\"writes\":$SW,\"requests\":$SR,\"txid\":\"\",\"lineage\":\"\",\"restoreTxid\":\"\",\"restoredSeq\":0,\"integrity\":\"\",\"casSeq\":0,\"casTxid\":\"\"$(clocks)}"
  [[ $OUTCOME == published ]] && DEADLINE=$((t + GMS)) QB=0 QW=0 QR=0 GI=$((GI + 1))
}
order() {  # command n at its submission clock; 1 when the lane must block
  now; ((submit <= NOW)) || sleep "$(ms $((submit - NOW)))"
  local rc=0; now
  if ! room 1 || ((NOW + MAXMS > DEADLINE)); then
    [[ $REASON != envelope ]] && renew || rc=1
    CLK=() PART="" OUTCOME=failed SB=0 SW=0 SR=0  # the renewal's state never reaches the command
    ((rc == 0)) || { [[ $REASON == envelope ]] || REASON="renewal-${REASON#renewal-}"; return 1; }
    room 1 || return 1
  fi
  plan "$kind" "$size" && live || return 1
  KIND="$kind"; entry "$n" "$size"
  [[ $OUTCOME == published ]]
}

printf '{"ev":"trace","schema":"prifly/qualification/early-publication-trace/v1","procedureSha256":"%s","runnerSha256":"%s","evaluatorSha256":"%s","probeSha256":"%s","manifestSha256":"%s","priorBytes":%d,"priorRequests":%d}\n' \
  "$(sha "$PROC")" "$(sha "${BASH_SOURCE[0]}")" "$(sha "$HERE/fixture.go")" "$(sha "$PROBE")" "$(sha "$MANIFEST")" "$PB" "$PR" >"$TRACE"
call "" declare && ((w == 0 && 2 * (b + TB) <= GB && 2 * (r + TR) <= GR)) || halt "the probe declares no write-free plan use that leaves a grant two tickets: ${REASON:-$b bytes $w writes $r requests}"
DB=$b DR=$r
for ((run = 1; run <= RUNS; run++)); do
  prefix="${PREFIX}run$run-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')/" QB=0 QW=0 QR=0 GI=0 REN=0 n=0 REASON="" PART=""
  now; DEADLINE=$((NOW + GMS)); emit "{\"ev\":\"grant\",\"run\":$run,\"t\":$NOW,\"deadline\":$DEADLINE}"
  room 0 && plan fixture 0 || halt "run $run fixture: $REASON"
  T0=$PT LB=$RB LW=$RW LR=$RR PART=""; charge "$RB" "$RW" "$RR"
  step "generator seed litestream dbBytes lineage" fixture "$run" "$BUCKET" "$prefix" "$SEED" "$WORK/run$run" || halt "run $run fixture: $REASON"
  charge $((-LB)) $((-LW)) $((-LR))
  LINEAGE="$(printf '%s' "$PART" | jq -rs 'add.lineage | strings')"
  [[ -n $LINEAGE ]] || halt "run $run fixture reported no lineage"
  emit "{\"ev\":\"run\",\"run\":$run,\"t0\":$T0,\"grant\":$GI,\"prefix\":\"$prefix\",\"lineage\":\"\",\"generator\":\"\",\"seed\":0,\"litestream\":\"\",\"dbBytes\":0,\"bytes\":$((RB - LB)),\"writes\":$((RW - LW)),\"requests\":$((RR - LR))}"
  PART="" LASTCAS=$((-SPACING)) BLOCKED=""
  for i in "${!ARR[@]}"; do
    n=$((i + 1)) submit=$((T0 + ARR[i])) OUTCOME=failed REASON=lane-blocked SB=0 SW=0 SR=0 PART="" CLK=()
    read -r kind size <<<"${MIX[i % ${#MIX[@]}]}"
    [[ -n $BLOCKED ]] || { REASON=""; order || BLOCKED=1; }
    emit "{\"ev\":\"cmd\",\"run\":$run,\"n\":$n,\"kind\":\"$kind\",\"arrival\":${ARR[i]},\"submit\":$submit,\"outcome\":\"$OUTCOME\",\"reason\":\"$REASON\",\"bytes\":$SB,\"writes\":$SW,\"requests\":$SR,\"payloadSha256\":\"none\",\"payloadBytes\":0,\"before\":\"none\",\"after\":\"\",\"dbBytes\":0,\"txid\":\"\",\"lineage\":\"\",\"restoreTxid\":\"\",\"restoredSeq\":0,\"restoredPayloadSha256\":\"\",\"integrity\":\"\",\"casSeq\":0,\"casTxid\":\"\"$(clocks)}"
  done
done
report; trap - EXIT
exec "$WORK/fixture" "$PROC" "$TRACE"
