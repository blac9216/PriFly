#!/usr/bin/env bash
# Q13 early remote-publication runner: drives an operator probe (the Litestream/R2 client) through the
# fixed P13 schedule in publication.json, writes a trace in fixture.go's grammar and execs fixture.go on it.
# A run with a fake probe is never a live PASS; this script itself contacts nothing remote.
# Usage: publication.sh --manifest FILE --probe EXECUTABLE --ledger FILE --work DIR
# The ledger is the operator-held record {"bytes":N,"requests":N} of use already charged to the shared
# cumulative P12a envelope. It is required, read before any probe call, and rewritten after every debit and
# settlement, so it never shows less than may have been sent; the trace header carries the prior values.
# Probe contract: argv, then (except plan) the entry's remaining reservation BYTES WRITES REQUESTS, which
# its use must stay within; its last stdout line is one JSON object with the fields below and the bytes,
# writes and requests it used:
#   plan RUN fixture|renewal|KIND PAYLOAD_BYTES → a finite bound: bytes writes requests (no remote use)
#   fixture RUN BUCKET_REF PREFIX SEED DIR      → generator seed litestream dbBytes lineage
#   artifact RUN N KIND PAYLOAD_BYTES           → payloadSha256 payloadBytes (upload and read-verify)
#   commit RUN SEQ N (N 0: renewal)             → before after dbBytes
#   sync RUN SEQ → txid lineage | restore RUN SEQ TXID → restoreTxid restoredSeq restoredPayloadSha256 integrity
#   cas RUN SEQ TXID                            → casSeq casTxid
# Per run: the fixture within P12a, a grant, a held renewal ticket, then each command at its submission
# clock: plan it; renew first when the grant lacks room for this ticket beside the held one (P12b) or ends
# within thresholds.maxMs (a slower publication misses P13 anyway, and a renewal must reserve inside a live
# grant). A renewal is a published command on the next sequence number (C3). Each entry: reserve the whole
# ticket; artifact; commit; sync, requiring a 16-hex TXID and the run's lineage before restore; restore that
# T, requiring its sequence, T, integrity and result; pace the CAS casMinSpacingMs after the last (P4);
# require the CAS readback of sequence and T; only then ack. Each probe call runs under timeout -k 1
# stepTimeoutS. A failure charges the whole reservation and blocks the lane for the rest of the run, so an
# ambiguous CAS never admits a successor; blocked commands are recorded failed, never dropped. A reservation
# that would pass P12a is not made. Exit: fixture.go's code; 20 refused before any probe call (usage;
# ledger missing, malformed or at the envelope; clock; preflight non-zero; evaluator build); 21 aborted with
# no verdict (a fixture step failed or would pass P12a, the clock ran backwards, or a signal).
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
  .thresholds.maxMs, (.grant | .ms, .bytes, .writes, .requests), (.ticket | .bytes, .writes, .requests), .envelope.bytes, .envelope.requests] | @tsv' "$PROC")
