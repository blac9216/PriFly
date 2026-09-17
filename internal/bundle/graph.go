// Work Item content checks: the kind, consumers, dependencies and outcomes read
// from each WorkItem/v1 artifact's bytes, and the dependency graph over them (C1
// "acyclic dependencies"; "SLICE or justified ENABLER with named consumers";
// "explicit dependency conditions"; "coverage of all outcomes"; "finite
// envelopes"), and one Work Item per execution envelope. Only these fields are
// read; the rest of each artifact is not validated structurally here.

package bundle

import (
	"fmt"
	"slices"
	"strings"
)

// edge is a reference from a Work Item's content to a Work Item ID or, in
// outcomes or execution_envelope, the ID of an artifact of the schema named in
// resolves; list and k locate it, and its path is built only when it is
// reported.
type edge struct {
	list string // "dependencies", "consumers", "outcomes" or "execution_envelope"
	k    int
	id   string // "" when absent or invalid
}

func (e edge) path(p string) string {
	switch e.list {
	case "consumers":
		return fmt.Sprintf("%s.content.consumers[%d]", p, e.k)
	case "outcomes":
		return fmt.Sprintf("%s.content.outcomes[%d].baseline", p, e.k)
	case "execution_envelope":
		return p + ".content.execution_envelope"
	}
	return fmt.Sprintf("%s.content.dependencies[%d].work_item", p, e.k)
}

// resolves maps an edge list naming a non-Work-Item artifact to that artifact's
// schema and the code reported when no entry of that schema has the ID.
var resolves = map[string][2]string{"outcomes": {"Baseline/v1", "unresolved-baseline"},
	"execution_envelope": {"ExecutionEnvelope/v1", "unresolved-envelope"}}

// body is the references read from one distinct content, reported at path, the
// first Work Item entry naming those bytes; slice is whether its kind is SLICE;
// envelope is the valid execution_envelope ID, and known is whether the content
// is an object naming one.
type body struct {
	path, envelope         string
	deps, users, artifacts []edge
	slice, known           bool
}

// workItem is one WorkItem/v1 artifact entry at path with its ID ("" when
// invalid) and the index of its bytes' body (-1 when they were not read).
type workItem struct {
	path, id string
	body     int
}

// workItems holds the Work Item entries and the bodies they name, the schema
// and ID of every artifact entry, the first ExecutionEnvelope/v1 entry of each
// ID, and whether an entry of an unsupported WorkItem schema version, which may
// be a Work Item, exists, and the artifact bytes left to read (negative once
// MaxArtifactBytes is passed). Content is parsed once per schema and SHA-256 of exact bytes: entries
// sharing bytes share their references and diagnostics, so memory is linear in
// the bundle's bytes, not entries × bytes.
type workItems struct {
	items     []workItem
	bodies    []body
	digest    map[string]int
	schemaIDs map[string]bool // schema + " " + ID
	envelopes []identity
	unknown   bool
	left      int
}

// read checks content of schema, whose SHA-256 is digest, at the entry path p
// only the first time that schema and those bytes are seen. It returns the
// index of a Work Item's body, else -1.
func (w *workItems) read(c *checker, p, schema, digest string, content []byte) int {
	if b, seen := w.digest[schema+" "+digest]; seen {
		return b
	}
	b := -1
	switch schema {
	case "WorkItem/v1":
		b, w.bodies = len(w.bodies), append(w.bodies, c.body(p, content))
	case "ExecutionEnvelope/v1":
		c.envelope(p, content)
	case "QualityEvaluation/v1":
		c.evaluation(p, content)
	}
	w.digest[schema+" "+digest] = b
	return b
}

