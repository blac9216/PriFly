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
// json.Number. ok is false when raw is not valid JSON or when anything but
// JSON whitespace follows the value (a stray "}", "]]]" or a second value).
func DecodeJSON(raw []byte) (v any, ok bool) {
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
