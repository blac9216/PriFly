//go:build linux

package bootstrap

import (
	"cmp"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"go/types"
	"maps"
	"os"
	"path"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"
	"unicode/utf8"
)

const modulePath = "github.com/blac9216/PriFly"

// renderCensus is every operand in the non-test source of internal/bootstrap and cmd/prifly-bootstrap that fmt
// renders with a verb other than %+q and that is not a literal, a string constant or an error sentinel of fixed
// text (see readRender). Each key is the file, the verb and the operand as written, and each count is exact, so a
// site added later that renders some other value, or the same value once more, is red until it is recorded here.
// The reason beside each row is why that operand cannot carry repository-supplied text; it is recorded, not
// checked: nothing here follows a value to where it was made.
var renderCensus = map[string]censusRow{
	"internal/bootstrap/decrypt.go %d e.Generation": {2, "an int decoded from the plaintext"},
	"internal/bootstrap/decrypt.go %d want":         {2, "an int from the manifest"},
	"internal/bootstrap/fetch.go %s path":           {1, "readBlob's path, which Fetch passes as ManifestPath or SecretsPath"},
	"cmd/prifly-bootstrap/main.go %v err": {2, "an error returned by ClaimWorkDir, Fetch, Decrypt or Discover, or " +
		"main.go's own Errorf wrapping bootstrap.ErrFetch; each is made in these packages at an fmt call or " +
		"errors.New this control reads"},
	"cmd/prifly-bootstrap/main.go %s v.Revision": {1, "the -revision argument, which Fetch returns only after it " +
		"matched 40 lowercase hex"},
}

// TestBootstrapRendersASCII is the static control behind TestDecryptRendersIDsASCII, over what prifly-bootstrap
// prints: the non-test source of internal/bootstrap and of cmd/prifly-bootstrap. It is the counterpart of
// cmd/prifly's TestCommandRendersASCII and is written separately, for this pair of packages; the rules are
// stated at readRender. cmd/priflyd is not read: it prints build information set when it is built, then either a
// fixed line or, when controller.Run returns an error, that error. Run returns its shutdown hook's error or
// controller.ErrShutdownTimedOut, and priflyd's hook returns nil, so the error is only ever that sentinel. Nothing it
// reads at run time reaches its terminal. The day something does, that change is where its escaping belongs.
func TestBootstrapRendersASCII(t *testing.T) {
	sources := map[string]string{}
	for dir, rel := range map[string]string{".": "internal/bootstrap", "../../cmd/prifly-bootstrap": "cmd/prifly-bootstrap"} {
		files, err := filepath.Glob(filepath.Join(dir, "*.go"))
		if err != nil {
			t.Fatal(err)
		}
		n := 0
		for _, file := range files {
			if strings.HasSuffix(file, "_test.go") {
				continue
			}
			data, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			sources[path.Join(rel, filepath.Base(file))] = string(data)
			n++
		}
		if n == 0 {
			t.Fatalf("no non-test Go source read in %s", dir)
		}
	}
	findings, counted := readRender(sources)
	for _, f := range findings {
		t.Error(f)
	}
	for _, f := range checkCensus(counted, renderCensus) {
		t.Error(f)
	}
}

// censusRow is one row of renderCensus: how many times the operand is rendered, and why it is safe to.
type censusRow struct {
	n   int
	why string
}

// checkCensus returns a finding for every operand counted a different number of times than census records,
// one it does not record included, and for every row of census no operand was counted for.
func checkCensus(counted map[string]int, census map[string]censusRow) (findings []string) {
	for _, key := range slices.Sorted(maps.Keys(counted)) {
		if want, ok := census[key]; !ok || counted[key] != want.n {
			findings = append(findings, fmt.Sprintf("%s: rendered %d times, census holds %d: give the site a case "+
				"driving a printable non-ASCII character through it (as TestDecryptRendersIDsASCII does) and render "+
				"any repository-supplied part with %%+q; then record the count and why the operand is safe in "+
				"renderCensus", key, counted[key], want.n))
		}
	}
	for _, key := range slices.Sorted(maps.Keys(census)) {
		if _, ok := counted[key]; !ok {
			findings = append(findings, fmt.Sprintf("%s: in renderCensus but counted nowhere: remove the row, unless "+
				"a call refused above renders it, since none of a refused call's operands is counted", key))
		}
	}
	return findings
}

