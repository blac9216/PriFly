package main

import (
	"bytes"
	"go/ast"
	"go/parser"
	"go/token"
	"maps"
	"path/filepath"
	"slices"
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
// %q verb nor a strconv call for the rules above to see. And the package's fmt
// prints, so a message added later is red on the count until its author records
// it here, which is what makes this control cover sites that do not exist yet
// rather than only the three TestCommandArgvRendersASCII drives.
//
// The two halves are read differently, and the difference is the fmt half's
// whole subject. A renderer row reads the identifier its call is written with.
// An fmt row reads what the name resolves to through the file's imports, is
// recorded only where this package calls the selector directly, and is reported
// rather than passed over when the table does not name the spelling, so that an
// alias, a name given an fmt value, and a family nobody anticipated each reach a
// row, a report or a refusal instead of a key nothing reads. What each half
// holds, and what neither holds, is stated at the table.
func TestCommandRendersASCII(t *testing.T) {
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	fset, calls, parsed := token.NewFileSet(), map[string]int{}, 0
	fmtSites := map[string][]token.Position{}
	called := map[ast.Expr]bool{} // the expressions this package calls, by node
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
				if x, isName := sel.X.(*ast.Ident); isName {
					if quotesRaw(imports[x.Name], sel.Sel.Name) {
						t.Errorf("%s: %s leaves printable non-ASCII raw; render operator-supplied text with bundle.Quote "+
							"or quoteArgs", fset.Position(sel.Pos()), asWritten(x.Name, sel.Sel.Name))
					}
					// Recorded by what the name resolves to, not by how it is
					// written, so f.Fprintf under import f "fmt" is recorded as
					// fmt.Fprintf and a call through a package bound to the name
					// fmt is not recorded at all. A print wrapped in a third
					// package is out of reach either way: this reads the file's
					// imports, one hop, the limit quotesRaw records.
					//
					// What is recorded is a selector this package calls, and one
					// it names without calling is reported instead. The leak rule
					// above reads a selector wherever it stands, because there a
					// single occurrence settles the question; a count cannot be
					// read that way. A name given fmt.Fprintf renders text at
					// every call made through it while the selector stands once,
					// so recording that one occurrence would hold three render
					// sites at one and passing over it would hold them at none.
					// The price is that this package may name an fmt member only
					// where it calls it directly: a value of one put in a
					// variable, passed to a function or held in a composite
					// literal is refused, and so are a selector that is not a
					// function at all and a call written through parentheses,
					// (fmt.Fprintf)(w, f, a), whose selector is not the call's own
					// function. Nothing here is written any of those ways today.
					if imports[x.Name] == "fmt" {
						name := "fmt." + sel.Sel.Name
						if called[sel] {
							fmtSites[name] = append(fmtSites[name], fset.Position(sel.Pos()))
						} else {
							t.Errorf("%s: %s is named here without being called, and the table below counts "+
								"calls, so calls made through a name given this value would not reach it; "+
								"name an fmt member only where you call it", fset.Position(sel.Pos()), name)
						}
					}
				}
			}
			if call, ok := n.(*ast.CallExpr); ok {
				// Recorded before the walk reaches call.Fun, which is this node's
				// own child: ast.Inspect visits a node before its children, so the
				// selector branch above reads a call recorded here.
				called[call.Fun] = true
				switch fun := call.Fun.(type) {
				case *ast.Ident:
					calls[fun.Name]++
				case *ast.SelectorExpr:
					// An fmt call is recorded above instead, by what its name
					// resolves to; recording it here as well would leave the same
					// site in two maps, only one of which is read.
					if x, isName := fun.X.(*ast.Ident); isName && imports[x.Name] != "fmt" {
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
	// What either table pins is that a site cannot be added silently, not that a
	// site prints safely: a new print site rendering operator-supplied text with
	// a plain %s is green once its author records the count here. That is why
	// each message below leads with the case to add and closes with the count —
	// the cheapest reading of it is the one that covers the new site.
	//
	// The two rows here read the identifier their call is written with, so they
	// hold less than the fmt rows below, and what they hold is still what they
	// are for. A name given bundle.Quote and called through it is not counted,
	// and neither are Quote calls a new file makes through an aliased import of
	// internal/bundle: both measured with probes that add no fmt call, the row
	// staying at 2 and this control green. Nothing is lost there, because such a
	// call still renders through the escaping renderer. What these rows catch is
	// a real call going away — replacing bundle.Quote with string concatenation,
	// or standing a bound name in its place — which lowers the row however the
	// call that remains is spelled: both measured red at 1. Aliasing the import
	// in a file that already calls Quote lowers it too, measured red at 0, both
	// calls standing in main.go. So an alias cannot hide a substitution here; it
	// can only leave added calls uncounted, and those are calls through the
	// renderer.
	for _, c := range []struct {
		name string
		want int
	}{{"quoteArgs", 2}, {"bundle.Quote", 2}} {
		if calls[c.name] != c.want {
			t.Errorf("%s call sites in cmd/prifly = %d, want %d: give the new site a case in "+
				"TestCommandArgvRendersASCII driving a printable non-ASCII character through it, rendering any "+
				"operator-supplied part of its message through bundle.Quote or quoteArgs; then record the new "+
				"count here", c.name, calls[c.name], c.want)
		}
	}
	// The rows above are of the two renderers this package escapes text with; the
	// rows below are of the sites that write text through fmt, by the spelling
	// each one uses. The two questions are different: a new site that renders
	// operator-supplied text through fmt without reaching quoteArgs or
	// bundle.Quote moves no row above and carries no quoting directive for the
	// rules to read, so without this table it is invisible to every other
	// judgement this control makes. That is why these rows are read by resolved
	// import rather than by spelling, are recorded only where the package calls
	// the selector directly, and are reported when the table does not name the
	// spelling: an added print reaches a row, a report or the refusal above
	// rather than a key nothing reads. The resolution runs the other way too, so
	// a row cannot be held up by a call into some other package a file has bound
	// to the name fmt. Measured, with the real fmt imported under another name
	// and internal/bundle imported as fmt: the three rows below still read 6, 2
	// and 2 through the aliased import, no fmt.Quote is recorded here, and it is
	// the renderer row above that goes red.
	//
	// The table names the three spellings live in the package today. A dot import
	// of fmt would leave a bare identifier with no selector for any of this to
	// read; reportImportHazards fails on one above — measured, on a new file
	// dot-importing fmt — which is what lets this table assume a selector.
	//
	// What no row here holds is that the numbers are a count of the sites that
	// render. A helper of this package's own wrapping a single fmt call renders
	// text at every call made to it while the selector inside it stands once:
	// measured, a probeWrap(w io.Writer, format string, args ...any) around one
	// fmt.Fprintf, called three times, moves fmt.Fprintf by one — red at 7 — and
	// is green once 7 is recorded. That is a limit disclosed here rather than
	// closed, and it is a different shape from the one the refusal above catches:
	// the wrapper is itself a call site, so it cannot be added without moving a
	// number, while a name given an fmt value adds none. Closing it would take a
	// rule about where a rendered value comes from, and every rule in this
	// control reads the shape of the source instead.
	//
	// A writer that is not an fmt call at all is left to
	// TestBundleImportsNoNetworkOrProcess, whose forbidden list is of selector
	// names and holds .Write and .WriteString among them. That list does not hold
	// Printf, Print, Println or Sprintf, so it is not the fallback for an fmt
	// spelling this table does not name; the loop below is.
	counted := map[string]bool{}
	for _, c := range []struct {
		name string
		want int
	}{{"fmt.Fprintf", 6}, {"fmt.Fprint", 2}, {"fmt.Fprintln", 2}} {
		counted[c.name] = true
		if got := len(fmtSites[c.name]); got != c.want {
			t.Errorf("%s call sites in cmd/prifly = %d, want %d (at %v): give the new site a case in "+
				"TestCommandArgvRendersASCII driving a printable non-ASCII character through it, rendering any "+
				"operator-supplied part of its message through bundle.Quote or quoteArgs; then record the new "+
				"count here", c.name, got, c.want, fmtSites[c.name])
		}
	}
	for _, name := range slices.Sorted(maps.Keys(fmtSites)) {
		if !counted[name] {
			t.Errorf("%s is called in cmd/prifly (at %v) and is a spelling this table does not name, so it is "+
				"reported rather than counted: give the site a case in TestCommandArgvRendersASCII driving a "+
				"printable non-ASCII character through it, rendering any operator-supplied part of its message "+
				"through bundle.Quote or quoteArgs; then give the spelling its own row in the table above",
				name, fmtSites[name])
		}
	}
}
