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
			replaceIn(dir, `"WorkItem/v1"`, `"\u001b[2K"`), replaceIn(dir, `"artifacts/baseline.json"`, `"\r\u202e"`), replaceIn(dir, `"`+bslSHA+`"`, `"\u001b[8m"`),
			replaceIn(dir, `"wi_8887ffc`, `"wi_8887FFC`))
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
	"digest-control-suffix":  func(dir string) error { return replaceIn(dir, wiSHA+`"`, wiSHA+`\u001b[2K\rresult: ok"`) },
	"non-string-jobs":        func(dir string) error { return replaceIn(dir, `"jobs": [`, `"jobs": [7, null, {"x": 1}, `) },
	"invalid-artifact-revision": func(dir string) error { // referenced by the work item, which names revision 1
		return replaceIn(dir, `a5a", "revision": 1, "schema"`, `a5a", "revision": 0, "schema"`)
	},
	"duplicate-key-trailing": func(dir string) error {
		return errors.Join(replaceIn(dir, `"revision": 1`, `"revision": 1, "revision": 1`), replaceIn(dir, "\n}\n", "\n}\n}"))
	},
	"dependency-cycle": func(dir string) error { // a self-loop; a 2-cycle; a tail into a 2-cycle closed at a second dependency; a later tail; an acyclic chain;
		// a 2-cycle beside a repeated dependency, and a repeated dependency outside it; two entries sharing bytes that depend on the second
		return addItems(dir, slice(0), slice(2), slice(1), slice(4), slice(5), slice(-1, 4), slice(-1, 1), slice(8), slice(-1), slice(11, 11, 10), slice(9), slice(), slice(11, 11), slice(14), slice(14))
	},
	"enabler-consumer": func(dir string) error { // two SLICEs with the same bytes, each depending twice on the ENABLER naming both
		return addItems(dir, slice(2, 2), slice(2, 2), `{"kind": "ENABLER", "consumers": ["`+wiN(0)+`", "`+wiN(1)+`"], "dependencies": []}`)
	},
	"unnamed-consumer": func(dir string) error {
		return addItems(dir, `{"kind": "ENABLER", "dependencies": []}`, `{"kind": "ENABLER", "consumers": [], "dependencies": []}`,
			`{"kind": "ENABLER", "consumers": "`+wiN(0)+`", "dependencies": []}`, `{"kind": "SLICE", "dependencies": []}`)
	},
	"unresolved-work-item": func(dir string) error {
		// the last two contents share bytes, so their unresolved reference is reported once, at the first
		err := addItems(dir, `{"kind": "ENABLER", "consumers": ["`+wiN(99)+`", "bsl_6e73c229223db574a3c8fa28dd5a1a5a", 7, "`+wiN(1)+`"], "dependencies": [{"work_item": "`+wiN(98)+`"}, "`+wiN(0)+`", {"condition": "x"}, {"work_item": "wi_\u001b[2K"}]}`, "{}", slice(97), slice(97))
		return errors.Join(err, os.Remove(dir+"/artifacts/item1.json")) // an unreadable Work Item is still one a consumer can name
	},
	"invalid-content": func(dir string) error {
		return addItems(dir, `[]`, `{"kind": "SLICE", "kind": "SLICE", "dependencies": []}`, `{"dependencies": []}`, // the last has item0's bytes: reported once
			`{"kind": "slice\u001b[2K", "dependencies": []}`, `{"kind": "SLICE"}`, `{"kind": "SLICE", "dependencies": {}}`, `{"kind": 7, "dependencies": []}`, `[]`)
	},
	"invalid-utf8": func(dir string) error { return replaceIn(dir, `"wi_8887ffc`, "\"wi_\xff\xfe8887ffc") },
	"lone-surrogate": func(dir string) error { // a high, a low before a pair, and a pair beside an escaped backslash
		return errors.Join(replaceIn(dir, `"bnd_`, `"bnd_\ud800`), replaceIn(dir, `"reviewer.implementation/v1"`, `"\udc00\ud83d\ude00"`),
			replaceIn(dir, `"WorkItem/v1"`, `"\ud83d\ude00\\ud800"`))
	},
}

