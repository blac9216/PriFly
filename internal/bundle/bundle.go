// Package bundle inspects the manifest of a local external planning bundle,
// <dir>/bundle.json: it reads it safely, hashes its exact bytes and reports
// diagnostics, and never stages, persists or starts anything. Field
// names, ID encodings and schema/job IDs are implementation allocations (RP-18).
// Every bundle-derived string in a diagnostic is escaped to printable ASCII.
package bundle

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"slices"
	"strconv"
	"strings"
)

// MaxFileBytes caps each file inspect reads; a larger file is reported, never read past the cap.
const MaxFileBytes = 16 << 20

// Schema is the only supported manifest schema.
const Schema = "ExternalPlanningBundle/v1"

var (
	idRE       = regexp.MustCompile(`^([a-z]+)_[0-9a-f]{32}$`)
	revisionRE = regexp.MustCompile(`^[1-9][0-9]*$`)
	plainKeyRE = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
)

// lit renders a bundle value for output: strings quoted with every control or
// non-ASCII character escaped, numbers, booleans and null as JSON literals,
// and arrays and objects by kind only.
func lit(v any) string {
	switch v := v.(type) {
	case string:
		return strconv.QuoteToASCII(v)
	case json.Number, bool:
		return fmt.Sprint(v)
	case nil:
		return "null"
	case []any:
		return "array"
	}
	return "object"
}

// member is path's field k: ".k" for a plain identifier, else `["k"]` escaped.
func member(path, k string) string {
	if plainKeyRE.MatchString(k) {
		return path + "." + k
	}
	return path + "[" + strconv.QuoteToASCII(k) + "]"
}

// readRegular reads name inside root only if it is a regular file, checked
// before opening so a FIFO or device is never opened, that is still the same
// file once open, and that is at most MaxFileBytes. On failure it returns the
// reason instead.
func readRegular(root *os.Root, name string) ([]byte, string) {
	info, err := root.Stat(name)
	if err != nil {
		return nil, "does not resolve to a file inside the bundle directory"
	} else if !info.Mode().IsRegular() {
		return nil, "is not a regular file"
	}
	f, err := root.Open(name)
	if err != nil {
		return nil, "cannot be opened"
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, MaxFileBytes+1))
	if opened, serr := f.Stat(); err != nil || serr != nil || !os.SameFile(info, opened) {
		return nil, "changed or failed while being read"
	} else if len(b) > MaxFileBytes {
		return nil, fmt.Sprintf("exceeds the %d-byte size cap", MaxFileBytes)
	}
	return b, ""
}

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
			c.add(member(path, k), "unknown-field", "field is not part of %s", Schema)
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

// id checks a typed ID with the given type prefix.
func (c *checker) id(m map[string]any, path, key, prefix string) {
	s, ok := c.str(m, path, key)
	if g := idRE.FindStringSubmatch(s); ok && (g == nil || g[1] != prefix) {
		c.add(path+"."+key, "invalid-id", "want %s_<32 lowercase hex>, got %s", prefix, lit(s))
	}
}

func (c *checker) revision(m map[string]any, path, key string) {
	n, ok := m[key].(json.Number)
	if _, present := m[key]; present && (!ok || !revisionRE.MatchString(n.String())) {
		c.add(path+"."+key, "invalid-revision", "want integer >= 1, got %s", lit(m[key]))
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
	raw, reason := readRegular(root, "bundle.json")
	if reason != "" {
		c.add("$", "unreadable-bundle", "bundle.json %s", reason)
		return
	}
	manifestSHA256 = fmt.Sprintf("%x", sha256.Sum256(raw))
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var doc any
	// InputOffset is the end of the decoded value; only JSON whitespace may follow it.
	if dec.Decode(&doc) != nil || dec.InputOffset() != int64(len(bytes.TrimRight(raw, " \t\r\n"))) {
		c.add("$", "invalid-json", "bundle.json is not a single JSON value")
		return
	}
	if m, ok := doc.(map[string]any); ok && m["schema"] != Schema {
		c.add("$.schema", "unsupported-schema", "want %q, got %s", Schema, lit(m["schema"]))
		return
	}
	top := c.object(doc, "$", "schema", "bundle_id", "revision")
	c.id(top, "$", "bundle_id", "bnd")
	c.revision(top, "$", "revision")
	return
}
