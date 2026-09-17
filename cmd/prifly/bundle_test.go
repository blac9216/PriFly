package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/blac9216/PriFly/internal/bundle"
)

const fixtures = "../../tests/fixtures/bundles"

// bundleCopy returns <tmp>/bundle, fixtures/valid overlaid with
// fixtures/<variant>, beside a <tmp>/valid copy so "../valid/bundle.json" names
// a real file outside the bundle root. Both trees stay writable, so an attempted write
// succeeds and shows up in snapshot.
func bundleCopy(t *testing.T, variant string) string {
	base, valid, overlay := t.TempDir(), os.DirFS(filepath.Join(fixtures, "valid")), os.DirFS(filepath.Join(fixtures, variant))
	dir := filepath.Join(base, "bundle")
	err := errors.Join(os.CopyFS(filepath.Join(base, "valid"), valid), os.CopyFS(dir, valid), fs.WalkDir(overlay, ".", func(p string, d fs.DirEntry, err error) error {
		if b, rerr := fs.ReadFile(overlay, p); err == nil && !d.IsDir() {
			return errors.Join(rerr, os.WriteFile(filepath.Join(dir, p), b, 0o644))
		}
		return err
	}))
	if err != nil {
		t.Fatal(err)
	}
	return dir
}

// snapshot fingerprints every path, mode, size, mtime and regular-file content under dir.
func snapshot(dir string) string {
	var b strings.Builder
	filepath.WalkDir(dir, func(p string, d fs.DirEntry, _ error) error {
		info, _ := d.Info()
		var content []byte
		if d.Type().IsRegular() {
			content, _ = os.ReadFile(p)
		}
		fmt.Fprintf(&b, "%s %v %d %d %x\n", p, info.Mode(), info.Size(), info.ModTime().UnixNano(), sha256.Sum256(content))
		return nil
	})
	return b.String()
}

// hostile edits the valid bundle's copy at test time; each key is a variant.
var hostile = map[string]func(dir string) error{
	"trailing-brace":   func(dir string) error { return replaceIn(dir, "\n}\n", "\n}\n}") },
	"trailing-arrays":  func(dir string) error { return replaceIn(dir, "\n}\n", "\n}\n]]]") },
	"trailing-garbage": func(dir string) error { return replaceIn(dir, "\n}\n", "\n}\n}garbage") },
	"control-chars": func(dir string) error {
		return errors.Join(replaceIn(dir, `"`+bundleID+`"`, `"a\u001b[1A\rresult: ok\u202e", "x\nresult: ok\u001b[2K": 1`),
			replaceIn(dir, `"revision": 1`, `"revision": "\u001b[8m"`), replaceIn(dir, `"reviewer.implementation/v1"`, `"\u001b[1A"`),
			replaceIn(dir, `"WorkItem/v1"`, `"\u001b[2K"`), replaceIn(dir, `"artifacts/baseline.json"`, `"\r\u202e"`), replaceIn(dir, `"`+bslSHA+`"`, `"\u001b[8m"`))
	},
	"id-prefix":        func(dir string) error { return replaceIn(dir, `"bnd_`, `"wi_`) },
	"id-length":        func(dir string) error { return replaceIn(dir, `12c12"`, `12c120"`) },
	"id-type":          func(dir string) error { return replaceIn(dir, `"`+bundleID+`"`, `7`) },
	"missing-revision": func(dir string) error { return replaceIn(dir, ",\n  \"revision\": 1", "") },
	"no-bundle-json":   func(dir string) error { return os.Remove(dir + "/bundle.json") },
	"fifo-bundle": func(dir string) error {
		return errors.Join(os.Remove(dir+"/bundle.json"), syscall.Mkfifo(dir+"/bundle.json", 0o644))
	},
	"symlink-escape": func(dir string) error {
		return errors.Join(os.Remove(dir+"/bundle.json"), os.Symlink("../valid/bundle.json", dir+"/bundle.json"))
	},
	"over-size-cap": func(dir string) error { return os.Truncate(dir+"/bundle.json", bundle.MaxFileBytes+1) },
	"fifo-artifact": func(dir string) error {
		return errors.Join(os.Remove(dir+"/artifacts/baseline.json"), syscall.Mkfifo(dir+"/artifacts/baseline.json", 0o644))
	},
	"symlink-escape-artifact": func(dir string) error {
		return errors.Join(os.Remove(dir+"/artifacts/baseline.json"), os.Symlink("../../valid/artifacts/baseline.json", dir+"/artifacts/baseline.json"))
	},
	"over-size-cap-artifact": func(dir string) error { return os.Truncate(dir+"/artifacts/baseline.json", bundle.MaxFileBytes+1) },
	"artifact-id-pattern":    func(dir string) error { return replaceIn(dir, `"wi_8887ffc`, `"wi_8887FFC`) },
}

