//go:build ignore

// Local evaluator of a Q13 publication trace: reads the procedure, the trace and the fixture.go beside the
// procedure, nothing else (go build -o BIN fixture.go; BIN PROCEDURE TRACE). It prints every latency and
// failure; a failure or timeout ranks as a failure and is never dropped. Exit 0: every run meets the fixed
// thresholds (feasibility evidence only, never a Q13 PASS); 1: one "REJECT <CODE> run <r> n <N>: <reason>"
// line per finding; 3: a trace with no finding misses a threshold; 2: usage error, unreadable or over-size
// file, or a procedure or trace outside this grammar (the input layer; semantic checks read only its result).
// Grammar. The procedure equals fixed below. Both files are valid UTF-8 JSON with no string escape
// that is a lone surrogate. The trace is lines split at "\n", one final "\n" optional; each line is
// one JSON object, with only JSON whitespace around it, no duplicate key and exactly the keys of its
// known event ev (keys below, exact case); a grant carrying a ticket is a renewal and carries the
// renewal keys; a plan line is one probe plan call's remote use. Every number is an unsigned integer
// literal in 0..2^53-1 (so -0 is refused); every string is non-empty, except that a published entry's
// reason is empty and a failed entry leaves its reason non-empty and may leave its result strings
// (results below) empty; outcome is published or failed. Line 1, and no other, is the trace header; an
// empty trace or a blank line is malformed.
// Semantics. Grants are in time order: the first a plain grant, every later one a renewal, a ticketed entry
// reserved inside the grant it renews, carrying a command's synced T, lineage and integrity when it published. A
// renewal may fail: it then opens no grant (t and deadline 0) and blocks the lane for the rest of the run, so no
// entry after it publishes, and it is a failure of an honest run, not a rejected trace.
// Lane clocks (ms, one clock, 0 = step not reached): ticket ≤ commitStart ≤ … ≤ casEnd ≤ ack. Commands
// and renewals share one lane in ticket order: each ticket is at or after the previous entry's ack; commands
// enter in schedule order; a renewal is a published command in the same sequence space (C3), so a published
// command n restores and CASes sequence n plus the renewals before it, and a renewal the sequence after the
// entry before it (the frontier never moves backwards, C3 step 2); a failed entry records no clock after its
// first 0; and no published step lasts over stepTimeoutS. No minimum step duration is set (no cited doc
// names one). Use: a ticketed entry records the reservation charged before its first step — bytes, writes and
// requests, each ≥1, within the ticket maxima — and the bytes, writes and requests it then used, each ≥1 when it
// published. A failure keeps the whole charge (already precharged finite tickets are resolved or charged fully
// unknown, P12b L75), so a failed ticketed entry records exactly its reservation, and is held to ≥1 apiece by
// that floor; an entry outside a ticket records neither use nor reservation. Grant lines are the
// control/recovery grants of #252 ruling 5714969372: each lasts at most grant.ms and has its own P12b control
// maxima, never reused or refilled (item 2); a ticket, or a plan call at its clock t, is charged to the last
// grant live at that clock. The fixture step is a run's first ticketed entry, with t0 as its ticket (ruling
// 5716255116 item 1): the run line names the last grant live at t0, and its use is held to the ticket maxima and
// charged to that grant and to P12a. It records no reservation, because it can never be recorded failed: a
// fixture step that fails ends the run with no trace. A plan line names its grant (index in the run's grant
// order, 0 the plain grant), records no writes, and its bytes and requests count in that grant's maxima and in
// P12a (5714969372 item 1). Each ticketed entry has one plan call of its own (5714969372 item 4) inside its
// window (5716255116 item 2): from the previous entry's ack (a failed entry's last clock; t0 for the fixture
// step and the first lane entry) up to its ticket, both inclusive. Plans pair with entries in clock order, so a
// plan before its entry's window, or a second plan for one entry, serves no entry, and entries sharing one plan
// leave one without. A failed command keeps its sequence number n (5714969372 item 3). Sums saturate, so the
// P12a envelope (the header's prior cumulative usage, plan calls, fixture steps, commands, renewals) and the
// per-grant maxima cannot wrap.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"
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
	Grant, Control, Ticket, Envelope                                    limits
	Thresholds                                                          struct{ P95Ms, MaxMs, BurstMs int64 }
}