// formatVerb is one directive of an fmt format: its flags and its verb.
type formatVerb struct {
	flags string
	verb  rune
}

func (v formatVerb) String() string { return "%" + v.flags + string(v.verb) }

// escapes reports whether v is %+q, which renders a string, a []byte and the text of an error or a Stringer with
// strconv.QuoteToASCII and an integer with strconv.QuoteRuneToASCII. An operand whose type has a Format method
// renders itself instead; readRender refuses one declared in the packages it reads, and cannot see one declared
// elsewhere. A sharp flag defeats it: fmt backquotes a string under %#+q when strconv.CanBackquote allows, and
// that leaves printable non-ASCII raw.
func (v formatVerb) escapes() bool {
	return v.verb == 'q' && strings.Contains(v.flags, "+") && !strings.Contains(v.flags, "#")
}

// formatVerbs returns the directives of an fmt format in order, one per operand. It reports false for a format
// whose directives it cannot map to operands by position: fmt's explicit argument index, a star width or
// precision, or a trailing percent sign.
func formatVerbs(s string) ([]formatVerb, bool) {
	var verbs []formatVerb
	for i := 0; i < len(s); i++ {
		if s[i] != '%' {
			continue
		}
		i++
		start := i
		for i < len(s) && strings.IndexByte("+-# 0", s[i]) >= 0 {
			i++
		}
		flags := s[start:i]
		for i < len(s) && (s[i] >= '0' && s[i] <= '9' || s[i] == '.') {
			i++
		}
		if i >= len(s) || s[i] == '[' || s[i] == '*' {
			return verbs, false
		}
		r, size := utf8.DecodeRuneInString(s[i:])
		if r != '%' { // a percent sign takes no operand, whatever flags precede it
			verbs = append(verbs, formatVerb{flags, r})
		}
		i += size - 1
	}
	return verbs, true
}

// Operand positions of the fmt functions readRender reads: the format's for the f family, the first rendered
// operand's for the others. Any other member of fmt is refused.
var (
	fmtFormats = map[string]int{"Errorf": 0, "Sprintf": 0, "Printf": 0, "Fprintf": 1, "Appendf": 1}
	fmtPrints  = map[string]int{"Print": 0, "Println": 0, "Sprint": 0, "Sprintln": 0, "Fprint": 1, "Fprintln": 1,
		"Append": 1, "Appendln": 1}
)

