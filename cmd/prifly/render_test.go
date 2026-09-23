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
					// A local bound to an imported name is still read as the
					// import, having no type information to ask: measured, a local
					// named fmt shadowing the import, with one Fprintf call made
					// through it, is red at 7 against a want of 6 although no call
					// there reaches package fmt. That much can only add a site to
					// a count and never hide one.
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
	// rows below are of the sites that write text through an fmt call, by the
	// spelling each one uses. The two questions are different: a new site that renders
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
	// What reaches these rows is an fmt call, so a write that makes none reaches
	// no row here, and nothing else in this control sees it either: such a site
	// carries neither a quoting directive for the format rule to read nor a
	// strconv selector for the leak rule. A stderr path built from io.Copy over a
	// strings.NewReader rendered a printable non-ASCII rune raw with this package
	// green, measured before TestCommandStreamsAreWrittenThroughFmt was written.
	//
	// That test is what stands behind these rows now, and only on its own terms.
	// It reads where this package's streams go rather than what its writes are
	// called, and refuses a stream expression anywhere but the first argument of
	// a call into fmt or an argument at an io.Writer parameter of a function of
	// this package, so the io.Copy path above is refused there. It also refuses,
	// by name, the three builtins that put text on standard error, os.NewFile,
	// which makes a fresh handle to the same file descriptor, and a selector
	// beginning with Must, whose panic the runtime writes there. It leaves this
	// table's own reach where it was: nothing here sees a write that makes no fmt
	// call. What each refuses, and what neither reaches, is stated at that test.
	//
	// TestBundleImportsNoNetworkOrProcess stands behind neither. What it
	// refuses is a selector on its forbidden list, .Write and .WriteString among
	// them, and neither Copy nor NewReader is on that list while io and strings
	// are both on its import allowlist. It is named here for what it refuses
	// rather than handed a class it does not cover: it does not hold Printf,
	// Print, Println or Sprintf either, so it is not the fallback for an fmt
	// spelling this table does not name. The loop below is that fallback, and it
	// is one only for a spelling of fmt's.
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

