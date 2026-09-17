#!/usr/bin/env bash
# Local fake probe for test-publication.sh: no Litestream, R2, network or credential. It appends each call's
# argv to $FAKE_STATE/calls. FAKE_MODE lists faults MODE@RUN:SEQ: lineage (sync reports another lineage),
# cas-seq (CAS reads back the previous sequence), cas-lost (CAS exits 1), hang (sync ignores TERM and sleeps
# 3s); heavy@RUN:K gives that run's first K commands 200 MiB uploads, with 64 MiB renewal holds meanwhile.
set -euo pipefail
st="$FAKE_STATE" mode=" ${FAKE_MODE:-} " verb="$1" run="$2"
echo "$*" >>"$st/calls"
use() { printf '"bytes":%d,"writes":%d,"requests":%d}\n' "$@"; }
hit() { [[ "$mode" == *" $1@$run:$2 "* ]]; }
heavy=0; k="${mode#* heavy@"$run":}"; [[ "$k" != "$mode" && $(cat "$st/heavy" 2>/dev/null || echo 0) -lt "${k%% *}" ]] && heavy=$((200 << 20))
case "$verb" in
  plan) case "$3" in
      fixture) printf '{'; use 52494336 2 9 ;;
      renewal) printf '{'; use $((heavy ? 64 << 20 : 8192)) 4 20 ;;
      *) printf '{'; use $((heavy + $4 + 65536)) 8 40 ;;
    esac ;;
  fixture) printf '{"generator":"fake-gen-v1","seed":%d,"litestream":"0.5.17","dbBytes":52428800,"lineage":"lineage-%s",' "$5" "$(sha256sum <<<"$4" | cut -c1-12)"
    echo "lineage-$(sha256sum <<<"$4" | cut -c1-12)" >"$st/lineage-$run"; use 52494336 2 9 ;;
  artifact) sha="$(sha256sum <<<"$run-$3" | cut -d' ' -f1)"; echo "$sha" >"$st/payload"
    ((heavy == 0)) || echo $(($(cat "$st/heavy" 2>/dev/null || echo 0) + 1)) >"$st/heavy"
    printf '{"payloadSha256":"%s","payloadBytes":%d,' "$sha" "$5"; use $((heavy + $5)) 1 2 ;;
  commit) printf '{"before":"s%d","after":"s%d","dbBytes":%d,' $(($4 - 1)) "$4" $((52428800 + $3 * 4096)); use 0 0 0 ;;
  sync) hit hang "$3" && { trap '' TERM; sleep 3; }
    lineage="$(cat "$st/lineage-$run")"; hit lineage "$3" && lineage="other-lineage"
    printf '{"txid":"%016x","lineage":"%s",' "$3" "$lineage"; use 4096 1 3 ;;
  restore) printf '{"restoreTxid":"%s","restoredSeq":%d,"restoredPayloadSha256":"%s","integrity":"ok",' "$4" "$3" "$(cat "$st/payload")"; use 0 0 10 ;;
  cas) hit cas-lost "$3" && exit 1
    printf '{"casSeq":%d,"casTxid":"%s",' $(($3 - $(hit cas-seq "$3" && echo 1 || echo 0))) "$4"; use 256 1 2 ;;
esac