const (
	bundleID = "bnd_8d0e1c6f026fef7621a0c7b017f12c12"
	bslSHA   = "70e2a30e1b5a5d53b311faf4e2eb50acaed9c4be464fdca8f8eb72c6416efe34"
	wiSHA    = "cd905736886656931e4d9113e0251dce6e5b75e2fd8cb04f45a99cd358ac7500"
)

// wiN is the Work Item ID addItems gives its n-th content; -1 is the valid fixture's work item.
func wiN(n int) string {
	if n < 0 {
		return "wi_8887ffc730f707abb82bb7cb7068e914"
	}
	return fmt.Sprintf("wi_%032x", n)
}

// slice is SLICE content depending, in order, on wiN of each n.
func slice(ns ...int) string {
	deps := []string{}
	for _, n := range ns {
		deps = append(deps, `{"work_item": "`+wiN(n)+`", "condition": "integrated"}`)
	}
	return `{"kind": "SLICE", "dependencies": [` + strings.Join(deps, ", ") + `]}`
}

// addItems writes each content to artifacts/item<n>.json and declares it, by
// its exact-bytes digest, as Work Item wiN(n) after the valid fixture's artifacts.
func addItems(dir string, contents ...string) error {
	entries := ""
	for n, content := range contents {
		name := fmt.Sprintf("artifacts/item%d.json", n)
		entries += fmt.Sprintf(`, {"id": "%s", "revision": 1, "schema": "WorkItem/v1", "path": "%s", "sha256": "%x", "refs": []}`, wiN(n), name, sha256.Sum256([]byte(content)))
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
			return err
		}
	}
	return replaceIn(dir, "}\n  ]\n}", "}"+entries+"\n  ]\n}")
}

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
		repeated   = ": key repeats an earlier key of this object"
		notJSON    = "invalid-json $: bundle.json is not a single JSON value"
		notObject  = "invalid-type $: want object"
		unresolved = "unreadable-bundle $: bundle.json does not resolve to a file inside the bundle directory"
		wi, bsl    = "$.artifacts[0]", "$.artifacts[1]"
		baseline   = "unreadable-artifact " + bsl + `.path: "artifacts/baseline.json" `
		unnamedWI  = `unresolved-work-item $.artifacts[2].content.consumers[0]: no Work Item in this bundle has ID "wi_8887ffc730f707abb82bb7cb7068e914"`
		missing    = ": required field is absent"
		item       = "$.artifacts[%d].content"
	)
	at := func(n int, rest string) string { return fmt.Sprintf(item, n+3) + rest }
	for variant, want := range map[string][]string{
		"valid":           {"result: ok manifest_sha256=930aa88a3c990d7a649c3766aec7415633cd58c8d9303cc97613e0912027bc0b (nothing staged or started)"},
		"tampered-digest": {"digest-mismatch " + wi + `.sha256: declared "` + wiSHA + `", exact bytes hash to 505b47608bd627b3695e76c8b61598e82fa1738e8ba2f6e52d328e1cff6ff20a`},
		"unsupported-version": {
			"unsupported-schema " + bsl + `.schema: artifact schema "Baseline/v2" is not supported`,
			`unsupported-job $.jobs[0]: job/version "implementer.implementation/v2" is not supported`},
		"unsupported-bundle-schema": {`unsupported-schema $.schema: want "ExternalPlanningBundle/v1", got "ExternalPlanningBundle/v2\x1b[2K"`},
		"unsupported-authority-field": {
			"unknown-field " + wi + ".factory_attempt_id" + notPartOf,
			"unknown-field $.dispatch_eligible" + notPartOf,
			"unknown-field $.owner_release_confirmed" + notPartOf,
			"unknown-field $.refs" + notPartOf},
		"malformed-identity": {
			`invalid-id ` + wi + `.id: want wi_<32 lowercase hex>, got "wi_8887ffc730f707abb82bb7cb7068e9140"`,
			"invalid-type " + wi + ".path: want string",
			"missing-field " + wi + ".refs: required field is absent",
			`invalid-revision ` + wi + `.revision: want integer >= 1, got "1"`,
			`invalid-id ` + bsl + `.id: want bsl_<32 lowercase hex>, got "wi_6e73c229223db574a3c8fa28dd5a1a5a"`,
			"unreadable-artifact " + bsl + `.path: "../valid/artifacts/baseline.json" does not resolve to a file inside the bundle directory`,
			"missing-field " + bsl + ".refs: required field is absent",
			"missing-field " + bsl + ".revision: required field is absent",
			"invalid-digest " + bsl + `.sha256: want 64 lowercase hex SHA-256, got "70E2A30E1B5A5D53B311FAF4E2EB50ACAED9C4BE464FDCA8F8EB72C6416EFE34"`,
			"invalid-type $.artifacts[2]: want object",
			`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "id: ` + bundleID + `"`,
			"invalid-type $.jobs: want array",
			"invalid-revision $.revision: want integer >= 1, got 0"},
		"missing-reference": {
			"unresolved-reference " + wi + `.refs[0].id: no artifact in this bundle has ID "wi_b171b88de6c22604fb5f583cc13b1fbe"`,
			"reference-revision-mismatch " + wi + ".refs[1].revision: reference names 2, artifact " + bsl + " has revision 1",
			"reference-digest-mismatch " + wi + `.refs[2].sha256: reference names "` + wiSHA + `", artifact ` + bsl + ` declares "` + bslSHA + `"`,
			"unknown-field " + wi + ".refs[3].dispatch_eligible" + notPartOf,
			"invalid-id " + wi + `.refs[3].id: want <type>_<32 lowercase hex>, got "bsl_6E73c229223db574a3c8fa28dd5a1a5a"`,
			"invalid-revision " + wi + ".refs[3].revision: want integer >= 1, got 0",
			"invalid-digest " + wi + `.refs[3].sha256: want 64 lowercase hex SHA-256, got "70E2A30E1B5A5D53B311FAF4E2EB50ACAED9C4BE464FDCA8F8EB72C6416EFE34"`,
			"reference-revision-mismatch " + bsl + ".refs[0].revision: reference names 3, artifact " + wi + " has revision 1",
			"reference-digest-mismatch " + bsl + `.refs[0].sha256: reference names "` + bslSHA + `", artifact ` + wi + ` declares "` + wiSHA + `"`},
		"invalid-artifact-revision": {"invalid-revision " + bsl + ".revision: want integer >= 1, got 0"},
		"duplicate-key-trailing":    {notJSON, "duplicate-key $.revision" + repeated},
		"duplicate-id":              {`duplicate-id $.artifacts[2].id: artifact ID "wi_8887ffc730f707abb82bb7cb7068e914" is already declared at ` + wi + ".id"},
		"duplicate-key": {
			"duplicate-key " + wi + ".refs[0].id" + repeated,
			"duplicate-key " + wi + ".sha256" + repeated,
			"duplicate-key " + bsl + ".refs" + repeated,
			"duplicate-key $.schema" + repeated,
			`duplicate-key $["x\x1b[2K"]` + repeated},
		"invalid-utf8": {"invalid-string " + wi + ".id: string is not valid UTF-8"},
		"lone-surrogate": {
			"invalid-string $.bundle_id: string escapes an unpaired surrogate",
			"invalid-string $.jobs[1]: string escapes an unpaired surrogate"},
		"digest-control-suffix": {`invalid-digest ` + wi + `.sha256: want 64 lowercase hex SHA-256, got "` + wiSHA + `\x1b[2K\rresult: ok"`},
		"non-string-jobs": {
			"unsupported-job $.jobs[0]: job/version 7 is not supported",
			"unsupported-job $.jobs[1]: job/version null is not supported",
			"unsupported-job $.jobs[2]: job/version object is not supported"},
		"artifact-id-pattern": {`invalid-id ` + wi + `.id: want wi_<32 lowercase hex>, got "wi_8887FFC730f707abb82bb7cb7068e914"`, unnamedWI},
		"id-prefix":           {`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "wi_8d0e1c6f026fef7621a0c7b017f12c12"`},
		"id-length":           {`invalid-id $.bundle_id: want bnd_<32 lowercase hex>, got "` + bundleID + `0"`},
		"id-type":             {"invalid-type $.bundle_id: want string"},
		"missing-revision":    {"missing-field $.revision: required field is absent"},
		"invalid-json":        {notJSON},
		"trailing-brace":      {notJSON},
		"trailing-arrays":     {notJSON},
		"trailing-garbage":    {notJSON},
		"control-chars": {
			`invalid-id ` + wi + `.id: want <type>_<32 lowercase hex>, got "wi_8887FFC730f707abb82bb7cb7068e914"`,
			`invalid-digest ` + wi + `.refs[0].sha256: want 64 lowercase hex SHA-256, got "\x1b[8m"`,
			`unsupported-schema ` + wi + `.schema: artifact schema "\x1b[2K" is not supported`,
			`unreadable-artifact ` + bsl + `.path: "\r\u202e" does not resolve to a file inside the bundle directory`,
			unnamedWI,
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
		"enabler-consumer": {"result: ok manifest_sha256=d72147c7e751181bf47b247a5fb65896eec7013ca0513b01c1fb2085807ca6ba (nothing staged or started)"},
		"dependency-cycle": {
			"dependency-cycle " + at(10, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(9) + `" -> "` + wiN(10) + `" -> "` + wiN(9) + `"`,
			"dependency-cycle " + at(14, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(14) + `" -> "` + wiN(14) + `"`,
			"dependency-cycle " + at(0, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(0) + `" -> "` + wiN(0) + `"`,
			"dependency-cycle " + at(2, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(1) + `" -> "` + wiN(2) + `" -> "` + wiN(1) + `"`,
			"dependency-cycle " + at(5, `.dependencies[1].work_item`) + `: Work Items depend in a cycle: "` + wiN(4) + `" -> "` + wiN(5) + `" -> "` + wiN(4) + `"`},
		"unnamed-consumer": {
			"unnamed-consumer " + at(0, ".consumers: ENABLER names no consuming Work Item"),
			"unnamed-consumer " + at(1, ".consumers: ENABLER names no consuming Work Item"),
			"invalid-type " + at(2, ".consumers: want array"),
			"unnamed-consumer " + at(2, ".consumers: ENABLER names no consuming Work Item")},
		"unresolved-work-item": {
			"unresolved-work-item " + at(0, `.consumers[0]: no Work Item in this bundle has ID "`+wiN(99)+`"`),
			"invalid-id " + at(0, `.consumers[1]: want wi_<32 lowercase hex>, got "bsl_6e73c229223db574a3c8fa28dd5a1a5a"`),
			"invalid-type " + at(0, `.consumers[2]: want string`),
			"unresolved-work-item " + at(0, `.dependencies[0].work_item: no Work Item in this bundle has ID "`+wiN(98)+`"`),
			"invalid-type " + at(0, `.dependencies[1]: want object`),
			"missing-field " + at(0, `.dependencies[2].work_item`+missing),
			"invalid-id " + at(0, `.dependencies[3].work_item: want wi_<32 lowercase hex>, got "wi_\x1b[2K"`),
			`unreadable-artifact $.artifacts[4].path: "artifacts/item1.json" does not resolve to a file inside the bundle directory`,
			"unresolved-work-item " + at(2, `.dependencies[0].work_item: no Work Item in this bundle has ID "`+wiN(97)+`"`)},
		"invalid-content": {
			"invalid-content " + at(0, ": want one JSON object with unique keys and exact strings"),
			"invalid-content " + at(1, ": want one JSON object with unique keys and exact strings"),
			"missing-field " + at(2, ".kind"+missing),
			"invalid-kind " + at(3, `.kind: want "SLICE" or "ENABLER", got "slice\x1b[2K"`),
			"missing-field " + at(4, ".dependencies"+missing),
			"invalid-type " + at(5, ".dependencies: want array"),
			"invalid-kind " + at(6, `.kind: want "SLICE" or "ENABLER", got 7`)},
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
			if !strings.HasPrefix(want[0], "result: ok") {
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
	allowed := []string{"bytes", "crypto/sha256", "encoding/json", "fmt", "io", "os", "regexp", "slices", "strconv", "strings", "unicode/utf8"}
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
