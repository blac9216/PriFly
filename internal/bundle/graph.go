// Work Item content checks: the kind, consumers, dependencies and outcomes read
// from each WorkItem/v1 artifact's bytes, and the dependency graph over them (C1
// "acyclic dependencies"; "SLICE or justified ENABLER with named consumers";
// "explicit dependency conditions"; "coverage of all outcomes"). Only these
// fields are read; structural validation of the rest is #181.

package bundle

import (
	"fmt"
	"slices"
	"strings"
)

// edge is a reference from a Work Item's content to a Work Item ID or, in
// outcomes, a Baseline ID; list and k locate it, and its path is built only
// when it is reported.
type edge struct {
	list string // "dependencies", "consumers" or "outcomes"
	k    int
	id   string // "" when absent or invalid
}

func (e edge) path(p string) string {
	switch e.list {
	case "consumers":
		return fmt.Sprintf("%s.content.consumers[%d]", p, e.k)
	case "outcomes":
		return fmt.Sprintf("%s.content.outcomes[%d].baseline", p, e.k)
	}
	return fmt.Sprintf("%s.content.dependencies[%d].work_item", p, e.k)
}

// body is the references read from one distinct content, reported at path, the
// first Work Item entry naming those bytes; slice is whether its kind is SLICE;
// next is the position in deps of the first dependency left after removal,
// found once for every walk.
type body struct {
	path                   string
	deps, users, baselines []edge
	slice                  bool
	next                   int
}

// workItem is one WorkItem/v1 artifact entry at path with its ID ("" when
// invalid) and the index of its bytes' body (-1 when they were not read).
type workItem struct {
	path, id string
	body     int
}

// workItems holds the Work Item entries and the bodies they name, and the IDs
// of the Baseline/v1 entries. Content is parsed once per schema and SHA-256 of
// exact bytes: entries sharing bytes share their references and diagnostics,
// so memory is linear in the bundle's bytes, not entries × bytes.
type workItems struct {
	items     []workItem
	bodies    []body
	digest    map[string]int
	baselines map[string]bool
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

// body reads kind, dependencies, outcomes and, for an ENABLER, consumers from
// the artifact content at path p (reported as p.content).
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
		b.baselines = append(b.baselines, edge{"outcomes", k, c.idValue(om["baseline"], op+".baseline", "bsl")})
		c.text(om, op, "obligation", "orphan-outcome", "outcome names no baseline obligation")
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
// outcome naming no Baseline/v1 entry, and it
// names one cycle per disjoint walk of the dependencies left after removing,
// iteratively, every Work Item whose dependencies are all removed (Kahn). A
// body is a node every entry naming it depends on, so shared bytes' edges are
// held once. Time and memory are linear in the Work Items, bodies and body
// edges; nothing recurses.
func (c *checker) graph(w workItems) {
	items, n := w.items, len(w.items)
	index := map[string]int{}
	for i, it := range items {
		if _, seen := index[it.id]; it.id != "" && !seen {
			index[it.id] = i
		}
	}
	// Node i < n is Work Item entry i; node n+b is body b.
	dependents, pending := make([][]int, n+len(w.bodies)), make([]int, n+len(w.bodies))
	for i, it := range items {
		if it.body >= 0 {
			dependents[n+it.body], pending[i] = append(dependents[n+it.body], i), 1
		}
	}
	for b, body := range w.bodies {
		for m, e := range slices.Concat(body.deps, body.users) {
			j, found := index[e.id]
			if e.id != "" && !found {
				c.add(e.path(body.path), "unresolved-work-item", "no Work Item in this bundle has ID %s", Quote(e.id))
			} else if found && m < len(body.deps) {
				dependents[j], pending[n+b] = append(dependents[j], n+b), pending[n+b]+1
			} else if found && items[j].body >= 0 && !w.bodies[items[j].body].slice {
				c.add(e.path(body.path), "non-slice-consumer", "consumer %s is not a SLICE Work Item", Quote(e.id))
			}
		}
		for _, e := range body.baselines {
			if e.id != "" && !w.baselines[e.id] {
				c.add(e.path(body.path), "unresolved-baseline", "no Baseline/v1 artifact in this bundle has ID %s", Quote(e.id))
			}
		}
	}
	queue := []int{}
	for i := range pending {
		if pending[i] == 0 {
			queue = append(queue, i)
		}
	}
	for len(queue) > 0 {
		for _, d := range dependents[queue[0]] {
			if pending[d]--; pending[d] == 0 {
				queue = append(queue, d)
			}
		}
		queue = queue[1:]
	}
	// Every Work Item left has a dependency left, so a walk along the first one
	// either closes a new cycle or reaches an earlier walk.
	walked, pos, via, walk := make([]int, n), make([]int, n), make([]edge, n), []int{}
	for s := range items {
		cur := s
		for walk = walk[:0]; pending[cur] > 0 && walked[cur] == 0; {
			walked[cur], pos[cur], walk = s+1, len(walk), append(walk, cur)
			for b := &w.bodies[items[cur].body]; b.next < len(b.deps); b.next++ {
				if t, found := index[b.deps[b.next].id]; found && pending[t] > 0 {
					via[cur], cur = b.deps[b.next], t
					break
				}
			}
		}
		if pending[cur] == 0 || walked[cur] != s+1 {
			continue
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