// body reads kind, dependencies, outcomes, execution_envelope and, for an
// ENABLER, consumers from the artifact content at path p (reported as
// p.content). A Work Item names exactly one ExecutionEnvelope/v1 artifact by ID.
func (c *checker) body(p string, content []byte) body {
	b, cp, m := body{path: p}, p+".content", c.content(p, content)
	if m == nil {
		return b
	}
	for _, key := range []string{"kind", "dependencies"} {
		if _, present := m[key]; !present {
			c.add(cp+"."+key, "missing-field", "required field is absent")
		}
	}
	for k, d := range c.list(m, cp, "dependencies") {
		dp := fmt.Sprintf("%s.dependencies[%d]", cp, k)
		o, isObject := d.(map[string]any)
		if !isObject {
			c.add(dp, "invalid-type", "want object")
			continue
		}
		if _, present := o["work_item"]; !present { // its condition is checked once it names one
			c.add(dp+".work_item", "missing-field", "required field is absent")
			continue
		}
		b.deps = append(b.deps, edge{"dependencies", k, c.idValue(o["work_item"], dp+".work_item", "wi")})
		c.text(o, dp, "condition", "missing-condition", "dependency states no condition")
	}
	outcomes := c.list(m, cp, "outcomes")
	if len(outcomes) == 0 {
		c.add(cp+".outcomes", "orphan-work-item", "Work Item names no outcome traced to a baseline obligation")
	}
	for k, o := range outcomes {
		op := fmt.Sprintf("%s.outcomes[%d]", cp, k)
		om, isObject := o.(map[string]any)
		if !isObject {
			c.add(op, "invalid-type", "want object")
			continue
		}
		if _, present := om["baseline"]; !present { // its obligation is checked once it names one
			c.add(op+".baseline", "orphan-outcome", "outcome names no baseline obligation")
			continue
		}
		b.artifacts = append(b.artifacts, edge{"outcomes", k, c.idValue(om["baseline"], op+".baseline", "bsl")})
		c.text(om, op, "obligation", "orphan-outcome", "outcome names no baseline obligation")
	}
	if _, present := m["execution_envelope"]; !present {
		c.add(cp+".execution_envelope", "unbound-work-item", "Work Item names no ExecutionEnvelope/v1 artifact")
	} else {
		b.envelope = c.idValue(m["execution_envelope"], cp+".execution_envelope", "xen")
		b.artifacts, b.known = append(b.artifacts, edge{"execution_envelope", 0, b.envelope}), b.envelope != ""
	}
	b.slice = m["kind"] == "SLICE"
	switch kind, present := m["kind"]; {
	case kind == "ENABLER":
		users := c.list(m, cp, "consumers")
		if len(users) == 0 {
			c.add(cp+".consumers", "unnamed-consumer", "ENABLER names no consuming Work Item")
		}
		for k, u := range users {
			b.users = append(b.users, edge{"consumers", k, c.idValue(u, fmt.Sprintf("%s.consumers[%d]", cp, k), "wi")})
		}
	case present && kind != "SLICE":
		c.add(cp+".kind", "invalid-kind", `want "SLICE" or "ENABLER", got %s`, Quote(kind))
	}
	return b
}

// graph rejects a dependency or consumer naming no Work Item in the bundle, a
// consumer naming a Work Item whose content is read but is not a SLICE, and an
// outcome or execution_envelope naming no entry of its schema, and an
// ExecutionEnvelope/v1 artifact named by several Work Item entries or by none;
// cycles then names one cycle in every cyclic component of the dependencies (C1
// "acyclic dependencies"). A body is a node every entry naming it depends on,
// so shared bytes' edges are held once. Time and memory are linear in the Work
// Items, bodies and body edges; nothing recurses.
func (c *checker) graph(w workItems) {
	items := w.items
	index := map[string]int{}
	for i, it := range items {
		if _, seen := index[it.id]; it.id != "" && !seen {
			index[it.id] = i
		}
	}
	for _, body := range w.bodies {
		for m, e := range slices.Concat(body.deps, body.users) {
			j, found := index[e.id]
			if e.id != "" && !found {
				c.add(e.path(body.path), "unresolved-work-item", "no Work Item in this bundle has ID %s", Quote(e.id))
			} else if found && m >= len(body.deps) && items[j].body >= 0 && !w.bodies[items[j].body].slice {
				c.add(e.path(body.path), "non-slice-consumer", "consumer %s is not a SLICE Work Item", Quote(e.id))
			}
		}
		for _, e := range body.artifacts {
			if r := resolves[e.list]; e.id != "" && !w.schemaIDs[r[0]+" "+e.id] {
				c.add(e.path(body.path), r[1], "no %s artifact in this bundle has ID %s", r[0], Quote(e.id))
			}
		}
	}
	// One envelope binds one Work Item. An entry repeating an earlier Work Item ID
	// is not counted. A binding that names no resolved envelope is unknown: it may
	// have meant any envelope, so while one exists no envelope is reported unnamed.
	named, unknown, counted := map[string]int{}, w.unknown, make([]bool, len(items))
	for i, it := range items {
		if it.body < 0 || !w.bodies[it.body].known {
			unknown = true // unreadable, not an object, or no valid execution_envelope
		} else if e := w.bodies[it.body].envelope; e != "" && !w.schemaIDs["ExecutionEnvelope/v1 "+e] {
			unknown = true // unresolved
		} else {
			first, seen := index[it.id]
			if counted[i] = !seen || first == i; counted[i] {
				named[e]++
			} else if _, found := named[e]; !found {
				named[e] = 0
			}
		}
	}
	for i, it := range items {
		if counted[i] && named[w.bodies[it.body].envelope] > 1 {
			e := w.bodies[it.body].envelope
			c.add(it.path+".content.execution_envelope", "shared-envelope", "ExecutionEnvelope/v1 artifact %s is named by %d Work Items", Quote(e), named[e])
		}
	}
	for _, e := range w.envelopes {
		if _, found := named[e.id]; !found && !unknown {
			c.add(e.path+".id", "orphan-envelope", "no Work Item in this bundle names this ExecutionEnvelope/v1 artifact")
		}
	}
	c.cycles(w, index)
}

