package bundle

import (
	"fmt"
	"math/rand/v2"
	"runtime"
	"runtime/debug"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"
)

// wiID is the Work Item ID numbered n; a negative n is an ID no entry declares.
func wiID(n int) string {
	if n < 0 {
		return fmt.Sprintf("wi_%032x", uint64(1)<<40-uint64(n))
	}
	return fmt.Sprintf("wi_%032x", n)
}

// entryPath is the path of the n-th Work Item entry.
func entryPath(n int) string { return fmt.Sprintf("$.artifacts[%d]", n) }

// graphOf builds the Work Item entries of a dependency graph: entry i is at
// entryPath(i), declares ID wiID(ids[i]) (wiID(i) when ids is nil, so every
// entry declares its own), and depends, in order, on wiID of each number in
// deps[i]. Entries given the same slice name one body, as entries whose bytes
// are equal do. A body carries nothing but its dependencies, so graph reports
// only what those reach: no outcome, envelope or consumer diagnostic.
func graphOf(deps [][]int, ids []int) workItems {
	w, bodies := workItems{digest: map[string]int{}, schemaIDs: map[string]bool{}}, map[string]int{}
	for i, d := range deps {
		key := fmt.Sprintf("%p %d", d, len(d))
		b, shared := bodies[key]
		if !shared {
			e := body{path: entryPath(i)}
			for k, j := range d {
				e.deps = append(e.deps, edge{"dependencies", k, wiID(j)})
			}
			b, bodies[key] = len(w.bodies), len(w.bodies)
			w.bodies = append(w.bodies, e)
		}
		id := i
		if ids != nil {
			id = ids[i]
		}
		w.items = append(w.items, workItem{entryPath(i), wiID(id), b})
	}
	return w
}

// firstByID maps each ID to the first entry declaring it, as graph does.
func firstByID(ids []int, n int) map[string]int {
	index := map[string]int{}
	for i := range n {
		id := i
		if ids != nil {
			id = ids[i]
		}
		if _, seen := index[wiID(id)]; !seen {
			index[wiID(id)] = i
		}
	}
	return index
}

// cycleNames is the IDs a dependency-cycle diagnostic names, in order, with the
// repeated first one dropped.
func cycleNames(t *testing.T, d Diagnostic) []string {
	t.Helper()
	detail, named := strings.CutPrefix(d.Detail, "Work Items depend in a cycle: ")
	if !named {
		t.Fatalf("%q is not a cycle detail", d.Detail)
	}
	quoted := strings.Split(detail, " -> ")
	names := make([]string, 0, len(quoted))
	for _, q := range quoted {
		name, err := strconv.Unquote(q)
		if err != nil {
			t.Fatalf("cycle names %s, which is not a quoted ID: %v", q, err)
		}
		names = append(names, name)
	}
	if len(names) < 2 || names[0] != names[len(names)-1] {
		t.Fatalf("cycle %q does not return to the ID it starts at", detail)
	}
	return names[:len(names)-1]
}

