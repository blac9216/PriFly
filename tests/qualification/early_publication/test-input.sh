#!/usr/bin/env bash
# Input-layer proof for fixture.go: jq writes one well-formed trace holding each event form (header,
# run, grant, renewal, published and failed command); each case breaks one input rule of the trace or
# of publication.json and asserts the exit code AND one whole output line. No runner, probe or network.
# EARLY may name a scratch copy of scripts/qualification/early (mutant pass).
# shellcheck disable=SC2016  # jq filters expand inside jq
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EARLY="${EARLY:-$HERE/../../../scripts/qualification/early}"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-input-tests.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
go build -o "$work/fixture" "$EARLY/fixture.go"
good="$work/good.jsonl"
jq -nc '("a" * 64) as $h
| def lane($t): {ticket: $t, commitStart: ($t + 100), commitEnd: ($t + 200), syncStart: ($t + 200), syncEnd: ($t + 500),
    restoreStart: ($t + 500), restoreEnd: ($t + 800), casStart: ($t + 800), casEnd: ($t + 1000), ack: ($t + 1100)};
  {ev: "trace", schema: "prifly/qualification/early-publication-trace/v1", procedureSha256: $h, runnerSha256: $h,
   evaluatorSha256: $h, probeSha256: $h, manifestSha256: $h, priorBytes: 0, priorRequests: 0},
  {ev: "run", run: 1, t0: 1000000, grant: 0, prefix: "q13/run1/", lineage: "lineage-1", generator: "gen-v1", seed: 9216,
   litestream: "0.5.17", dbBytes: 52428800, bytes: 52494336, writes: 2, requests: 9},
  {ev: "grant", run: 1, t: 1000000, deadline: 1600000},
  (lane(1590000) + {ev: "grant", run: 1, t: 1591100, deadline: 2191100, outcome: "published", bytes: 65536, writes: 3, requests: 25,
   txid: "t2", lineage: "lineage-1", restoreTxid: "t2", restoredSeq: 2, integrity: "ok", casSeq: 2, casTxid: "t2"}),
  (lane(1000000) + {ev: "cmd", run: 1, n: 1, kind: "package-revision", arrival: 0, submit: 1000000, outcome: "published",
   reason: "", bytes: 328192, writes: 4, requests: 27, payloadSha256: $h, payloadBytes: 262144, before: "s0", after: "s1",
   dbBytes: 52432896, txid: "t1", lineage: "lineage-1", restoreTxid: "t1", restoredSeq: 1, restoredPayloadSha256: $h,
   integrity: "ok", casSeq: 1, casTxid: "t1"}),
  (lane(1015000) + {restoreStart: 0, restoreEnd: 0, casStart: 0, casEnd: 0, ack: 0, ev: "cmd", run: 1, n: 2,
   kind: "attempt-result", arrival: 15000, submit: 1015000, outcome: "failed", reason: "sync-exit124", bytes: 1114112,
   writes: 2, requests: 12, payloadSha256: $h, payloadBytes: 1048576, before: "s1", after: "", dbBytes: 0, txid: "",
   lineage: "", restoreTxid: "", restoredSeq: 0, restoredPayloadSha256: "", integrity: "", casSeq: 0, casTxid: ""})' >"$good"
fails=0
verdict() {  # name, want exit, want whole output line, procedure, trace, optional ulimit -v KiB
  local out="$work/${1// /-}.out"
  set +e; ( [[ -z "${6:-}" ]] || ulimit -v "$6"; exec "$work/fixture" "$4" "$5" ) >"$out" 2>&1; rc=$?; set -e
  if [[ "$rc" == "$2" ]] && grep -qxF -- "$3" "$out"; then echo "ok   $1"; else
    echo "FAIL $1: exit $rc (want $2), want line: $3"; head -n 4 "$out" | sed 's/^/     | /' || true; fails=$((fails + 1)); fi
}
made() {  # name, file, generator command...: writes the file; a failing generator fails the case
  local name="$1" file="$2"; shift 2
  if "$@" >"$file"; then return 0; else echo "FAIL $name: generator exit $?"; fails=$((fails + 1)); return 1; fi
}
feed() {  # name, want exit, want line, generator command... writing the trace
  local f="$work/${1// /-}.jsonl" name="$1" rc="$2" want="$3"; shift 3
  if made "$name" "$f" "$@"; then verdict "$name" "$rc" "$want" "$EARLY/publication.json" "$f"; fi
}
edit() { feed "$1" 2 "fixture: malformed trace line $2" jq -c "$3 | .[]" -s "$good"; }
text() { feed "$1" 2 "fixture: malformed trace line $2" sed "$3" "$good"; }
grants() { cat "$good" && awk -v n="$1" 'NR == 3 { for (i = 0; i < n; i++) print }' "$good"; }  # good plus n grant lines
fill() { sed -n 1p "$good" && head -c "$1" /dev/zero | tr '\0' "$2"; }  # header plus a line of n copies of a byte
input() {  # well formed, so exit 1 from the semantic checks; at 4,096 lines, a line only the last appended grant produces
  if (($1 == 4096)); then echo "REJECT RENEWAL run 1 n 0: grant 4091: only a grant after the first is a renewal"; else echo "VERDICT: trace rejected; no feasibility result"; fi; }