// cycles names one cycle in every cyclic component of the dependency graph, so
// one run shows every cycle a producer must break independently.
//
// Node i < n is Work Item entry i and node n+b is body b: an entry depends on
// its body, and a body on the first entry declaring each ID its dependencies
// name. Entries sharing bytes share their body's edges, so nodes and edges stay
// linear in the entries, bodies and body dependencies. Every path alternates
// entry and body nodes, so no node reaches itself in one step: a strongly
// connected component holds a cycle exactly when it holds more than one node,
// and every such component holds an entry.
//
// The components are Tarjan's, found iteratively: frames carries the traversal's
// own stack of nodes and of the dependency each has reached, num the order a
// node was first reached in, low the earliest num reachable from it, and comp
// the component it was assigned. A node is on stack exactly while it is reached
// and unassigned, so no separate flag is kept. Every node and edge is traversed
// once, and the walk that names each cycle stays inside one component, so the
// components partition its steps.
func (c *checker) cycles(w workItems, index map[string]int) {
	items, n := w.items, len(w.items)
	nodes := n + len(w.bodies)
	// next is the first successor of node v at or after cursor k, with the cursor
	// it was found at, or -1 when v has none left.
	next := func(v, k int) (int, int) {
		if v < n {
			if k == 0 && items[v].body >= 0 {
				return n + items[v].body, 0
			}
			return -1, k
		}
		for deps := w.bodies[v-n].deps; k < len(deps); k++ {
			if j, found := index[deps[k].id]; found {
				return j, k
			}
		}
		return -1, k
	}
	type frame struct{ v, k int }
	num, low, comp := make([]int, nodes), make([]int, nodes), make([]int, nodes)
	reached, components, stack, frames, starts := 0, 0, []int{}, []frame{}, []int{}
	for s := range nodes {
		if num[s] > 0 {
			continue
		}
		reached++
		num[s], low[s] = reached, reached
		stack, frames = append(stack, s), append(frames, frame{s, 0})
		for len(frames) > 0 {
			f := len(frames) - 1
			v := frames[f].v
			if t, at := next(v, frames[f].k); t < 0 {
				if frames = frames[:f]; f > 0 { // v is done: its low reaches its parent
					low[frames[f-1].v] = min(low[frames[f-1].v], low[v])
				}
				if low[v] != num[v] {
					continue
				}
				// v roots a component: pop it, and keep the least entry of a component
				// of more than one node to walk a cycle from.
				components++
				least, size := -1, 0
				for u := -1; u != v; {
					u = stack[len(stack)-1]
					stack, comp[u], size = stack[:len(stack)-1], components, size+1
					if u < n && (least < 0 || u < least) {
						least = u
					}
				}
				if size > 1 {
					starts = append(starts, least)
				}
			} else if frames[f].k = at + 1; num[t] == 0 {
				reached++
				num[t], low[t] = reached, reached
				stack, frames = append(stack, t), append(frames, frame{t, 0})
			} else if comp[t] == 0 { // t is on stack, so it reaches v
				low[v] = min(low[v], num[t])
			}
		}
	}
	// Every entry of a cyclic component has a dependency inside it, so a walk
	// along the first one never stops short and, the component being finite,
	// closes on an entry it already walked. Each component is walked once and
	// holds the entries it walks, so the walks cost one step per entry at most.
	walked, pos, via, walk := make([]int, n), make([]int, n), make([]edge, n), []int{}
	for _, s := range starts {
		cur, id := s, comp[s]
		for walk = walk[:0]; walked[cur] != id; {
			walked[cur], pos[cur] = id, len(walk)
			walk = append(walk, cur)
			for _, e := range w.bodies[items[cur].body].deps {
				if j, found := index[e.id]; found && comp[j] == id {
					via[cur], cur = e, j
					break
				}
			}
		}
		cycle := walk[pos[cur]:]
		names := make([]string, 0, len(cycle)+1)
		for _, i := range cycle {
			names = append(names, Quote(items[i].id))
		}
		last := cycle[len(cycle)-1]
		c.add(via[last].path(items[last].path), "dependency-cycle", "Work Items depend in a cycle: %s", strings.Join(append(names, names[0]), " -> "))
	}
}
