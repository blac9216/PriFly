#!/usr/bin/env bash
# Local fake probe for test-publication.sh: no Litestream, R2, network or credential. It appends each call's
# argv and the ledger file it sees ($FAKE_STATE/../ledger.json) to $FAKE_STATE/calls. FAKE_MODE lists faults
# MODE@RUN:SEQ: lineage, short-txid, over-use (sync reports another lineage, a 1-digit T, use past its
# reservation), hang (sync ignores TERM and sleeps 3s), restore-txid, restore-seq, integrity, payload (restore
# reports another T, sequence, integrity or payload), cas-seq, cas-txid (CAS reads back another sequence or
# T), cas-lost (CAS exits 1), exit1 (commit reports, then exits 1), ledger (commit makes the ledger file
# unwritable), term (commit signals the runner); MODE@RUN:0 at the fixture: trace (makes the trace
# unwritable), no-lineage, fixture-over (use past its plan); MODE@RUN:KIND at a plan (KIND renewal for a
# hold): huge (bound past the ticket), greedy (use past the declared), stall (the virtual clock jumps 700 s);
# hold-fail@RUN:K fails the run's Kth renewal plan; heavy@RUN:K gives that run's first K commands 150 MiB
# uploads, with 64 MiB renewal holds meanwhile.
set -euo pipefail
st="$FAKE_STATE" mode=" ${FAKE_MODE:-} " verb="$1" run="${2:-0}"
echo "$* $(tr -d '\n' 2>/dev/null <"$st/../ledger.json")" >>"$st/calls"
use() { printf '"bytes":%d,"writes":%d,"requests":%d}\n' "$@"; }
hit() { [[ "$mode" == *" $1@$run:$2 "* ]]; }
alt() { if hit "$1" "$2"; then echo "$3"; else echo "$4"; fi; }  # MODE KEY FAULTY NORMAL
heavy=0; k="${mode#* heavy@"$run":}"; [[ "$k" != "$mode" && $(cat "$st/heavy-$run" 2>/dev/null || echo 0) -lt "${k%% *}" ]] && heavy=$((150 << 20))
case "$verb" in
  declare) printf '{'; use 0 0 1 ;;
  plan) ! hit stall "$3" || echo $(($(cat "$VCLOCK") + 700000)) >"$VCLOCK"
    [[ $3 != renewal ]] || { echo x >>"$st/holds-$run"; ! hit hold-fail "$(wc -l <"$st/holds-$run")" || exit 1; }
    case "$3" in fixture) b=52494336 w=2 r=9 ;; renewal) b=$((heavy ? 64 << 20 : 8192)) w=4 r=20 ;; *) b=$((heavy + $4 + 65536)) w=8 r=40 ;; esac
    printf '{"planBytes":%d,"planWrites":%d,"planRequests":%d,' "$(alt huge "$3" 268435457 "$b")" "$w" "$r"; use 0 0 "$(alt greedy "$3" 2 1)" ;;
  fixture) lineage="lineage-$(sha256sum <<<"$4" | cut -c1-12)"; echo "$lineage" >"$st/lineage-$run"
    ! hit trace 0 || { rm "$st/../work/trace.jsonl" && mkdir "$st/../work/trace.jsonl"; }
    printf '{"generator":"fake-gen-v1","seed":%d,"litestream":"0.5.17","dbBytes":52428800,"lineage":"%s",' "$5" "$(alt no-lineage 0 "" "$lineage")"
    use "$(alt fixture-over 0 52494337 52494336)" 2 9 ;;
  artifact) sha="$(sha256sum <<<"$run-$3" | cut -d' ' -f1)"; echo "$sha" >"$st/payload"
    ((heavy == 0)) || echo $(($(cat "$st/heavy-$run" 2>/dev/null || echo 0) + 1)) >"$st/heavy-$run"
    printf '{"payloadSha256":"%s","payloadBytes":%d,' "$sha" "$5"; use $((heavy + $5)) 1 2 ;;
  commit) ! hit ledger "$3" || mkdir "$st/../ledger.json.new"
    ! hit term "$3" || kill -TERM "$PPID"
    printf '{"before":"s%d","after":"s%d","dbBytes":%d,' $(($4 - 1)) "$4" $((52428800 + $3 * 4096)); use 0 0 0; ! hit exit1 "$3" || exit 1 ;;
  sync) hit hang "$3" && { trap '' TERM; sleep 3; }
    printf '{"txid":"%s","lineage":"%s",' "$(alt short-txid "$3" 5 "$(printf %016x "$3")")" "$(alt lineage "$3" other-lineage "$(cat "$st/lineage-$run")")"
    use 4096 1 "$(alt over-use "$3" 100000 3)" ;;
  restore) printf '{"restoreTxid":"%s","restoredSeq":%d,"restoredPayloadSha256":"%s","integrity":"%s",' "$(alt restore-txid "$3" 0000000000000000 "$4")" \
      "$(alt restore-seq "$3" $(($3 - 1)) "$3")" "$(alt payload "$3" "$(sha256sum <<<other | cut -d' ' -f1)" "$(cat "$st/payload")")" "$(alt integrity "$3" corrupt ok)"
    use 0 0 10 ;;
  cas) hit cas-lost "$3" && exit 1
    printf '{"casSeq":%d,"casTxid":"%s",' "$(alt cas-seq "$3" $(($3 - 1)) "$3")" "$(alt cas-txid "$3" 0000000000000000 "$4")"; use 256 1 2 ;;
esac