const (
	bundleID = "bnd_8d0e1c6f026fef7621a0c7b017f12c12"
	bslSHA   = "70e2a30e1b5a5d53b311faf4e2eb50acaed9c4be464fdca8f8eb72c6416efe34"
)

func replaceIn(dir, old, new string) error {
	b, err := os.ReadFile(dir + "/bundle.json")
	if err == nil && !bytes.Contains(b, []byte(old)) {
		err = fmt.Errorf("bundle.json does not contain %q", old)
	}
	return errors.Join(err, os.WriteFile(dir+"/bundle.json", bytes.Replace(b, []byte(old), []byte(new), 1), 0o644))
}

// TestBundleInspectFixtures asserts each fixture's exact output and exit code
// on all of 20 runs (sorted diagnostics, never map order), finishing within
// 30s, with the writable bundle tree left unchanged.
func TestBundleInspectFixtures(t *testing.T) {
	const (
		notPartOf  = ": field is not part of ExternalPlanningBundle/v1"
		notJSON    = "invalid-json $: bundle.json is not a single JSON value"
		notObject  = "invalid-type $: want object"
		unresolved = "unreadable-bundle $: bundle.json does not resolve to a file inside the bundle directory"
		wi, bsl    = "$.artifacts[0]", "$.artifacts[1]"
		baseline   = "unreadable-artifact " + bsl + `.path: "artifacts/baseline.json" `
		wiSHA      = "e7d95ce6f478a7f82dbca4bee40b67d11efe93cdb245a22a03a28703024fa143"
	)
	for variant, want := range map[string][]string{
		"valid":           {"result: ok manifest_sha256=fbc1794d24f6d94d47c2d62021734bf5efdea5d34093f27d6bd905000f546220 (nothing staged or started)"},
		"tampered-digest": {"digest-mismatch " + wi + ".sha256: declared " + wiSHA + ", exact bytes hash to be9861302628ee7be1c9586b626e6d9ecf1403d9dec73e1f148e037140a1ade6"},
		"unsupported-version": {
			"unsupported-schema " + bsl + `.schema: artifact schema "Baseline/v2" is not supported`,
			`unsupported-job $.jobs[0]: job/version "implementer.implementation/v2" is not supported`},
		"unsupported-bundle-schema": {`unsupported-schema $.schema: want "ExternalPlanningBundle/v1", got "ExternalPlanningBundle/v2\x1b[2K"`},
		"unsupported-authority-field": {
			"unknown-field " + wi + ".factory_attempt_id" + notPartOf,
			"unknown-field " + bsl + ".refs" + notPartOf,
			"unknown-field $.dispatch_eligible" + notPartOf,
			"unknown-field $.owner_release_confirmed" + notPartOf,
			"unknown-field $.refs" + notPartOf},
		"malformed-identity": {
			`invalid-id ` + wi + `.id: want wi_<32 lowercase hex>, got "wi_8887ffc730f707abb82bb7cb7068e9140"`,
			"invalid-type " + wi + ".path: want string",
			`invalid-revision ` + wi + `.revision: want integer >= 1, got "1"`,
			`invalid-id ` + bsl + `.id: want bsl_<32 lowercase hex>, got "wi_6e73c229223db574a3c8fa28dd5a1a5a"`,
			"unreadable-artifact " + bsl + `.path: "../valid/artifacts/baseline.json" does not resolve to a file inside the bundle directory`,
			"missing-field " + bsl + ".revision: required field is absent",
			"invalid-digest " + bsl + `.sha256: want 64 lowercase hex SHA-256, got "70E2A30E1B5A5D53B311FAF4E2EB50ACAED9C4BE464FDCA8F8EB72C6416EFE34"`,
			"invalid-type $.artifacts[2]: want object",
			`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "id: ` + bundleID + `"`,
			"invalid-type $.jobs: want array",
			"invalid-revision $.revision: want integer >= 1, got 0"},
		"artifact-id-pattern": {`invalid-id ` + wi + `.id: want wi_<32 lowercase hex>, got "wi_8887FFC730f707abb82bb7cb7068e914"`},
		"id-prefix":           {`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "wi_8d0e1c6f026fef7621a0c7b017f12c12"`},
		"id-length":           {`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "` + bundleID + `0"`},
		"id-type":             {"invalid-type $.bundle_id: want string"},
		"missing-revision":    {"missing-field $.revision: required field is absent"},
		"invalid-json":        {notJSON},
		"trailing-brace":      {notJSON},
		"trailing-arrays":     {notJSON},
		"trailing-garbage":    {notJSON},
		"control-chars": {
			`unsupported-schema ` + wi + `.schema: artifact schema "\x1b[2K" is not supported`,
			`unreadable-artifact ` + bsl + `.path: "\r\u202e" does not resolve to a file inside the bundle directory`,
			`invalid-digest ` + bsl + `.sha256: want 64 lowercase hex SHA-256, got "\x1b[8m"`,
			`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "a\x1b[1A\rresult: ok\u202e"`,
			`unsupported-job $.jobs[1]: job/version "\x1b[1A" is not supported`,
			`invalid-revision $.revision: want integer >= 1, got "\x1b[8m"`,
			`unknown-field $["x\nresult: ok\x1b[2K"]` + notPartOf},
		"no-bundle-json":          {unresolved},
		"symlink-escape":          {unresolved},
		"fifo-bundle":             {"unreadable-bundle $: bundle.json is not a regular file"},
		"over-size-cap":           {"unreadable-bundle $: bundle.json exceeds the 16777216-byte size cap"},
		"fifo-artifact":           {baseline + "is not a regular file"},
		"symlink-escape-artifact": {baseline + "does not resolve to a file inside the bundle directory"},
		"over-size-cap-artifact":  {baseline + "exceeds the 16777216-byte size cap"},
		"top-level-array":         {notObject}, "top-level-null": {notObject}, "top-level-string": {notObject},
	} {
		t.Run(variant, func(t *testing.T) {
			setup, isHostile := hostile[variant]
			dir, code := bundleCopy(t, map[bool]string{false: variant, true: "valid"}[isHostile]), 0
			if isHostile {
				if err := setup(dir); err != nil {
					t.Fatal(err)
				}
			}
			before := snapshot(filepath.Dir(dir))
			if variant != "valid" {
				code, want = 1, append(want, fmt.Sprintf("result: invalid diagnostics=%d (nothing staged or started)", len(want)))
			}
			done := make(chan map[string]int, 1)
			go func() {
				outputs := map[string]int{}
				for range 20 {
					var stdout, stderr bytes.Buffer
					outputs[fmt.Sprintf("exit=%d stderr=%q\n%s", run([]string{"bundle", "inspect", dir}, &stdout, &stderr), stderr.String(), stdout.String())]++
				}
				done <- outputs
			}()
			select {
			case outputs := <-done:
				if wantOut := fmt.Sprintf("exit=%d stderr=\"\"\n%s\n", code, strings.Join(want, "\n")); outputs[wantOut] != 20 {
					t.Errorf("outputs over 20 runs = %v, want only %q", outputs, wantOut)
				}
			case <-time.After(30 * time.Second):
				t.Fatal("inspect did not finish within 30s")
			}
			if snapshot(filepath.Dir(dir)) != before {
				t.Error("bundle tree changed during inspect")
			}
		})
	}
}

