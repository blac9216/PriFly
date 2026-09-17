// Work Item content checks: the kind, consumers and dependencies read from
// each WorkItem/v1 artifact's bytes, and the dependency graph over them (C1
// "acyclic dependencies"; "SLICE or justified ENABLER with named consumers").
// Only these fields are read; structural validation of the rest is #181.

package bundle

import (
	"fmt"
	"slices"
	"strings"
)

// edge is a reference from a Work Item's content to a Work Item ID; list and k
// locate it, and its path is built only when it is reported.
type edge struct {
	list string // "dependencies" or "consumers"
	k    int
	id   string // "" when absent or invalid
}

func (e edge) path(p string) string {
	if e.list == "consumers" {
		return fmt.Sprintf("%s.content.consumers[%d]", p, e.k)
	}
	return fmt.Sprintf("%s.content.dependencies[%d].work_item", p, e.k)
}

// body is the references read from one distinct content, reported at path, the
// first Work Item entry naming those bytes; next is the position in deps of
// the first dependency left after removal, found once for every walk.
type body struct {
	path        string
	deps, users []edge
	next        int
}

// workItem is one WorkItem/v1 artifact entry at path with its ID ("" when
// invalid) and the index of its bytes' body (-1 when they were not read).
type workItem struct {
	path, id string
	body     int
}

// workItems holds the Work Item entries and the bodies they name, parsed once
// per SHA-256 of exact bytes: entries sharing bytes share their references and
// diagnostics, so memory is linear in the bundle's bytes, not entries × bytes.
type workItems struct {
	items  []workItem
	bodies []body
	digest map[string]int
}

// read returns the index of the body of content, whose SHA-256 is digest, at
// the Work Item entry path p, reading it only the first time those bytes are seen.
func (w *workItems) read(c *checker, p, digest string, content []byte) int {
	if b, seen := w.digest[digest]; seen {
		return b
	}
	w.digest[digest], w.bodies = len(w.bodies), append(w.bodies, c.body(p, content))
	return len(w.bodies) - 1
}

// body reads kind, dependencies and, for an ENABLER, consumers from the
// artifact content at path p (reported as p.content).
func (c *checker) body(p string, content []byte) body {
	b, cp := body{path: p}, p+".content"
	doc, ok := DecodeJSON(content)
	m, isObject := doc.(map[string]any)
	if !ok || !isObject {
		c.add(cp, "invalid-content", "want one JSON object with unique keys and exact strings")
		return b
	}
	for _, key := range []string{"kind", "dependencies"} {
		if _, present := m[key]; !present {
			c.add(cp+"."+key, "missing-field", "required field is absent")
		}
	}
	for k, d := range c.list(m, cp, "dependencies") {
		dp := fmt.Sprintf("%s.dependencies[%d]", cp, k)
		if o, isObject := d.(map[string]any); !isObject {
			c.add(dp, "invalid-type", "want object")
		} else if _, present := o["work_item"]; !present {
			c.add(dp+".work_item", "missing-field", "required field is absent")
		} else {
			b.deps = append(b.deps, edge{"dependencies", k, c.idValue(o["work_item"], dp+".work_item", "wi")})
		}
	}
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

// graph rejects a dependency or consumer naming no Work Item in the bundle and
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