// TestGraphNamesEveryCyclicComponent pins the exact diagnostics of graphs whose
// components a walk along first dependencies alone does not separate: the first
// subtest is the shape #255 names, two cycles in different components where one
// component's first dependencies lead into the other's, and a walk that stops
// at an entry an earlier walk reached names only the first of them.
func TestGraphNamesEveryCyclicComponent(t *testing.T) {
	cycle := func(entry, k int, ids ...int) Diagnostic {
		names := make([]string, 0, len(ids)+1)
		for _, n := range ids {
			names = append(names, Quote(wiID(n)))
		}
		return Diagnostic{fmt.Sprintf("%s.content.dependencies[%d].work_item", entryPath(entry), k),
			"dependency-cycle", "Work Items depend in a cycle: " + strings.Join(append(names, names[0]), " -> ")}
	}
	sharedBytes := []int{2}
	for label, c := range map[string]struct {
		deps [][]int
		ids  []int
		want []Diagnostic
	}{
		// 0 <-> 1, and 2 <-> 3 whose first dependency enters the first component.
		"entered-component": {deps: [][]int{{1}, {0}, {0, 3}, {2}},
			want: []Diagnostic{cycle(1, 0, 0, 1), cycle(3, 0, 2, 3)}},
		// A self-loop entered by a 2-cycle: the entry a walk stops at is the cycle.
		"entered-self-loop": {deps: [][]int{{0}, {0, 2}, {1}},
			want: []Diagnostic{cycle(0, 0, 0), cycle(2, 0, 1, 2)}},
		// Three components in a chain, each entering the one before it.
		"chained-components": {deps: [][]int{{1}, {0}, {0, 3}, {2}, {2, 5}, {4}},
			want: []Diagnostic{cycle(1, 0, 0, 1), cycle(3, 0, 2, 3), cycle(5, 0, 4, 5)}},
		// Entries 1 and 2 share bytes, so one body carries both their dependencies;
		// only entry 2, which the shared dependency names, is in the cycle.
		"shared-bytes": {deps: [][]int{{1}, sharedBytes, sharedBytes},
			want: []Diagnostic{cycle(2, 0, 2)}},
		// Two cycles in one component: a producer breaking either breaks both, so
		// the component is named once.
		"two-cycles-one-component": {deps: [][]int{{1}, {0, 2}, {1}},
			want: []Diagnostic{cycle(1, 0, 0, 1)}},
		// A repeated dependency is walked once, at the position first naming it.
		"repeated-dependency": {deps: [][]int{{1, 1}, {0, 0}},
			want: []Diagnostic{cycle(1, 0, 0, 1)}},
		// Entry 1 repeats entry 0's ID, so nothing resolves to it and it is in no
		// cycle; the cycle runs through entry 0 and entry 2.
		"repeated-id": {deps: [][]int{{1}, {}, {0}}, ids: []int{0, 0, 1},
			want: []Diagnostic{cycle(2, 0, 0, 1)}},
		// Dependencies no entry declares are reported and close no cycle.
		"unresolved-and-acyclic": {deps: [][]int{{-1}, {0}, {}},
			want: []Diagnostic{{entryPath(0) + ".content.dependencies[0].work_item", "unresolved-work-item",
				"no Work Item in this bundle has ID " + Quote(wiID(-1))}}},
	} {
		t.Run(label, func(t *testing.T) {
			var check checker
			check.graph(graphOf(c.deps, c.ids))
			if got := check.done(true); !slices.Equal(got, c.want) {
				t.Errorf("graph(%v) = %q, want %q", c.deps, got, c.want)
			}
		})
	}
}

