// Package bundle inspects local external planning bundles. This file is its
// input-safety layer: every read of bundle content goes through ReadRegular,
// every JSON document through DecodeJSON, and every bundle-derived string that
// reaches output through Quote or Member.
package bundle

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"strconv"
	"unicode/utf8"
)

// MaxFileBytes caps every file ReadRegular reads; reading stops one byte past
// the cap, so a larger file is reported and never read into memory whole.
const MaxFileBytes = 16 << 20

// ReadRegular reads name through root, so the name cannot resolve outside the
// root by "..", an absolute path or a symlink. The file must be a regular file,
// checked before it is opened so a FIFO or device is never opened (opening one
// can block), still the same file once open, and at most MaxFileBytes long. On
// failure it returns a fixed reason for a diagnostic instead of the bytes; the
// reason never contains name.
func ReadRegular(root *os.Root, name string) ([]byte, string) {
	info, err := root.Stat(name)
	if err != nil {
		return nil, "does not resolve to a file inside the bundle directory"
	} else if !info.Mode().IsRegular() {
		return nil, "is not a regular file"
	}
	f, err := root.Open(name)
	if err != nil {
		return nil, "cannot be read"
	}
	defer f.Close()
	return readChecked(f, info)
}

// readChecked reads f, opened for the regular file that info describes. It
// first re-checks that f is that same file, so a FIFO or other file swapped in
// between the check and the open is rejected before any read can block on it;
// being the same file as info, f is regular.
func readChecked(f *os.File, info os.FileInfo) ([]byte, string) {
	if opened, err := f.Stat(); err != nil || !os.SameFile(info, opened) {
		return nil, "changed between the check and the open"
	}
	return readCapped(f, MaxFileBytes)
}

// readCapped reads r to EOF but consumes at most limit+1 bytes, so a larger
// input is reported without being read into memory whole.
func readCapped(r io.Reader, limit int) ([]byte, string) {
	b, err := io.ReadAll(io.LimitReader(r, int64(limit)+1))
	if err != nil {
		return nil, "cannot be read"
	} else if len(b) > limit {
		return nil, fmt.Sprintf("exceeds the %d-byte size cap", limit)
	}
	return b, ""
}

// DecodeJSON decodes raw as exactly one JSON value, keeping numbers as
// json.Number. ok is false when raw is not valid JSON, when anything but JSON
// whitespace follows the value (a stray "}", "]]]" or a second value), or when
// Faults finds a repeated key or a string that would not decode exactly.
func DecodeJSON(raw []byte) (v any, ok bool) {
	v, ok = decodeValue(raw)
	return v, ok && Faults(raw) == nil
}

// decodeValue is DecodeJSON without Faults: ok is whether raw is one JSON value.
func decodeValue(raw []byte) (v any, ok bool) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	// InputOffset is the end of the decoded value.
	ok = dec.Decode(&v) == nil && dec.InputOffset() == int64(len(bytes.TrimRight(raw, " \t\r\n")))
	return v, ok
}

// Quote renders a decoded JSON value for output as printable ASCII: a string
// quoted with every control and non-ASCII character escaped, a number or
// boolean as its JSON literal, null as "null", and an array or object by kind
// only, so none of its contents are printed.
func Quote(v any) string {
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

var plainKeyRE = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

// Member returns the JSON path of object field key under path: path.key when
// key is a plain identifier, otherwise path["key"] with key escaped as by Quote.
func Member(path, key string) string {
	if plainKeyRE.MatchString(key) {
		return path + "." + key
	}
	return path + "[" + strconv.QuoteToASCII(key) + "]"
}

// Faults walks raw's tokens and returns, in document order, a diagnostic at
// the JSON path of each object key repeated in its object and of each key or
// string value that is not valid UTF-8 or escapes an unpaired surrogate, which
// encoding/json would silently resolve to the last value or map to U+FFFD. The
// walk ends at a syntax error or after the first value without reporting it:
// DecodeJSON then returns ok=false and Inspect adds invalid-json. A path is
// built only for a fault, and no fault is added once the paths reported total
// len(raw) bytes, so memory stays linear in len(raw) however deep raw nests.
func Faults(raw []byte) (faults []Diagnostic) {
	type frame struct {
		key  string          // object: the key whose value is next or open
		keys map[string]bool // nil for an array
		next int             // array: next index; object: 1 when a value is next
	}
	// The root frame is an object awaiting the value of its member at $.
	dec, stack, budget := json.NewDecoder(bytes.NewReader(raw)), []*frame{{keys: map[string]bool{}, next: 1}}, len(raw)
	dec.UseNumber() // as DecodeJSON: 1e400 is valid JSON and must not end the walk
	add := func(code, detail string) {
		path := []byte("$") // appended to, never re-copied per level
		for _, f := range stack[1:] {
			if f.keys == nil {
				path = fmt.Appendf(path, "[%d]", f.next-1)
			} else {
				path = append(path, Member("", f.key)...)
			}
		}
		faults, budget = append(faults, Diagnostic{string(path), code, detail}), budget-len(path)
	}
	for budget > 0 && (len(stack) > 1 || stack[0].next == 1) {
		start := dec.InputOffset()
		tok, err := dec.Token()
		if err != nil {
			return faults
		}
		f, isKey := stack[len(stack)-1], false
		s, isString := tok.(string)
		switch {
		case tok == json.Delim('}') || tok == json.Delim(']'):
			stack = stack[:len(stack)-1]
		case f.keys == nil:
			f.next++
		case f.next == 0:
			f.key, f.next, isKey = s, 1, true
		default:
			f.next = 0
		}
		reason := ""
		if isString {
			reason = textFault(raw[start:dec.InputOffset()])
		}
		switch {
		case tok == json.Delim('{'):
			stack = append(stack, &frame{keys: map[string]bool{}})
		case tok == json.Delim('['):
			stack = append(stack, &frame{})
		case reason != "":
			add("invalid-string", "string "+reason)
		case isKey && f.keys[s]:
			add("duplicate-key", "key repeats an earlier key of this object")
		case isKey:
			f.keys[s] = true
		}
	}
	return faults
}

// textFault returns why the string token in lit (the token and any separators
// before it) would not decode exactly: invalid UTF-8 or a \u escape of an
// unpaired surrogate; "" if it decodes exactly. Token has checked its syntax.
func textFault(lit []byte) string {
	if !utf8.Valid(lit) {
		return "is not valid UTF-8"
	}
	// escape reports whether lit holds, at i, a \u escape of a unit in [lo, hi].
	escape := func(i int, lo, hi uint64) bool {
		if i+6 > len(lit) || lit[i] != '\\' || lit[i+1] != 'u' {
			return false
		}
		n, _ := strconv.ParseUint(string(lit[i+2:i+6]), 16, 16)
		return n >= lo && n <= hi
	}
	for i := 0; i < len(lit); i++ {
		switch {
		case escape(i, 0xd800, 0xdbff) && escape(i+6, 0xdc00, 0xdfff):
			i += 11
		case escape(i, 0xd800, 0xdfff):
			return "escapes an unpaired surrogate"
		case lit[i] == '\\':
			i++
		}
	}
	return ""
}