// readRender reads Go sources keyed by slash path from the module root and returns what it refuses and, for every
// operand fmt renders that is not escaped or fixed text, how many times each file renders it with each verb.
//
// It refuses:
//   - %q, or any q directive carrying a sharp flag or no plus flag: strconv.Quote, or backquotes, leave printable
//     non-ASCII raw. %+q is the escaping spelling, and an operand under it is never counted;
//   - an fmt call whose format is not a string literal, whose directives formatVerbs cannot map, whose operands
//     are spread with ..., or whose directive and operand counts differ. fmt renders an extra operand after the
//     text and a directive with no operand as %!verb(MISSING), and either way the directives cannot be paired with
//     the operands. None of a refused call's operands is counted, so its census rows can read as counted nowhere;
//   - a member of fmt that is named without being the function of the call it stands in, such as one bound to a
//     variable or called through parentheses, and one that is neither in fmtFormats nor in fmtPrints;
//   - errors.New of anything but a string literal, and a member of errors other than New, Is and As;
//   - an assignment to an exempt name, as the target of =, of a range clause or of &: a sentinel is fixed text
//     only while nothing writes to it, and a write would give it any text at all. These two packages are the only
//     ones of this module prifly-bootstrap links (measured with go list -deps, not checked here), and no package
//     outside the module can import internal/bootstrap, so they are the only sources that can write one by name;
//   - a dot import, which leaves no selector to resolve;
//   - a method named Error, String, GoString or Format, which fmt calls to render a value, so a type declaring one
//     decides its own text past every directive.
//
// Package names are resolved through each file's imports, so an aliased fmt or errors is read as itself. A name
// resolves to an import only where the parser leaves it unresolved in the file: a local variable of the same name
// shadows the import, and a call made through one is not read as fmt.
//
// What this does not reach: a write that makes no fmt call
// (an io.Writer's Write, io.WriteString, io.Copy, the log package or panic); text a function in another package
// renders and returns; and where an operand's value came from, which renderCensus records rather than checks.
// cmd/prifly's TestCommandStreamsAreWrittenThroughFmt, which refuses a write to its streams made other than through
// fmt, has no counterpart here.
func readRender(sources map[string]string) (findings []string, counted map[string]int) {
	fset, counted := token.NewFileSet(), map[string]int{}
	type parsed struct {
		file *ast.File
		pkg  string // import path
	}
	var files []parsed
	topLevel := map[any]bool{}           // the package-level value specs, by node
	free := map[string]map[string]bool{} // import path -> names of string constants and fixed-text sentinels
	for _, name := range slices.Sorted(maps.Keys(sources)) {
		f, err := parser.ParseFile(fset, name, sources[name], 0)
		if err != nil {
			findings = append(findings, err.Error())
			continue
		}
		pkg := modulePath + "/" + path.Dir(name)
		files = append(files, parsed{f, pkg})
		if free[pkg] == nil {
			free[pkg] = map[string]bool{}
		}
		imports := map[string]string{}
		for _, imp := range f.Imports {
			p, _ := strconv.Unquote(imp.Path.Value)
			imports[cmp.Or(nameOf(imp.Name), path.Base(p))] = p
		}
		for _, decl := range f.Decls {
			gen, ok := decl.(*ast.GenDecl)
			if !ok || (gen.Tok != token.CONST && gen.Tok != token.VAR) {
				continue
			}
			for _, spec := range gen.Specs {
				vs := spec.(*ast.ValueSpec)
				topLevel[vs] = true
				for i, id := range vs.Names {
					if i < len(vs.Values) && fixedText(vs.Values[i], gen.Tok, imports) {
						free[pkg][id.Name] = true
					}
				}
			}
		}
	}
	for _, p := range files {
		f := p.file
		at := func(n ast.Node) string { return fset.Position(n.Pos()).String() }
		file := fset.Position(f.Pos()).Filename
		imports := map[string]string{}
		for _, imp := range f.Imports {
			ipath, _ := strconv.Unquote(imp.Path.Value)
			if nameOf(imp.Name) == "." {
				findings = append(findings, fmt.Sprintf("%s: dot import of %s leaves no selector to resolve", at(imp), ipath))
				continue
			}
			imports[cmp.Or(nameOf(imp.Name), path.Base(ipath))] = ipath
		}
		// pkgOf resolves x to the import it names, or "" when it names something else.
		pkgOf := func(x ast.Expr) string {
			if id, ok := x.(*ast.Ident); ok && id.Obj == nil {
				return imports[id.Name]
			}
			return ""
		}
		// exempt reports whether e, parentheses aside, names a string constant or a fixed-text sentinel: a
		// package-level name of this package, or one of another package read here through its import.
		exempt := func(e ast.Expr) bool {
			for paren, ok := e.(*ast.ParenExpr); ok; paren, ok = e.(*ast.ParenExpr) {
				e = paren.X
			}
			switch a := e.(type) {
			case *ast.Ident:
				return (a.Obj == nil || topLevel[a.Obj.Decl]) && free[p.pkg][a.Name]
			case *ast.SelectorExpr:
				return free[pkgOf(a.X)] != nil && free[pkgOf(a.X)][a.Sel.Name]
			}
			return false
		}
		isFree := func(arg ast.Expr) bool {
			_, lit := arg.(*ast.BasicLit)
			return lit || exempt(arg)
		}
		// assigned refuses a write to an exempt name, which would make its text whatever was written.
		assigned := func(target ast.Expr) {
			if exempt(target) {
				findings = append(findings, fmt.Sprintf("%s: %s is exempt from the census as text written in this "+
					"source, and a write to it would render whatever was written; leave it as declared",
					at(target), types.ExprString(target)))
			}
		}
		render := func(v formatVerb, arg ast.Expr) {
			switch {
			case v.verb == 'q' && !v.escapes():
				findings = append(findings, fmt.Sprintf("%s: %v renders %s with strconv.Quote or backquotes, which "+
					"leave printable non-ASCII raw; use %%+q", at(arg), v, types.ExprString(arg)))
			case v.escapes() || isFree(arg):
			default:
				counted[fmt.Sprintf("%s %v %s", file, v, types.ExprString(arg))]++
			}
		}
		called := map[ast.Expr]bool{}
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.AssignStmt:
				for _, lhs := range n.Lhs {
					assigned(lhs)
				}
			case *ast.RangeStmt:
				// Under :=, as in an assignment, the names are new locals, which exempt does not read as package-level.
				for _, target := range []ast.Expr{n.Key, n.Value} { // either may be nil, which exempt reads as no name
					assigned(target)
				}
			case *ast.UnaryExpr:
				if n.Op == token.AND {
					assigned(n.X) // its address is a write waiting to happen
				}
			case *ast.FuncDecl:
				if n.Recv != nil && slices.Contains([]string{"Error", "String", "GoString", "Format"}, n.Name.Name) {
					findings = append(findings, fmt.Sprintf("%s: method %s decides how fmt renders its type, past "+
						"every directive this control reads", at(n), n.Name.Name))
				}
			case *ast.CallExpr:
				called[n.Fun] = true // recorded before the walk reaches n.Fun, its child
				sel, ok := n.Fun.(*ast.SelectorExpr)
				if !ok {
					break
				}
				switch pkgOf(sel.X) {
				case "errors":
					if sel.Sel.Name == "New" && (len(n.Args) != 1 || !isString(n.Args[0])) {
						findings = append(findings, fmt.Sprintf("%s: errors.New of %s: its text reaches the "+
							"terminal unread; give it a string literal", at(n), exprs(n.Args)))
					}
				case "fmt":
					if n.Ellipsis.IsValid() {
						findings = append(findings, fmt.Sprintf("%s: fmt.%s spreads its operands with ..., so its "+
							"directives cannot be mapped to them", at(n), sel.Sel.Name))
						break
					}
					if i, ok := fmtPrints[sel.Sel.Name]; ok && i <= len(n.Args) {
						for _, arg := range n.Args[i:] {
							render(formatVerb{verb: 'v'}, arg)
						}
						break
					}
					i, ok := fmtFormats[sel.Sel.Name]
					if !ok || i >= len(n.Args) {
						findings = append(findings, fmt.Sprintf("%s: fmt.%s is not a function this control reads",
							at(n), sel.Sel.Name))
						break
					}
					lit, ok := n.Args[i].(*ast.BasicLit)
					format, err := "", error(nil)
					if ok && lit.Kind == token.STRING {
						format, err = strconv.Unquote(lit.Value)
					}
					verbs, mappable := formatVerbs(format)
					switch {
					case !ok || lit.Kind != token.STRING || err != nil:
						findings = append(findings, fmt.Sprintf("%s: fmt.%s format %s is not a string literal, so "+
							"its directives go unread", at(n), sel.Sel.Name, types.ExprString(n.Args[i])))
					case !mappable:
						findings = append(findings, fmt.Sprintf("%s: format %q uses an explicit argument index, a "+
							"star width or precision, or a trailing %%, which this control cannot map to operands",
							at(n), format))
					case len(verbs) < len(n.Args)-i-1:
						findings = append(findings, fmt.Sprintf("%s: format %q has %d directives for %d operands; "+
							"fmt renders each extra operand after the text, where no directive reads it, so none of "+
							"this call's operands is counted", at(n), format, len(verbs), len(n.Args)-i-1))
					case len(verbs) > len(n.Args)-i-1:
						findings = append(findings, fmt.Sprintf("%s: format %q has %d directives for %d operands; "+
							"fmt renders a directive with no operand as %%!verb(MISSING), and this control cannot tell "+
							"which operand each directive reads, so none of this call's operands is counted",
							at(n), format, len(verbs), len(n.Args)-i-1))
					default:
						for j, v := range verbs {
							render(v, n.Args[i+1+j])
						}
					}
				}
			case *ast.SelectorExpr:
				switch pkgOf(n.X) {
				case "fmt":
					if !called[n] {
						findings = append(findings, fmt.Sprintf("%s: fmt.%s is named here without being called, "+
							"so the calls made through it go unread; name an fmt member only where you call it",
							at(n), n.Sel.Name))
					}
				case "errors":
					if !slices.Contains([]string{"New", "Is", "As"}, n.Sel.Name) || n.Sel.Name == "New" && !called[n] {
						findings = append(findings, fmt.Sprintf("%s: errors.%s is not a use this control reads; "+
							"call errors.New only with a string literal", at(n), n.Sel.Name))
					}
				}
			}
			return true
		})
	}
	return findings, counted
}