// TestGraphNamesEveryCyclicComponentRandom draws 20,000 dependency graphs of 1
// to 9 entries, with self-loops, repeated dependencies, repeated IDs and
// dependencies no entry declares, and checks graph against mutual reachability
// computed here: every component holding a cycle is named exactly once, and
// every cycle named is one the dependencies really close.
func TestGraphNamesEveryCyclicComponentRandom(t *testing.T) {
	rng, components, named := rand.New(rand.NewPCG(255, 1)), 0, 0
	for range 20000 {
		n := 1 + rng.IntN(9)
		deps, ids := make([][]int, n), make([]int, n)
		for i := range n {
			for range rng.IntN(4) {
				deps[i] = append(deps[i], rng.IntN(n+2)-2) // -2 and -1 declare no entry
			}
			if ids[i] = i; i > 0 && rng.IntN(8) == 0 {
				ids[i] = rng.IntN(i) // an entry repeating an earlier entry's ID
			}
		}
		index := firstByID(ids, n)
		// to is the entry a dependency names, or -1 when no entry declares its ID.
		to := func(d int) int {
			if j, found := index[wiID(d)]; found {
				return j
			}
			return -1
		}
		// path[i][j] is a dependency path of one step or more from entry i to entry j.
		path := make([][]bool, n)
		for i := range path {
			path[i] = make([]bool, n)
			for _, d := range deps[i] {
				if j := to(d); j >= 0 {
					path[i][j] = true
				}
			}
		}
		for k := range n {
			for i := range n {
				for j := range n {
					path[i][j] = path[i][j] || path[i][k] && path[k][j]
				}
			}
		}
		// An entry is in a cycle when it reaches itself; the entries that reach each
		// other are one component, named by its least entry.
		// component is the least entry reaching and reached by entry i, naming the
		// component it is in; entries in no cycle are in no cyclic component.
		component := func(i int) int {
			least := i
			for j := range i {
				if path[i][j] && path[j][i] {
					least = min(least, j)
				}
			}
			return least
		}
		want := map[int]bool{}
		for i := range n {
			if path[i][i] {
				want[component(i)] = true
			}
		}
		var check checker
		check.graph(graphOf(deps, ids))
		got := map[int]bool{}
		for _, d := range check.done(true) {
			if d.Code != "dependency-cycle" {
				continue
			}
			names := cycleNames(t, d)
			entries := make([]int, 0, len(names))
			for _, name := range names {
				i, found := index[name]
				if !found {
					t.Fatalf("deps %v ids %v: cycle names %s, which no entry declares", deps, ids, Quote(name))
				}
				entries = append(entries, i)
			}
			for k, i := range entries {
				j := entries[(k+1)%len(entries)]
				if !slices.ContainsFunc(deps[i], func(d int) bool { return to(d) == j }) {
					t.Fatalf("deps %v ids %v: %q names a step from entry %d to entry %d that is not a dependency", deps, ids, d, i, j)
				}
			}
			least, last := component(entries[0]), entries[len(entries)-1]
			if k := slices.IndexFunc(deps[last], func(d int) bool { return to(d) == entries[0] }); d.Path != fmt.Sprintf("%s.content.dependencies[%d].work_item", entryPath(last), k) {
				t.Fatalf("deps %v ids %v: %q is not reported at the dependency closing the cycle", deps, ids, d)
			}
			if got[least] {
				t.Fatalf("deps %v ids %v: the component of entry %d is named twice", deps, ids, least)
			}
			got[least], named = true, named+1
		}
		components += len(want)
		if !sameKeys(want, got) {
			t.Fatalf("deps %v ids %v: named the components of %v, want %v", deps, ids, keys(got), keys(want))
		}
	}
	if components == 0 || components != named {
		t.Errorf("named %d cycles for %d cyclic components", named, components)
	}
	t.Logf("%d cyclic components over 20,000 graphs, each named once", components)
}

// sameKeys reports whether a and b hold the same keys.
func sameKeys(a, b map[int]bool) bool { return len(a) == len(b) && slices.Equal(keys(a), keys(b)) }

// keys is m's keys in order.
func keys(m map[int]bool) []int {
	k := make([]int, 0, len(m))
	for i := range m {
		k = append(k, i)
	}
	return slices.Sorted(slices.Values(k))
}

// ring is n entries depending in one cycle.
func ring(n int) [][]int {
	deps := make([][]int, n)
	for i := range deps {
		deps[i] = []int{(i + 1) % n}
	}
	return deps
}

// pairs is n/2 two-cycles, each entering the one before it: a walk along first
// dependencies alone names only the first of them.
func pairs(n int) [][]int {
	deps := make([][]int, n)
	for i := 0; i+1 < n; i += 2 {
		if deps[i], deps[i+1] = []int{i + 1}, []int{i}; i > 0 {
			deps[i] = []int{i - 2, i + 1}
		}
	}
	return deps
}

// shared is n entries naming one body that depends on every one of them.
func shared(n int) [][]int {
	body, deps := make([]int, n), make([][]int, n)
	for i := range body {
		body[i] = i
	}
	for i := range deps {
		deps[i] = body
	}
	return deps
}

