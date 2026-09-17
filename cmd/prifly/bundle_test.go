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
// fixtures/<variant>, beside a <tmp>/valid copy so "../valid/..." names a real
// file outside the bundle root. Both trees stay writable, so an attempted write
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
	"trailing-brace":   func(dir string) error { return appendFile(dir+"/bundle.json", "}") },
	"trailing-arrays":  func(dir string) error { return appendFile(dir+"/bundle.json", "]]]") },
	"trailing-garbage": func(dir string) error { return appendFile(dir+"/bundle.json", "}garbage") },
	"control-chars": func(dir string) error {
		b, err := os.ReadFile(dir + "/bundle.json")
		b = bytes.Replace(b, []byte(`"jobs": [`), []byte(`"x\nresult: ok\u001b[2K": 1, "jobs": ["a\u001b[1A\rresult: ok\u202e", `), 1)
		return errors.Join(err, os.WriteFile(dir+"/bundle.json", b, 0o644))
	},
	"fifo-artifact": func(dir string) error {
		return errors.Join(os.Remove(dir+"/artifacts/baseline.json"), syscall.Mkfifo(dir+"/artifacts/baseline.json", 0o644))
	},
	"fifo-bundle": func(dir string) error {
		return errors.Join(os.Remove(dir+"/bundle.json"), syscall.Mkfifo(dir+"/bundle.json", 0o644))
	},
	"symlink-escape": func(dir string) error {
		return errors.Join(os.Remove(dir+"/artifacts/baseline.json"), os.Symlink("../../valid/artifacts/baseline.json", dir+"/artifacts/baseline.json"))
	},
	"over-size-cap": func(dir string) error { return os.Truncate(dir+"/artifacts/baseline.json", bundle.MaxFileBytes+1) },
}

func appendFile(name, text string) error {
	f, err := os.OpenFile(name, os.O_APPEND|os.O_WRONLY, 0)
	if err == nil {
		_, err = f.WriteString(text)
		err = errors.Join(err, f.Close())
	}
	return err
}

