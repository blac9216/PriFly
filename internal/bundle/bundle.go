// Manifest checks for <dir>/bundle.json and its artifact files. Inspect reads
// every file through the input-safety layer (input.go), hashes exact bytes and
// reports diagnostics; it never stages, persists or starts anything. Field
// names, ID encodings and schema/job IDs are implementation allocations (RP-18).

package bundle

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
)

// Schema is the only supported manifest schema.
const Schema = "ExternalPlanningBundle/v1"

// artifactSchemas maps each supported artifact schema to its typed-ID prefix.
var artifactSchemas = map[string]string{
	"Baseline/v1": "bsl", "PlanningGraph/v1": "pgr", "ReviewPackage/v1": "rpk",
	"WorkItem/v1": "wi", "Estimate/v1": "est", "ExecutionEnvelope/v1": "xen",
	"ValidationTarget/v1": "vt", "QualityEvaluation/v1": "qev", "PhaseRelease/v1": "rel",
}

// jobs is the supported job/version set: the admitted initial Worker jobs (C5).
var jobs = []string{"implementer.implementation/v1", "implementer.current-correction/v1",
	"reviewer.implementation/v1", "rebaser.semantic-conflict-correction/v1", "validator.target-execution/v1"}

var (
	digestRE   = regexp.MustCompile(`^[0-9a-f]{64}$`)
	idRE       = regexp.MustCompile(`^([a-z]+)_[0-9a-f]{32}$`)
	revisionRE = regexp.MustCompile(`^[1-9][0-9]*$`)
)

// Diagnostic is one field-level finding at a JSON path.
type Diagnostic struct{ Path, Code, Detail string }

func (d Diagnostic) String() string { return d.Code + " " + d.Path + ": " + d.Detail }

// MaxDiagnostics caps the diagnostics a list holds, so a fault-dense manifest
// within MaxFileBytes cannot fill memory or output with them. It is an
// implementation guard: no planning document fixes a value.
const MaxDiagnostics = 1000

// checker collects diagnostics as a heap whose top is the last in order,
// holding at most MaxDiagnostics+1: past that, a diagnostic replaces the top
// only if it comes before it, so what done lists never depends on the order
// diagnostics were added in.
type checker []Diagnostic

func (c *checker) add(path, code, format string, args ...any) {
	d, h := Diagnostic{path, code, fmt.Sprintf(format, args...)}, *c
	i := len(h)
	if i <= MaxDiagnostics { // a new leaf, moved up past each parent before it
		h = append(h, d)
		for ; i > 0 && order(h[(i-1)/2], d) < 0; i = (i - 1) / 2 {
			h[i] = h[(i-1)/2]
		}
	} else if order(d, h[0]) < 0 { // the top, moved down past each child after it
		for i = 0; 2*i+1 < len(h); {
			j := 2*i + 1
			if j+1 < len(h) && order(h[j+1], h[j]) > 0 {
				j++
			}
			if order(h[j], d) <= 0 {
				break
			}
			h[i], i = h[j], j
		}
	} else {
		return
	}
	h[i], *c = d, h
}

// order compares diagnostics by path, then code, then detail.
func order(a, b Diagnostic) int {
	if a.Path != b.Path {
		return strings.Compare(a.Path, b.Path)
	} else if a.Code != b.Code {
		return strings.Compare(a.Code, b.Code)
	}
	return strings.Compare(a.Detail, b.Detail)
}

// done returns c in order and cut to its first MaxDiagnostics, followed by
// incomplete when it held more or complete is false.
func (c checker) done(complete bool) []Diagnostic {
	if slices.SortFunc(c, order); len(c) > MaxDiagnostics {
		c, complete = c[:MaxDiagnostics], false
	}
	if !complete {
		c = append(c, incomplete)
	}
	return c
}

// object returns v as a closed object of schema, reporting unknown and missing
// fields.
func (c *checker) object(v any, path, schema string, keys ...string) map[string]any {
	m, ok := v.(map[string]any)
	if !ok {
		c.add(path, "invalid-type", "want object")
	}
	for k := range m {
		if !slices.Contains(keys, k) {
			c.add(Member(path, k), "unknown-field", "field is not part of %s", schema)
		}
	}
	for _, k := range keys {
		if _, present := m[k]; ok && !present {
			c.add(path+"."+k, "missing-field", "required field is absent")
		}
	}
	return m
}

// str returns a string field; ok is false when it is absent or mistyped.
func (c *checker) str(m map[string]any, path, key string) (string, bool) {
	s, ok := m[key].(string)
	if _, present := m[key]; present && !ok {
		c.add(path+"."+key, "invalid-type", "want string")
	}
	return s, ok
}

