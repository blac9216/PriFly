package main

import (
	"fmt"
	"go/parser"
	"go/token"
	"io/fs"
	"maps"
	"os"
	"path"
	"slices"
	"strconv"
	"strings"
	"testing"
	"testing/fstest"
)

// TestLinkedPackagesHoldOnlyGoSource refuses, in every module package prifly
// or prifly-bootstrap links, a file the go tool can build into the package that
// no render or import control reads. Each of those controls parses a package's
// *.go files: TestCommandRendersASCII, TestCommandStreamsAreWrittenThroughFmt,
// TestBundleImportsNoNetworkOrProcess and TestBundleDiagnosticsRenderASCII here,
// and TestBootstrapRendersASCII in internal/bootstrap. The go tool also builds
// assembly and object files into a package with no cgo at all, and C and the
// other cgo kinds into one where a .go file imports "C", so any such file is
// part of the package and outside every one of them. What it refuses is stated
// at linkedNonGoSources, and what that closes and does not close is stated at
// each control whose limits it changes.
//
// The packages are derived from the link graph rather than listed, so a package
// linked later is read by the rule as soon as it is linked. linkSets pins what
// the derivation finds today for each binary on its own, which keeps the walk
// from going quietly inert and makes a package either binary newly links red
// here until someone records it, having decided whether the Go-source controls
// above reach it too. The pin is per binary rather than over both together
// because the controls are: a package prifly-bootstrap newly links is outside
// TestBootstrapRendersASCII even when prifly already links it.
func TestLinkedPackagesHoldOnlyGoSource(t *testing.T) {
	repo := os.DirFS("../..")
	_, findings, err := linkedNonGoSources(repo, slices.Sorted(maps.Keys(linkSets))...)
	if err != nil {
		t.Fatal(err)
	}
	drift, err := linkSetDrift(repo, linkSets)
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range append(findings, drift...) {
		t.Error(f)
	}
}

// linkSets is, for the main package of each binary, the module packages
// linkedNonGoSources derives it links, as directories of the module's root.
var linkSets = map[string][]string{
	"cmd/prifly":           {"cmd/prifly", "internal/buildinfo", "internal/bundle"},
	"cmd/prifly-bootstrap": {"cmd/prifly-bootstrap", "internal/bootstrap"},
}

// linkSetDrift returns a finding for each root of want whose link set, derived
// by linkedNonGoSources from that root alone, is not want[root].
func linkSetDrift(fsys fs.FS, want map[string][]string) ([]string, error) {
	var findings []string
	for _, root := range slices.Sorted(maps.Keys(want)) {
		dirs, _, err := linkedNonGoSources(fsys, root)
		if err != nil {
			return nil, err
		}
		if !slices.Equal(dirs, want[root]) {
			findings = append(findings, fmt.Sprintf("%s links module packages %q, want %q; record a package it "+
				"newly links once the render and import controls that read it are decided", root, dirs, want[root]))
		}
	}
	return findings, nil
}

// linkedNonGoSources returns the module packages the binaries whose main
// packages are roots link, as directories of fsys, which is the module's root,
// and a finding for each file among them that the go tool can build into its
// package and that is not Go source. Each finding names the file and says why.
//
// The packages are the roots, then every module package that a non-test .go
// file of a package already found imports. Every such file is read whatever its
// build constraints say, so a package imported only on some other platform is
// in the set too: the set can be larger than what one build links, never
// smaller. A test file's imports are not followed, since the go tool does not
// link a test file into a binary.
//
// In each of those packages it refuses two things:
//   - Any entry that is not a directory and whose name does not end in .go. This
//     is by name rather than by go/build's lists of non-Go files, so it needs no
//     list of the extensions the go tool builds, which a later toolchain could
//     add to, and it evaluates no build constraint, so a file that this platform
//     would leave out is refused as well. It has no test-file exception: the go
//     tool treats no non-Go file as a test file, so a _test.s is built into the
//     package too. A name that begins with _ or ., which the go tool ignores, is
//     refused anyway, since nothing on the tree needs one.
//   - A .go file, a test file included, that imports "C". The C in such a file's
//     preamble is built into the package, a constructor that writes to fd 2
//     included, with no non-Go file at all. The go tool does not accept cgo in a
//     test file, so reading those too costs nothing and needs no exception.
func linkedNonGoSources(fsys fs.FS, roots ...string) (dirs, findings []string, err error) {
	const module = "github.com/blac9216/PriFly"
	fset, seen, queue := token.NewFileSet(), map[string]bool{}, slices.Clone(roots)
	for len(queue) > 0 {
		dir := queue[0]
		queue = queue[1:]
		if seen[dir] {
			continue
		}
		seen[dir] = true
		entries, err := fs.ReadDir(fsys, dir)
		if err != nil {
			return nil, nil, err
		}
		for _, e := range entries {
			name, file := e.Name(), path.Join(dir, e.Name())
			if e.IsDir() {
				continue
			}
			if !strings.HasSuffix(name, ".go") {
				findings = append(findings, fmt.Sprintf("%s: not a .go file; the go tool can build a file of "+
					"this kind into the package, and no render or import control reads one", file))
				continue
			}
			src, err := fs.ReadFile(fsys, file)
			if err != nil {
				return nil, nil, err
			}
			f, err := parser.ParseFile(fset, file, src, parser.ImportsOnly)
			if err != nil {
				return nil, nil, err
			}
			for _, imp := range f.Imports {
				p, _ := strconv.Unquote(imp.Path.Value)
				if p == "C" {
					findings = append(findings, fmt.Sprintf("%s: imports \"C\"; the go tool builds the C in "+
						"its preamble into the package, and no render or import control reads it", file))
				}
				if strings.HasSuffix(name, "_test.go") {
					continue
				}
				if p == module {
					queue = append(queue, ".")
				} else if pkg, local := strings.CutPrefix(p, module+"/"); local {
					queue = append(queue, pkg)
				}
			}
		}
	}
	return slices.Sorted(maps.Keys(seen)), findings, nil
}

