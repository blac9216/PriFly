package bundle

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
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
	// lockeddir holds a file behind a directory that may not be traversed, so
	// the read is refused for permission and not for a name that does not
	// resolve. Its mode is restored before TempDir's cleanup, which cannot
	// remove a file inside a directory it may not traverse.
	locked := filepath.Join(dir, "lockeddir")
	t.Cleanup(func() { os.Chmod(locked, 0o755) })
	for _, err := range []error{
		os.WriteFile(filepath.Join(base, "outside.json"), []byte("{}"), 0o644),
		os.MkdirAll(filepath.Join(dir, "sub"), 0o755),
		os.MkdirAll(locked, 0o755),
		os.WriteFile(filepath.Join(locked, "x"), []byte("{}"), 0o644),
		os.Chmod(locked, 0o000),
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
		"regular":        {"ok.json", "", 12},
		"symlink-inside": {"link-in", "", 12},
		"dotdot-inside":  {"sub/../ok.json", "", 12},
		"at-cap":         {"at-cap", "", MaxFileBytes},
		"over-cap":       {"over-cap", "exceeds the 16777216-byte size cap", 0},
		"fifo":           {"fifo", "is not a regular file", 0},
		"directory":      {"sub", "is not a regular file", 0},
		"unreadable":     {"locked", "cannot be read", 0},
		// A present file behind a mode-000 directory: "cannot be read", never
		// unresolved, which would report a file that is there as missing or
		// outside the bundle. Removing input.go's fs.ErrPermission mapping
		// turns this case red.
		"unreadable-directory": {"lockeddir/x", "cannot be read", 0},
		"missing":              {"missing.json", unresolved, 0},
		"symlink-escape":       {"link-out", unresolved, 0},
		"dotdot-escape":        {"../outside.json", unresolved, 0},
		"absolute-escape":      {filepath.Join(base, "outside.json"), unresolved, 0},
	} {
		t.Run(label, func(t *testing.T) {
			if strings.HasPrefix(label, "unreadable") && os.Geteuid() == 0 {
				t.Skip("root reads mode-000 files and traverses mode-000 directories")
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
				_, reason := readChecked(f, info, MaxFileBytes)
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

// countingReader serves n bytes, then err or else io.EOF, and counts the bytes
// consumed.
type countingReader struct {
	n, consumed int
	err         error
}

func (r *countingReader) Read(p []byte) (int, error) {
	k := min(len(p), r.n-r.consumed)
	if k == 0 && r.err != nil {
		return 0, r.err
	} else if k == 0 {
		return 0, io.EOF
	}
	r.consumed += k
	return k, nil
}

// TestReadCapped pins the read bound: with a 16-byte cap, readCapped consumes
// at most 17 bytes of a 1 MiB input, however much the input holds. A read that
// fails after 3 bytes returns those 3 bytes with its reason.
func TestReadCapped(t *testing.T) {
	if b, reason := readCapped(&countingReader{n: 3, err: io.ErrUnexpectedEOF}, 16); string(b) != "\x00\x00\x00" || reason != "cannot be read" {
		t.Errorf("readCapped(3 bytes, then an error) = %q, %q; want 3 bytes, \"cannot be read\"", b, reason)
	}
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
		"pair-range-bottom":   {`["\ud800\udc00"]`, true, `"\U00010000"`},
		"pair-range-top":      {`["\udbff\udfff"]`, true, `"\U0010ffff"`},
		"lone-surrogate-top":  {`["\udfff"]`, false, ""},
		"lone-high-top":       {`["\udbff"]`, false, ""},
		"beside-surrogates":   {`["\ud7ff\ue000"]`, true, `"\ud7ff\ue000"`},
		"escaped-backslash-u": {`["\\ud800"]`, true, `"\\ud800"`},
		"duplicate-key":       {`[{"a": 1, "a": 1}]`, false, ""},
		"escaped-dup-key":     {`[{"a": 1, "\u0061": 2}]`, false, ""},
		"nested-dup-key":      {`[{"a": [{"b": {}, "b": {}}]}]`, false, ""},
		"same-key-per-object": {`[{"a": {"a": 1}}, {"a": 2}]`, true, "object"},
		"case-distinct-keys":  {`[{"a": 1, "A": 2}]`, true, "object"},
	} {
		t.Run(label, func(t *testing.T) {
			v, ok := DecodeJSON([]byte(c.raw))
			if ok != c.ok || ok && Quote(v.([]any)[0]) != c.quoted {
				t.Errorf("DecodeJSON(%q) = %#v, %v; want ok=%v, element %q", c.raw, v, ok, c.ok, c.quoted)
			}
		})
	}
}

// TestFaultsBudget pads 10 nested objects, each repeating its 10-byte key, to
// the length of the paths of the four deepest faults, and to one byte more. At
// that length the budget is exactly spent after four, so the fifth fault is not
// listed; one byte more lists the fifth and not the sixth. Both lists are
// marked incomplete.
func TestFaultsBudget(t *testing.T) {
	dup := func(d int) Diagnostic {
		return Diagnostic{"$" + strings.Repeat(".kkkkkkkkkk", d), "duplicate-key", "key repeats an earlier key of this object"}
	}
	raw := strings.Repeat(`{"kkkkkkkkkk": `, 10) + "1" + strings.Repeat(`, "kkkkkkkkkk": 1}`, 10)
	for extra, from := range []int{7, 6} {
		size, want := extra, []Diagnostic{}
		for d := 7; d <= 10; d++ {
			size += len(dup(d).Path)
		}
		for d := from; d <= 10; d++ {
			want = append(want, dup(d))
		}
		if got := Faults([]byte(raw + strings.Repeat(" ", size-len(raw)))); !slices.Equal(got, append(want, incomplete)) {
			t.Errorf("Faults(%d bytes) = %q, want %q", size, got, append(want, incomplete))
		}
	}
}

// TestArtifactReadLimit pins each artifact read to min(MaxFileBytes, bytes
// left) exactly, one byte consumed past it: a 100-byte file leaves -1 from 10
// or 0 bytes left and 0 from 100, and a larger file takes MaxFileBytes+1.
func TestArtifactReadLimit(t *testing.T) {
	dir := t.TempDir()
	err := errors.Join(os.WriteFile(dir+"/small", make([]byte, 100), 0o644), os.WriteFile(dir+"/large", nil, 0o644), os.Truncate(dir+"/large", MaxFileBytes+100))
	root, openErr := os.OpenRoot(dir)
	if err = errors.Join(err, openErr); err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	for _, r := range []struct {
		name       string
		left, want int
	}{{"small", 10, -1}, {"small", 0, -1}, {"small", 100, 0}, {"large", MaxArtifactBytes, MaxArtifactBytes - MaxFileBytes - 1}} {
		var c checker
		w := workItems{digest: map[string]int{}, schemaIDs: map[string]bool{}, left: r.left}
		if c.artifact(root, "$", map[string]any{"path": r.name}, &w); w.left != r.want {
			t.Errorf("%s with %d bytes left: %d left after the read, want %d", r.name, r.left, w.left, r.want)
		}
	}
}

// TestEntriesMemory checks 100,000 artifacts[] entries, or references of one
// entry, that have no ID, and bounds the bytes still held after checking them,
// with what entries returns kept, to 8 per entry: an identity held per entry
// takes over 64.
func TestEntriesMemory(t *testing.T) {
	const n = 100000
	zeros, objects := make([]any, n), make([]any, n)
	for i := range n {
		zeros[i], objects[i] = json.Number("0"), map[string]any{}
	}
	for label, list := range map[string][]any{"zeros": zeros, "empty-objects": objects,
		"ref-zeros": {map[string]any{"refs": zeros}}, "ref-empty-objects": {map[string]any{"refs": objects}}} {
		t.Run(label, func(t *testing.T) {
			var c checker
			var before, after runtime.MemStats
			w := workItems{digest: map[string]int{}, schemaIDs: map[string]bool{}, left: MaxArtifactBytes}
			runtime.GC()
			runtime.ReadMemStats(&before)
			artifacts, refs := c.entries(nil, list, &w)
			runtime.GC()
			runtime.ReadMemStats(&after)
			if held := int64(after.HeapAlloc) - int64(before.HeapAlloc); held > 8*n || len(c) != MaxDiagnostics+1 {
				t.Errorf("%d entries: %d bytes held, %d diagnostics; want at most %d bytes, %d diagnostics", n, held, len(c), 8*n, MaxDiagnostics+1)
			}
			runtime.KeepAlive(artifacts)
			runtime.KeepAlive(refs)
			runtime.KeepAlive(w)
		})
	}
}

// TestCheckerKeepsFirst adds n diagnostics, drawn from 84 distinct ones so
// that repeats and ties on path and code are common, in 20 shuffled orders. The
// checker must never hold more than MaxDiagnostics+1, and done must list the
// first MaxDiagnostics of the diagnostics sorted by path, code and detail,
// followed by incomplete exactly when n is over MaxDiagnostics.
func TestCheckerKeepsFirst(t *testing.T) {
	rng := rand.New(rand.NewPCG(248, 1))
	for _, n := range []int{0, 1, 999, 1000, 1001, 1002, 2001, 2002, 2003, 5000} {
		all := make([]Diagnostic, n)
		for i := range all {
			all[i] = Diagnostic{fmt.Sprintf("$.p%d", rng.IntN(7)), fmt.Sprintf("code-%d", rng.IntN(4)), fmt.Sprintf("detail %d", rng.IntN(3))}
		}
		want := slices.Clone(all)
		slices.SortFunc(want, func(a, b Diagnostic) int {
			return strings.Compare(a.Path+"\x00"+a.Code+"\x00"+a.Detail, b.Path+"\x00"+b.Code+"\x00"+b.Detail)
		})
		if n > MaxDiagnostics {
			want = append(want[:MaxDiagnostics], incomplete)
		}
		for range 20 {
			rng.Shuffle(n, func(i, j int) { all[i], all[j] = all[j], all[i] })
			var c checker
			for _, d := range all {
				if c.add(d.Path, d.Code, "%s", d.Detail); len(c) > MaxDiagnostics+1 {
					t.Fatalf("n=%d: checker holds %d diagnostics", n, len(c))
				}
			}
			if got := c.done(true); !slices.Equal(got, want) {
				t.Fatalf("n=%d: done lists %d diagnostics, not the first of the sorted list", n, len(got))
			}
		}
	}
}

// TestFaultsMemory walks 1000 nested objects with 100-byte keys, once with a
// repeated key at the innermost level and once in every object, and one object
// repeating a key 50,000 times, and bounds the bytes allocated to 32 times the
// input: per-level path copies would allocate about 50 MB, an unbounded list of
// faults with deep paths as much, and one fault per repeated key about 40 times
// the input.
func TestFaultsMemory(t *testing.T) {
	key := `"` + strings.Repeat("k", 100) + `"`
	for label, c := range map[string]struct{ open, inner, close string }{
		"innermost-fault": {"{" + key + ": ", `{"a": 1, "a": 2}`, "}"},
		"fault-per-level": {"{" + key + ": ", "null", ", " + key + ": 1}"},
		"flat-faults":     {"", `{"a": 1` + strings.Repeat(`, "a": 1`, 50000) + "}", ""},
	} {
		t.Run(label, func(t *testing.T) {
			raw := []byte(strings.Repeat(c.open, 1000) + c.inner + strings.Repeat(c.close, 1000))
			var before, after runtime.MemStats
			runtime.GC()
			runtime.ReadMemStats(&before)
			faults := Faults(raw)
			runtime.ReadMemStats(&after)
			if n := after.TotalAlloc - before.TotalAlloc; len(faults) == 0 || faults[0].Code != "duplicate-key" || n > uint64(32*len(raw)) {
				t.Errorf("Faults allocated %d bytes for %d input bytes (limit 32x), first of %d faults %.40q", n, len(raw), len(faults), faults)
			}
		})
	}
}

// TestGraphMemory bounds the bytes allocated per Work Item by reading bodies and
// running graph at the larger size to twice those at the smaller: for a ring of
// 1,000 and of 16,000 Work Items (the longest cycle; a cycle name or walk copied
// per step is quadratic), and for 200 and 800 entries naming one content that
// lists 2n IDs, n unresolved (bytes parsed, edges held or diagnostics reported
// per entry sharing it are quadratic).
func TestGraphMemory(t *testing.T) {
	wi := func(i int) string { return fmt.Sprintf(`{"work_item": "wi_%032x", "condition": "c"}`, i) }
	perItem := func(n int, shared bool) uint64 {
		contents, keys, want := make([][]byte, n), make([]string, n), n+1 // each Work Item is reported naming the shared envelope
		for i := range contents {
			deps := []string{wi((i + 1) % n)}
			if keys[i] = fmt.Sprint(i); shared {
				deps, keys[i], want = []string{}, "shared", 2*n+1
				for j := range 2 * n {
					deps = append(deps, wi(j))
				}
			}
			contents[i] = []byte(`{"kind": "SLICE", "dependencies": [` + strings.Join(deps, ", ") + `], "outcomes": [{"baseline": "bsl_6e73c229223db574a3c8fa28dd5a1a5a", "obligation": "o"}], "execution_envelope": "xen_dd00d1cf54fb4ef059011c2dc206e701"}`)
		}
		var c checker
		var before, after runtime.MemStats
		w := workItems{digest: map[string]int{}, schemaIDs: map[string]bool{"Baseline/v1 bsl_6e73c229223db574a3c8fa28dd5a1a5a": true, "ExecutionEnvelope/v1 xen_dd00d1cf54fb4ef059011c2dc206e701": true}}
		runtime.GC()
		runtime.ReadMemStats(&before)
		for i, content := range contents {
			w.items = append(w.items, workItem{"$", fmt.Sprintf("wi_%032x", i), w.read(&c, "$", "WorkItem/v1", keys[i], content)})
		}
		c.graph(w)
		runtime.ReadMemStats(&after)
		if d := c.done(true); len(d) != min(want, MaxDiagnostics+1) || d[0].Code != "dependency-cycle" { // listed first, then capped
			t.Errorf("%d Work Items, shared %v: got %d diagnostics, want %d starting with dependency-cycle", n, shared, len(d), min(want, MaxDiagnostics+1))
		}
		return (after.TotalAlloc - before.TotalAlloc) / uint64(n)
	}
	for _, s := range []struct {
		small, large int
		shared       bool
	}{{1000, 16000, false}, {200, 800, true}} {
		if small, large := perItem(s.small, s.shared), perItem(s.large, s.shared); large > 2*small {
			t.Errorf("shared %v: %d bytes per Work Item for %d, %d for %d (limit 2x)", s.shared, large, s.large, small, s.small)
		}
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