// id checks a typed ID with the given type prefix; prefix "" (an unsupported
// artifact schema or a reference) accepts any type prefix. It returns the ID,
// or "" when it is absent or invalid.
func (c *checker) id(m map[string]any, path, key, prefix string) string {
	if _, present := m[key]; !present {
		return ""
	}
	return c.idValue(m[key], path+"."+key, prefix)
}

// idValue is id for the value v at path.
func (c *checker) idValue(v any, path, prefix string) string {
	s, ok := v.(string)
	if g := idRE.FindStringSubmatch(s); !ok {
		c.add(path, "invalid-type", "want string")
	} else if g == nil || prefix != "" && g[1] != prefix {
		if prefix == "" {
			prefix = "<type>"
		}
		c.add(path, "invalid-id", "want %s_<32 lowercase hex>, got %s", prefix, Quote(s))
	} else {
		return s
	}
	return ""
}

// revision checks a revision, returning it, or "" when it is absent or invalid.
func (c *checker) revision(m map[string]any, path, key string) string {
	n, ok := m[key].(json.Number)
	if _, present := m[key]; present && (!ok || !revisionRE.MatchString(n.String())) {
		c.add(path+"."+key, "invalid-revision", "want integer >= 1, got %s", Quote(m[key]))
		return ""
	}
	return n.String()
}

// digest checks a SHA-256 digest, returning it, or "" when absent or invalid.
func (c *checker) digest(m map[string]any, path, key string) string {
	s, ok := c.str(m, path, key)
	if ok && !digestRE.MatchString(s) {
		c.add(path+"."+key, "invalid-digest", "want 64 lowercase hex SHA-256, got %s", Quote(s))
		return ""
	}
	return s
}

// list returns an array field, reporting a mistyped one.
func (c *checker) list(m map[string]any, path, key string) []any {
	l, ok := m[key].([]any)
	if _, present := m[key]; present && !ok {
		c.add(path+"."+key, "invalid-type", "want array")
	}
	return l
}

// identity is an artifact's or a reference's ID+revision+digest at a path; a
// component that is absent or invalid is "" and never compared.
type identity struct{ path, id, revision, digest string }

// ident checks the id, revision and sha256 fields of m at path p.
func (c *checker) ident(m map[string]any, p, prefix string) identity {
	return identity{p, c.id(m, p, "id", prefix), c.revision(m, p, "revision"), c.digest(m, p, "sha256")}
}

// artifact checks one artifacts[] entry at path p, compares the SHA-256 of its
// file's exact bytes, read through readRegular within the artifact bytes left
// (w.left), with the declared digest, and
// returns the artifact's identity and its references' identities; a WorkItem/v1
// entry is added to w with the body read from its bytes, every entry's schema
// and ID, and each first ExecutionEnvelope/v1 ID, are added to w, and
// ExecutionEnvelope/v1 and QualityEvaluation/v1 content is checked.
func (c *checker) artifact(root *os.Root, p string, a any, w *workItems) (self identity, refs []identity) {
	m := c.object(a, p, Schema, "id", "revision", "schema", "path", "sha256", "refs")
	schema, isString := c.str(m, p, "schema")
	prefix, supported := artifactSchemas[schema]
	if isString && !supported {
		c.add(p+".schema", "unsupported-schema", "artifact schema %s is not supported", Quote(schema))
	}
	self = c.ident(m, p, prefix)
	for i, r := range c.list(m, p, "refs") {
		rp := fmt.Sprintf("%s.refs[%d]", p, i)
		if ref := c.ident(c.object(r, rp, Schema, "id", "revision", "sha256"), rp, ""); ref.id != "" {
			refs = append(refs, ref) // closure compares only references with an ID
		}
	}
	isItem, b := schema == "WorkItem/v1", -1
	if schema == "ExecutionEnvelope/v1" && self.id != "" && !w.schemaIDs[schema+" "+self.id] {
		w.envelopes = append(w.envelopes, self)
	}
	if self.id != "" {
		w.schemaIDs[schema+" "+self.id] = true
	}
	// An entry of another WorkItem schema version may be a Work Item.
	w.unknown = w.unknown || !supported && strings.HasPrefix(schema, "WorkItem/")
	defer func() { // an unreadable Work Item is still an entry, with no body
		if isItem {
			w.items = append(w.items, workItem{p, self.id, b})
		}
	}()
	name, ok := c.str(m, p, "path")
	if !ok || w.left < 0 { // no entry past MaxArtifactBytes is read
		return self, refs
	}
	content, reason := readRegular(root, name, min(MaxFileBytes, w.left))
	if w.left -= len(content); w.left < 0 {
		c.add(p+".path", "unreadable-artifact", "%s exceeds the %d-byte cap on artifact bytes read per bundle", Quote(name), MaxArtifactBytes)
		return self, refs
	} else if reason != "" {
		c.add(p+".path", "unreadable-artifact", "%s %s", Quote(name), reason)
		return self, refs
	}
	got := fmt.Sprintf("%x", sha256.Sum256(content))
	if self.digest != "" && got != self.digest {
		c.add(p+".sha256", "digest-mismatch", "declared %s, exact bytes hash to %s", Quote(self.digest), got)
	}
	if isItem || schema == "ExecutionEnvelope/v1" || schema == "QualityEvaluation/v1" {
		b = w.read(c, p, schema, got, content)
	}
	return self, refs
}

