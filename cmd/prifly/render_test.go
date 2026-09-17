package main

import (
	"bytes"
	"go/ast"
	"go/parser"
	"go/token"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// nonASCIIArg carries two printable non-ASCII runes: U+00E9, which renders as a
// letter, and U+0430 (Cyrillic small a), a homoglyph of the Latin a. fmt's %q is
// strconv.Quote, which escapes only what is not printable, so it prints both of
// these unchanged while escaping, say, a bidi override — %q is not a substitute
// for strconv.QuoteToASCII on text the operator did not write.
const nonASCIIArg = "ca\u00e9sar\u0430"

// nonASCIIArgEscaped is what strconv.QuoteToASCII, and so bundle.Quote, renders
// nonASCIIArg as. Written as a raw literal so this file states the expected
// bytes rather than computing them with the renderer under test.
const nonASCIIArgEscaped = `"ca\u00e9sar\u0430"`

// TestCommandArgvRendersASCII drives a printable non-ASCII argument through each
// stderr path of cmd/prifly that echoes argv back and pins the whole message.
// These are the paths a script iterating a hostile bundle directory's entries
// reaches: it hands prifly names that directory chose.
//
// Each case compares the exact stderr, so a site returning to %q is red here and
// not only in the static control below, and the two slice-valued sites are held
// to escaping element by element: bundle.Quote takes any and has no []string
// case, so a naive Quote(args) would print the string "object" instead.
func TestCommandArgvRendersASCII(t *testing.T) {
	for _, c := range []struct {
		name string
		args []string
		want string
	}{{
		name: "version with an extra argument", // main.go, the version guard
		args: []string{"version", nonASCIIArg},
		want: "prifly: version takes no arguments (got [" + nonASCIIArgEscaped + "])\n\n" + usage,
	}, {
		name: "bundle with the wrong arguments", // bundle.go, the usage guard
		args: []string{"bundle", "inspect", "a", nonASCIIArg},
		want: `prifly: want bundle inspect <bundle-dir> (got ["inspect" "a" ` + nonASCIIArgEscaped + "])\n\n" + usage,
	}, {
		name: "unknown command", // main.go, the dispatch fallthrough
		args: []string{nonASCIIArg},
		want: "prifly: unknown command " + nonASCIIArgEscaped + "\n\n" + usage,
	}} {
		t.Run(c.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			code := run(c.args, &stdout, &stderr)

			if code != 2 {
				t.Errorf("exit code = %d, want 2", code)
			}
			if stdout.Len() != 0 {
				t.Errorf("stdout = %q, want empty on a usage error", stdout.String())
			}
			if got := stderr.String(); got != c.want {
				t.Errorf("stderr =\n%q\nwant\n%q", got, c.want)
			}
			printableASCII(t, "stderr", stderr.String())
		})
	}
}