// fixed is the only procedure accepted, value for value from docs/reference/deployment-parameters.md:
// litestream and casMinSpacingMs P4 L63; envelope P12a L74; grant, control and ticket P12b L75; runs, cadence,
// duration, burst count and thresholds P13 L76; seed and database bytes L91; mix sizes and burst minute
// L95; warm-up L97. This trace contract's own: the schema, sources, the 120 s step timeout, and the mix
// kind labels, its names for L95's four command categories in order (package/annotation revision update,
// attempt/result transition, Finding/review result update, target or command-reconciliation update).
var fixed = procedure{Schema: "prifly/qualification/early-publication/v1", Litestream: "0.5.17", Seed: 9216, Runs: 3,
	Sources:    "docs/reference/deployment-parameters.md P4, P12a, P12b, P13 fixed fixture and measurement method; D3 contract C3",
	DbMinBytes: 48 << 20, DbMaxInitialBytes: 52 << 20, DbMaxBytes: 64 << 20, StepTimeoutS: 120,
	WarmupMs: 5 * 60000, DurationMs: 30 * 60000, CadenceMs: 15000, CasMinSpacingMs: 1100,
	Burst: struct{ AtMs, Count int64 }{15 * 60000, 10}, Thresholds: struct{ P95Ms, MaxMs, BurstMs int64 }{10000, 30000, 120000},
	Mix:   []slot{{"package-revision", 256 << 10}, {"attempt-result", 1 << 20}, {"finding-review", 64 << 10}, {"target-reconciliation", 16 << 10}},
	Grant: limits{10 * 60000, 1 << 30, 4096, 10000}, Control: limits{0, 768 << 20, 3072, 24576},
	Ticket: limits{0, 256 << 20, 1024, 8192}, Envelope: limits{0, 8 << 30, 0, 100000}}

// Size guards of this layer, not authority values: the fixed workload is 150 commands a run (warm-up
// and duration at the 15 s cadence plus the burst of 10, L76/L97) over three runs, about 450 command
// lines of under 1 KiB each, so 4,096 lines of at most 4,096 bytes bound memory with ample headroom:
// the whole trace is read under its byte bound, and each line's length is checked before it is decoded.
const maxLines, maxLine, maxProcedure = 4096, 4096, 1 << 16

type clocks struct {
	Ticket, CommitStart, CommitEnd, SyncStart, SyncEnd, RestoreStart, RestoreEnd, CasStart, CasEnd, Ack int64
}

type event struct {
	clocks
	Ev, Schema, Prefix, Lineage, Generator, Litestream, Kind, Outcome, Reason                  string
	ProcedureSha256, RunnerSha256, EvaluatorSha256, ProbeSha256, ManifestSha256                string
	Before, After, PayloadSha256, RestoredPayloadSha256, Txid, RestoreTxid, CasTxid, Integrity string
	Run, N, Seed, DbBytes, T0, T, Deadline, Arrival, Submit, PriorBytes, PriorRequests         int64
	PayloadBytes, RestoredSeq, CasSeq, Bytes, Writes, Requests, Grant                          int64
	ReservedBytes, ReservedWrites, ReservedRequests                                            int64
	renewal                                                                                    bool
}

const lane = " ticket commitStart commitEnd syncStart syncEnd restoreStart restoreEnd casStart casEnd ack"

// reserved is the ticket a ticketed lane entry reserved, and was charged, before its first step.
const reserved = " reservedBytes reservedWrites reservedRequests"

const renewal = "ev run t deadline outcome reason bytes writes requests txid lineage restoreTxid restoredSeq integrity casSeq casTxid" + lane + reserved

// results are the strings a failed command, which never reached its result, may leave empty.
const results = " after txid lineage restoreTxid restoredPayloadSha256 integrity casTxid "

var keys = map[string]string{
	"trace": "ev schema procedureSha256 runnerSha256 evaluatorSha256 probeSha256 manifestSha256 priorBytes priorRequests",
	"run":   "ev run t0 grant prefix lineage generator seed litestream dbBytes bytes writes requests",
	"grant": "ev run t deadline",
	"plan":  "ev run t grant bytes writes requests",
	"cmd": "ev run n kind arrival submit outcome reason bytes writes requests payloadSha256 payloadBytes before after " +
		"dbBytes txid lineage restoreTxid restoredSeq restoredPayloadSha256 integrity casSeq casTxid" + lane + reserved,
}