// entries checks each artifacts[] entry of list and returns the identities
// closure compares: only artifacts and references with an ID, so an entry
// without one, such as 0 or {}, is checked but not held.
func (c *checker) entries(root *os.Root, list []any, w *workItems) (artifacts, refs []identity) {
	for i, a := range list {
		self, r := c.artifact(root, fmt.Sprintf("$.artifacts[%d]", i), a, w)
		if refs = append(refs, r...); self.id != "" {
			artifacts = append(artifacts, self)
		}
	}
	return artifacts, refs
}

// closure rejects a repeated artifact ID and resolves each reference by ID,
// then compares its revision and digest with the first artifact declaring
// that ID (C1 closure of references; C2 ID+revision+digest).
func (c *checker) closure(artifacts, refs []identity) {
	byID := map[string]identity{}
	for _, a := range artifacts {
		if first, seen := byID[a.id]; a.id != "" && seen {
			c.add(a.path+".id", "duplicate-id", "artifact ID %s is already declared at %s.id", Quote(a.id), first.path)
		} else if a.id != "" {
			byID[a.id] = a
		}
	}
	for _, r := range refs {
		a, found := byID[r.id]
		if r.id != "" && !found {
			c.add(r.path+".id", "unresolved-reference", "no artifact in this bundle has ID %s", Quote(r.id))
		}
		if found && r.revision != "" && a.revision != "" && r.revision != a.revision {
			c.add(r.path+".revision", "reference-revision-mismatch", "reference names %s, artifact %s has revision %s", Quote(json.Number(r.revision)), a.path, Quote(json.Number(a.revision)))
		}
		if found && r.digest != "" && a.digest != "" && r.digest != a.digest {
			c.add(r.path+".sha256", "reference-digest-mismatch", "reference names %s, artifact %s declares %s", Quote(r.digest), a.path, Quote(a.digest))
		}
	}
}

// Inspect reads and validates the bundle in dir without writing. It returns
// diagnostics as checker.done lists them, and the manifest's SHA-256.
func Inspect(dir string) (diags []Diagnostic, manifestSHA256 string) {
	var c checker
	complete := true
	defer func() { diags = c.done(complete) }()
	root, err := os.OpenRoot(dir)
	if err != nil {
		c.add("$", "unreadable-bundle", "bundle directory cannot be opened")
		return
	}
	defer root.Close()
	raw, reason := ReadRegular(root, "bundle.json")
	if reason != "" {
		c.add("$", "unreadable-bundle", "bundle.json %s", reason)
		return
	}
	manifestSHA256 = fmt.Sprintf("%x", sha256.Sum256(raw))
	doc, isJSON := decodeValue(raw)
	if c, complete = faults(raw); !isJSON {
		c.add("$", "invalid-json", "bundle.json is not a single JSON value")
	}
	if len(c) > 0 {
		return
	}
	if m, ok := doc.(map[string]any); ok && m["schema"] != Schema {
		c.add("$.schema", "unsupported-schema", "want %q, got %s", Schema, Quote(m["schema"]))
		return
	}
	top := c.object(doc, "$", Schema, "schema", "bundle_id", "revision", "jobs", "artifacts")
	c.id(top, "$", "bundle_id", "bnd")
	c.revision(top, "$", "revision")
	for i, j := range c.list(top, "$", "jobs") {
		if s, _ := j.(string); !slices.Contains(jobs, s) {
			c.add(fmt.Sprintf("$.jobs[%d]", i), "unsupported-job", "job/version %s is not supported", Quote(j))
		}
	}
	w := workItems{digest: map[string]int{}, schemaIDs: map[string]bool{}, left: MaxArtifactBytes}
	c.closure(c.entries(root, c.list(top, "$", "artifacts"), &w))
	c.graph(w)
	complete = w.left >= 0
	return
}