// TestCommandStreamsAreWrittenThroughFmt reads where this package's streams go,
// and refuses by name the shapes that reach one of them while naming none: the
// three builtins that write to standard error, however the call to them is
// parenthesised, os.NewFile, and a Must selector. It is the control standing
// behind the fmt tables in TestCommandRendersASCII, which need an fmt call to
// have anything to read: a write that makes none carries no format string for
// the directive rule, no strconv selector for the leak rule and no fmt selector
// for the tables, so it reaches no row, no report and no refusal there.
// Measured before this test existed, a reachable branch writing with io.Copy
// over a strings.NewReader put U+0430 raw on stderr with the package green
// (issue #368).
//
// The rule is one sentence. A stream expression may stand as the first argument
// of a call into fmt, or as an argument at an io.Writer parameter of a function
// this package declares, and nowhere else. Every other position is reported:
// a write through another package (io.Copy(stderr, r), io.CopyN, an encoder
// built on json.NewEncoder(stderr)), a write whose stream is the argument of a
// method on something else (strings.NewReader(s).WriteTo(stderr)), a write
// through the stream's own methods (stderr.Write), a binding that gives the
// stream another name (sink := stderr), and a handoff to a parameter that is not
// an io.Writer, which would carry the value out of this rule's sight.
//
// Three shapes reach the same terminal while naming no stream at all, so the
// sentence above cannot reach them, and each is refused separately by name: a
// call to the builtin println, print or panic, whose text the runtime writes to
// standard error, a panic's when nothing recovers it; os.NewFile, which makes a
// writable handle to a descriptor this process already has; and a selector
// beginning with Must, Go's name for a function that panics where its sibling
// returns an error. The reasons each is a name here and io.Copy is a position
// are at its check.
//
// The rule holds the value where it stands rather than following it, and a name
// this file declares io.Writer is a stream expression wherever it stands, so a
// stream cannot be parked somewhere the walk does not look: measured, a struct
// field of type io.Writer filled with stderr and written through with io.Copy is
// three reports — the field's name where the literal fills it, stderr itself,
// and the field's name again where the write reads it.
//
// It reads the position rather than the writer's name because a list of names is
// open-ended by construction, which is the shape the forbidden list in
// TestBundleImportsNoNetworkOrProcess already has: .Write and .WriteString are on
// it, Copy, CopyN and WriteTo are not, and adding those three leaves the next
// spelling green — measured, with those three names appended to that list, on a
// write through json.NewEncoder(stderr).Encode, whose two selectors are neither
// of them. Nothing here is a judgement about what the callee does: io.Copy is
// reported for taking a stream at all, not for being io.Copy.
//
// A stream expression is one of two things, and the second is a list of names.
// It is an identifier the file declares with the type io.Writer, resolved
// through the file's imports so an alias changes nothing; or it is the selector
// os.Stdin, os.Stdout or os.Stderr, the three values os binds to this process's
// standard descriptors, matched by name, with os itself resolved through the
// imports as well. Standard input is one of the three because an interactive
// operator's three descriptors are one terminal, and the reason is at streamExpr
// with the measurement.
//
// What the rule does not reach, stated rather than left to be found:
//
//   - A handle to this process's standard streams got some way that has not
//     been measured. What has been is at the os.NewFile check: of the ten
//     functions and methods of os at go1.27.1 that return a *os.File, NewFile
//     is refused here, five are on TestBundleImportsNoNetworkOrProcess's
//     forbidden list under three names, three open read-only and Pipe makes a
//     new pipe, and no other package on that test's import allowlist returns
//     one. An os function a later toolchain adds is not in that count.
//   - A panic this package's source does not raise by name. A runtime panic's
//     text is the runtime's own, an index out of range for one, and is not
//     read here. A callee's panic can carry an argument this package passed
//     it, and the Must rule reaches that only by the prefix: its check says
//     what was read to measure it, and a callee in a package it did not read,
//     or one that panics with its argument under another name, is not reached.
//   - Anything outside this package's own non-test source. This reads one hop
//     and has no type information, the limit quotesRaw records. internal/bundle
//     needs no rule of this kind: it declares no io.Writer and names no os.Std*
//     in its non-test source, so it returns its text rather than writing it,
//     and its only Must calls compile constant patterns of printable ASCII.
//     cmd/priflyd and cmd/prifly-bootstrap do take an io.Writer and carry no
//     ASCII control at all, which is a different question and not this one.
//   - What a permitted write puts on the stream. That a site reaches fmt is all
//     this says; whether its text is escaped is the subject of the rules in
//     TestCommandRendersASCII, and their own limits stand unchanged.
//
// That list is what has been measured, not a proof that nothing else reaches an
// operator's terminal. Five routes were found green and are closed here now,
// and only one of them was ever an entry on it: the print builtins, and a write
// to os.Stdin, each found by someone attacking a sentence that claimed more
// than the tree carried; panic, found by a review varying who does the writing
// rather than where it goes, and a callee's panic, found when that finding was
// triaged; and os.NewFile, which this list disclosed. A route not on the list
// is not a route this control has ruled out.
//
// Where the rule cannot decide, it reports. A parameter list it cannot flatten
// to positions — a variadic io.Writer, which nothing here has — makes those
// positions unpermitted rather than permitted, and a stream reaching a call
// through anything but a plain identifier or an imported selector is reported
// too. The counts at the end are what keep the walk from going quietly inert:
// they are of the stream expressions the rule admitted, so a change that stopped
// finding streams at all reads as zero rather than as silence.
func TestCommandStreamsAreWrittenThroughFmt(t *testing.T) {
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	fset := token.NewFileSet()
	parsedFiles := map[string]*ast.File{}
	for _, file := range files {
		if strings.HasSuffix(file, "_test.go") {
			continue
		}
		f, err := parser.ParseFile(fset, file, nil, 0)
		if err != nil {
			t.Fatal(err)
		}
		parsedFiles[file] = f
	}

	// Which argument positions of each function this package declares are
	// io.Writer, gathered across every file first because the calls cross files:
	// main.go calls runBundle, which bundle.go declares.
	writerArgs := map[string][]bool{}
	for _, file := range slices.Sorted(maps.Keys(parsedFiles)) {
		f := parsedFiles[file]
		imports, _ := fileImports(f)
		for _, decl := range f.Decls {
			fn, isFunc := decl.(*ast.FuncDecl)
			if !isFunc || fn.Recv != nil {
				continue
			}
			writerArgs[fn.Name.Name] = writerParams(fn.Type, imports)
		}
	}

	admitted := map[string]int{}
	for _, file := range slices.Sorted(maps.Keys(parsedFiles)) {
		f := parsedFiles[file]
		imports, dotted := fileImports(f)
		reportImportHazards(t, fset, f, imports, dotted)
		streams := streamNames(f, imports)
		isStream := func(e ast.Expr) bool { return streamExpr(e, imports, streams) != "" }

		declared := map[ast.Expr]bool{}    // the identifiers this file declares
		permitted := map[ast.Expr]string{} // a stream expression a call above it admits
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.Field:
				for _, id := range n.Names {
					declared[id] = true
				}
			case *ast.ValueSpec:
				for _, id := range n.Names {
					declared[id] = true
				}
			case *ast.AssignStmt:
				if n.Tok == token.DEFINE {
					for _, lhs := range n.Lhs {
						declared[lhs] = true
					}
				}
			case *ast.CallExpr:
				// Recorded before the walk reaches the arguments, which are this
				// node's own children: ast.Inspect visits a node before them, so
				// the report below reads what was admitted here.
				//
				// The builtin check reads through parentheses and the two arms
				// after it do not. Both directions are the fail-closed one, which
				// is why they differ. (println)("x") is a call to the builtin
				// whatever the parentheses say, and a call node's Fun is then an
				// ast.ParenExpr, which matches neither arm below: that spelling
				// was green before ast.Unparen was put here, measured with U+0430
				// raw on the terminal and the package passing. The arms below
				// admit a stream; a parenthesised call is a shape they do not
				// read, so its streams stay unadmitted and are reported, which is
				// what should happen to a shape a rule cannot decide about.
				// Measured: (fmt.Fprint)(stderr, usage) is red at the report and
				// at the fmt count, and (runBundle)(args[1:], stdout, stderr) is
				// red at two reports and the handoff count.
				if callee, isName := ast.Unparen(n.Fun).(*ast.Ident); isName {
					// println and print write text to standard error without
					// naming a stream: a call to one carries no argument for
					// the rule below to judge, no import for the allowlist in
					// TestBundleImportsNoNetworkOrProcess to refuse and no
					// selector for its forbidden list, so before this check
					// every control in the package passed over one. Measured,
					// at 4b6076c and at the head that added the rule below:
					// green, with U+0430 raw on the terminal, byte for byte the
					// io.Copy measurement.
					//
					// panic is the third, and it is refused on the same ground.
					// A panic nothing recovers ends the process with the runtime
					// writing the panic value to standard error, raw, and an
					// error value's Error text the same way. Measured at
					// b05932b: panic("prifly: " + args[1]), run with U+0430 as
					// the argument, left the package green and put "panic:
					// prifly: " then the bytes d0 b0 on stderr, exit 2, and so
					// did (panic)(...) and a panic of an error type of this
					// package's. The cost is that an invariant panic this
					// package might want, panic("unreachable") say, is a red
					// too; nothing here calls panic today, and the way to fail
					// is the way run already does, a message through fmt and a
					// non-zero exit code. What this does not reach is a panic
					// raised in another package carrying an argument this one
					// passed it, which is the Must rule's subject below, and a
					// runtime panic whose text the runtime generates, an index
					// out of range for one.
					//
					// They are refused by name where io.Copy is not, and the
					// difference is not a preference. The argument against a
					// list of writer names is that it is open-ended by
					// construction; these three are closed by the language
					// specification — its predeclared functions are a fixed
					// list, and these are the three of it that put text on
					// standard error here — so naming them ends a class rather
					// than starting a list. A package-level function of one of
					// those names this package declares is not the builtin and
					// is left alone; the carve-out reads this package's function
					// declarations, so a package-level var or a local holding a
					// func value and named println is reported instead —
					// measured, both of them, and a false red in the safe
					// direction rather than a hole.
					_, declaredHere := writerArgs[callee.Name]
					switch {
					case declaredHere:
					case callee.Name == "println" || callee.Name == "print":
						t.Errorf("%s: the builtin %s writes text to standard error, which is the stream this "+
							"package hands its callees, while naming no stream this control can read: no rule here, "+
							"no import and no selector records it. Write operator-visible text to this package's own "+
							"stream with fmt.Fprint*, rendering any operator-supplied part of it through bundle.Quote "+
							"or quoteArgs", fset.Position(callee.Pos()), callee.Name)
					case callee.Name == "panic":
						t.Errorf("%s: the builtin panic, unrecovered, has the runtime write its value to standard "+
							"error raw, and names no stream this control can read. Report the failure to this "+
							"package's own stream with fmt.Fprint*, rendering any operator-supplied part of it through "+
							"bundle.Quote or quoteArgs, and return a non-zero exit code", fset.Position(callee.Pos()))
					}
				}
				switch fun := n.Fun.(type) {
				case *ast.SelectorExpr:
					// fmt's writing functions take the stream first, and a stream
					// anywhere else in an fmt call is being rendered as a value
					// rather than written to, which is not a write this control
					// has a rule for. So only the first argument is admitted.
					if x, isName := fun.X.(*ast.Ident); isName && imports[x.Name] == "fmt" &&
						len(n.Args) > 0 && isStream(n.Args[0]) {
						permitted[n.Args[0]] = "as an fmt call's first argument"
					}
				case *ast.Ident:
					for i, arg := range n.Args {
						if at := writerArgs[fun.Name]; i < len(at) && at[i] && isStream(arg) {
							permitted[arg] = "at an io.Writer parameter of this package"
						}
					}
				}
			case *ast.SelectorExpr:
				// Two selectors reach the terminal without a stream expression,
				// and each is refused wherever it is named, called or not, so a
				// method value (nf := os.NewFile) or a parenthesised callee is
				// refused where it is written.
				//
				// os.NewFile makes a *os.File out of a bare descriptor number, so
				// os.NewFile(2, "stderr") is a writable handle to standard error
				// that is neither an io.Writer declaration nor one of the three
				// os streams. Measured at b05932b: io.Copy to it, and a
				// strings.Reader's WriteTo into it, each left the package green
				// with "prifly: " then d0 b0 on stderr. os is resolved through
				// the imports, as streamExpr resolves it.
				//
				// It is named rather than followed, and the list it completes is
				// measured, not open: the functions and methods of os that return
				// a *os.File at go1.27.1 are Create, CreateTemp, NewFile, Open,
				// OpenFile, OpenInRoot, Pipe, and Root's Create, Open and
				// OpenFile. Create, CreateTemp and OpenFile, Root's two
				// included, are on TestBundleImportsNoNetworkOrProcess's
				// forbidden list; Open, OpenInRoot and Root's Open open
				// read-only, so a copy to what they return puts nothing on the
				// terminal — measured for os.Open("/dev/stderr") and
				// os.OpenInRoot("/dev", "stderr"), green and stderr empty; Pipe
				// makes a new pipe rather than reaching a descriptor this
				// process already has. NewFile was the one left, and no other
				// package on that test's import allowlist returns a *os.File.
				if x, isName := n.X.(*ast.Ident); isName && imports[x.Name] == "os" && n.Sel.Name == "NewFile" {
					t.Errorf("%s: %s.NewFile makes a writable handle out of a bare descriptor number, so a write "+
						"to it reaches this process's standard streams while naming none of them, and no rule here "+
						"reads it. Write operator-visible text to this package's own stream with fmt.Fprint*, "+
						"rendering any operator-supplied part of it through bundle.Quote or quoteArgs",
						fset.Position(n.Pos()), x.Name)
				}
				// A selector whose name begins with Must is the second. Go names
				// a function that panics where its sibling returns an error that
				// way, and the runtime writes a panic's text to standard error
				// raw, so a Must call given operator text is the panic refused
				// above, raised one package away where that refusal cannot see
				// it. Measured at b05932b: regexp.MustCompile("(" + args[1]), run
				// with U+0430 as the argument, left the package green and put
				// "panic: regexp: Compile(`(" then d0 b0 on stderr, exit 2.
				//
				// The prefix is a naming convention and not a proof that nothing
				// else panics carrying its argument. It is read by name on any
				// selector, so an alias, a value or a package of this module
				// changes nothing. What it is measured against: the non-test
				// source of every package on TestBundleImportsNoNetworkOrProcess's
				// import allowlist, and regexp/syntax under regexp, at go1.27.1,
				// read at each panic whose value is not a string literal. Two
				// carry text a caller passed in and escape their package:
				// regexp.MustCompile and regexp.MustCompilePOSIX, both of which
				// the prefix reaches. The rest are recovered inside their own
				// package, carry their own or the system's text, or re-raise a
				// panic they did not start, such as one from a method of a value
				// they were given, which in this package would be the builtin
				// refusal's. The packages those import in turn were not read.
				//
				// The cost is that a constant pattern compiled with
				// regexp.MustCompile, the usual shape of a package-level regexp,
				// is a red here too. A constant is not exempt because a constant
				// can carry the rune as well: measured at b05932b,
				// regexp.MustCompile with a constant pattern holding the Go
				// escape for U+0430 put d0 b0 on stderr the same way. Admitting a
				// literal of printable ASCII would be sound and is not written,
				// because nothing in this package compiles a regexp today.
				// regexp.Compile, with its error reported, is the spelling that
				// passes.
				if strings.HasPrefix(n.Sel.Name, "Must") {
					t.Errorf("%s: .%s panics where its sibling returns an error, and the runtime writes a panic's "+
						"text to standard error raw; regexp's two Must functions put the pattern they were given in "+
						"that text. Call the function that returns the error, and report it to this package's own "+
						"stream with fmt.Fprint*, rendering any operator-supplied part of it through bundle.Quote or "+
						"quoteArgs", fset.Position(n.Sel.Pos()), n.Sel.Name)
				}
			}
			e, isExpr := n.(ast.Expr)
			if !isExpr || declared[e] {
				return true
			}
			written := streamExpr(e, imports, streams)
			if written == "" {
				return true
			}
			if why, ok := permitted[e]; ok {
				admitted[why]++
				return true
			}
			t.Errorf("%s: %s escapes this package's print path here: a stream may stand as the first argument "+
				"of a call into fmt, or at an io.Writer parameter of a function of this package, and nowhere "+
				"else. A write made any other way carries no format string, no strconv selector and no fmt "+
				"selector, so no rule of TestCommandRendersASCII reads what it puts on the terminal; write "+
				"operator-visible text with fmt.Fprint*, rendering any operator-supplied part of it through "+
				"bundle.Quote or quoteArgs", fset.Position(e.Pos()), written)
			return true
		})
	}
	if len(parsedFiles) < 2 {
		t.Errorf("parsed %d non-test files of cmd/prifly, want at least 2", len(parsedFiles))
	}
	// By occurrence, like the tables above, and for the same reason those tables
	// give: a number that only ever rises with real sites is what makes a rule
	// that finds nothing read as a failure. The first row equals the sum of the
	// fmt rows above today because every fmt call this package makes writes to a
	// stream, and the two are still different questions — an fmt.Sprintf added
	// here would be reported by the table above and leave this row where it is.
	for _, c := range []struct {
		why  string
		want int
	}{{"as an fmt call's first argument", 10}, {"at an io.Writer parameter of this package", 4}} {
		if admitted[c.why] != c.want {
			t.Errorf("stream expressions admitted %s in cmd/prifly = %d, want %d: a new write of "+
				"operator-visible text needs a case in TestCommandArgvRendersASCII driving a printable "+
				"non-ASCII character through it, rendering any operator-supplied part of its message through "+
				"bundle.Quote or quoteArgs; then record the new count here", c.why, admitted[c.why], c.want)
		}
	}
}