type laneEntry struct {
	event
	grant int
	from  int64 // plan window start: the lane clock before this entry (the fixture step, t0 alone, precedes the first)
}

var rejected bool

func check(bad bool, code string, run, n int64, reason string) bool {
	if bad {
		fmt.Printf("REJECT %s run %d n %d: %s\n", code, run, n, reason)
		rejected = true
	}
	return bad
}

// escape reads string escapes left to right; a 6-byte match is a surrogate escape outside a pair.
var escape = regexp.MustCompile(`\\(u[dD][89abAB]..\\u[dD][c-fC-F]..|u[dD][89a-fA-F]..|.)`)

func fail(format string, a ...any) { fmt.Fprintf(os.Stderr, "fixture: "+format+"\n", a...); os.Exit(2) }

func sum(b []byte) string { return fmt.Sprintf("%x", sha256.Sum256(b)) }

// add sums non-negative use, saturating at MaxInt64 instead of wrapping.
func add(a, b int64) int64 { return min(a, math.MaxInt64-b) + b }

// scan fails on an object that holds a key twice, at any depth, and on a number token that is not an
// unsigned integer literal in 0..2^53-1.
func scan(d *json.Decoder) error {
	t, err := d.Token()
	if n, num := t.(json.Number); num {
		_, err = strconv.ParseUint(string(n), 10, 53)
	}
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
		if err := scan(d); err != nil {
			return err
		}
	}
	_, err = d.Token()
	return err
}

// canon renames Go field names to JSON keys (first letter lowered).
func canon(v any) any {
	switch t := v.(type) {
	case []any:
		for i := range t {
			t[i] = canon(t[i])
		}
	case map[string]any:
		m := map[string]any{}
		for k, x := range t {
			m[strings.ToLower(k[:1])+k[1:]] = canon(x)
		}
		return m
	}
	return v
}

// strict decodes doc into v and returns doc as read (loose) and v as re-encoded (round): the two are
// equal only when every key is an exact field name and no field is missing, null or of the wrong type
// (a wrong-typed value leaves its field's zero value, which round then shows). v is filled even when ok
// is false, so ok alone refuses what the byte and token checks refuse.
func strict(doc []byte, v any) (loose, round any, ok bool) {
	_ = json.Unmarshal(doc, v)
	d := json.NewDecoder(bytes.NewReader(doc))
	d.UseNumber()
	if !utf8.Valid(doc) || slices.ContainsFunc(escape.FindAll(doc, -1), func(m []byte) bool { return len(m) == 6 }) ||
		json.Unmarshal(doc, &loose) != nil || scan(d) != nil {
		return nil, nil, false
	}
	out, _ := json.Marshal(v)
	_ = json.Unmarshal(out, &round)
	return loose, canon(round), true
}

// parse reads one trace line under the grammar above.
func parse(line []byte) (e event, ok bool) {
	l, r, ok := strict(line, &e)
	loose, _ := l.(map[string]any)
	round, _ := r.(map[string]any)
	want := strings.Fields(keys[e.Ev])
	if _, ticket := loose["ticket"]; e.Ev == "grant" && ticket {
		want, e.renewal = strings.Fields(renewal), true
	}
	for k := range round {
		if !slices.Contains(want, k) {
			delete(round, k)
		}
	}
	_, outcome := loose["outcome"]
	failed := e.Outcome == "failed"
	ok = ok && keys[e.Ev] != "" && reflect.DeepEqual(loose, round) && (!outcome || failed || e.Outcome == "published")
	for k, x := range loose {
		s, str := x.(string)
		ok = ok && (!str || k == "reason" && (s == "") != failed || k != "reason" && (s != "" || failed && strings.Contains(results, " "+k+" ")))
	}
	return e, ok
}

