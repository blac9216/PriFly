//go:build ignore

// Input layer of the local Q13 publication evaluator: reads a procedure and a trace and nothing else
// (go build -o BIN fixture.go; BIN PROCEDURE TRACE). Exit 0: the procedure is the fixed one and every
// trace line is well formed, printed as one "INPUT:" line that is no feasibility verdict and no Q13
// PASS; 2: usage error, unreadable file, or a procedure or trace outside this grammar.
// Grammar. The procedure equals fixed below. Each trace line is one JSON object with no duplicate
// key and exactly its event's keys (keys below, exact case); a grant carrying a ticket is a renewal
// and carries the renewal keys. Every number is an integer in 0..2^53-1; every string is non-empty,
// except that a published entry's reason is empty and a failed entry may leave any string but its
// reason empty; outcome is published or failed. Line 1, and no other, is the trace header; an empty
// trace or a blank line is malformed.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"slices"
	"strings"
)

type limits struct {
	Ms, Bytes, Writes, Requests int64 `json:",omitempty"`
}

type slot struct {
	Kind         string
	PayloadBytes int64
}

type procedure struct {
	Schema, Sources, Litestream                                         string
	Seed, Runs, DbMinBytes, DbMaxInitialBytes, DbMaxBytes, StepTimeoutS int64
	WarmupMs, DurationMs, CadenceMs, CasMinSpacingMs                    int64
	Burst                                                               struct{ AtMs, Count int64 }
	Mix                                                                 []slot
	Grant, Ticket, Envelope                                             limits
	Thresholds                                                          struct{ P95Ms, MaxMs, BurstMs int64 }
}

// fixed is the only procedure accepted, value for value from docs/reference/deployment-parameters.md:
// litestream and casMinSpacingMs P4 L63; envelope P12a L74; grant and ticket P12b L75; runs, cadence,
// duration, burst count and thresholds P13 L76; seed and database bytes L91; mix and burst minute L95;
// warm-up L97. The schema, sources and the 120 s step timeout are this trace contract's own.
var fixed = procedure{Schema: "prifly/qualification/early-publication/v1", Litestream: "0.5.17", Seed: 9216, Runs: 3,
	Sources:    "docs/reference/deployment-parameters.md P4, P12a, P12b, P13 fixed fixture and measurement method; D3 contract C3",
	DbMinBytes: 48 << 20, DbMaxInitialBytes: 52 << 20, DbMaxBytes: 64 << 20, StepTimeoutS: 120,
	WarmupMs: 5 * 60000, DurationMs: 30 * 60000, CadenceMs: 15000, CasMinSpacingMs: 1100,
	Burst: struct{ AtMs, Count int64 }{15 * 60000, 10}, Thresholds: struct{ P95Ms, MaxMs, BurstMs int64 }{10000, 30000, 120000},
	Mix:   []slot{{"package-revision", 256 << 10}, {"attempt-result", 1 << 20}, {"finding-review", 64 << 10}, {"target-reconciliation", 16 << 10}},
	Grant: limits{10 * 60000, 1 << 30, 4096, 10000}, Ticket: limits{0, 256 << 20, 1024, 8192}, Envelope: limits{0, 8 << 30, 0, 100000}}

type clocks struct {
	Ticket, CommitStart, CommitEnd, SyncStart, SyncEnd, RestoreStart, RestoreEnd, CasStart, CasEnd, Ack int64
}

type event struct {
	clocks
	Ev, Schema, Prefix, Lineage, Generator, Litestream, Kind, Outcome, Reason                  string
	ProcedureSha256, RunnerSha256, EvaluatorSha256, ProbeSha256, ManifestSha256                string
	Before, After, PayloadSha256, RestoredPayloadSha256, Txid, RestoreTxid, CasTxid, Integrity string
	Run, N, Seed, DbBytes, T0, T, Deadline, Arrival, Submit                                    int64
	PayloadBytes, RestoredSeq, CasSeq, Bytes, Writes, Requests                                 int64
}

const lane = " ticket commitStart commitEnd syncStart syncEnd restoreStart restoreEnd casStart casEnd ack"

const renewal = "ev run t deadline outcome bytes writes requests" + lane