// writerParams flattens fn's parameter list to one entry per argument position,
// reporting for each whether it is declared io.Writer. A field naming several
// parameters fills one position each, and an unnamed field fills one. A variadic
// parameter's type is an ellipsis rather than the type itself, so it reads as not
// a writer and its positions are not admitted — the safe direction, and nothing
// in this package is declared that way.
func writerParams(fn *ast.FuncType, imports map[string]string) []bool {
	var at []bool
	for _, field := range fn.Params.List {
		isWriter := isWriterType(field.Type, imports)
		n := max(len(field.Names), 1)
		for range n {
			at = append(at, isWriter)
		}
	}
	return at
}

// isWriterType reports whether the type expression e is io.Writer, reading the
// package from the file's imports rather than from the identifier it is written
// with, so io.Writer under an aliased import is the same type here.
func isWriterType(e ast.Expr, imports map[string]string) bool {
	sel, isSel := e.(*ast.SelectorExpr)
	if !isSel {
		return false
	}
	x, isName := sel.X.(*ast.Ident)
	return isName && imports[x.Name] == "io" && sel.Sel.Name == "Writer"
}

// streamNames returns the names f declares with the type io.Writer, at any
// scope: a parameter, a result, a package-level or local var, a struct field.
// A short variable declaration carries no type expression, so a name bound that
// way is not one of these; a stream reaching one is reported at the binding
// instead, which is the point at which it would leave this rule's sight.
//
// Names are read per file and without type information, so a name declared a
// stream in one function makes every occurrence of that name in the file a
// stream expression. That can only add occurrences to judge and never hide one.
func streamNames(f *ast.File, imports map[string]string) map[string]bool {
	names := map[string]bool{}
	ast.Inspect(f, func(n ast.Node) bool {
		switch n := n.(type) {
		case *ast.Field:
			if isWriterType(n.Type, imports) {
				for _, id := range n.Names {
					names[id.Name] = true
				}
			}
		case *ast.ValueSpec:
			if isWriterType(n.Type, imports) {
				for _, id := range n.Names {
					names[id.Name] = true
				}
			}
		}
		return true
	})
	return names
}