proc() {  # name, sed expression over publication.json
  made "$1" "$work/${1// /-}.json" sed "$2" "$EARLY/publication.json" || return 0
  verdict "$1" 2 "fixture: procedure is not the fixed P4/P12a/P12b/P13 procedure" "$work/${1// /-}.json" "$good"
}
line() { echo "to_entries | map(if .key == $1 - 1 then .value |= ($2) else . end) | map(.value)"; }
feed "valid trace" 1 "$(input 6)" cat "$good"
"$work/fixture" "$EARLY/publication.json" "$good" >"$work/again.out" 2>&1 || true
if cmp -s "$work/valid-trace.out" "$work/again.out"; then echo "ok   deterministic output"; else echo "FAIL deterministic output"; fails=$((fails + 1)); fi
# Header and line framing
edit "missing header" 1 '.[1:]'
edit "second header" 2 '.[:1] + .'
edit "empty trace" 1 '[]'
text "blank line" 3 '2G'
text "trailing value" 5 '5s/$/ {}/'
edit "null line" 2 "$(line 2 'null')"
text "blank line before header" 1 '1s/^/\n/'
text "trailing blank line" 7 '$s/$/\n/'
text "leading no-break space" 1 '1s/^/\xc2\xa0/'
text "leading next-line character" 1 '1s/^/\xc2\x85/'
text "trailing line separator" 6 '$s/$/\xe2\x80\xa8/'
# Size guards: 4,096 lines of at most 4,096 bytes (the trace read stops past 16,781,312 bytes)
pad=$((4096 - $(sed -n 5p "$good" | wc -c) + 1))
feed "line of 4096 bytes" 1 "$(input 6)" sed "5s/\"lineage-1\"/\"lineage-1$(printf "%${pad}s" | tr ' ' x)\"/" "$good"
text "line over 4096 bytes" 5 "5s/\"lineage-1\"/\"lineage-1$(printf "%$((pad + 1))s" | tr ' ' x)\"/"
feed "trace of 4096 lines" 1 "$(input 4096)" grants 4090
feed "trace over 4096 lines" 2 "fixture: trace over 4096 lines" grants 4091
feed "trace of 16781312 bytes" 1 "$(input 4096)" awk '{ while (length($0) < 4096) $0 = $0 " "; print }' <(grants 4090)
made "escape-heavy line" "$work/escapes.jsonl" fill 16700000 "\\\\" &&  # refused before decoding: fits 1 GiB of address space
  verdict "escape-heavy line refused before decoding" 2 "fixture: malformed trace line 2" "$EARLY/publication.json" "$work/escapes.jsonl" 1048576