var keys = map[string]string{
	"trace": "ev schema procedureSha256 runnerSha256 evaluatorSha256 probeSha256 manifestSha256",
	"run":   "ev run t0 prefix lineage generator seed litestream dbBytes bytes writes requests",
	"grant": "ev run t deadline",
	"cmd": "ev run n kind arrival submit outcome reason bytes writes requests payloadSha256 payloadBytes before after " +
		"dbBytes txid lineage restoreTxid restoredSeq restoredPayloadSha256 integrity casSeq casTxid" + lane,
}

func fail(format string, a ...any) { fmt.Fprintf(os.Stderr, "fixture: "+format+"\n", a...); os.Exit(2) }

// unique fails on an object that holds a key twice, at any depth.
func unique(d *json.Decoder) error {
	t, err := d.Token()
	if open, _ := t.(json.Delim); err != nil || open != '{' && open != '[' {
		return err
	}
	seen := map[any]bool{}
	for d.More() {
		if t == json.Delim('{') {
			k, _ := d.Token()
			if seen[k] {
				return fmt.Errorf("duplicate key %v", k)
			}
			seen[k] = true
		}
		if err := unique(d); err != nil {
			return err
		}
	}
	_, err = d.Token()
	return err
}

// canon renames Go field names to JSON keys (first letter lowered) and flags a number outside 0..2^53-1.
func canon(v any, bad *bool) any {
	switch t := v.(type) {
	case float64:
		*bad = *bad || t < 0 || t > 1<<53-1
	case []any:
		for i := range t {
			t[i] = canon(t[i], bad)
		}
	case map[string]any:
		m := map[string]any{}
		for k, x := range t {
			m[strings.ToLower(k[:1])+k[1:]] = canon(x, bad)
		}
		return m
	}
	return v
}

// strict decodes doc into v and returns doc as read (loose) and v as re-encoded (round): the two are
// equal only when every key is an exact field name and no field is missing, null or of the wrong type.
func strict(doc []byte, v any) (loose, round any, ok bool) {
	if json.Unmarshal(doc, &loose) != nil || json.Unmarshal(doc, v) != nil || unique(json.NewDecoder(bytes.NewReader(doc))) != nil {
		return nil, nil, false
	}
	out, _ := json.Marshal(v)
	bad := json.Unmarshal(out, &round) != nil
	return loose, canon(round, &bad), !bad
}

// parse reads one trace line under the grammar above.
func parse(line []byte) (e event, ok bool) {
	l, r, ok := strict(line, &e)
	loose, _ := l.(map[string]any)
	round, _ := r.(map[string]any)
	want := strings.Fields(keys[e.Ev])
	if _, ticket := loose["ticket"]; e.Ev == "grant" && ticket {
		want = strings.Fields(renewal)
	}
	for k := range round {
		if !slices.Contains(want, k) {
			delete(round, k)
		}
	}
	_, outcome := loose["outcome"]
	failed := e.Outcome == "failed"
	ok = ok && reflect.DeepEqual(loose, round) && (!outcome || failed || e.Outcome == "published")
	for k, x := range loose {
		s, str := x.(string)
		ok = ok && (!str || k == "reason" && (s == "") != failed || k != "reason" && (s != "" || failed))
	}
	return e, ok
}

func main() {
	if len(os.Args) != 3 {
		fail("usage: fixture PROCEDURE TRACE")
	}
	raw, err := os.ReadFile(os.Args[1])
	trace, err2 := os.ReadFile(os.Args[2])
	if err != nil || err2 != nil {
		fail("cannot read procedure or trace")
	}
	var p procedure
	if loose, round, ok := strict(raw, &p); !ok || !reflect.DeepEqual(loose, round) || !reflect.DeepEqual(p, fixed) {
		fail("procedure is not the fixed P4/P12a/P12b/P13 procedure")
	}
	lines := bytes.Split(bytes.TrimSpace(trace), []byte("\n"))
	for i, line := range lines {
		if e, ok := parse(line); !ok || (i == 0) != (e.Ev == "trace") {
			fail("malformed trace line %d", i+1)
		}
	}
	fmt.Printf("INPUT: fixed procedure and %d well-formed trace lines; no feasibility verdict, not a Q13 PASS\n", len(lines))
}