// TestTamperedArtifactIsWhitespaceOnly pins the tampered-digest fixture to a
// whitespace-only change: its bytes differ from the valid artifact's, but both
// compact to the same JSON, so only an exact-bytes digest can tell them apart.
func TestTamperedArtifactIsWhitespaceOnly(t *testing.T) {
	var raw [2][]byte
	var compact [2]bytes.Buffer
	for i, variant := range []string{"valid", "tampered-digest"} {
		b, err := os.ReadFile(filepath.Join(fixtures, variant, "artifacts/work-item.json"))
		if raw[i] = b; err != nil || json.Compact(&compact[i], b) != nil {
			t.Fatalf("%s: read %v or not JSON", variant, err)
		}
	}
	if bytes.Equal(raw[0], raw[1]) || !bytes.Equal(compact[0].Bytes(), compact[1].Bytes()) {
		t.Errorf("artifacts %q and %q: want different bytes, same compact JSON", raw[0], raw[1])
	}
}

func TestBundleUsageErrors(t *testing.T) {
	for _, args := range [][]string{{"bundle"}, {"bundle", "inspect"}, {"bundle", "import", "x"}, {"bundle", "inspect", "a", "b"}} {
		var stdout, stderr bytes.Buffer
		if code := run(args, &stdout, &stderr); code != 2 || stdout.Len() != 0 || !strings.Contains(stderr.String(), "Usage:") {
			t.Errorf("%q: exit=%d stdout=%q stderr=%q, want 2, empty stdout, usage", args, code, stdout.String(), stderr.String())
		}
	}
}