read -r PB PR < <(jq -r "select(type == \"object\" and keys == [\"bytes\", \"requests\"]) | .writes = 0 | $USE | \"\(.bytes) \(.requests)\"" "$LEDGER" 2>/dev/null) ||
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
trap report EXIT
trap 'halt "signal"' INT TERM HUP
ledger() { printf '{"bytes":%d,"requests":%d}\n' $((PB + UB)) $((PR + UR)) >"$LEDGER.new" && mv "$LEDGER.new" "$LEDGER"; }
ms() { printf '%d.%03d' $(($1 / 1000)) $(($1 % 1000)); }
sha() { sha256sum "$1" | cut -d' ' -f1; }
call() {  # KEYS VERB ARGS...: one bounded probe call, its output in its own file; b w r = its use, PICK = KEYS of it
  local keys="$1" f="$WORK/probe.$((++CALLS))" rc=0; shift
  echo "STEP $*" >&2
  timeout -k 1 "$STEP" "$PROBE" "$@" >"$f" || rc=$?
  read -r b w r PICK < <(tail -n1 "$f" | jq -rc --arg k "$keys" "$USE"' | "\(.bytes) \(.writes) \(.requests) \(with_entries(select(.key | IN($k | split(" ")[]))))"' 2>/dev/null) &&
    ((rc == 0)) || { REASON="$1-exit$rc"; ((rc)) || REASON="$1-output"; return 1; }
}
plan() { call "" plan "$run" "$@" && RB=$b RW=$w RR=$r; }
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
fits() {  # HELD_B HELD_W HELD_R: the reservation RB RW RR beside a held ticket fits P12a, then the grant
  ((PB + UB + RB + $1 <= EB && PR + UR + RR + $3 <= ER)) || { REASON=envelope; return 1; }
  ((QB + RB + $1 <= GB && QW + RW + $2 <= GW && QR + RR + $3 <= GR)) || { REASON=grant-headroom; return 1; }
}
publish() {  # N PAYLOAD_BYTES: lane entry KIND at sequence SEQ, debiting reservation RB RW RR before any send
  now; CLK=([ticket]=$NOW) LB=$RB LW=$RW LR=$RR PART="" TXID=""
  QB=$((QB + RB)) QW=$((QW + RW)) QR=$((QR + RR)) UB=$((UB + RB)) UR=$((UR + RR)); ledger
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
entry() {  # N PAYLOAD_BYTES: publish, then settle: a published entry's charge becomes its use, a failure keeps all
  SEQ=$((SEQ + 1)) OUTCOME=published REASON=""
  publish "$@" || OUTCOME=failed LB=0 LW=0 LR=0
  QB=$((QB - LB)) QW=$((QW - LW)) QR=$((QR - LR)) UB=$((UB - LB)) UR=$((UR - LR)); ledger
  SB=$((RB - LB)) SW=$((RW - LW)) SR=$((RR - LR))
}
hold() { if plan renewal 0 && ((RB <= TB && RW <= TW && RR <= TR)); then HB=$RB HW=$RW HR=$RR; else REASON=renewal-plan; return 1; fi; }
renew() {  # the held ticket as a published command; its grant opens at its ack
  RB=$HB RW=$HW RR=$HR KIND=renewal; now
  ((NOW <= DEADLINE)) || { REASON=grant-expired; return 1; }
  fits 0 0 0 || return 1
  entry 0 0
  local t=0; [[ $OUTCOME != published ]] || t=${CLK[ack]}
  emit "{\"ev\":\"grant\",\"run\":$run,\"t\":$t,\"deadline\":$((t ? t + GMS : 0)),\"outcome\":\"$OUTCOME\",\"bytes\":$SB,\"writes\":$SW,\"requests\":$SR,\"restoredSeq\":0,\"casSeq\":0$(clocks)}"
  [[ $OUTCOME == published ]] && DEADLINE=$((t + GMS)) QB=0 QW=0 QR=0 && hold
}
order() {  # command n at its submission clock; 1 when the lane must block
  now; ((submit <= NOW)) || sleep "$(ms $((submit - NOW)))"
  plan "$kind" "$size" || return 1
  ((RB <= TB && RW <= TW && RR <= TR)) || { REASON=plan-over-ticket; return 1; }
  local cb=$RB cw=$RW cr=$RR; now
  if ! fits "$HB" "$HW" "$HR" || ((NOW + MAXMS > DEADLINE)); then
    [[ $REASON != envelope ]] && renew || return 1
    CLK=() PART="" OUTCOME=failed SB=0 SW=0 SR=0 RB=$cb RW=$cw RR=$cr
    fits "$HB" "$HW" "$HR" || return 1
  fi
  KIND="$kind"; entry "$n" "$size"
  [[ $OUTCOME == published ]]
}

printf '{"ev":"trace","schema":"prifly/qualification/early-publication-trace/v1","procedureSha256":"%s","runnerSha256":"%s","evaluatorSha256":"%s","probeSha256":"%s","manifestSha256":"%s","priorBytes":%d,"priorRequests":%d}\n' \
  "$(sha "$PROC")" "$(sha "${BASH_SOURCE[0]}")" "$(sha "$HERE/fixture.go")" "$(sha "$PROBE")" "$(sha "$MANIFEST")" "$PB" "$PR" >"$TRACE"
for ((run = 1; run <= RUNS; run++)); do
  prefix="${PREFIX}run$run-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')/" PART="" QB=0 QW=0 QR=0 REASON=""
  plan fixture 0 || halt "run $run fixture plan: $REASON"
  ((PB + UB + RB <= EB && PR + UR + RR <= ER)) || halt "run $run fixture would pass the P12a envelope"
  LB=$RB LW=$RW LR=$RR UB=$((UB + RB)) UR=$((UR + RR)); ledger
  step "generator seed litestream dbBytes lineage" fixture "$run" "$BUCKET" "$prefix" "$SEED" "$WORK/run$run" || halt "run $run fixture: $REASON"
  UB=$((UB - LB)) UR=$((UR - LR)); ledger
  LINEAGE="$(printf '%s' "$PART" | jq -rs 'add.lineage | strings')"; now; T0=$NOW
  [[ -n $LINEAGE ]] || halt "run $run fixture reported no lineage"
  emit "{\"ev\":\"run\",\"run\":$run,\"t0\":$T0,\"prefix\":\"$prefix\",\"lineage\":\"\",\"generator\":\"\",\"seed\":0,\"litestream\":\"\",\"dbBytes\":0,\"bytes\":$((RB - LB)),\"writes\":$((RW - LW)),\"requests\":$((RR - LR))}"
  PART="" SEQ=0 LASTCAS=$((-SPACING)) BLOCKED=""; now; DEADLINE=$((NOW + GMS))
  emit "{\"ev\":\"grant\",\"run\":$run,\"t\":$NOW,\"deadline\":$DEADLINE}"
  hold || BLOCKED=1
  for i in "${!ARR[@]}"; do
    n=$((i + 1)) submit=$((T0 + ARR[i])) OUTCOME=failed REASON=lane-blocked SB=0 SW=0 SR=0 PART="" CLK=()
    read -r kind size <<<"${MIX[i % ${#MIX[@]}]}"
    [[ -n $BLOCKED ]] || { REASON=""; order || BLOCKED=1; }
    emit "{\"ev\":\"cmd\",\"run\":$run,\"n\":$n,\"kind\":\"$kind\",\"arrival\":${ARR[i]},\"submit\":$submit,\"outcome\":\"$OUTCOME\",\"reason\":\"$REASON\",\"bytes\":$SB,\"writes\":$SW,\"requests\":$SR,\"payloadSha256\":\"none\",\"payloadBytes\":0,\"before\":\"none\",\"after\":\"\",\"dbBytes\":0,\"txid\":\"\",\"lineage\":\"\",\"restoreTxid\":\"\",\"restoredSeq\":0,\"restoredPayloadSha256\":\"\",\"integrity\":\"\",\"casSeq\":0,\"casTxid\":\"\"$(clocks)}"
  done
done
report; trap - EXIT
exec "$WORK/fixture" "$PROC" "$TRACE"