feed "trace over 16781312 bytes" 2 "fixture: cannot read procedure or trace within 16781312 bytes" fill 16781312 x
# Keys: no duplicate, exact case, exactly the event's keys
text "duplicate key" 5 '5s/"outcome":"published"/"outcome":"failed","outcome":"published"/'
text "key case variant" 5 '5s/"ticket":/"TICKET":/'
text "event key case variant" 2 '2s/"ev":/"Ev":/'
edit "unknown event" 3 "$(line 3 '.ev = "renewal"')"
text "empty object line" 4 '3a {}'
text "unknown event alone" 4 '3a {"ev":"renewal"}'
edit "extra key" 5 "$(line 5 '.note = "x"')"
edit "header without runner identity" 1 "$(line 1 'del(.runnerSha256)')"
edit "run without prefix" 2 "$(line 2 'del(.prefix)')"
edit "run without its grant" 2 "$(line 2 'del(.grant)')"  # #252 ruling 5716255116 item 1: the run line names the fixture step's grant
edit "grant without deadline" 3 "$(line 3 'del(.deadline)')"
edit "grant with a partial lane" 3 "$(line 3 '.ticket = 1000000')"
edit "renewal without ack" 4 "$(line 4 'del(.ack)')"
edit "renewal without T" 4 "$(line 4 'del(.txid)')"
edit "renewal without integrity" 4 "$(line 4 'del(.integrity)')"
edit "published renewal with an empty lineage" 4 "$(line 4 '.lineage = ""')"
feed "plan call use" 1 "$(input 7)" sed '3a {"ev":"plan","run":1,"t":1000000,"grant":0,"bytes":0,"writes":0,"requests":1}' "$good"
text "plan without requests" 4 '3a {"ev":"plan","run":1,"t":1000000,"grant":0,"bytes":0,"writes":0}'
text "plan without its grant" 4 '3a {"ev":"plan","run":1,"t":1000000,"bytes":0,"writes":0,"requests":1}'
feed "failed renewal with empty result strings" 1 "$(input 6)" jq -c "$(line 4 '.outcome = "failed" | .txid = "" | .lineage = "" | .restoreTxid = "" | .integrity = "" | .casTxid = ""') | .[]" -s "$good"
edit "command without payload hash" 5 "$(line 5 'del(.payloadSha256)')"
edit "failed command without database size" 6 "$(line 6 'del(.dbBytes)')"
# Values: unsigned integers in 0..2^53-1, typed, UTF-8, no lone surrogate, non-empty strings, outcome and reason
edit "null value" 5 "$(line 5 '.casEnd = null')"
edit "string for integer" 5 "$(line 5 '.ack = "1001100"')"
edit "fractional number" 5 "$(line 5 '.ticket = 1000000.5')"
text "integer written as 0.0" 6 '6s/"casSeq":0,/"casSeq":0.0,/'
edit "nested value" 5 "$(line 5 '.lineage = ["lineage-1"]')"
edit "negative number" 5 "$(line 5 '.writes = -1000000')"
edit "number over 2^53-1" 5 "$(line 5 '.bytes = 9007199254740992')"
feed "number of exactly 2^53-1" 1 "$(input 6)" sed '5s/"bytes":328192/"bytes":9007199254740991/' "$good"
text "negative zero" 2 '2s/"run":1,/"run":-0,/'
text "invalid UTF-8" 5 '5s/"txid":"t1"/"txid":"t1\xff"/'
text "lone surrogate escape" 5 '5s/"txid":"t1"/"txid":"t1\\ud800"/'
text "lone low surrogate escape" 5 '5s/"txid":"t1"/"txid":"t1\\udc00"/'
text "high surrogate pair" 5 '5s/"txid":"t1"/"txid":"t1\\ud800\\ud800"/'
feed "surrogate pair escape" 1 "$(input 6)" sed '5s/"txid":"t1"/"txid":"t1\\ud83d\\ude00"/' "$good"
feed "escaped backslash before u" 1 "$(input 6)" sed '5s/"txid":"t1"/"txid":"t1\\\\ud800"/' "$good"
edit "empty string" 2 "$(line 2 '.generator = ""')"
edit "run with an empty lineage" 2 "$(line 2 '.lineage = ""')"
edit "published with an empty T" 5 "$(line 5 '.txid = "" | .restoreTxid = "" | .casTxid = ""')"
edit "unknown outcome" 5 "$(line 5 '.outcome = "done"')"
edit "published with a reason" 5 "$(line 5 '.reason = "late"')"
edit "failed without a reason" 6 "$(line 6 '.reason = ""')"
edit "failed command with an empty kind" 6 "$(line 6 '.kind = ""')"
edit "failed command with an empty payload hash" 6 "$(line 6 '.payloadSha256 = ""')"
edit "failed command with an empty before state" 6 "$(line 6 '.before = ""')"
# Procedure: exact keys at every depth and the pinned P4/P12a/P12b/P13 values
proc "procedure differs from P13" 's/"runs": 3/"runs": 0/'
proc "procedure duplicate key" 's/"runs": 3/"runs": 0, "runs": 3/'
proc "procedure nested duplicate key" 's/"grant": {"ms": 600000,/"grant": {"ms": 600000, "ms": 600000,/'
proc "procedure key case variant" 's/"seed"/"Seed"/'
proc "procedure nested key case variant" 's/"atMs"/"AtMs"/'
proc "procedure missing field" 's/  "stepTimeoutS": 120,//'
proc "procedure extra field" 's/"runs": 3,/"runs": 3, "note": 1,/'
pads() { cat "$EARLY/publication.json" && printf "%$(($1 - $(wc -c <"$EARLY/publication.json")))s" ''; }  # procedure padded to n bytes
made "procedure of 65536 bytes" "$work/procedure-65536.json" pads 65536 &&
  verdict "procedure of 65536 bytes" 1 "$(input 6)" "$work/procedure-65536.json" "$good"
made "procedure over 65536 bytes" "$work/procedure-65537.json" pads 65537 &&
  verdict "procedure over 65536 bytes" 2 "fixture: cannot read procedure or trace within 65536 bytes" "$work/procedure-65537.json" "$good"
echo "$fails failed"
((fails == 0))