// TestBundleInspectFixtures asserts each fixture's exact output and exit code
// on all of 20 runs (sorted diagnostics, never map order), finishing within
// 30s, with the writable bundle tree left unchanged.
func TestBundleInspectFixtures(t *testing.T) {
	const (
		wi, bsl, wiID = "$.artifacts[0]", "$.artifacts[1]", "wi_8887ffc730f707abb82bb7cb7068e914"
		wiSHA         = "e7d95ce6f478a7f82dbca4bee40b67d11efe93cdb245a22a03a28703024fa143"
		notPartOf     = ": field is not part of ExternalPlanningBundle/v1"
		notJSON       = "invalid-json $: bundle.json is not a single JSON value"
		baseline      = bsl + `.path: "artifacts/baseline.json" `
	)
	for variant, want := range map[string][]string{
		"valid": {"result: ok manifest_sha256=fbc1794d24f6d94d47c2d62021734bf5efdea5d34093f27d6bd905000f546220 (nothing staged or started)"},
		"tampered-digest": {
			"digest-mismatch " + wi + ".sha256: declared " + wiSHA + ", exact bytes hash to be9861302628ee7be1c9586b626e6d9ecf1403d9dec73e1f148e037140a1ade6"},
		"unsupported-version": {
			"unsupported-schema " + bsl + `.schema: artifact schema "Baseline/v2" is not supported`,
			`unsupported-job $.jobs[0]: job/version "implementer.implementation/v2" is not supported`},
		"unsupported-bundle-schema": {`unsupported-schema $.schema: want "ExternalPlanningBundle/v1", got "ExternalPlanningBundle/v2"`},
		"unsupported-authority-field": {
			"unknown-field " + wi + ".factory_attempt_id" + notPartOf,
			"unknown-field " + bsl + ".refs" + notPartOf,
			"unknown-field $.dispatch_eligible" + notPartOf,
			"unknown-field $.owner_release_confirmed" + notPartOf,
			"unknown-field $.refs" + notPartOf},
		"malformed-identity": {
			`invalid-id ` + wi + `.id: want wi_<32 lowercase hex>, got "` + wiID + `0"`,
			"invalid-type " + wi + ".path: want string",
			`invalid-id ` + bsl + `.id: want bsl_<32 lowercase hex>, got "wi_6e73c229223db574a3c8fa28dd5a1a5a"`,
			"unreadable-artifact " + bsl + `.path: "../valid/artifacts/baseline.json" does not resolve to a file inside the bundle directory`,
			"missing-field " + bsl + ".revision: required field is absent",
			"invalid-digest " + bsl + `.sha256: want 64 lowercase hex SHA-256, got "70E2A30E1B5A5D53B311FAF4E2EB50ACAED9C4BE464FDCA8F8EB72C6416EFE34"`,
			`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "id: bnd_8d0e1c6f026fef7621a0c7b017f12c12"`,
			"invalid-type $.jobs: want array",
			"invalid-revision $.revision: want integer >= 1, got 0"},
		"invalid-json":     {notJSON},
		"trailing-brace":   {notJSON},
		"trailing-arrays":  {notJSON},
		"trailing-garbage": {notJSON},
		"control-chars": {
			`unsupported-job $.jobs[0]: job/version "a\x1b[1A\rresult: ok\u202e" is not supported`,
			`unknown-field $["x\nresult: ok\x1b[2K"]` + notPartOf},
		"fifo-artifact":   {"unreadable-artifact " + baseline + "is not a regular file"},
		"fifo-bundle":     {"unreadable-bundle $: bundle.json is not a regular file"},
		"symlink-escape":  {"unreadable-artifact " + baseline + "does not resolve to a file inside the bundle directory"},
		"over-size-cap":   {"unreadable-artifact " + baseline + "exceeds the 16777216-byte size cap"},
		"valid/artifacts": {"unreadable-bundle $: bundle.json does not resolve to a file inside the bundle directory"},
	} {
		t.Run(variant, func(t *testing.T) {
			name, sub, _ := strings.Cut(variant, "/")
			setup, isHostile := hostile[name]
			bundleDir, code := bundleCopy(t, map[bool]string{false: name, true: "valid"}[isHostile]), 0
			if isHostile {
				if err := setup(bundleDir); err != nil {
					t.Fatal(err)
				}
			}
			dir, before := filepath.Join(bundleDir, sub), snapshot(filepath.Dir(bundleDir))
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
			if snapshot(filepath.Dir(bundleDir)) != before {
				t.Error("bundle tree changed during inspect")
			}
		})
	}
}

// TestBundleDigestHashesExactBytes: the tampered work item differs from the
// valid one only in JSON whitespace, so its digest-mismatch proves exact bytes
// are hashed rather than a re-serialized form.
func TestBundleDigestHashesExactBytes(t *testing.T) {
	var compact [2]bytes.Buffer
	valid, err1 := os.ReadFile(fixtures + "/valid/artifacts/work-item.json")
	tampered, err2 := os.ReadFile(fixtures + "/tampered-digest/artifacts/work-item.json")
	err := errors.Join(err1, err2, json.Compact(&compact[0], valid), json.Compact(&compact[1], tampered))
	if err != nil || bytes.Equal(valid, tampered) || compact[0].String() != compact[1].String() {
		t.Fatalf("work-item fixtures must differ in bytes but not in compacted JSON (err=%v)", err)
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
// package and, transitively, of each module package it imports. It fails on an
// import outside a standard-library allowlist (so no net, os/exec, syscall,
// unsafe or reflect) and on any selector that writes files or starts processes.
func TestBundleImportsNoNetworkOrProcess(t *testing.T) {
	const module = "github.com/blac9216/PriFly/"
	allowed := []string{"bytes", "cmp", "crypto/sha256", "encoding/json", "fmt", "io", "os", "regexp", "slices", "strconv", "strings"}
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
				if pkg, local := strings.CutPrefix(p, module); local && !slices.Contains(dirs, "../../"+pkg) && scanned["../../"+pkg] == 0 {
					dirs = append(dirs, "../../"+pkg)
				} else if !local && !slices.Contains(allowed, p) {
					t.Errorf("%s: import %q is not in the no-network/no-process allowlist", file, p)
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
	if scanned["."] < 2 || scanned["../../internal/bundle"] < 1 {
		t.Errorf("scanned files per package = %v, want cmd/prifly and internal/bundle", scanned)
	}
}