func nameOf(id *ast.Ident) string {
	if id == nil {
		return ""
	}
	return id.Name
}

func isString(e ast.Expr) bool {
	lit, ok := e.(*ast.BasicLit)
	return ok && lit.Kind == token.STRING
}

// fixedText reports whether a package-level value renders as text written in this source: a constant whose value
// is a string literal, or a variable initialised with errors.New of one.
func fixedText(value ast.Expr, tok token.Token, imports map[string]string) bool {
	if tok == token.CONST {
		return isString(value)
	}
	call, ok := value.(*ast.CallExpr)
	if !ok || len(call.Args) != 1 || !isString(call.Args[0]) {
		return false
	}
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok {
		return false
	}
	x, isName := sel.X.(*ast.Ident)
	return isName && imports[x.Name] == "errors" && sel.Sel.Name == "New"
}

func exprs(args []ast.Expr) string {
	s := make([]string, len(args))
	for i, a := range args {
		s[i] = types.ExprString(a)
	}
	return strings.Join(s, ", ")
}

// TestCheckCensus holds checkCensus to each way a count can differ from the census.
func TestCheckCensus(t *testing.T) {
	census := map[string]censusRow{"a %s x": {2, ""}, "a %d y": {1, ""}}
	for name, c := range map[string]struct {
		counted map[string]int
		want    []string
	}{
		"as recorded":      {map[string]int{"a %s x": 2, "a %d y": 1}, nil},
		"one more":         {map[string]int{"a %s x": 3, "a %d y": 1}, []string{"a %s x: rendered 3 times, census holds 2"}},
		"one fewer":        {map[string]int{"a %s x": 1, "a %d y": 1}, []string{"a %s x: rendered 1 times, census holds 2"}},
		"not recorded":     {map[string]int{"a %s x": 2, "a %d y": 1, "a %v z": 1}, []string{"a %v z: rendered 1 times, census holds 0"}},
		"rendered nowhere": {map[string]int{"a %s x": 2}, []string{"a %d y: in renderCensus but counted nowhere"}},
	} {
		t.Run(name, func(t *testing.T) {
			got := checkCensus(c.counted, census)
			ok := len(got) == len(c.want)
			for i := 0; ok && i < len(got); i++ {
				ok = strings.HasPrefix(got[i], c.want[i])
			}
			if !ok {
				t.Errorf("findings = %q, want %q", got, c.want)
			}
		})
	}
}

