package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"
)

const fixtures = "../../tests/fixtures/bundles"

// bundleCopy returns <tmp>/bundle, fixtures/valid overlaid with
// fixtures/<variant>, beside a <tmp>/valid copy so "../valid/..." names a real
// file outside the bundle root. Both trees are read-only during the test.
func bundleCopy(t *testing.T, variant string) string {
	base, valid, overlay := t.TempDir(), os.DirFS(filepath.Join(fixtures, "valid")), os.DirFS(filepath.Join(fixtures, variant))
	dir := filepath.Join(base, "bundle")
	err := errors.Join(os.CopyFS(filepath.Join(base, "valid"), valid), os.CopyFS(dir, valid), fs.WalkDir(overlay, ".", func(p string, d fs.DirEntry, err error) error {
		if b, rerr := fs.ReadFile(overlay, p); err == nil && !d.IsDir() {
			return errors.Join(rerr, os.WriteFile(filepath.Join(dir, p), b, 0o644))
		}
		return err
	}))
	chmod := func(file, dir fs.FileMode) {
		filepath.WalkDir(base, func(p string, d fs.DirEntry, _ error) error {
			return os.Chmod(p, map[bool]fs.FileMode{false: file, true: dir}[d.IsDir()])
		})
	}
	chmod(0o444, 0o555)
	t.Cleanup(func() { chmod(0o644, 0o755) })
	if err != nil {
		t.Fatal(err)
	}
	return dir
}

// snapshot fingerprints every path, mode, size, mtime and content under dir.
func snapshot(dir string) string {
	var b strings.Builder
	filepath.WalkDir(dir, func(p string, d fs.DirEntry, _ error) error {
		info, _ := d.Info()
		content, _ := os.ReadFile(p)
		fmt.Fprintf(&b, "%s %v %d %d %x\n", p, info.Mode(), info.Size(), info.ModTime().UnixNano(), sha256.Sum256(content))
		return nil
	})
	return b.String()
}

// TestBundleInspectFixtures asserts each fixture's exact output and exit code
// on all of 20 runs (sorted diagnostics, never map order), with the read-only
// bundle tree left unchanged.
func TestBundleInspectFixtures(t *testing.T) {
	const (
		wi, bsl, wiID = "$.artifacts[0]", "$.artifacts[1]", "wi_8887ffc730f707abb82bb7cb7068e914"
		wiSHA         = "e7d95ce6f478a7f82dbca4bee40b67d11efe93cdb245a22a03a28703024fa143"
		notPartOf     = ": field is not part of ExternalPlanningBundle/v1"
	)
	for variant, want := range map[string][]string{
		"valid": {"result: ok manifest_sha256=fbc1794d24f6d94d47c2d62021734bf5efdea5d34093f27d6bd905000f546220 (nothing staged or started)"},
		"tampered-digest": {
			"digest-mismatch " + wi + ".sha256: declared " + wiSHA + ", exact bytes hash to be9861302628ee7be1c9586b626e6d9ecf1403d9dec73e1f148e037140a1ade6"},
		"unsupported-version": {
			"unsupported-schema " + bsl + ".schema: artifact schema Baseline/v2 is not supported",
			"unsupported-job $.jobs[0]: job/version implementer.implementation/v2 is not supported"},
		"unsupported-bundle-schema": {`unsupported-schema $.schema: want "ExternalPlanningBundle/v1", got ExternalPlanningBundle/v2`},
		"unsupported-authority-field": {
			"unknown-field " + wi + ".factory_attempt_id" + notPartOf,
			"unknown-field $.dispatch_eligible" + notPartOf,
			"unknown-field $.owner_release_confirmed" + notPartOf},
		"malformed-identity": {
			`invalid-id ` + bsl + `.id: want bsl_<32 lowercase hex>, got "wi_6e73c229223db574a3c8fa28dd5a1a5a"`,
			"unreadable-artifact " + bsl + `.path: no regular file "../valid/artifacts/baseline.json" inside the bundle`,
			"missing-field " + bsl + ".revision: required field is absent",
			"invalid-digest " + bsl + `.sha256: want 64 lowercase hex SHA-256, got "ABC"`,
			`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "` + wiID + `"`,
			"invalid-type $.jobs: want array",
			"invalid-revision $.revision: want integer >= 1, got 0"},
		"invalid-json":    {"invalid-json $: bundle.json is not a single JSON value"},
		"valid/artifacts": {"unreadable-bundle $: cannot read bundle.json in a bundle directory"},
	} {
		t.Run(variant, func(t *testing.T) {
			name, sub, _ := strings.Cut(variant, "/")
			bundleDir, code := bundleCopy(t, name), 0
			dir, before := filepath.Join(bundleDir, sub), snapshot(filepath.Dir(bundleDir))
			if variant != "valid" {
				code, want = 1, append(want, fmt.Sprintf("result: invalid diagnostics=%d (nothing staged or started)", len(want)))
			}
			outputs := map[string]int{}
			for range 20 {
				var stdout, stderr bytes.Buffer
				outputs[fmt.Sprintf("exit=%d stderr=%q\n%s", run([]string{"bundle", "inspect", dir}, &stdout, &stderr), stderr.String(), stdout.String())]++
			}
			if wantOut := fmt.Sprintf("exit=%d stderr=\"\"\n%s\n", code, strings.Join(want, "\n")); outputs[wantOut] != 20 {
				t.Errorf("outputs over 20 runs = %v, want only %q", outputs, wantOut)
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

// TestBundleImportsNoNetworkOrProcess pins the inspect path's direct imports
// to a standard-library allowlist with no net, os/exec or syscall.
func TestBundleImportsNoNetworkOrProcess(t *testing.T) {
	allowed := []string{"bytes", "cmp", "crypto/sha256", "encoding/json", "fmt", "io", "os", "regexp", "slices", "strings",
		"github.com/blac9216/PriFly/internal/buildinfo", "github.com/blac9216/PriFly/internal/bundle"}
	for _, file := range []string{"main.go", "bundle.go", "../../internal/bundle/bundle.go"} {
		f, err := parser.ParseFile(token.NewFileSet(), file, nil, parser.ImportsOnly)
		if err != nil {
			t.Fatal(err)
		}
		for _, imp := range f.Imports {
			if p, _ := strconv.Unquote(imp.Path.Value); !slices.Contains(allowed, p) {
				t.Errorf("%s: import %q is not in the no-network/no-process allowlist", file, p)
			}
		}
	}
}
