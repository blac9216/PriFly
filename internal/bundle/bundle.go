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
			c.add(Member(path, k), "unknown-field", "field is not part of %s", Schema)
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
// artifact schema) accepts any type prefix.
func (c *checker) id(m map[string]any, path, key, prefix string) {
	s, ok := c.str(m, path, key)
	if g := idRE.FindStringSubmatch(s); ok && (g == nil || prefix != "" && g[1] != prefix) {
		if prefix == "" {
			prefix = "<type>"
		}
		c.add(path+"."+key, "invalid-id", "want %s_<32 lowercase hex>, got %s", prefix, Quote(s))
	}
}

func (c *checker) revision(m map[string]any, path, key string) {
	n, ok := m[key].(json.Number)
	if _, present := m[key]; present && (!ok || !revisionRE.MatchString(n.String())) {
		c.add(path+"."+key, "invalid-revision", "want integer >= 1, got %s", Quote(m[key]))
	}
}

// list returns an array field, reporting a mistyped one.
func (c *checker) list(m map[string]any, path, key string) []any {
	l, ok := m[key].([]any)
	if _, present := m[key]; present && !ok {
		c.add(path+"."+key, "invalid-type", "want array")
	}
	return l
}

// artifact checks one artifacts[] entry at path p and compares the SHA-256 of
// its file's exact bytes, read through ReadRegular, with the declared digest.
func (c *checker) artifact(root *os.Root, p string, a any) {
	m := c.object(a, p, "id", "revision", "schema", "path", "sha256")
	schema, isString := c.str(m, p, "schema")
	prefix, supported := artifactSchemas[schema]
	if isString && !supported {
		c.add(p+".schema", "unsupported-schema", "artifact schema %s is not supported", Quote(schema))
	}
	c.id(m, p, "id", prefix)
	c.revision(m, p, "revision")
	want, wantOK := c.str(m, p, "sha256")
	if wantOK && !digestRE.MatchString(want) {
		c.add(p+".sha256", "invalid-digest", "want 64 lowercase hex SHA-256, got %s", Quote(want))
		wantOK = false
	}
	name, ok := c.str(m, p, "path")
	if !ok {
		return
	}
	if content, reason := ReadRegular(root, name); reason != "" {
		c.add(p+".path", "unreadable-artifact", "%s %s", Quote(name), reason)
	} else if got := fmt.Sprintf("%x", sha256.Sum256(content)); wantOK && got != want {
		c.add(p+".sha256", "digest-mismatch", "declared %s, exact bytes hash to %s", want, got)
	}
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
	doc, ok := DecodeJSON(raw)
	if !ok {
		c.add("$", "invalid-json", "bundle.json is not a single JSON value")
		return
	}
	if m, ok := doc.(map[string]any); ok && m["schema"] != Schema {
		c.add("$.schema", "unsupported-schema", "want %q, got %s", Schema, Quote(m["schema"]))
		return
	}
	top := c.object(doc, "$", "schema", "bundle_id", "revision", "jobs", "artifacts")
	c.id(top, "$", "bundle_id", "bnd")
	c.revision(top, "$", "revision")
	for i, j := range c.list(top, "$", "jobs") {
		if s, _ := j.(string); !slices.Contains(jobs, s) {
			c.add(fmt.Sprintf("$.jobs[%d]", i), "unsupported-job", "job/version %s is not supported", Quote(j))
		}
	}
	for i, a := range c.list(top, "$", "artifacts") {
		c.artifact(root, fmt.Sprintf("$.artifacts[%d]", i), a)
	}
	return
}