// TestCommandRendersASCII is to cmd/prifly what TestBundleDiagnosticsRenderASCII
// is to internal/bundle: a static control over the package's own non-test source,
// so that a stderr site added later is red rather than silently uncovered by the
// three cases above. It fails on a strconv quoting call that is not a ToASCII
// one, on any string literal holding a directive that renders its argument the
// way strconv.Quote does, and on a format whose verbs it cannot map to their
// runtime arguments — fmt's explicit argument index, which is how the same check
// in internal/bundle used to be evadable (see formatVerbs).
//
// Both rules ask what a thing renders rather than how it is spelled, because
// each used to be evadable by writing the same call another way: the quoting
// rule reads %q and a sharp-flagged %#v alike, since fmt renders a string under
// either with strconv.Quote (see formatVerb.quotes), and the strconv rule
// resolves the package through the file's imports, so an alias is reported and a
// dot import, which leaves no selector to read at all, is reported as such (see
// fileImports). A quoting call bound to a name and called through it is the same
// selector, so it is reported where it is bound.
//
// It admits no %q carve-out: unlike internal/bundle, which renders its own Schema
// constant with one, nothing in this package quotes a value it wrote itself.
//
// The call-site counts pin two things by occurrence. The renderers, so replacing
// one with string concatenation is red even though such a site carries neither a
// %q verb nor a strconv call for the rules above to see. And every fmt print in
// the package, so a message added later is red on the count until its author
// records it here, which is what makes this control cover sites that do not
// exist yet rather than only the three TestCommandArgvRendersASCII drives.
func TestCommandRendersASCII(t *testing.T) {
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	fset, calls, parsed := token.NewFileSet(), map[string]int{}, 0
	for _, file := range files {
		if strings.HasSuffix(file, "_test.go") {
			continue
		}
		f, err := parser.ParseFile(fset, file, nil, 0)
		if err != nil {
			t.Fatal(err)
		}
		parsed++
		imports, dotted := fileImports(f)
		reportImportHazards(t, fset, f, imports, dotted)
		ast.Inspect(f, func(n ast.Node) bool {
			// Every selector, not only one in call position: a quoting call
			// bound to a name and called through it (q := strconv.Quote; q(s))
			// is this selector too, so reading them all covers that form.
			if sel, ok := n.(*ast.SelectorExpr); ok {
				if x, isName := sel.X.(*ast.Ident); isName && quotesRaw(imports[x.Name], sel.Sel.Name) {
					t.Errorf("%s: %s leaves printable non-ASCII raw; render operator-supplied text with bundle.Quote "+
						"or quoteArgs", fset.Position(sel.Pos()), asWritten(x.Name, sel.Sel.Name))
				}
			}
			if call, ok := n.(*ast.CallExpr); ok {
				switch fun := call.Fun.(type) {
				case *ast.Ident:
					calls[fun.Name]++
				case *ast.SelectorExpr:
					if x, isName := fun.X.(*ast.Ident); isName {
						calls[x.Name+"."+fun.Sel.Name]++
					}
				}
				return true
			}
			lit, ok := n.(*ast.BasicLit)
			if !ok || lit.Kind != token.STRING {
				return true
			}
			s, err := strconv.Unquote(lit.Value)
			if err != nil {
				return true
			}
			verbs, mappable := formatVerbs(s)
			if !mappable {
				t.Errorf("%s: format %q uses fmt syntax this control cannot map to its arguments (an explicit "+
					"argument index or a star width or precision), so a quoting directive in it would go unseen; "+
					"write it plainly", fset.Position(lit.Pos()), s)
			}
			for _, verb := range verbs {
				if verb.quotes() {
					t.Errorf("%s: %v renders its argument with strconv.Quote, which leaves printable non-ASCII raw; "+
						"render operator-supplied text with bundle.Quote or quoteArgs", fset.Position(lit.Pos()), verb)
				}
			}
			return true
		})
	}
	if parsed < 2 {
		t.Errorf("parsed %d non-test files of cmd/prifly, want at least 2", parsed)
	}
	// What the count pins is that a site cannot be added silently, not that a
	// site prints safely: a new print site rendering operator-supplied text with
	// a plain %s is green once its author records the count here. That is why the
	// message below leads with the case to add and closes with the count — the
	// cheapest reading of it is the one that covers the new site. The count also
	// knows only these five spellings, so a writer that is not one of them is
	// left to TestBundleImportsNoNetworkOrProcess, which rejects a .Write or
	// .WriteString selector for its own reasons.
	for _, c := range []struct {
		name string
		want int
	}{{"quoteArgs", 2}, {"bundle.Quote", 2}, {"fmt.Fprintf", 6}, {"fmt.Fprint", 2}, {"fmt.Fprintln", 2}} {
		if calls[c.name] != c.want {
			t.Errorf("%s call sites in cmd/prifly = %d, want %d: give the new site a case in "+
				"TestCommandArgvRendersASCII driving a printable non-ASCII character through it, rendering any "+
				"operator-supplied part of its message through bundle.Quote or quoteArgs; then record the new "+
				"count here", c.name, calls[c.name], c.want)
		}
	}
}