// TestLinkedNonGoSourcesRule pins each rule of linkedNonGoSources with a case
// that is red when that rule alone is reverted. Every fixture is in memory, so
// nothing here writes into the source tree.
func TestLinkedNonGoSourcesRule(t *testing.T) {
	const module = "github.com/blac9216/PriFly"
	goFile := func(pkg string, imports ...string) *fstest.MapFile {
		src := "package " + pkg + "\n"
		for _, p := range imports {
			src += "\nimport _ " + strconv.Quote(p) + "\n"
		}
		return &fstest.MapFile{Data: []byte(src)}
	}

	// One case per kind. The extensions are go/build's own at go1.27.1
	// (fileListForExt), written out rather than read from go/build so the cases
	// do not move with it, then names that are refused by the same rule for a
	// reason of their own: a test-file suffix, a build-constraint suffix a
	// linux/amd64 build excludes, the two prefixes the go tool ignores, and names
	// with no extension the go tool knows.
	names := []string{}
	for _, ext := range []string{".c", ".cc", ".cpp", ".cxx", ".m", ".h", ".hh", ".hpp", ".hxx",
		".f", ".F", ".for", ".f90", ".s", ".S", ".sx", ".swig", ".swigcxx", ".syso"} {
		names = append(names, "x"+ext)
	}
	names = append(names, "x_test.s", "x_windows_arm64.s", "_x.s", ".x.s", "x.GO", "README")
	for _, name := range names {
		t.Run("kind "+name, func(t *testing.T) {
			fsys := fstest.MapFS{"p/p.go": goFile("p"), "p/" + name: &fstest.MapFile{}}
			_, findings, err := linkedNonGoSources(fsys, "p")
			if err != nil {
				t.Fatal(err)
			}
			if len(findings) != 1 || !strings.HasPrefix(findings[0], "p/"+name+": not a .go file") {
				t.Errorf("findings = %q, want one for p/%s", findings, name)
			}
		})
	}

	for name, c := range map[string]struct {
		fsys   fstest.MapFS
		refuse []string // the file each finding names, in order
	}{
		"go source only":  {fstest.MapFS{"p/p.go": goFile("p"), "p/p_test.go": goFile("p", "testing")}, nil},
		"a subdirectory":  {fstest.MapFS{"p/p.go": goFile("p"), "p/testdata/x.s": {}, "p/y.s/z.go": goFile("z")}, nil},
		"a symlink":       {fstest.MapFS{"p/p.go": goFile("p"), "p/l.s": {Mode: fs.ModeSymlink, Data: []byte("x.s")}}, []string{"p/l.s: not a .go file"}},
		"cgo":             {fstest.MapFS{"p/p.go": goFile("p", "C")}, []string{"p/p.go: imports \"C\""}},
		"cgo in a test":   {fstest.MapFS{"p/p.go": goFile("p"), "p/p_test.go": goFile("p", "C")}, []string{"p/p_test.go: imports \"C\""}},
		"cgo among other": {fstest.MapFS{"p/p.go": goFile("p", "fmt", "C", "os")}, []string{"p/p.go: imports \"C\""}},
	} {
		t.Run(name, func(t *testing.T) {
			_, findings, err := linkedNonGoSources(c.fsys, "p")
			if err != nil {
				t.Fatal(err)
			}
			if len(findings) != len(c.refuse) {
				t.Fatalf("findings = %q, want one each for %q", findings, c.refuse)
			}
			for i, want := range c.refuse {
				if !strings.HasPrefix(findings[i], want) {
					t.Errorf("finding %d = %q, want it to begin %q", i, findings[i], want)
				}
			}
		})
	}

	// The link graph: two roots sharing a package, a package reached only
	// through another, two reached only as the second module import of a file,
	// one imported only by a file whose name limits it to windows, the module's
	// root package, and two that nothing linked imports: one imported only by a
	// test file, one by nothing.
	graph := fstest.MapFS{
		"a/a.go":         goFile("main", module+"/b"),
		"a/a_windows.go": goFile("main", module+"/f"),
		"a/a_test.go":    goFile("main", module+"/e"),
		"r/r.go":         goFile("main", module+"/c", module+"/h"),
		"b/b.go":         goFile("b", "fmt", module+"/c", module+"/g"),
		"c/c.go":         goFile("c", module),
		"root.go":        goFile("prifly"),
		"d/d.go":         goFile("d"),
		"e/e.go":         goFile("e"),
		"f/f.go":         goFile("f"),
		"g/g.go":         goFile("g"),
		"h/h.go":         goFile("h"),
	}
	dirs, findings, err := linkedNonGoSources(graph, "a", "r")
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{".", "a", "b", "c", "f", "g", "h", "r"}; !slices.Equal(dirs, want) || len(findings) != 0 {
		t.Errorf("linked = %q with findings %q, want %q and none", dirs, findings, want)
	}
	for _, dir := range dirs {
		t.Run("graph dir "+dir, func(t *testing.T) { refusedIn(t, graph, dir, "a", "r") })
	}

	// The per-root pin: each root's set as derived, then each root newly linking
	// a package only the other root linked, which leaves the union of the two
	// unchanged.
	sets := map[string][]string{"a": {".", "a", "b", "c", "f", "g"}, "r": {".", "c", "h", "r"}}
	for name, c := range map[string]struct {
		file, imports string // a file added to the graph, and the one package it imports
		drift         string // how the one finding begins, or "" for none
	}{
		"link sets as pinned": {},
		"a newly links h":     {"a/zz.go", module + "/h", "a links"},
		"r newly links b":     {"r/zz.go", module + "/b", "r links"},
	} {
		t.Run(name, func(t *testing.T) {
			fsys := maps.Clone(graph)
			if c.file != "" {
				fsys[c.file] = goFile("main", c.imports)
			}
			drift, err := linkSetDrift(fsys, sets)
			if err != nil {
				t.Fatal(err)
			}
			if c.drift == "" && len(drift) != 0 || c.drift != "" && (len(drift) != 1 || !strings.HasPrefix(drift[0], c.drift)) {
				t.Errorf("drift = %q, want one finding beginning %q, or none if that is empty", drift, c.drift)
			}
		})
	}

	// One case per directory of the real link set: the tree's own Go files,
	// copied into memory, with an empty .s file added to one directory at a time.
	// Only Go files are copied, so a non-Go file on the tree is reported by
	// TestLinkedPackagesHoldOnlyGoSource and not by every case here.
	repo := os.DirFS("../..")
	roots := slices.Sorted(maps.Keys(linkSets))
	dirs, _, err = linkedNonGoSources(repo, roots...)
	if err != nil {
		t.Fatal(err)
	}
	tree := fstest.MapFS{}
	for _, dir := range dirs {
		entries, err := fs.ReadDir(repo, dir)
		if err != nil {
			t.Fatal(err)
		}
		for _, e := range entries {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".go") {
				continue
			}
			data, err := fs.ReadFile(repo, path.Join(dir, e.Name()))
			if err != nil {
				t.Fatal(err)
			}
			tree[path.Join(dir, e.Name())] = &fstest.MapFile{Data: data}
		}
	}
	for _, dir := range dirs {
		t.Run("linked dir "+dir, func(t *testing.T) { refusedIn(t, tree, dir, roots...) })
	}
}

// refusedIn checks that linkedNonGoSources, run over fsys with an empty .s file
// added to dir, reports exactly that file.
func refusedIn(t *testing.T, fsys fstest.MapFS, dir string, roots ...string) {
	t.Helper()
	probe := path.Join(dir, "zz_probe.s")
	fsys = maps.Clone(fsys)
	fsys[probe] = &fstest.MapFile{}
	_, findings, err := linkedNonGoSources(fsys, roots...)
	if err != nil {
		t.Fatal(err)
	}
	if len(findings) != 1 || !strings.HasPrefix(findings[0], probe+": not a .go file") {
		t.Errorf("findings = %q, want one for %s", findings, probe)
	}
}