func main() {
	if len(os.Args) != 3 {
		fail("usage: fixture PROCEDURE TRACE")
	}
	var in [2][]byte
	for i, limit := range []int{maxProcedure, maxLines * (maxLine + 1)} {
		f, err := os.Open(os.Args[i+1])
		b, err2 := io.ReadAll(io.LimitReader(f, int64(limit)+1))
		if in[i] = b; err != nil || err2 != nil || len(b) > limit {
			fail("cannot read procedure or trace within %d bytes", limit)
		}
	}
	var p procedure
	if loose, round, ok := strict(in[0], &p); !ok || !reflect.DeepEqual(loose, round) || !reflect.DeepEqual(p, fixed) {
		fail("procedure is not the fixed P4/P12a/P12b/P13 procedure")
	}
	var arrivals []int64
	for a := int64(0); a < p.WarmupMs+p.DurationMs; a += p.CadenceMs {
		arrivals = append(arrivals, a)
		for k := int64(0); a == p.WarmupMs+p.Burst.AtMs && k < p.Burst.Count; k++ {
			arrivals = append(arrivals, a)
		}
	}
	var head, plans event
	runs, grants, planned, cmds := map[int64]event{}, map[int64][]event{}, map[int64][]event{}, map[[2]int64]event{}
	lines := bytes.Split(bytes.TrimSuffix(in[1], []byte("\n")), []byte("\n"))
	if len(lines) > maxLines {
		fail("trace over %d lines", maxLines)
	}
	for i, line := range lines {
		if len(line) > maxLine {
			fail("malformed trace line %d", i+1) // before any decoding, so parse never sees more than maxLine bytes
		}
		e, ok := parse(line)
		if !ok || (i == 0) != (e.Ev == "trace") {
			fail("malformed trace line %d", i+1)
		}
		check(e.Ev != "trace" && (e.Run < 1 || e.Run > p.Runs), "SEQUENCE", e.Run, e.N, fmt.Sprintf("event outside runs 1..%d", p.Runs))
		switch e.Ev {
		case "trace":
			head = e
		case "run":
			_, dup := runs[e.Run]
			check(dup, "IDENTITY", e.Run, 0, "run recorded twice")
			runs[e.Run] = e
		case "grant":
			grants[e.Run] = append(grants[e.Run], e)
		case "plan":
			plans.Bytes, plans.Requests = add(plans.Bytes, e.Bytes), add(plans.Requests, e.Requests)
			planned[e.Run] = append(planned[e.Run], e)
		case "cmd":
			_, dup := cmds[[2]int64{e.Run, e.N}]
			check(dup, "SEQUENCE", e.Run, e.N, "command recorded twice")
			check(e.N < 1 || e.N > int64(len(arrivals)), "SEQUENCE", e.Run, e.N, "command outside the fixed schedule")
			cmds[[2]int64{e.Run, e.N}] = e
		}
	}
	hex := regexp.MustCompile(`^[0-9a-f]{64}$`)
	subject := []string{head.ProcedureSha256, head.RunnerSha256, head.EvaluatorSha256, head.ProbeSha256, head.ManifestSha256}
	for _, h := range subject {
		check(!hex.MatchString(h), "IDENTITY", 0, 0, "subject identity is not a SHA-256")
	}
	src, err := os.ReadFile(filepath.Join(filepath.Dir(os.Args[1]), "fixture.go")) // unreadable: the trace cannot be bound
	check(err != nil || head.Schema != "prifly/qualification/early-publication-trace/v1" || head.ProcedureSha256 != sum(in[0]) || head.EvaluatorSha256 != sum(src),
		"IDENTITY", 0, 0, "trace is not bound to this procedure file and evaluator source")
	fmt.Printf("SUBJECT procedure %s runner %s evaluator %s probe %s manifest %s\n", subject[0], subject[1], subject[2], subject[3], subject[4])
	seen, first, miss := map[string]bool{}, runs[1], false
	usedBytes, usedRequests := add(head.PriorBytes, plans.Bytes), add(head.PriorRequests, plans.Requests)
	for r := int64(1); r <= p.Runs; r++ {
		ru, ok := runs[r]
		check(!ok || seen[ru.Prefix] || seen[ru.Lineage] || ru.Generator != first.Generator ||
			ru.Seed != p.Seed || ru.Litestream != p.Litestream || ru.DbBytes < p.DbMinBytes || ru.DbBytes > p.DbMaxInitialBytes,
			"IDENTITY", r, 0, "run missing, reused prefix/lineage, or fixture identity/size differs from the procedure")
		check(ok && (ru.Bytes < 1 || ru.Writes < 1 || ru.Requests < 1), "LEDGER", r, 0, "fixture step records no remote use")
		seen[ru.Prefix], seen[ru.Lineage] = true, true
		usedBytes, usedRequests = add(usedBytes, ru.Bytes), add(usedRequests, ru.Requests)
		lane, renewalFailed := []laneEntry{}, false
		for k, g := range grants[r] {
			check(g.Deadline < g.T || g.Deadline-g.T > p.Grant.Ms, "EXPIRED-PERMIT", r, 0, fmt.Sprintf("grant %d ends before it starts or lasts over %dms", k, p.Grant.Ms))
			check(g.renewal != (k > 0), "RENEWAL", r, 0, fmt.Sprintf("grant %d: only a grant after the first is a renewal", k))
			if k > 0 {
				check(g.Ticket < grants[r][k-1].T || g.Ticket > grants[r][k-1].Deadline || g.Outcome == "published" && g.T < g.Ack,
					"RENEWAL", r, 0, fmt.Sprintf("grant %d is not a ticketed publication reserved inside the grant it renews", k))
				if g.Outcome != "published" { // an honest failed renewal, retained: it opens nothing and its run misses
					check(g.T != 0 || g.Deadline != 0, "RENEWAL", r, 0, fmt.Sprintf("grant %d: a failed renewal opens no grant", k))
					fmt.Printf("FAILURE run %d grant %d kind renewal reason %s\n", r, k, g.Reason)
					renewalFailed = true
				}
				check(g.Outcome == "published" && (g.RestoreTxid != g.Txid || g.CasTxid != g.Txid || g.Lineage != ru.Lineage),
					"WRONG-T", r, 0, fmt.Sprintf("grant %d: renewal restore or frontier T/lineage is not the synced T", k))
				check(g.Outcome == "published" && g.Integrity != "ok", "WRONG-RESULT", r, 0, fmt.Sprintf("grant %d: renewal restore integrity is not ok", k))
				lane = append(lane, laneEntry{event: g, grant: k - 1})
			}
		}
		lat, burst, failures := []int64{}, int64(0), int64(0)
		payloads, prev := map[string]bool{}, event{}
		for i, a := range arrivals {
			n, m := int64(i+1), p.Mix[i%len(p.Mix)]
			c, ok := cmds[[2]int64{r, n}]
			if check(!ok, "DROPPED", r, n, "command missing; every latency, failure and timeout is retained") {
				continue
			}
			check(c.Kind != m.Kind || c.Arrival != a || c.Submit != ru.T0+a || (c.Ticket != 0 && c.Ticket < c.Submit),
				"SCHEDULE", r, n, "kind, arrival or submission clock is not the fixed schedule")
			usedBytes, usedRequests = add(usedBytes, c.Bytes), add(usedRequests, c.Requests)
			gi := -1
			for k, g := range grants[r] {
				if c.Ticket > 0 && g.T <= c.Ticket && c.Ticket <= g.Deadline {
					gi = k
				}
			}
			if gi >= 0 {
				lane = append(lane, laneEntry{event: c, grant: gi})
			}
			check(gi < 0 && (c.clocks != clocks{} || c.Outcome == "published" || c.Bytes != 0 || c.Writes != 0 || c.Requests != 0 ||
				c.ReservedBytes != 0 || c.ReservedWrites != 0 || c.ReservedRequests != 0),
				"EXPIRED-PERMIT", r, n, fmt.Sprintf("remote use or publication without a ticket inside a live grant of at most %dms", p.Grant.Ms))
			l := int64(math.MaxInt64)
			if c.Outcome == "published" {
				check(c.After == c.Before || !hex.MatchString(c.PayloadSha256) || c.PayloadBytes != m.PayloadBytes || payloads[c.PayloadSha256] ||
					(prev.After != "" && prev.After != c.Before), "NO-OP", r, n, "no state change, replayed or resized payload, or broken state chain")
				check(c.DbBytes < 1 || c.DbBytes > p.DbMaxBytes, "IDENTITY", r, n, fmt.Sprintf("database size missing or over %d bytes", p.DbMaxBytes))
				payloads[c.PayloadSha256], prev = true, c
				check(c.RestoreTxid != c.Txid || c.CasTxid != c.Txid || c.Lineage != ru.Lineage,
					"WRONG-T", r, n, "restore or frontier T/lineage is not the synced T")
				check(c.Integrity != "ok" || c.RestoredPayloadSha256 != c.PayloadSha256,
					"WRONG-RESULT", r, n, "restored database does not hold the exact command result")
				l = c.Ack - c.Submit
				fmt.Printf("LATENCY run %d n %d kind %s arrival %d ms %d\n", r, n, c.Kind, a, l)
			} else {
				fmt.Printf("FAILURE run %d n %d kind %s arrival %d reason %s\n", r, n, c.Kind, a, c.Reason)
			}
			if a >= p.WarmupMs {
				lat, failures = append(lat, l), failures+l/math.MaxInt64
			}
			if i > 0 && a == p.WarmupMs+p.Burst.AtMs && arrivals[i-1] == a {
				burst = max(burst, l)
			}
		}
		sort.SliceStable(lane, func(i, j int) bool { return lane[i].Ticket < lane[j].Ticket })
		free, lastCas, lastN, renewals, use := int64(0), int64(math.MinInt64/2), int64(0), int64(0), make([]limits, len(grants[r]))
		blocked := false
		for i, e := range lane {
			lane[i].from = free
			published, reached, last := e.Outcome == "published", true, e.Ticket
			check(blocked && published, "RENEWAL", r, e.N, "entry published after a failed renewal blocked the lane")
			blocked = blocked || e.renewal && !published
			if e.N > 0 {
				check(e.N <= lastN, "OLD-FRONTIER", r, e.N, fmt.Sprintf("command entered the lane after command %d; the frontier moved backwards", lastN))
				lastN = e.N
			}
			want := e.N + renewals
			if e.renewal {
				renewals++
				want = lastN + renewals
			}
			for _, seq := range []int64{e.RestoredSeq, e.CasSeq} {
				check(published && seq < want, "OLD-FRONTIER", r, e.N, fmt.Sprintf("restore or frontier at sequence %d", seq))
				check(published && seq > want, "LATER-FRONTIER", r, e.N, fmt.Sprintf("restore or frontier at sequence %d", seq))
			}
			for _, t := range []int64{e.Ticket, e.CommitStart, e.CommitEnd, e.SyncStart, e.SyncEnd, e.RestoreStart, e.RestoreEnd, e.CasStart, e.CasEnd} {
				reached = reached && (t != 0 || published)
				check(reached && t < free || !reached && t != 0, "LANE", r, e.N, "step clock out of lane order; commands run one at a time")
				check(published && t-last > p.StepTimeoutS*1000, "STEP-TIMEOUT", r, e.N, fmt.Sprintf("a published step lasted over %ds", p.StepTimeoutS))
				free, last = max(free, t), t
			}
			check(published && e.Ack < e.CasEnd, "EARLY-ACK", r, e.N, "acknowledged before the frontier CAS result")
			free = max(free, e.Ack)
			if e.CasStart != 0 {
				check(e.CasStart-lastCas < p.CasMinSpacingMs, "PACING", r, e.N, fmt.Sprintf("CAS write under %dms after the previous one", p.CasMinSpacingMs))
				lastCas = e.CasStart
			}
			check(e.Bytes > p.Ticket.Bytes || e.Writes > p.Ticket.Writes || e.Requests > p.Ticket.Requests,
				"LEDGER", r, e.N, "remote use exceeds the pre-send ticket")
			check(e.ReservedBytes > p.Ticket.Bytes || e.ReservedWrites > p.Ticket.Writes || e.ReservedRequests > p.Ticket.Requests,
				"LEDGER", r, e.N, "reservation exceeds the pre-send ticket")
			check(published && (e.Bytes < 1 || e.Writes < 1 || e.Requests < 1), "LEDGER", r, e.N, "publication records no remote use")
			check(e.Ticket != 0 && (e.ReservedBytes < 1 || e.ReservedWrites < 1 || e.ReservedRequests < 1),
				"LEDGER", r, e.N, "ticketed entry records no reservation")
			check(!published && e.Ticket != 0 && (e.Bytes != e.ReservedBytes || e.Writes != e.ReservedWrites || e.Requests != e.ReservedRequests),
				"LEDGER", r, e.N, "failed ticketed entry does not record its reservation, which is charged in full")
			u := &use[e.grant]
			u.Bytes, u.Writes, u.Requests = add(u.Bytes, e.Bytes), add(u.Writes, e.Writes), add(u.Requests, e.Requests)
		}
		ts, got := []int64{}, 0
		for _, e := range planned[r] {
			gi := -1
			for k, g := range grants[r] {
				if g.T <= e.T && e.T <= g.Deadline {
					gi = k
				}
			}
			check(e.Writes > 0, "LEDGER", r, 0, "plan call records writes")
			if !check(int64(gi) != e.Grant, "EXPIRED-PERMIT", r, 0, "plan call outside the live grant it names") {
				u := &use[gi]
				u.Bytes, u.Requests = add(u.Bytes, e.Bytes), add(u.Requests, e.Requests)
			}
			ts = append(ts, e.T)
		}
		gi := -1
		for k, g := range grants[r] {
			if g.T <= ru.T0 && ru.T0 <= g.Deadline {
				gi = k
			}
		}
		check(ok && (ru.Bytes > p.Ticket.Bytes || ru.Writes > p.Ticket.Writes || ru.Requests > p.Ticket.Requests), "LEDGER", r, 0, "fixture step exceeds the pre-send ticket")
		if !check(ok && int64(gi) != ru.Grant, "EXPIRED-PERMIT", r, 0, "fixture step outside the grant it names, live at t0") && ok {
			u := &use[gi]
			u.Bytes, u.Writes, u.Requests = add(u.Bytes, ru.Bytes), add(u.Writes, ru.Writes), add(u.Requests, ru.Requests)
		}
		slices.Sort(ts)
		for _, e := range append([]laneEntry{{event: event{clocks: clocks{Ticket: ru.T0}}, from: ru.T0}}, lane...) {
			for ; got < len(ts) && ts[got] < e.from; got++ {
				check(true, "PLAN", r, e.N, "plan call serves no entry: before this entry's window, or a second plan for the entry before")
			}
			if !check(got == len(ts) || ts[got] > e.Ticket, "PLAN", r, e.N, "no plan call of its own from the previous entry's ack (or t0) up to its ticket") {
				got++
			}
		}
		for ; got < len(ts); got++ {
			check(true, "PLAN", r, 0, "plan call serves no entry: after the run's last ticketed entry, or a second plan for it")
		}
		for k, u := range use {
			check(u.Bytes > p.Control.Bytes || u.Writes > p.Control.Writes || u.Requests > p.Control.Requests,
				"LEDGER", r, 0, fmt.Sprintf("grant %d ticket and plan use exceeds the P12b control/recovery grant maxima", k))
			if k > 0 {
				usedBytes, usedRequests = add(usedBytes, grants[r][k].Bytes), add(usedRequests, grants[r][k].Requests)
			}
		}
		if check(len(lat) == 0, "DROPPED", r, 0, "no measured command") {
			continue
		}
		sort.Slice(lat, func(i, j int) bool { return lat[i] < lat[j] })
		p95, worst := lat[int(math.Ceil(0.95*float64(len(lat))))-1], lat[len(lat)-1]
		meets := p95 <= p.Thresholds.P95Ms && worst <= p.Thresholds.MaxMs && burst <= p.Thresholds.BurstMs && !renewalFailed
		miss = miss || !meets
		fmt.Printf("RUN %d measured %d failures %d p95 %d max %d burst %d meets %t\n", r, len(lat), failures, p95, worst, burst, meets)
	}
	check(usedBytes > p.Envelope.Bytes || usedRequests > p.Envelope.Requests, "LEDGER", 0, 0, "trace exceeds the P12a envelope (prior use, plan calls, fixture steps, commands and renewals)")
	switch {
	case rejected:
		fmt.Println("VERDICT: trace rejected; no feasibility result")
		os.Exit(1)
	case miss:
		fmt.Println("VERDICT: a run misses a fixed publication threshold; feasibility evidence only")
		os.Exit(3)
	}
	fmt.Println("VERDICT: every run meets the fixed publication thresholds; feasibility evidence only, not a Q13 PASS")
}