// TestReadRenderRules holds each rule of readRender to a fixture it must refuse or count, and the escaping and
// fixed-text spellings to fixtures it must pass, so that weakening a rule is red here and not only on a tree that
// happens to carry the shape.
func TestReadRenderRules(t *testing.T) {
	const x, cmd = "internal/bootstrap/x.go", "cmd/prifly-bootstrap/main.go"
	lib := func(body string) map[string]string {
		return map[string]string{x: "package bootstrap\n\nimport (\n\t\"errors\"\n\t\"fmt\"\n\t\"io\"\n)\n\n" +
			"var ErrX = errors.New(\"x\")\n\nconst C = \"c\"\n\nvar _ io.Writer\n\n" + body}
	}
	type ruleCase struct {
		sources map[string]string
		refuse  []string       // one finding holding each, and no other
		counted map[string]int // exactly
	}
	cases := map[string]ruleCase{
		"escaped id":          {lib(`func f(id string) error { return fmt.Errorf("%w: %+q", ErrX, id) }`), nil, nil},
		"escaped with width":  {lib(`func f(id string) error { return fmt.Errorf("%w: %-+8q", ErrX, id) }`), nil, nil},
		"flag after width":    {lib(`func f(id string) error { return fmt.Errorf("%w: %-8+q", ErrX, id) }`), nil, map[string]int{x + " %-+ id": 1}},
		"plain q":             {lib(`func f(id string) error { return fmt.Errorf("%w: %q", ErrX, id) }`), []string{"%q renders id"}, nil},
		"sharp plus q":        {lib(`func f(id string) error { return fmt.Errorf("%w: %#+q", ErrX, id) }`), []string{"%#+q renders id"}, nil},
		"q on a constant":     {lib(`func f() error { return fmt.Errorf("%w: %q", ErrX, C) }`), []string{"%q renders C"}, nil},
		"s of a parameter":    {lib(`func f(id string) error { return fmt.Errorf("%w: %s", ErrX, id) }`), nil, map[string]int{x + " %s id": 1}},
		"d of a field":        {lib(`func f(e struct{ N int }) error { return fmt.Errorf("%d %d", e.N, e.N) }`), nil, map[string]int{x + " %d e.N": 2}},
		"s of a constant":     {lib(`func f() error { return fmt.Errorf("%w: %s %v", ErrX, C, "lit") }`), nil, nil},
		"shadowed constant":   {lib(`func f(id string) error { C := id; return fmt.Errorf("%s", C) }`), nil, map[string]int{x + " %s C": 1}},
		"w of a variable":     {lib(`func f(err error) error { return fmt.Errorf("%w", err) }`), nil, map[string]int{x + " %w err": 1}},
		"percent sign":        {lib(`func f(id string) error { return fmt.Errorf("100%% %s", id) }`), nil, map[string]int{x + " %s id": 1}},
		"format not literal":  {lib(`func f(id string) error { return fmt.Errorf(C, id) }`), []string{"format C is not a string literal"}, nil},
		"argument index":      {lib(`func f(id string) error { return fmt.Errorf("%[1]s", id) }`), []string{"cannot map"}, nil},
		"star width":          {lib(`func f(id string) error { return fmt.Errorf("%*s", 4, id) }`), []string{"cannot map"}, nil},
		"star precision":      {lib(`func f(id string) error { return fmt.Errorf("%.*s", 4, id) }`), []string{"cannot map"}, nil},
		"trailing percent":    {lib(`func f(id string) error { return fmt.Errorf("%s %", id) }`), []string{"cannot map"}, nil},
		"extra operand":       {lib(`func f(id string) error { return fmt.Errorf("%w", ErrX, id) }`), []string{"1 directives for 2 operands; fmt renders each extra operand"}, nil},
		"missing operand":     {lib(`func f(id string) error { return fmt.Errorf("%s %s", id) }`), []string{"2 directives for 1 operands; fmt renders a directive with no operand"}, nil},
		"spread operands":     {lib(`func f(a []any) error { return fmt.Errorf("%s", a...) }`), []string{"spreads its operands"}, nil},
		"bound fmt member":    {lib(`var p = fmt.Sprintf`), []string{"fmt.Sprintf is named here without being called"}, nil},
		"parenthesised call":  {lib(`func f(id string) string { return (fmt.Sprintf)("%s", id) }`), []string{"fmt.Sprintf is named here without being called"}, nil},
		"unread fmt member":   {lib(`func f(id string) { var s string; fmt.Sscan(id, &s) }`), []string{"fmt.Sscan is not a function this control reads"}, nil},
		"print family":        {lib(`func f(w any, id string) { fmt.Fprint(w, id, C); fmt.Println("lit") }`), nil, map[string]int{x + " %v id": 1}},
		"errors.New of text":  {lib(`func f(id string) error { return errors.New(id) }`), []string{"errors.New of id"}, nil},
		"errors.Join":         {lib(`func f(err error) error { return errors.Join(ErrX, err) }`), []string{"errors.Join is not a use"}, nil},
		"bound errors.New":    {lib(`var n = errors.New`), []string{"errors.New is not a use"}, nil},
		"error method":        {lib(`type e string` + "\n\n" + `func (v e) Error() string { return string(v) }`), []string{"method Error decides"}, nil},
		"format method":       {lib(`type e string` + "\n\n" + `func (v e) Format() {}`), []string{"method Format decides"}, nil},
		"errors.Is and As":    {lib(`func f(err error) bool { var p *error; return errors.Is(err, ErrX) || errors.As(err, p) }`), nil, nil},
		"sentinel from a var": {lib(`var ErrY = errors.New(C)` + "\n\n" + `func f() error { return fmt.Errorf("%v", ErrY) }`), []string{"errors.New of C"}, map[string]int{x + " %v ErrY": 1}},
		"plus s and plus v":   {lib(`func f(id string) error { return fmt.Errorf("%w: %+s %+v", ErrX, id, id) }`), nil, map[string]int{x + " %+s id": 1, x + " %+v id": 1}},
		"string method":       {lib(`type e string` + "\n\n" + `func (v e) String() string { return string(v) }`), []string{"method String decides"}, nil},
		"gostring method":     {lib(`type e string` + "\n\n" + `func (v e) GoString() string { return string(v) }`), []string{"method GoString decides"}, nil},
		"assign sentinel":     {lib(`func f(err error) { ErrX = err }`), []string{"ErrX is exempt from the census"}, nil},
		"assign in parens":    {lib(`func f(err error) { (ErrX), _ = err, 1 }`), []string{"(ErrX) is exempt from the census"}, nil},
		"range assigns":       {lib(`func f(errs []error) { for _, ErrX = range errs {} }`), []string{"ErrX is exempt from the census"}, nil},
		"range key assigns":   {lib(`func f(m map[error]int) { for ErrX = range m {} }`), []string{"ErrX is exempt from the census"}, nil},
		"address of sentinel": {lib(`func f() *error { return &ErrX }`), []string{"ErrX is exempt from the census"}, nil},
		"define shadows":      {lib(`func f(err error) error { ErrX := err; for ErrX := range []error{err} { _ = ErrX }; return ErrX }`), nil, nil},
		"assign a local":      {lib(`func f(id string) error { var e error; e = ErrX; _ = &e; return fmt.Errorf("%s", id) }`), nil, map[string]int{x + " %s id": 1}},
		"computed constant":   {lib(`const N = 1 << 3` + "\n\n" + `func f() error { return fmt.Errorf("%d", N) }`), nil, map[string]int{x + " %d N": 1}},
		"new of another package": {lib(`var ErrZ = other.New("z")` + "\n\n" + `func f() error { return fmt.Errorf("%v", ErrZ) }`), nil,
			map[string]int{x + " %v ErrZ": 1}},
		"errors member not New": {lib(`var ErrW = errors.Join("w")` + "\n\n" + `func f() error { return fmt.Errorf("%v", ErrW) }`),
			[]string{"errors.Join is not a use"}, map[string]int{x + " %v ErrW": 1}},
		"errors.New of nothing": {lib(`var ErrV = errors.New()`), []string{"errors.New of :"}, nil},
		"format of nothing":     {lib(`func f() error { return fmt.Errorf() }`), []string{"fmt.Errorf is not a function"}, nil},
		"print of nothing":      {lib(`func f() { fmt.Fprint() }`), []string{"fmt.Fprint is not a function"}, nil},
		"unparsable source":     {map[string]string{x: "package bootstrap\n\nfunc {"}, []string{"expected"}, nil},
		"shadowed fmt": {lib(`type w struct{}` + "\n\n" + `func (w) Sprintf(string, ...any) string { return "" }` + "\n\n" +
			`func f(id string) string { fmt := w{}; return fmt.Sprintf("%q", id) }`), nil, nil},
		"aliased fmt": {map[string]string{x: "package bootstrap\n\nimport f \"fmt\"\n\nfunc g(id string) error { return f.Errorf(\"%q\", id) }"},
			[]string{"%q renders id"}, nil},
		"dot import": {map[string]string{x: "package bootstrap\n\nimport . \"fmt\"\n\nfunc g(id string) error { return Errorf(\"%s\", id) }"},
			[]string{"dot import of fmt"}, nil},
		"sentinel across packages": {map[string]string{
			x:   "package bootstrap\n\nimport \"errors\"\n\nvar ErrX = errors.New(\"x\")\n\nconst P = \"p\"",
			cmd: "package main\n\nimport (\n\t\"fmt\"\n\n\tb \"github.com/blac9216/PriFly/internal/bootstrap\"\n)\n\nfunc g(id string) error { return fmt.Errorf(\"%w: %s %s\", b.ErrX, b.P, b.Q) }",
		}, nil, map[string]int{cmd + " %s b.Q": 1}},
		"assign across packages": {map[string]string{
			x:   "package bootstrap\n\nimport \"errors\"\n\nvar ErrX = errors.New(\"x\")",
			cmd: "package main\n\nimport b \"github.com/blac9216/PriFly/internal/bootstrap\"\n\nfunc g(err error) { b.ErrX = err }",
		}, []string{"b.ErrX is exempt from the census"}, nil},
		"assign in another file": {map[string]string{
			x:                         "package bootstrap\n\nimport \"errors\"\n\nvar ErrX = errors.New(\"x\")",
			"internal/bootstrap/y.go": "package bootstrap\n\nfunc g(err error) { ErrX = err }",
		}, []string{"ErrX is exempt from the census"}, nil},
		"sentinel of another package": {map[string]string{
			x:   "package bootstrap\n\nimport \"errors\"\n\nvar ErrX = errors.New(\"x\")",
			cmd: "package main\n\nimport (\n\t\"fmt\"\n\t\"io\"\n)\n\nfunc g() error { return fmt.Errorf(\"%w %v\", io.EOF, ErrX) }",
		}, nil, map[string]int{cmd + " %w io.EOF": 1, cmd + " %v ErrX": 1}},
	}
	// One case per print-family member, the id its first rendered operand, so each operand position is pinned.
	// The calls are written out rather than built from fmtPrints, which would move with a mutant of it.
	for fn, call := range map[string]string{
		"Print": "fmt.Print(id)", "Println": "fmt.Println(id)", "Sprint": "_ = fmt.Sprint(id)",
		"Sprintln": "_ = fmt.Sprintln(id)", "Fprint": "fmt.Fprint(w, id)", "Fprintln": "fmt.Fprintln(w, id)",
		"Append": "_ = fmt.Append(b, id)", "Appendln": "_ = fmt.Appendln(b, id)",
	} {
		cases["print family "+fn] = ruleCase{lib(`func f(w io.Writer, b []byte, id string) { ` + call + ` }`), nil,
			map[string]int{x + " %v id": 1}}
	}
	for fn := range fmtPrints {
		if _, ok := cases["print family "+fn]; !ok {
			t.Errorf("fmt.%s is read as a print-family member and has no case of its own here", fn)
		}
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			findings, counted := readRender(c.sources)
			for _, want := range c.refuse {
				n := 0
				for _, f := range findings {
					if strings.Contains(f, want) {
						n++
					}
				}
				if n != 1 {
					t.Errorf("%d findings hold %q, want 1: %q", n, want, findings)
				}
			}
			if len(findings) != len(c.refuse) {
				t.Errorf("findings = %q, want one for each of %q", findings, c.refuse)
			}
			if !maps.Equal(counted, c.counted) && len(counted)+len(c.counted) != 0 {
				t.Errorf("counted = %v, want %v", counted, c.counted)
			}
		})
	}
}
