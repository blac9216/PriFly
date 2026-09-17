package bundle

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

// TestReadRegular reads each name through a root beside an outside file and
// checks the exact reason (and length on success), each read bounded by 10s so
// a FIFO that gets opened fails the test instead of hanging it.
func TestReadRegular(t *testing.T) {
	base := t.TempDir()
	dir := filepath.Join(base, "root")
	const unresolved = "does not resolve to a file inside the bundle directory"
	for _, err := range []error{
		os.WriteFile(filepath.Join(base, "outside.json"), []byte("{}"), 0o644),
		os.MkdirAll(filepath.Join(dir, "sub"), 0o755),
		os.WriteFile(filepath.Join(dir, "ok.json"), []byte(`{"ok": true}`), 0o644),
		os.WriteFile(filepath.Join(dir, "locked"), []byte("{}"), 0o000),
		os.WriteFile(filepath.Join(dir, "at-cap"), nil, 0o644),
		os.Truncate(filepath.Join(dir, "at-cap"), MaxFileBytes),
		os.WriteFile(filepath.Join(dir, "over-cap"), nil, 0o644),
		os.Truncate(filepath.Join(dir, "over-cap"), MaxFileBytes+1),
		syscall.Mkfifo(filepath.Join(dir, "fifo"), 0o644),
		os.Symlink("ok.json", filepath.Join(dir, "link-in")),
		os.Symlink("../outside.json", filepath.Join(dir, "link-out")),
	} {
		if err != nil {
			t.Fatal(err)
		}
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	for label, c := range map[string]struct {
		name, reason string
		size         int
	}{
		"regular":         {"ok.json", "", 12},
		"symlink-inside":  {"link-in", "", 12},
		"dotdot-inside":   {"sub/../ok.json", "", 12},
		"at-cap":          {"at-cap", "", MaxFileBytes},
		"over-cap":        {"over-cap", "exceeds the 16777216-byte size cap", 0},
		"fifo":            {"fifo", "is not a regular file", 0},
		"directory":       {"sub", "is not a regular file", 0},
		"unreadable":      {"locked", "cannot be read", 0},
		"missing":         {"missing.json", unresolved, 0},
		"symlink-escape":  {"link-out", unresolved, 0},
		"dotdot-escape":   {"../outside.json", unresolved, 0},
		"absolute-escape": {filepath.Join(base, "outside.json"), unresolved, 0},
	} {
		t.Run(label, func(t *testing.T) {
			if label == "unreadable" && os.Geteuid() == 0 {
				t.Skip("root reads mode-000 files")
			}
			done := make(chan string, 1)
			go func() {
				b, reason := ReadRegular(root, c.name)
				if len(b) != c.size {
					reason += " (wrong size)"
				}
				done <- reason
			}()
			select {
			case reason := <-done:
				if reason != c.reason {
					t.Errorf("ReadRegular(%q) reason = %q, want %q and %d bytes", c.name, reason, c.reason, c.size)
				}
			case <-time.After(10 * time.Second):
				t.Fatalf("ReadRegular(%q) did not return within 10s", c.name)
			}
		})
	}
}

// TestReadChecked hands readChecked a file opened read-write (so opening a FIFO
// does not block, but reading it would) with the checked info of another file,
// as if the name had been swapped between the check and the open.
func TestReadChecked(t *testing.T) {
	dir := t.TempDir()
	checked, other, fifo := filepath.Join(dir, "checked"), filepath.Join(dir, "other"), filepath.Join(dir, "fifo")
	err := errors.Join(os.WriteFile(checked, []byte("{}"), 0o644), os.WriteFile(other, []byte("{}"), 0o644), syscall.Mkfifo(fifo, 0o644))
	info, statErr := os.Stat(checked)
	if err = errors.Join(err, statErr); err != nil {
		t.Fatal(err)
	}
	const changed = "changed between the check and the open"
	for label, c := range map[string]struct{ name, reason string }{
		"same-file":       {checked, ""},
		"swapped-regular": {other, changed},
		"swapped-fifo":    {fifo, changed},
	} {
		t.Run(label, func(t *testing.T) {
			f, err := os.OpenFile(c.name, os.O_RDWR, 0)
			if err != nil {
				t.Fatal(err)
			}
			defer f.Close()
			done := make(chan string, 1)
			go func() {
				_, reason := readChecked(f, info)
				done <- reason
			}()
			select {
			case reason := <-done:
				if reason != c.reason {
					t.Errorf("readChecked(%s) reason = %q, want %q", label, reason, c.reason)
				}
			case <-time.After(10 * time.Second):
				t.Fatalf("readChecked(%s) did not return within 10s", label)
			}
		})
	}
}

// countingReader serves n bytes, then io.EOF, and counts the bytes consumed.
type countingReader struct{ n, consumed int }

func (r *countingReader) Read(p []byte) (int, error) {
	k := min(len(p), r.n-r.consumed)
	if k == 0 {
		return 0, io.EOF
	}
	r.consumed += k
	return k, nil
}

// TestReadCapped pins the read bound: with a 16-byte cap, readCapped consumes
// at most 17 bytes of a 1 MiB input, however much the input holds.
func TestReadCapped(t *testing.T) {
	for label, c := range map[string]struct {
		n, consumed int
		reason      string
	}{
		"under-cap": {15, 15, ""},
		"at-cap":    {16, 16, ""},
		"over-cap":  {1 << 20, 17, "exceeds the 16-byte size cap"},
	} {
		t.Run(label, func(t *testing.T) {
			r := &countingReader{n: c.n}
			b, reason := readCapped(r, 16)
			if reason != c.reason || r.consumed != c.consumed || reason == "" && len(b) != c.n {
				t.Errorf("readCapped(%d bytes) = %d bytes, %q after consuming %d; want %q after consuming %d", c.n, len(b), reason, r.consumed, c.reason, c.consumed)
			}
		})
	}
}

func TestDecodeJSON(t *testing.T) {
	for label, c := range map[string]struct {
		raw    string
		ok     bool
		quoted string // Quote of the decoded array's first element, when ok
	}{
		"single-value":        {`[1.50]`, true, "1.50"},
		"huge-number":         {`[1e400]`, true, "1e400"},
		"dup-after-huge":      {`[1e400, {"a": 1, "a": 2}]`, false, ""},
		"trailing-whitespace": {"[true] \t\r\n", true, "true"},
		"trailing-brace":      {`{"a": 1}}`, false, ""},
		"trailing-arrays":     {`{"a": 1}]]]`, false, ""},
		"trailing-garbage":    {`{"a": 1}}garbage`, false, ""},
		"second-value":        {`{"a": 1} {"b": 2}`, false, ""},
		"trailing-vtab":       {"[true]\v", false, ""},
		"truncated":           {`{"a": `, false, ""},
		"empty":               {"", false, ""},
		"invalid-utf8":        {"[\"\xff\xfe\"]", false, ""},
		"encoded-surrogate":   {"[\"\xed\xa0\x80\"]", false, ""},
		"lone-high-surrogate": {`["a\ud800"]`, false, ""},
		"lone-low-surrogate":  {`["\udc00a"]`, false, ""},
		"surrogate-pair":      {`["\ud83d\ude00"]`, true, `"\U0001f600"`},
		"escaped-backslash-u": {`["\\ud800"]`, true, `"\\ud800"`},
		"duplicate-key":       {`[{"a": 1, "a": 1}]`, false, ""},
		"escaped-dup-key":     {`[{"a": 1, "\u0061": 2}]`, false, ""},
		"nested-dup-key":      {`[{"a": [{"b": {}, "b": {}}]}]`, false, ""},
		"same-key-per-object": {`[{"a": {"a": 1}}, {"a": 2}]`, true, "object"},
	} {
		t.Run(label, func(t *testing.T) {
			v, ok := DecodeJSON([]byte(c.raw))
			if ok != c.ok || ok && Quote(v.([]any)[0]) != c.quoted {
				t.Errorf("DecodeJSON(%q) = %#v, %v; want ok=%v, element %q", c.raw, v, ok, c.ok, c.quoted)
			}
		})
	}
}

// printableASCII fails t unless s holds only bytes 0x20-0x7e.
func printableASCII(t *testing.T, s string) {
	for _, r := range []byte(s) {
		if r < 0x20 || r > 0x7e {
			t.Errorf("%q contains byte %#x outside printable ASCII", s, r)
		}
	}
}

func TestQuote(t *testing.T) {
	for label, c := range map[string]struct {
		v    any
		want string
	}{
		"plain":         {"Baseline/v1", `"Baseline/v1"`},
		"controls-bidi": {"a\x1b[1A\x1b[2K\rresult: ok\n\u202e\u009b\x00\u00e9", `"a\x1b[1A\x1b[2K\rresult: ok\n\u202e\u009b\x00\u00e9"`},
		"number":        {json.Number("0"), "0"},
		"boolean":       {true, "true"},
		"null":          {nil, "null"},
		"array":         {[]any{"\x1b[2K"}, "array"},
		"object":        {map[string]any{"\x1b[2K": "\n"}, "object"},
	} {
		t.Run(label, func(t *testing.T) {
			if got := Quote(c.v); got != c.want {
				t.Errorf("Quote(%#v) = %q, want %q", c.v, got, c.want)
			}
			printableASCII(t, Quote(c.v))
		})
	}
}

func TestMember(t *testing.T) {
	for label, c := range map[string]struct{ key, want string }{
		"identifier":    {"owner_release_confirmed2", "$.owner_release_confirmed2"},
		"forged-line":   {"x\nresult: ok\x1b[2K", `$["x\nresult: ok\x1b[2K"]`},
		"bidi":          {"refs\u202e", `$["refs\u202e"]`},
		"path-syntax":   {"a.b[0]", `$["a.b[0]"]`},
		"dot":           {"a.b", `$["a.b"]`},
		"index":         {"a[0]", `$["a[0]"]`},
		"leading-digit": {"1a", `$["1a"]`},
		"empty":         {"", `$[""]`},
	} {
		t.Run(label, func(t *testing.T) {
			if got := Member("$", c.key); got != c.want {
				t.Errorf("Member(%q) = %q, want %q", c.key, got, c.want)
			}
			printableASCII(t, Member("$", c.key))
		})
	}
}