// TestBundleImportsNoNetworkOrProcess parses every non-test Go file of this
// package and, transitively, of each module package it imports. It fails on a dot
// import (its names would not be selectors), an import outside a standard-library
// allowlist (so no net, os/exec, syscall, unsafe or reflect) and on any selector
// that writes files or starts processes.
func TestBundleImportsNoNetworkOrProcess(t *testing.T) {
	const module = "github.com/blac9216/PriFly/"
	allowed := []string{"bytes", "crypto/sha256", "encoding/json", "fmt", "io", "os", "regexp", "slices", "strconv", "strings"}
	forbidden := []string{"StartProcess", "Command", "CommandContext", "Exec", "ForkExec", "WriteFile", "Create", "CreateTemp",
		"OpenFile", "Mkdir", "MkdirAll", "MkdirTemp", "Remove", "RemoveAll", "Rename", "Link", "Symlink", "Chmod", "Chown",
		"Lchown", "Chtimes", "Truncate", "Write", "WriteAt", "WriteString", "CopyFS"}
	fset, dirs, scanned := token.NewFileSet(), []string{"."}, map[string]int{}
	for len(dirs) > 0 {
		dir := dirs[0]
		dirs = dirs[1:]
		files, _ := filepath.Glob(filepath.Join(dir, "*.go"))
		for _, file := range files {
			if strings.HasSuffix(file, "_test.go") {
				continue
			}
			f, err := parser.ParseFile(fset, file, nil, 0)
			if err != nil {
				t.Fatal(err)
			}
			scanned[dir]++
			for _, imp := range f.Imports {
				p, _ := strconv.Unquote(imp.Path.Value)
				pkg, local := strings.CutPrefix(p, module)
				if imp.Name != nil && imp.Name.Name == "." || !local && !slices.Contains(allowed, p) {
					t.Errorf("%s: import %q is a dot import or not in the no-network/no-process allowlist", file, p)
				} else if local && !slices.Contains(dirs, "../../"+pkg) && scanned["../../"+pkg] == 0 {
					dirs = append(dirs, "../../"+pkg)
				}
			}
			ast.Inspect(f, func(n ast.Node) bool {
				if s, ok := n.(*ast.SelectorExpr); ok && slices.Contains(forbidden, s.Sel.Name) {
					t.Errorf("%s: selector .%s may write files or start processes", fset.Position(s.Pos()), s.Sel.Name)
				}
				return true
			})
		}
	}
	if scanned["."] < 2 || scanned["../../internal/bundle"] < 2 {
		t.Errorf("scanned files per package = %v, want cmd/prifly and internal/bundle", scanned)
	}
}
