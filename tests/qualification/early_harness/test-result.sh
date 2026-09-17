#!/usr/bin/env bash
# Local proof for result.go over crafted traces: no runner, launcher, harness, provider,
# credential, network or engine. Each case asserts its exit code AND one exact output line,
# so a case cannot pass because another rule fired. RESULT may point at a copied result.go
# so mutants run without touching this tree.
# shellcheck disable=SC2016  # jq filters expand inside jq
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT="${RESULT:-$HERE/../../../scripts/qualification/early/result.go}"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-result-tests.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
go build -o "$work/result" "$RESULT"
fails=0
{  # success: codex-cli run a1 and claude-code run b2, writers every 100ms, 300ms declared window, 400ms observed
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
case_() {  # name, jq filter over the success trace, want exit, want line
  local f="$work/${1// /-}"
  jq -c "$2" "$work/success.jsonl" >"$f.jsonl"
  set +e; "$work/result" "$f.jsonl" >"$f.out" 2>&1; rc=$?; set -e
  if [[ "$rc" == "$3" ]] && grep -qF -- "$4" "$f.out"; then echo "ok   $1"; else
    echo "FAIL $1: exit $rc (want $3), want line: $4"; sed 's/^/     | /' "$f.out"; fails=$((fails + 1)); fi
}
case_ "success trace" . 0 "VERDICT: expected observations for both candidates"
case_ "engine socket reachable" 'if .run == "a1" and .target == "engine" then .outcome = "allowed" else . end' 1 "REJECT CONTROL-ACCESS codex-cli: engine was reachable"
case_ "herdr socket reachable" 'if .run == "b2" and .target == "herdr" then .outcome = "allowed" else . end' 1 "REJECT CONTROL-ACCESS claude-code: herdr was reachable"
case_ "other workspace reachable" 'if .run == "b2" and .target == "other-workspace" then .outcome = "allowed" else . end' 1 "REJECT OTHER-WORKSPACE claude-code: other-workspace was reachable"
case_ "herdr probe skipped" 'select(.target != "herdr")' 1 "REJECT FALSE-SUCCESS codex-cli: no denied herdr access attempt observed"
case_ "no result" 'select(.ev != "result")' 1 "REJECT FALSE-SUCCESS codex-cli: want exactly one typed result, found 0"
case_ "stop-only trace without observation" 'select(.ev != "observed" and .ev != "inventory")' 1 "REJECT FALSE-SUCCESS codex-cli: stop without post-stop observation and inventory"
case_ "inventory missing" 'select(.ev != "inventory")' 1 "REJECT FALSE-SUCCESS codex-cli: stop without post-stop observation and inventory"
case_ "untyped result" 'if .ev == "result" and .run == "b2" then .status = "done" else . end' 1 "REJECT UNTYPED-RESULT claude-code: result is not the fixed typed result"
case_ "result with another schema" 'if .ev == "result" then .schema = "prifly/qualification/early-result/v0" else . end' 1 "REJECT UNTYPED-RESULT codex-cli"
case_ "result after stop" 'if .ev == "result" then .t += 100000 else . end' 1 "REJECT STALE-RESULT codex-cli: result outside"
case_ "result before launch" 'if .ev == "result" then .t = 0 else . end' 1 "REJECT STALE-RESULT codex-cli: result outside"
case_ "result from another run" 'if .ev == "result" and .run == "b2" then .run = "ff" else . end' 1 "REJECT STALE-RESULT -: result for run ff"
case_ "window shorter than declared" 'if .ev == "trace" then .observe_ms = 999999 else . end' 1 "after stop, declared window 999999ms"
case_ "window shorter than writer cadence" 'if .ev == "trace" then .observe_ms = 50 else . end' 1 "REJECT FALSE-SUCCESS codex-cli: declared window 50ms is shorter than loop writer cadence 100ms"
case_ "process left in inventory" 'if .ev == "inventory" then .live = 1 else . end' 1 "REJECT DETACHED-WRITER codex-cli: 1 attempt processes remain after stop"
case_ "detached writer after stop" 'if .writer == "detached" and .run == "a1" then .t += 1000 else . end' 1 "REJECT DETACHED-WRITER codex-cli: detached writer wrote 2 sentinel(s) after stop"
case_ "detached writer never started" 'select(.writer != "detached")' 1 "REJECT FALSE-SUCCESS codex-cli: detached writer never observed before stop"
case_ "writer seen once before stop" 'select(.writer != "docker" or .t != 5200)' 1 "REJECT FALSE-SUCCESS claude-code: docker writer seen once before stop; its cadence is unknown"
case_ "unknown writer name" 'if .writer == "docker" then .writer = "docker2" else . end' 2 "malformed event"
case_ "unknown access target" 'if .target == "herdr" then .target = "herdr2" else . end' 2 "malformed event"
case_ "one candidate only" 'select(.run != "b2" and .harness != "claude-code")' 1 "REJECT MISSING-CANDIDATE claude-code: no launch of exact version 2.1.268"
case_ "unpinned candidate version" 'if .harness == "claude-code" then .version = "2.1.269" else . end' 1 "REJECT MISSING-CANDIDATE claude-code"
case_ "unknown field" 'if .ev == "stop" then .by = "ctrl-c" else . end' 2 'unknown field "by"'
case_ "trace header with another schema" 'if .ev == "trace" then .schema = "prifly/qualification/early-trace/v0" else . end' 2 "result: line 1: unexpected event"
case_ "over-long line then a late write" '., inputs, {ev: "sentinel", run: "b2", writer: "loop", t: 5100, version: ("x" * 70000)}, {ev: "sentinel", run: "b2", writer: "detached", t: 9999}' 2 "result: unreadable trace"
echo "failures: $fails"
((fails == 0))