// streamExpr names e the way its file writes it when e is one of this package's
// streams, and returns "" when it is not. A stream is an identifier declared
// io.Writer, or the selector os.Stdin, os.Stdout or os.Stderr — that second half
// is a list of three names, of the values os binds to this process's standard
// descriptors, and it is resolved through the file's imports so an aliased os is
// read as os and a local package bound to the name os is not.
//
// os.Stdin is on that list because writing to it reaches the operator's terminal
// whenever the operator is interactive: a shell gives the process one open file
// description on the tty for all three descriptors, so a write to descriptor 0
// lands where a write to descriptor 2 does. Measured on a pty at the head before
// this name was added: io.Copy(os.Stdin, ...) left the package green and put
// "prifly: " then the bytes d0 b0 — U+0430 — on the terminal. The cost is a false
// red on a legitimate read of standard input made outside an fmt call, such as
// io.ReadAll(os.Stdin); nothing in this package names os.Stdin today. A read
// made through fmt with os.Stdin first is admitted instead, and moves the fmt
// count: the first-argument rule reads the package a selector resolves to and
// not the member's name, so fmt.Fscan(os.Stdin, ...) is admitted the way a write
// is — measured with fmt.Fprintln(os.Stdin, ...), which that rule reads the
// same, at 11 against a want of 10.
func streamExpr(e ast.Expr, imports map[string]string, streams map[string]bool) string {
	switch e := e.(type) {
	case *ast.Ident:
		if streams[e.Name] {
			return e.Name
		}
	case *ast.SelectorExpr:
		x, isName := e.X.(*ast.Ident)
		isStd := e.Sel.Name == "Stdin" || e.Sel.Name == "Stdout" || e.Sel.Name == "Stderr"
		if isName && imports[x.Name] == "os" && isStd {
			return x.Name + "." + e.Sel.Name
		}
	}
	return ""
}
