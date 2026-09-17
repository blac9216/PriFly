//go:build ignore

// Local evaluator for an early E1/E4 probe trace written by harness.sh; it reads one
// JSON-lines file and nothing else. Build with go build -o BIN result.go, run BIN TRACE.
// Exit 0: expected observations for both candidates (never a live PASS by itself);
// 1: rejected, one "REJECT <CODE> <harness>: <reason>" line per finding; 2: usage error
// or malformed trace (including an unreadable or over-long line, or an unknown writer).
// Covers, per candidate: launch at the exact pinned version; E1 denied engine, HerdR and
// other-workspace access; one fixed typed result inside launch..stop; E4 loop, detached and
// docker writers each seen at least twice before stop, none after it, a post-stop window
// no shorter than the declared one or any writer's cadence, and an empty inventory. Not
// covered, left to R01-R05/Q03 and not certified by a Q12 PASS: E1 terminal-to-process
// mapping and native identity; E4 HerdR disconnect/restart with observer attach,
// late-result rejection, no native resume, and unresolved cleanup holding the next lease.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
)

type event struct {
	Ev, Schema, Harness, Version, Run, Target, Outcome, Status, Writer string
	T                                                                  int64
	Live                                                               *int
	ObserveMS                                                          *int64 `json:"observe_ms"`
}

var candidates = [][2]string{{"codex-cli", "0.154.0"}, {"claude-code", "2.1.268"}}
var rejected bool

func reject(code, who, format string, a ...any) {
	fmt.Printf("REJECT %s %s: %s\n", code, who, fmt.Sprintf(format, a...))
	rejected = true
}

func main() {
	f, err := os.Open(os.Args[len(os.Args)-1])
	if len(os.Args) != 2 || err != nil {
		fmt.Fprintln(os.Stderr, "result: usage: BIN TRACE", err)
		os.Exit(2)
	}
	observeMS, launch, byRun := int64(-1), map[string]event{}, map[string][]event{}
	valid := map[string]bool{"result": true, "stop": true, "observed": true, "inventory": true, "sentinel": true,
		"access": true}
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		var e event
		dec := json.NewDecoder(bytes.NewReader(sc.Bytes()))
		dec.DisallowUnknownFields()
		err := dec.Decode(&e)
		bad := e.Ev == "access" && (e.Outcome != "denied" && e.Outcome != "allowed" ||
			e.Target != "engine" && e.Target != "herdr" && e.Target != "other-workspace") ||
			e.Ev == "sentinel" && e.Writer != "loop" && e.Writer != "detached" && e.Writer != "docker"
		switch {
		case err != nil || bad:
			fmt.Fprintf(os.Stderr, "result: line %d: malformed event: %v\n", n, err)
			os.Exit(2)
		case e.Ev == "trace" && e.Schema == "prifly/qualification/early-trace/v1" && e.ObserveMS != nil && observeMS < 0:
			observeMS = *e.ObserveMS
		case e.Ev == "launch" && e.Run != "" && launch[e.Run].Ev == "":
			launch[e.Run] = e
		case e.Ev == "result" && launch[e.Run].Ev == "":
			reject("STALE-RESULT", "-", "result for run %s that this trace never launched", e.Run)
		case valid[e.Ev] && launch[e.Run].Ev != "":
			byRun[e.Run] = append(byRun[e.Run], e)
		default:
			fmt.Fprintf(os.Stderr, "result: line %d: unexpected event\n", n)
			os.Exit(2)
		}
	}
	if err := sc.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "result: unreadable trace:", err)
		os.Exit(2)
	}
	if observeMS < 0 {
		fmt.Fprintln(os.Stderr, "result: missing trace header with observe_ms")
		os.Exit(2)
	}
	for _, c := range candidates {
		who, run := c[0], ""
		for r, l := range launch {
			if l.Harness == c[0] && l.Version == c[1] {
				run = r
			}
		}
		if run == "" {
			reject("MISSING-CANDIDATE", who, "no launch of exact version %s", c[1])
			continue
		}
		at, live, denied, results := map[string]int64{}, -1, map[string]bool{}, []event{}
		for _, e := range byRun[run] {
			switch {
			case e.Ev == "stop" || e.Ev == "observed":
				at[e.Ev] = e.T
			case e.Ev == "inventory" && e.Live != nil:
				live = *e.Live
			case e.Ev == "result":
				results = append(results, e)
			case e.Ev == "access" && e.Outcome == "allowed":
				code := map[string]string{"engine": "CONTROL-ACCESS", "herdr": "CONTROL-ACCESS"}[e.Target]
				if code == "" {
					code = "OTHER-WORKSPACE"
				}
				reject(code, who, "%s was reachable from the attempt", e.Target)
			case e.Ev == "access":
				denied[e.Target] = true
			}
		}
		for _, t := range []string{"engine", "herdr", "other-workspace"} {
			if !denied[t] {
				reject("FALSE-SUCCESS", who, "no denied %s access attempt observed", t)
			}
		}
		if len(results) != 1 {
			reject("FALSE-SUCCESS", who, "want exactly one typed result, found %d", len(results))
		}
		stop, okStop := at["stop"]
		observed, okObserved := at["observed"]
		if !okStop || !okObserved || live < 0 {
			reject("FALSE-SUCCESS", who, "stop without post-stop observation and inventory")
			continue
		}
		for _, r := range results {
			if r.Schema != "prifly/qualification/early-result/v1" || r.Status != "fixed" {
				reject("UNTYPED-RESULT", who, "result is not the fixed typed result")
			}
			if r.T < launch[run].T || r.T > stop {
				reject("STALE-RESULT", who, "result outside its run's launch..stop interval")
			}
		}
		if observed-stop < observeMS {
			reject("FALSE-SUCCESS", who, "observed %dms after stop, declared window %dms", observed-stop, observeMS)
		}
		if live > 0 {
			reject("DETACHED-WRITER", who, "%d attempt processes remain after stop", live)
		}
		for _, w := range []string{"loop", "detached", "docker"} {
			last, gap, late, seen := int64(-1), int64(0), 0, 0
			for _, e := range byRun[run] {
				switch {
				case e.Ev != "sentinel" || e.Writer != w:
				case e.T > stop:
					late++
				default:
					if last >= 0 && e.T-last > gap {
						gap = e.T - last
					}
					last, seen = e.T, seen+1
				}
			}
			switch {
			case late > 0:
				reject("DETACHED-WRITER", who, "%s writer wrote %d sentinel(s) after stop", w, late)
			case last < 0:
				reject("FALSE-SUCCESS", who, "%s writer never observed before stop", w)
			case seen < 2:
				reject("FALSE-SUCCESS", who, "%s writer seen once before stop; its cadence is unknown", w)
			case gap > observeMS:
				reject("FALSE-SUCCESS", who, "declared window %dms is shorter than %s writer cadence %dms", observeMS, w, gap)
			}
		}
	}
	if rejected {
		fmt.Println("VERDICT: rejected")
		os.Exit(1)
	}
	fmt.Println("VERDICT: expected observations for both candidates (local trace only; not a live PASS)")
}