// chain is a tail of n-1 entries into a two-cycle: the longest path a traversal
// of n entries can take.
func chain(n int) [][]int {
	deps := make([][]int, n)
	for i := range n - 1 {
		deps[i] = []int{i + 1}
	}
	deps[n-1] = []int{n - 2}
	return deps
}

// TestGraphCyclesScale runs graph over each shape at two sizes 16 times apart
// and bounds the bytes allocated and the time taken per Work Item at the larger
// size to 2 and 8 times those at the smaller: naming one cycle per component by
// re-walking the graph per component, or re-reading a shared body per entry
// naming it, is quadratic in one or the other.
func TestGraphCyclesScale(t *testing.T) {
	const small, large = 2000, 32000
	for label, shape := range map[string]func(int) [][]int{"ring": ring, "pairs": pairs, "shared": shared, "chain": chain} {
		t.Run(label, func(t *testing.T) {
			perItem := func(n int) (bytes uint64, taken time.Duration) {
				w, want := graphOf(shape(n), nil), 1
				if label == "pairs" {
					want = n / 2
				}
				for run := range 3 {
					var check checker
					var before, after runtime.MemStats
					runtime.GC()
					runtime.ReadMemStats(&before)
					start := time.Now()
					check.graph(w)
					if elapsed := time.Since(start); run == 0 || elapsed < taken {
						taken = elapsed
					}
					runtime.ReadMemStats(&after)
					if run == 0 {
						bytes = (after.TotalAlloc - before.TotalAlloc) / uint64(n)
					}
					cycles := 0
					for _, d := range check.done(true) {
						if d.Code == "dependency-cycle" {
							cycles++
						}
					}
					if cycles != min(want, MaxDiagnostics) {
						t.Fatalf("%s at %d: named %d cycles, want %d", label, n, cycles, min(want, MaxDiagnostics))
					}
				}
				return bytes, taken / time.Duration(n)
			}
			smallBytes, smallTaken := perItem(small)
			largeBytes, largeTaken := perItem(large)
			if largeBytes > 2*smallBytes {
				t.Errorf("%d bytes per Work Item at %d, %d at %d (limit 2x)", largeBytes, large, smallBytes, small)
			}
			if largeTaken > 8*smallTaken {
				t.Errorf("%v per Work Item at %d, %v at %d (limit 8x)", largeTaken, large, smallTaken, small)
			}
			t.Logf("%d bytes and %v per Work Item at %d; %d bytes and %v at %d", smallBytes, smallTaken, small, largeBytes, largeTaken, large)
		})
	}
}

// TestGraphCyclesKeepsStackFlat bounds the goroutine stack graph grows over the
// longest path 100,000 entries can take to 256 KiB, measured with the collector
// off so no stack is shrunk before it is read. A traversal recursing per entry
// would need a frame per step of that path.
func TestGraphCyclesKeepsStackFlat(t *testing.T) {
	defer debug.SetGCPercent(debug.SetGCPercent(-1))
	grown := func(n int) uint64 {
		w := graphOf(chain(n), nil)
		var before, after runtime.MemStats
		ran, hold := make(chan struct{}), make(chan struct{})
		runtime.ReadMemStats(&before)
		go func() {
			var check checker
			check.graph(w)
			close(ran)
			<-hold // the stack the call grew is counted only while its goroutine lives
		}()
		<-ran
		runtime.ReadMemStats(&after)
		close(hold)
		if after.StackInuse < before.StackInuse {
			return 0
		}
		return after.StackInuse - before.StackInuse
	}
	const limit = 256 << 10
	short, long := grown(1000), grown(100000)
	if max(short, long) > limit {
		t.Errorf("graph grew %d bytes of stack over 100,000 entries and %d over 1,000 (limit %d)", long, short, limit)
	}
	t.Logf("graph grew %d bytes of stack over 100,000 entries, %d over 1,000", long, short)
}
