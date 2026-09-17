// Package bundle inspects a local external planning bundle, <dir>/bundle.json
// plus artifact files under <dir>: it reads, hashes exact artifact bytes and
// reports diagnostics, and never stages, persists or starts anything. Field
// names, ID encodings and schema/job IDs are implementation allocations (RP-18).
package bundle

import (
	"bytes"
	"cmp"
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

// jobs is the supported job/version set: the admitted initial Worker jobs.
var jobs = []string{"implementer.implementation/v1", "implementer.correction/v1",
	"reviewer.implementation/v1", "rebaser.semantic-conflict-correction/v1", "validator.target-execution/v1"}

var (
	idRE       = regexp.MustCompile(`^([a-z]+)_[0-9a-f]{32}$`)
	digestRE   = regexp.MustCompile(`^[0-9a-f]{64}$`)
	revisionRE = regexp.MustCompile(`^[1-9][0-9]*$`)
)

// Diagnostic is one field-level finding at a JSON path.
type Diagnostic struct{ Path, Code, Detail string }

func (d Diagnostic) String() string { return d.Code + " " + d.Path + ": " + d.Detail }

type checker []Diagnostic

func (c *checker) add(path, code, format string, args ...any) {
	*c = append(*c, Diagnostic{path, code, fmt.Sprintf(format, args...)})
}

// object returns v as a closed object, reporting unknown and missing fields.
func (c *checker) object(v any, path string, keys ...string) map[string]any {
	m, ok := v.(map[string]any)
	if !ok {
		c.add(path, "invalid-type", "want object")
	}
	for k := range m {
		if !slices.Contains(keys, k) {
			c.add(path+"."+k, "unknown-field", "field is not part of %s", Schema)
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

// id checks a typed ID; prefix "" (an unsupported artifact schema) accepts any type prefix.
func (c *checker) id(m map[string]any, path, key, prefix string) {
	s, ok := c.str(m, path, key)
	if g := idRE.FindStringSubmatch(s); ok && (g == nil || prefix != "" && g[1] != prefix) {
		c.add(path+"."+key, "invalid-id", "want %s_<32 lowercase hex>, got %q", cmp.Or(prefix, "<type>"), s)
	}
}

func (c *checker) digest(m map[string]any, path, key string) (string, bool) {
	s, ok := c.str(m, path, key)
	if ok && !digestRE.MatchString(s) {
		c.add(path+"."+key, "invalid-digest", "want 64 lowercase hex SHA-256, got %q", s)
		return s, false
	}
	return s, ok
}

func (c *checker) revision(m map[string]any, path, key string) {
	n, ok := m[key].(json.Number)
	if _, present := m[key]; present && (!ok || !revisionRE.MatchString(n.String())) {
		c.add(path+"."+key, "invalid-revision", "want integer >= 1, got %v", m[key])
	}
}

func (c *checker) list(m map[string]any, path, key string) []any {
	l, ok := m[key].([]any)
	if _, present := m[key]; present && !ok {
		c.add(path+"."+key, "invalid-type", "want array")
	}
	return l
}

// Inspect reads and validates the bundle in dir without writing. It returns
// diagnostics sorted by path then code, and the manifest's SHA-256.
func Inspect(dir string) (diags []Diagnostic, manifestSHA256 string) {
	var c checker
	defer func() {
		slices.SortFunc(c, func(a, b Diagnostic) int { return strings.Compare(a.Path+"\x00"+a.Code, b.Path+"\x00"+b.Code) })
		diags = c
	}()
	root, err := os.OpenRoot(dir)
	var raw []byte
	if err == nil {
		defer root.Close()
		raw, err = root.ReadFile("bundle.json")
	}
	if err != nil {
		c.add("$", "unreadable-bundle", "cannot read bundle.json in a bundle directory")
		return
	}
	manifestSHA256 = fmt.Sprintf("%x", sha256.Sum256(raw))
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var doc any
	if dec.Decode(&doc) != nil || dec.More() {
		c.add("$", "invalid-json", "bundle.json is not a single JSON value")
		return
	}
	if m, ok := doc.(map[string]any); ok && m["schema"] != Schema {
		c.add("$.schema", "unsupported-schema", "want %q, got %v", Schema, m["schema"])
		return
	}
	top := c.object(doc, "$", "schema", "bundle_id", "revision", "jobs", "artifacts")
	c.id(top, "$", "bundle_id", "bnd")
	c.revision(top, "$", "revision")
	for i, j := range c.list(top, "$", "jobs") {
		if s, _ := j.(string); !slices.Contains(jobs, s) {
			c.add(fmt.Sprintf("$.jobs[%d]", i), "unsupported-job", "job/version %v is not supported", j)
		}
	}
	for i, a := range c.list(top, "$", "artifacts") {
		p := fmt.Sprintf("$.artifacts[%d]", i)
		m := c.object(a, p, "id", "revision", "schema", "path", "sha256")
		schema, _ := c.str(m, p, "schema")
		prefix, supported := artifactSchemas[schema]
		if _, present := m["schema"]; present && !supported {
			c.add(p+".schema", "unsupported-schema", "artifact schema %v is not supported", m["schema"])
		}
		c.id(m, p, "id", prefix)
		c.revision(m, p, "revision")
		want, wantOK := c.digest(m, p, "sha256")
		if name, ok := c.str(m, p, "path"); ok {
			if content, err := root.ReadFile(name); err != nil {
				c.add(p+".path", "unreadable-artifact", "no regular file %q inside the bundle", name)
			} else if got := fmt.Sprintf("%x", sha256.Sum256(content)); wantOK && got != want {
				c.add(p+".sha256", "digest-mismatch", "declared %s, exact bytes hash to %s", want, got)
			}
		}
	}
	return
}
