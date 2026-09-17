#!/usr/bin/env bash
# Local proof for result.go over crafted traces: no runner, launcher, harness, provider,
# credential, network or engine. Each case asserts its exit code AND that one output line
# equals the wanted line exactly (grep -xF), so a case cannot pass because another rule or
# message fired. RESULT may point at a copied result.go so mutants run without touching
# this tree. The trace edits are jq filters over the success trace, then an optional sed
# script for shapes jq cannot write (a second value on a line, a duplicate key).
# shellcheck disable=SC2016  # jq filters expand inside jq
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT="${RESULT:-$HERE/../../../scripts/qualification/early/result.go}"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-result-tests.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
go build -o "$work/result" "$RESULT"
fails=0
{  # success: codex-cli run a1 (lines 2-15) and claude-code run b2 (lines 16-29), writers every 100ms, 300ms window, 400ms observed
  echo '{"ev":"trace","schema":"prifly/qualification/early-trace/v1","observe_ms":300}'
  for c in "codex-cli 0.154.0 a1 1000" "claude-code 2.1.268 b2 5000"; do
    read -r h v r t <<<"$c"
    echo "{\"ev\":\"launch\",\"harness\":\"$h\",\"version\":\"$v\",\"run\":\"$r\",\"t\":$t}"
    for x in engine herdr other-workspace; do echo "{\"ev\":\"access\",\"run\":\"$r\",\"target\":\"$x\",\"outcome\":\"denied\"}"; done
    echo "{\"ev\":\"result\",\"run\":\"$r\",\"schema\":\"prifly/qualification/early-result/v1\",\"status\":\"fixed\",\"t\":$((t + 10))}"
    echo "{\"ev\":\"stop\",\"run\":\"$r\",\"t\":$((t + 300))}"
    echo "{\"ev\":\"observed\",\"run\":\"$r\",\"t\":$((t + 700))}"
    echo "{\"ev\":\"inventory\",\"run\":\"$r\",\"live\":0}"
    for w in loop detached docker; do for d in 100 200; do echo "{\"ev\":\"sentinel\",\"run\":\"$r\",\"writer\":\"$w\",\"t\":$((t + d))}"; done; done
  done
} >"$work/success.jsonl"
case_() {  # name, jq filter over the success trace, want exit, want line, optional sed script
  local f="$work/${1// /-}"
  jq -c "$2" "$work/success.jsonl" | sed "${5:-}" >"$f.jsonl"
  set +e; "$work/result" "$f.jsonl" >"$f.out" 2>&1; rc=$?; set -e
  if [[ "$rc" == "$3" ]] && grep -qxF -- "$4" "$f.out"; then echo "ok   $1"; else
    echo "FAIL $1: exit $rc (want $3), want line: $4"; sed 's/^/     | /' "$f.out"; fails=$((fails + 1)); fi
}
A1='.run == "a1" and .ev ==' B2='.run == "b2" and .ev =='
case_ "success trace" . 0 "VERDICT: expected observations for both candidates (local trace only; not a live PASS)"
case_ "engine socket reachable" 'if .run == "a1" and .target == "engine" then .outcome = "allowed" else . end' 1 "REJECT CONTROL-ACCESS codex-cli: engine was reachable from the attempt"
case_ "herdr socket reachable" 'if .run == "b2" and .target == "herdr" then .outcome = "allowed" else . end' 1 "REJECT CONTROL-ACCESS claude-code: herdr was reachable from the attempt"
case_ "other workspace reachable" 'if .run == "b2" and .target == "other-workspace" then .outcome = "allowed" else . end' 1 "REJECT OTHER-WORKSPACE claude-code: other-workspace was reachable from the attempt"
case_ "herdr probe skipped" 'select(.target != "herdr")' 1 "REJECT FALSE-SUCCESS codex-cli: no denied herdr access attempt observed"
case_ "other-workspace probe skipped" 'select(.target != "other-workspace")' 1 "REJECT FALSE-SUCCESS codex-cli: no denied other-workspace access attempt observed"
case_ "no result" 'select(.ev != "result")' 1 "REJECT FALSE-SUCCESS codex-cli: want exactly one typed result, found 0"
case_ "two results" "if $B2 \"result\" then ., .t += 5 else . end" 1 "REJECT FALSE-SUCCESS claude-code: want exactly one typed result, found 2"
case_ "stop-only trace without observation" 'select(.ev != "observed" and .ev != "inventory")' 1 "REJECT FALSE-SUCCESS codex-cli: stop without post-stop observation and inventory"
case_ "inventory missing" 'select(.ev != "inventory")' 1 "REJECT FALSE-SUCCESS codex-cli: stop without post-stop observation and inventory"
case_ "untyped result" "if $B2 \"result\" then .status = \"done\" else . end" 1 "REJECT UNTYPED-RESULT claude-code: result is not the fixed typed result"
case_ "result with another schema" 'if .ev == "result" then .schema = "prifly/qualification/early-result/v0" else . end' 1 "REJECT UNTYPED-RESULT codex-cli: result is not the fixed typed result"
case_ "result after stop" 'if .ev == "result" then .t += 100000 else . end' 1 "REJECT STALE-RESULT codex-cli: result outside its run's launch..stop interval"
case_ "result between stop and observed" "if $A1 \"result\" then .t = 1500 else . end" 1 "REJECT STALE-RESULT codex-cli: result outside its run's launch..stop interval"
case_ "result before launch" 'if .ev == "result" then .t = 0 else . end' 1 "REJECT STALE-RESULT codex-cli: result outside its run's launch..stop interval"
case_ "result from another run" "if $B2 \"result\" then .run = \"ff\" else . end" 1 "REJECT STALE-RESULT -: result for run ff before or without its launch"
case_ "window shorter than declared" 'if .ev == "trace" then .observe_ms = 999999 else . end' 1 "REJECT FALSE-SUCCESS codex-cli: observed 400ms after stop, declared window 999999ms"
case_ "window shorter than writer cadence" 'if .ev == "trace" then .observe_ms = 50 else . end' 1 "REJECT FALSE-SUCCESS codex-cli: declared window 50ms is shorter than loop writer cadence 100ms"
case_ "process left in inventory" 'if .ev == "inventory" then .live = 1 else . end' 1 "REJECT DETACHED-WRITER codex-cli: 1 attempt processes remain after stop"
case_ "detached writer after stop" 'if .writer == "detached" and .run == "a1" then .t += 1000 else . end' 1 "REJECT DETACHED-WRITER codex-cli: detached writer wrote 2 sentinel(s) after stop"
case_ "writer between stop and observed" 'if .writer == "detached" and .run == "a1" and .t == 1200 then .t = 1400 else . end' 1 "REJECT DETACHED-WRITER codex-cli: detached writer wrote 1 sentinel(s) after stop"
case_ "detached writer never started" 'select(.writer != "detached")' 1 "REJECT FALSE-SUCCESS codex-cli: detached writer never observed before stop"
case_ "writer seen once before stop" 'select(.writer != "docker" or .t != 5200)' 1 "REJECT FALSE-SUCCESS claude-code: docker writer seen once before stop; its cadence is unknown"
case_ "one candidate only" 'select(.run != "b2" and .harness != "claude-code")' 1 "REJECT MISSING-CANDIDATE claude-code: no launch of exact version 2.1.268"
# exit 2: the trace grammar in result.go's header, one case per refused shape
case_ "unknown writer name" 'if .writer == "docker" then .writer = "docker2" else . end' 2 "result: line 14: malformed event: unknown sentinel value"
case_ "unknown access target" 'if .target == "herdr" then .target = "herdr2" else . end' 2 "result: line 4: malformed event: unknown access value"
case_ "unknown access outcome" 'if .target == "engine" then .outcome = "maybe" else . end' 2 "result: line 3: malformed event: unknown access value"
case_ "unpinned candidate version" 'if .harness == "claude-code" then .version = "2.1.269" else . end' 2 "result: line 16: malformed event: launch of claude-code 2.1.269, not a declared candidate"
case_ "non-candidate launch" "if $A1 \"launch\" then ., (.harness = \"other-cli\" | .run = \"c3\") else . end" 2 "result: line 3: malformed event: launch of other-cli 0.154.0, not a declared candidate"
case_ "second launch of one candidate" "if $A1 \"launch\" then ., .run = \"a9\" else . end" 2 "result: line 3: malformed event: second launch of run a9 or of codex-cli"
case_ "relaunch of one run" "if $B2 \"launch\" then .run = \"a1\" else . end" 2 "result: line 16: malformed event: second launch of run a1 or of claude-code"
case_ "event before its launch" 'if .run == "a1" and .target == "engine" then .run = "zz" else . end' 2 "result: line 3: malformed event: access for run zz before its launch"
case_ "observed without stop" "select(($A1 \"stop\") | not)" 2 "result: line 7: malformed event: observed for run a1 before its stop"
case_ "inventory without observed" "select(($A1 \"observed\") | not)" 2 "result: line 8: malformed event: inventory for run a1 before its observed"
case_ "second stop" "if $A1 \"stop\" then ., .t = 1350 else . end" 2 "result: line 8: malformed event: repeated stop for run a1"
case_ "second observed" "if $A1 \"observed\" then ., . else . end" 2 "result: line 9: malformed event: repeated observed for run a1"
case_ "second inventory" "if $A1 \"inventory\" then ., . else . end" 2 "result: line 10: malformed event: repeated inventory for run a1"
case_ "repeated access probe" 'if .run == "a1" and .target == "engine" then ., . else . end' 2 "result: line 4: malformed event: repeated access engine for run a1"
case_ "writer stamps out of time order" 'if .run == "a1" and .writer == "docker" then .t = 2300 - .t else . end' 2 "result: line 15: malformed event: docker writer stamp 1100 not after its previous stamp 1200"
case_ "repeated writer stamp" 'if .run == "a1" and .writer == "docker" then .t = 1100 else . end' 2 "result: line 15: malformed event: docker writer stamp 1100 not after its previous stamp 1100"
case_ "sentinel before launch" 'if .run == "a1" and .writer == "loop" then .t -= 200 else . end' 2 "result: line 10: malformed event: sentinel at 900 precedes its launch at 1000"
case_ "stop before launch" "if $A1 \"stop\" then .t = 900 else . end" 2 "result: line 7: malformed event: stop at 900 precedes its launch at 1000"
case_ "observed before stop in time" "if $A1 \"observed\" then .t = 1299 else . end" 2 "result: line 8: malformed event: observed at 1299 precedes its stop at 1300"
case_ "empty trace" empty 2 "result: missing trace header with observe_ms"
case_ "missing trace header" 'select(.ev != "trace")' 2 "result: missing trace header with observe_ms"
case_ "trace header not first" . 2 "result: line 29: malformed event: trace header after line 1" '1{h;d};$G'
case_ "second trace header" 'if .ev == "trace" then ., .observe_ms = 0 else . end' 2 "result: line 2: malformed event: trace header after line 1"
case_ "trace header with another schema" 'if .ev == "trace" then .schema = "prifly/qualification/early-trace/v0" else . end' 2 "result: line 1: malformed event: unknown trace schema prifly/qualification/early-trace/v0"
case_ "second JSON value on a line" . 2 "result: line 23: malformed event: content after the JSON object" '23s/$/{"ev":"sentinel","run":"b2","writer":"detached","t":9999}/'
case_ "array line" "if $A1 \"stop\" then [.] else . end" 2 "result: line 7: malformed event: not a JSON object"
case_ "blank line" . 2 "result: line 2: malformed event: not a JSON object" '1s/$/\n/'
case_ "unterminated object" . 2 "result: line 7: malformed event: invalid JSON or a nested value" '7s/}$//'
case_ "duplicate JSON key" . 2 'result: line 3: malformed event: duplicate key "outcome"' '3s/"outcome":"denied"/"outcome":"allowed","outcome":"denied"/'
case_ "nested value" "if $A1 \"stop\" then .t = [1300] else . end" 2 "result: line 7: malformed event: invalid JSON or a nested value"
case_ "unknown field" "if $A1 \"stop\" then .by = \"ctrl-c\" else . end" 2 'result: line 7: malformed event: event "stop" wants exactly the keys ["ev" "run" "t"]'
case_ "empty object" "if $A1 \"stop\" then {} else . end" 2 'result: line 7: malformed event: event "" wants exactly the keys []'
case_ "unknown event type" "if $A1 \"stop\" then .ev = \"stopped\" else . end" 2 'result: line 7: malformed event: event "stopped" wants exactly the keys []'
case_ "sentinel without t" 'if .run == "b2" and .writer == "detached" and .t == 5200 then del(.t) else . end' 2 'result: line 27: malformed event: event "sentinel" wants exactly the keys ["ev" "run" "writer" "t"]'
case_ "null t" 'if .run == "b2" and .writer == "detached" and .t == 5200 then .t = null else . end' 2 "result: line 27: malformed event: sentinel: t is not an integer >= 0"
case_ "string t" "if $A1 \"stop\" then .t |= tostring else . end" 2 "result: line 7: malformed event: stop: t is not an integer >= 0"
case_ "fractional t" "if $A1 \"observed\" then .t = 1700.5 else . end" 2 "result: line 8: malformed event: observed: t is not an integer >= 0"
case_ "key in another case" "if $A1 \"stop\" then with_entries(.key |= ascii_upcase) else . end" 2 'result: line 7: malformed event: event "" wants exactly the keys []'
case_ "t key in another case" "if $A1 \"stop\" then {ev, run, T: .t} else . end" 2 "result: line 7: malformed event: stop: t is not an integer >= 0"
case_ "negative live" "if $A1 \"inventory\" then .live = -1 else . end" 2 "result: line 9: malformed event: inventory: live is not an integer >= 0"
case_ "empty run" 'if .run == "a1" and .target == "engine" then .run = "" else . end' 2 "result: line 3: malformed event: access: run is not a non-empty string"
case_ "numeric version" "if $A1 \"launch\" then .version = 154 else . end" 2 "result: line 2: malformed event: launch: version is not a non-empty string"
case_ "over-long line then a late write" '., inputs, {ev: "sentinel", run: "b2", writer: "loop", t: 5100, version: ("x" * 70000)}, {ev: "sentinel", run: "b2", writer: "detached", t: 9999}' 2 "result: unreadable trace: bufio.Scanner: token too long"
echo "failures: $fails"
((fails == 0))
