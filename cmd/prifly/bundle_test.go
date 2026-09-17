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
	"enabler-consumer": func(dir string) error { // two SLICEs with the same bytes, so one envelope, each depending twice on the ENABLER naming both
		return addItems(dir, slice(2, 2), slice(2, 2), `{"kind": "ENABLER", "consumers": ["`+wiN(0)+`", "`+wiN(1)+`"], "dependencies": [], `+traced+`}`)
	},
	"unnamed-consumer": func(dir string) error {
		return addItems(dir, `{"kind": "ENABLER", "dependencies": [], `+traced+`}`, `{"kind": "ENABLER", "consumers": [], "dependencies": [], `+traced+`}`,
			`{"kind": "ENABLER", "consumers": "`+wiN(0)+`", "dependencies": [], `+traced+`}`, slice())
	},
	"unresolved-work-item": func(dir string) error {
		// the last two contents share bytes, so their unresolved reference is reported once, at the first
		err := addItems(dir, `{"kind": "ENABLER", "consumers": ["`+wiN(99)+`", "bsl_6e73c229223db574a3c8fa28dd5a1a5a", 7, "`+wiN(1)+`"], "dependencies": [{"work_item": "`+wiN(98)+`", "condition": "x"}, "`+wiN(0)+`", {"condition": "x"}, {"work_item": "wi_\u001b[2K", "condition": "x"}], `+traced+`}`, slice(), slice(97), slice(97))
		return errors.Join(err, os.Remove(dir+"/artifacts/wi1.json")) // an unreadable Work Item is still one a consumer can name, and may name its own envelope
	},
	"invalid-content": func(dir string) error { // wi1's own envelope is named only by content that cannot be read, so it is not reported
		return addItems(dir, `[]`, `{"kind": "SLICE", "kind": "SLICE", "dependencies": [], `+traced+`}`, `{"dependencies": [], `+traced+`}`, // the last has item0's bytes: reported once
			`{"kind": "slice\u001b[2K", "dependencies": [], `+traced+`}`, `{"kind": "SLICE", `+traced+`}`, `{"kind": "SLICE", "dependencies": {}, `+traced+`}`, `{"kind": 7, "dependencies": [], `+traced+`}`, `[]`)
	},
	"orphan-outcome": func(dir string) error { // the last content repeats the one before: reported once; bsl_0 is a Baseline/v2 entry
		return errors.Join(addItems(dir, `{"kind": "SLICE", "dependencies": [], `+bound+`}`, `{"kind": "SLICE", "dependencies": [], "outcomes": [], `+bound+`}`,
			`{"kind": "SLICE", "dependencies": [], "outcomes": "AT-08", `+bound+`}`, badOutcomes, badOutcomes),
			addArtifacts(dir, "bsl", "Baseline/v2", `{}`))
	},
	"missing-condition": func(dir string) error {
		w := `{"work_item": "` + wiN(-1) + `"`
		return addItems(dir, `{"kind": "SLICE", "dependencies": [`+w+`}, `+w+`, "condition": ""}, `+w+`, "condition": 7}, `+w+`, "condition": null}, {"condition": "x"}, 7, {}], `+traced+`}`)
	},
	"non-slice-consumer": func(dir string) error { // wi4 repeats wi0's bytes: reported once; wi3 is unreadable
		err := addItems(dir, consumerEnabler, `{"kind": "ENABLER", "consumers": ["`+wiN(-1)+`"], "dependencies": [], `+traced+`}`, `{"kind": "slice", "dependencies": [], `+traced+`}`, slice(), consumerEnabler, `[]`)
		return errors.Join(err, os.Remove(dir+"/artifacts/wi3.json"))
	},
	"invalid-bound": func(dir string) error { // xen6 repeats xen2's bytes: reported once
		bad := `{"bounds": {"attempts": 0, "repairs_per_attempt": -1, "attempt_minutes": 1.5, "worker_minutes": "360", "tokens\u001b[2K": 1}}`
		items := []string{}
		for n := range 7 {
			items = append(items, naming(fmt.Sprintf("xen_%032x", n), slice()))
		}
		return errors.Join(addArtifacts(dir, "xen", "ExecutionEnvelope/v1", `{}`, `{"bounds": []}`, bad, `{"bounds": {"attempts": 1e3, "repairs_per_attempt": null, "attempt_minutes": 90.0}}`, `[]`, `{"bounds": {"attempts": true, "repairs_per_attempt": 2, "attempt_minutes": 90, "worker_minutes": 360}}`, bad), addItems(dir, items...))
	},
	"blocking-result": func(dir string) error { // qev4 repeats qev0's bytes: reported once; qev5 repeats a Work Item's bytes: still checked
		item, results := `{"kind": "SLICE", "dependencies": [], `+traced+`, "results": [{"result": "FAIL"}]}`, `{"results": [{"result": "PASS"}, {"result": "FAIL"}, {"result": "NOT_APPLICABLE"}, {"result": "UNKNOWN"}, {"result": "fail\u001b[2K"}, {}, 7, {"result": null}, {"result": "NOT_APPLICABLE", "applicability": ""}, {"result": "NOT_APPLICABLE", "applicability": 7}]}`
		return errors.Join(addItems(dir, item), addArtifacts(dir, "qev", "QualityEvaluation/v1", results, `{}`, `{"results": {}}`, `[]`, results, item, `{"results": []}`))
	},
	"covered-bounded-passing": func(dir string) error {
		bsl := `{"baseline": "bsl_6e73c229223db574a3c8fa28dd5a1a5a", "obligation": `
		return errors.Join(addItems(dir, slice(-1), `{"kind": "ENABLER", "consumers": ["`+wiN(0)+`", "`+wiN(-1)+`"], "dependencies": [{"work_item": "`+wiN(-1)+`", "condition": " "}], "outcomes": [`+bsl+`"a"}, `+bsl+`"b"}], `+naming(fmt.Sprintf("xen_%032x", 0), bound)+`}`),
			addArtifacts(dir, "xen", "ExecutionEnvelope/v1", `{"bounds": {"attempts": 8, "repairs_per_attempt": 2, "attempt_minutes": 90, "worker_minutes": 123456789012345678901234567890}, "note": "x"}`),
			addArtifacts(dir, "qev", "QualityEvaluation/v1", `{"results": [{"result": "PASS", "criterion": "x"}, {"result": "NOT_APPLICABLE", "applicability": " "}]}`))
	},
	"unbound-work-item": func(dir string) error { // wi6 repeats wi0's bytes: reported once; wi7 is an unbound ENABLER, wi8 unbound with no outcomes; xen0 is an ExecutionEnvelope/v2 entry
		item := func(envelope string) string {
			return `{"kind": "SLICE", "dependencies": [], "outcomes": [{"baseline": "bsl_6e73c229223db574a3c8fa28dd5a1a5a", "obligation": "x"}]` + envelope + `}`
		}
		return errors.Join(addItems(dir, item(""), item(`, "execution_envelope": ["`+xenID+`", "`+xenID+`"]`), item(`, "execution_envelope": "bsl_6e73c229223db574a3c8fa28dd5a1a5a"`),
			item(`, "execution_envelope": "xen_\u001b[2K"`), item(`, "execution_envelope": "xen_`+fmt.Sprintf("%032x", 99)+`"`), item(`, "execution_envelope": "xen_`+fmt.Sprintf("%032x", 0)+`"`), item(""),
			`{"kind": "ENABLER", "consumers": ["`+wiN(0)+`"], "dependencies": [], "outcomes": [{"baseline": "bsl_6e73c229223db574a3c8fa28dd5a1a5a", "obligation": "x"}]}`, `{"kind": "SLICE", "dependencies": []}`),
			addArtifacts(dir, "xen", "ExecutionEnvelope/v2", `{}`))
	},
	"shared-envelope": func(dir string) error { return addItems(dir, naming(xen2ID, slice())) }, // with the valid ENABLER
	"shared-envelope-many": func(dir string) error { // with the valid SLICE; the last two share bytes
		return addItems(dir, naming(xenID, slice(-1)), naming(xenID, slice()), naming(xenID, slice()))
	},
	"orphan-envelope": func(dir string) error { // wi0 and wi1 repeat the valid SLICE's ID: wi0 alone names xen1, wi1 names xen4 before wi2; xen2 repeats xen0's ID; xen3's ID is invalid
		return errors.Join(addItems(dir, naming(fmt.Sprintf("xen_%032x", 1), slice()), naming(fmt.Sprintf("xen_%032x", 4), slice()), naming(fmt.Sprintf("xen_%032x", 4), slice(-1))),
			addArtifacts(dir, "xen", "ExecutionEnvelope/v1", `{}`, envelope, envelope, envelope, envelope), replaceIn(dir, `"`+wiN(0)+`"`, `"`+wiN(-1)+`"`), replaceIn(dir, `"`+wiN(1)+`"`, `"`+wiN(-1)+`"`),
			replaceIn(dir, fmt.Sprintf(`"xen_%032x"`, 2), fmt.Sprintf(`"xen_%032x"`, 0)), replaceIn(dir, fmt.Sprintf(`"xen_%032x"`, 3), `"xen_\u001b[2K"`))
	},
	// Each unknown-binding bundle holds one Work Item whose binding is unknown beside an unnamed envelope.
	"unknown-binding-missing":     unknownBinding(strings.Replace(slice(), ", "+bound, "", 1)),
	"unknown-binding-type":        unknownBinding(strings.Replace(slice(), `"`+own+`"`, "7", 1)),
	"unknown-binding-id":          unknownBinding(naming(`xen_\u001b[2K`, slice())),
	"unknown-binding-unresolved":  unknownBinding(naming(fmt.Sprintf("xen_%032x", 99), slice())),
	"unknown-binding-workitem-v2": func(dir string) error { return addArtifacts(dir, "wi", "WorkItem/v2", slice()) }, // its own envelope is unnamed
	"unrelated-unsupported-schemas": func(dir string) error { // QualityEvaluation/v2 and ExecutionEnvelope/v2 entries beside an unnamed envelope
		return errors.Join(addArtifacts(dir, "qev", "QualityEvaluation/v2", `{}`), addArtifacts(dir, "xen", "ExecutionEnvelope/v1", envelope, `{}`),
			replaceIn(dir, `"ExecutionEnvelope/v1", "path": "artifacts/xen1.json"`, `"ExecutionEnvelope/v2", "path": "artifacts/xen1.json"`))
	},
	"envelope-cardinality": func(dir string) error { // wi4 repeats wi3's bytes; wi7 repeats wi0's bytes and ID; the invalid IDs leave unknown whether xen0 is named
		unresolved, invalid := fmt.Sprintf("xen_%032x", 99), `xen_\u001b[2K`
		return errors.Join(addItems(dir, naming(xenID, slice()), naming(xen2ID, slice()), naming(xen2ID, slice(-1)), naming(unresolved, slice()), naming(unresolved, slice()),
			naming(invalid, slice()), naming(invalid, slice(-1)), naming(xenID, slice())), addArtifacts(dir, "xen", "ExecutionEnvelope/v1", envelope), replaceIn(dir, `"`+wiN(7)+`"`, `"`+wiN(0)+`"`))
	},
	"fault-budget":        nested(10, ""),   // 4 of 10 repeated keys total the manifest's length in paths
	"fault-budget-at-end": nested(5, ""),    // the last repeated key brings the paths past it
	"fault-budget-syntax": nested(10, " x"), // a cut fault list, then a syntax error
	"diagnostic-cap": func(dir string) error { // $.zz is added first, the unreadable artifact last
		return errors.Join(replaceIn(dir, `"jobs": [`, `"zz": 1, "jobs": [`+strings.Repeat("7, ", 2000)), replaceIn(dir, `"artifacts/baseline.json"`, `"artifacts/missing.json"`))
	},
	"invalid-utf8": func(dir string) error { return replaceIn(dir, `"wi_8887ffc`, "\"wi_\xff\xfe8887ffc") },
	"lone-surrogate": func(dir string) error { // a high, a low before a pair, and a pair beside an escaped backslash
		return errors.Join(replaceIn(dir, `"bnd_`, `"bnd_\ud800`), replaceIn(dir, `"reviewer.implementation/v1"`, `"\udc00\ud83d\ude00"`),
			replaceIn(dir, `"WorkItem/v1"`, `"\ud83d\ude00\\ud800"`))
	},
}

// incomplete is the diagnostic ending a list that stopped at a bound.
const incomplete = "incomplete-diagnostics $: list is incomplete: inspect stopped at a bound and diagnostics past it are not listed"

const (
	bundleID = "bnd_8d0e1c6f026fef7621a0c7b017f12c12"
	bslSHA   = "70e2a30e1b5a5d53b311faf4e2eb50acaed9c4be464fdca8f8eb72c6416efe34"
	wiSHA    = "e75149f5b53460eacd7e4bdb6af989a3903fb87754a129c906cb038f396646b3"
	xenID    = "xen_dd00d1cf54fb4ef059011c2dc206e701"
	xen2ID   = "xen_e2fdb6cef203d6f22cd9815948d7665f"
	xenSHA   = "926292edd0e04fef4e8208bec6d1bc8ef899e12183b8942de1e0fc12802f03e9"
	own      = "xen_<own>" // replaced by ownXen of the content naming it
	envelope = `{"bounds": {"attempts": 3, "repairs_per_attempt": 2, "attempt_minutes": 90, "worker_minutes": 360}}`
)

// nested writes bundle.json as d objects, each nesting the next under a 10-byte
// key and repeating that key after it, with tail before the last "}".
func nested(d int, tail string) func(dir string) error {
	return func(dir string) error {
		k := `"kkkkkkkkkk": `
		return os.WriteFile(dir+"/bundle.json", []byte(strings.Repeat("{"+k, d)+"1"+strings.Repeat(", "+k+"1}", d-1)+", "+k+"1"+tail+"}"), 0o644)
	}
}

// capped is diagnostic-cap's output, 1,000 of its 2,002 diagnostics: the
// unreadable artifact then 999 of 2,000 jobs, before $.zz; then incomplete.
func capped() []string {
	jobs := []string{}
	for i := range 2000 {
		jobs = append(jobs, fmt.Sprintf("unsupported-job $.jobs[%d]: job/version 7 is not supported", i))
	}
	slices.Sort(jobs)
	return append(append([]string{`unreadable-artifact $.artifacts[1].path: "artifacts/missing.json" does not resolve to a file inside the bundle directory`}, jobs[:999]...), incomplete)
}

// dups is the duplicate-key lines of nested at depths from to d, in list order.
func dups(from, d int) (lines []string) {
	for ; from <= d; from++ {
		lines = append(lines, "duplicate-key $"+strings.Repeat(".kkkkkkkkkk", from)+": key repeats an earlier key of this object")
	}
	return lines
}

// unknownBinding adds content as a Work Item and an unnamed envelope.
func unknownBinding(content string) func(dir string) error {
	return func(dir string) error {
		return errors.Join(addItems(dir, content), addArtifacts(dir, "xen", "ExecutionEnvelope/v1", envelope))
	}
}

// ownXen is the envelope ID a content naming own names once added: identical
// contents name one envelope.
func ownXen(content string) string { return fmt.Sprintf("xen_%x", sha256.Sum256([]byte(content)))[:36] }

// naming is content with own replaced by the envelope ID id.
func naming(id, content string) string { return strings.ReplaceAll(content, own, id) }

// consumerEnabler is ENABLER content naming the consumers of non-slice-consumer.
var consumerEnabler = `{"kind": "ENABLER", "consumers": ["` + wiN(1) + `", "` + wiN(2) + `", "` + wiN(-1) + `", "` + wiN(3) + `", "` + wiN(0) + `", "` + wiN(5) + `"], "dependencies": [], ` + traced + `}`

// badOutcomes is Work Item content whose outcomes are each faulty.
var badOutcomes = `{"kind": "SLICE", "dependencies": [], "outcomes": [7, {}, {"baseline": "bsl_` + fmt.Sprintf("%032x", 99) + `", "obligation": ""}, {"baseline": "` + wiN(-1) + `", "obligation": 7}, {"baseline": "bsl_\u001b[2K", "obligation": "x"}, {"baseline": "bsl_` + fmt.Sprintf("%032x", 0) + `", "obligation": "x"}, {"baseline": "bsl_6e73c229223db574a3c8fa28dd5a1a5a"}], ` + bound + `}`

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
	return `{"kind": "SLICE", "dependencies": [` + strings.Join(deps, ", ") + `], ` + traced + `}`
}

// traced is an outcomes field tracing one outcome to the valid fixture's
// baseline, then bound.
const traced = `"outcomes": [{"baseline": "bsl_6e73c229223db574a3c8fa28dd5a1a5a", "obligation": "AT-08"}], ` + bound

// bound is an execution_envelope field naming the content's own envelope.
const bound = `"execution_envelope": "` + own + `"`

// addItems writes each content to artifacts/wi<n>.json and declares it, by
// its exact-bytes digest, as Work Item wiN(n) after the valid fixture's artifacts.
func addItems(dir string, contents ...string) error {
	return addArtifacts(dir, "wi", "WorkItem/v1", contents...)
}

// addArtifacts is addItems for an artifact schema whose IDs have type prefix
// prefix: content n is artifacts/<prefix><n>.json with ID <prefix>_<n as 32 hex>.
// own in a content becomes ownXen; for Work Items, each such envelope is declared
// with the valid envelope's bytes after every artifact any call adds.
func addArtifacts(dir, prefix, schema string, contents ...string) error {
	entries, envelopes := "", ""
	for n, content := range contents {
		if id := ownXen(content); strings.Contains(content, own) {
			if content = naming(id, content); prefix == "wi" && !strings.Contains(envelopes, id) {
				envelopes += `, {"id": "` + id + `", "revision": 1, "schema": "ExecutionEnvelope/v1", "path": "artifacts/envelope.json", "sha256": "` + xenSHA + `", "refs": []}`
			}
		}
		name := fmt.Sprintf("artifacts/%s%d.json", prefix, n)
		entries += fmt.Sprintf(`, {"id": "%s_%032x", "revision": 1, "schema": "%s", "path": "%s", "sha256": "%x", "refs": []}`, prefix, n, schema, name, sha256.Sum256([]byte(content)))
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
			return err
		}
	}
	return replaceIn(dir, "}\n  ", "}"+entries+"\n  "+envelopes)
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
		orphan     = "outcome names no baseline obligation"
		orphanWI   = "Work Item names no outcome traced to a baseline obligation"
	)
	at := func(n int, rest string) string { return fmt.Sprintf(item, n+5) + rest }
	shared := func(content string, count int, id string) string {
		return fmt.Sprintf(`shared-envelope %s.execution_envelope: ExecutionEnvelope/v1 artifact "%s" is named by %d Work Items`, content, id, count)
	}
	for variant, want := range map[string][]string{
		"valid":           {"result: ok manifest_sha256=c5efab12f090dbd316f2e3f200316bb4f5f8d43d05c41ec31f08d0647177f563 (nothing staged or started)"},
		"tampered-digest": {"digest-mismatch " + wi + `.sha256: declared "` + wiSHA + `", exact bytes hash to fd7e08ca1eb7efa6a194db6a76b3cc19d5c4c7fd56f3c4e1b4285411e1e894a8`},
		"unsupported-version": {
			"unresolved-baseline " + wi + `.content.outcomes[0].baseline: no Baseline/v1 artifact in this bundle has ID "bsl_6e73c229223db574a3c8fa28dd5a1a5a"`,
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
		"invalid-utf8":        {"invalid-string " + wi + ".id: string is not valid UTF-8"},
		"diagnostic-cap":      capped(),
		"fault-budget":        append(dups(7, 10), incomplete),
		"fault-budget-at-end": dups(1, 5),
		"fault-budget-syntax": append(append([]string{"invalid-json $: bundle.json is not a single JSON value"}, dups(7, 10)...), incomplete),
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
			"orphan-envelope $.artifacts[3].id: no Work Item in this bundle names this ExecutionEnvelope/v1 artifact",
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
		"enabler-consumer": {shared(at(0, ""), 2, ownXen(slice(2, 2))), shared(at(1, ""), 2, ownXen(slice(2, 2)))},
		"dependency-cycle": {
			"dependency-cycle " + at(5, `.dependencies[1].work_item`) + `: Work Items depend in a cycle: "` + wiN(4) + `" -> "` + wiN(5) + `" -> "` + wiN(4) + `"`,
			"dependency-cycle " + at(10, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(9) + `" -> "` + wiN(10) + `" -> "` + wiN(9) + `"`,
			shared(at(13, ""), 2, ownXen(slice(14))),
			"dependency-cycle " + at(14, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(14) + `" -> "` + wiN(14) + `"`,
			shared(at(14, ""), 2, ownXen(slice(14))),
			"dependency-cycle " + at(0, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(0) + `" -> "` + wiN(0) + `"`,
			"dependency-cycle " + at(2, `.dependencies[0].work_item`) + `: Work Items depend in a cycle: "` + wiN(1) + `" -> "` + wiN(2) + `" -> "` + wiN(1) + `"`},
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
			`unreadable-artifact $.artifacts[6].path: "artifacts/wi1.json" does not resolve to a file inside the bundle directory`,
			"unresolved-work-item " + at(2, `.dependencies[0].work_item: no Work Item in this bundle has ID "`+wiN(97)+`"`),
			shared(at(2, ""), 2, ownXen(slice(97))), shared(at(3, ""), 2, ownXen(slice(97)))},
		"orphan-outcome": {
			`unsupported-schema $.artifacts[10].schema: artifact schema "Baseline/v2" is not supported`,
			"orphan-work-item " + at(0, ".outcomes: "+orphanWI),
			"orphan-work-item " + at(1, ".outcomes: "+orphanWI),
			"invalid-type " + at(2, ".outcomes: want array"),
			"orphan-work-item " + at(2, ".outcomes: "+orphanWI),
			shared(at(3, ""), 2, ownXen(badOutcomes)),
			"invalid-type " + at(3, ".outcomes[0]: want object"),
			"orphan-outcome " + at(3, ".outcomes[1].baseline: "+orphan),
			"unresolved-baseline " + at(3, `.outcomes[2].baseline: no Baseline/v1 artifact in this bundle has ID "bsl_`+fmt.Sprintf("%032x", 99)+`"`),
			"orphan-outcome " + at(3, ".outcomes[2].obligation: "+orphan),
			"invalid-id " + at(3, `.outcomes[3].baseline: want bsl_<32 lowercase hex>, got "`+wiN(-1)+`"`),
			"invalid-type " + at(3, ".outcomes[3].obligation: want string"),
			"invalid-id " + at(3, `.outcomes[4].baseline: want bsl_<32 lowercase hex>, got "bsl_\x1b[2K"`),
			"unresolved-baseline " + at(3, `.outcomes[5].baseline: no Baseline/v1 artifact in this bundle has ID "bsl_`+fmt.Sprintf("%032x", 0)+`"`),
			"orphan-outcome " + at(3, ".outcomes[6].obligation: "+orphan),
			shared(at(4, ""), 2, ownXen(badOutcomes))},
		"missing-condition": {
			"missing-condition " + at(0, ".dependencies[0].condition: dependency states no condition"),
			"missing-condition " + at(0, ".dependencies[1].condition: dependency states no condition"),
			"invalid-type " + at(0, ".dependencies[2].condition: want string"),
			"invalid-type " + at(0, ".dependencies[3].condition: want string"),
			"missing-field " + at(0, ".dependencies[4].work_item"+missing),
			"invalid-type " + at(0, ".dependencies[5]: want object"),
			"missing-field " + at(0, ".dependencies[6].work_item"+missing)},
		"non-slice-consumer": {
			"invalid-content " + at(5, ": want one JSON object with unique keys and exact strings"),
			"non-slice-consumer " + at(0, `.consumers[0]: consumer "`+wiN(1)+`" is not a SLICE Work Item`),
			"non-slice-consumer " + at(0, `.consumers[1]: consumer "`+wiN(2)+`" is not a SLICE Work Item`),
			"non-slice-consumer " + at(0, `.consumers[4]: consumer "`+wiN(0)+`" is not a SLICE Work Item`),
			"non-slice-consumer " + at(0, `.consumers[5]: consumer "`+wiN(5)+`" is not a SLICE Work Item`),
			shared(at(0, ""), 2, ownXen(consumerEnabler)),
			"invalid-kind " + at(2, `.kind: want "SLICE" or "ENABLER", got "slice"`),
			`unreadable-artifact $.artifacts[8].path: "artifacts/wi3.json" does not resolve to a file inside the bundle directory`,
			shared(at(4, ""), 2, ownXen(consumerEnabler))},
		"invalid-bound": {
			"invalid-bound " + at(5, ".bounds.attempts: want integer >= 1, got true"),
			"missing-field " + at(0, ".bounds"+missing),
			"invalid-type " + at(1, ".bounds: want object"),
			"invalid-bound " + at(2, ".bounds.attempt_minutes: want integer >= 1, got 1.5"),
			"invalid-bound " + at(2, ".bounds.attempts: want integer >= 1, got 0"),
			"invalid-bound " + at(2, ".bounds.repairs_per_attempt: want integer >= 1, got -1"),
			"invalid-bound " + at(2, `.bounds.worker_minutes: want integer >= 1, got "360"`),
			"unknown-field " + at(2, `.bounds["tokens\x1b[2K"]: field is not part of ExecutionEnvelope/v1`),
			"invalid-bound " + at(3, ".bounds.attempt_minutes: want integer >= 1, got 90.0"),
			"invalid-bound " + at(3, ".bounds.attempts: want integer >= 1, got 1e3"),
			"invalid-bound " + at(3, ".bounds.repairs_per_attempt: want integer >= 1, got null"),
			"missing-field " + at(3, ".bounds.worker_minutes"+missing),
			"invalid-content " + at(4, ": want one JSON object with unique keys and exact strings")},
		"blocking-result": {
			"blocking-result " + at(6, `.results[0].result: imported "FAIL" result rejects admission`),
			"empty-evaluation " + at(7, ".results: evaluation reports no result; absence of evidence rejects admission"),
			"blocking-result " + at(1, `.results[1].result: imported "FAIL" result rejects admission`),
			"missing-applicability " + at(1, ".results[2].applicability: NOT_APPLICABLE result states no applicability path"),
			"blocking-result " + at(1, `.results[3].result: imported "UNKNOWN" result rejects admission`),
			"invalid-result " + at(1, `.results[4].result: want "PASS", "FAIL", "NOT_APPLICABLE" or "UNKNOWN", got "fail\x1b[2K"`),
			"missing-field " + at(1, ".results[5].result"+missing),
			"invalid-type " + at(1, ".results[6]: want object"),
			"invalid-result " + at(1, `.results[7].result: want "PASS", "FAIL", "NOT_APPLICABLE" or "UNKNOWN", got null`),
			"missing-applicability " + at(1, ".results[8].applicability: NOT_APPLICABLE result states no applicability path"),
			"invalid-type " + at(1, ".results[9].applicability: want string"),
			"missing-field " + at(2, ".results"+missing),
			"invalid-type " + at(3, ".results: want array"),
			"invalid-content " + at(4, ": want one JSON object with unique keys and exact strings")},
		"unbound-work-item": {
			"unresolved-envelope " + at(5, `.execution_envelope: no ExecutionEnvelope/v1 artifact in this bundle has ID "xen_`+fmt.Sprintf("%032x", 0)+`"`),
			"unbound-work-item " + at(7, ".execution_envelope: Work Item names no ExecutionEnvelope/v1 artifact"),
			"unbound-work-item " + at(8, ".execution_envelope: Work Item names no ExecutionEnvelope/v1 artifact"),
			"orphan-work-item " + at(8, ".outcomes: Work Item names no outcome traced to a baseline obligation"),
			"unsupported-schema $.artifacts[14].schema: artifact schema \"ExecutionEnvelope/v2\" is not supported",
			"unbound-work-item " + at(0, ".execution_envelope: Work Item names no ExecutionEnvelope/v1 artifact"),
			"invalid-type " + at(1, ".execution_envelope: want string"),
			"invalid-id " + at(2, `.execution_envelope: want xen_<32 lowercase hex>, got "bsl_6e73c229223db574a3c8fa28dd5a1a5a"`),
			"invalid-id " + at(3, `.execution_envelope: want xen_<32 lowercase hex>, got "xen_\x1b[2K"`),
			"unresolved-envelope " + at(4, `.execution_envelope: no ExecutionEnvelope/v1 artifact in this bundle has ID "xen_`+fmt.Sprintf("%032x", 99)+`"`)},
		"shared-envelope":      {shared("$.artifacts[2].content", 2, xen2ID), shared(at(0, ""), 2, xen2ID)},
		"shared-envelope-many": {shared(wi+".content", 4, xenID), shared(at(0, ""), 4, xenID), shared(at(1, ""), 4, xenID), shared(at(2, ""), 4, xenID)},
		"orphan-envelope": {
			`duplicate-id $.artifacts[10].id: artifact ID "xen_` + fmt.Sprintf("%032x", 0) + `" is already declared at $.artifacts[8].id`,
			`invalid-id $.artifacts[11].id: want xen_<32 lowercase hex>, got "xen_\x1b[2K"`,
			`duplicate-id $.artifacts[5].id: artifact ID "` + wiN(-1) + `" is already declared at ` + wi + ".id",
			`duplicate-id $.artifacts[6].id: artifact ID "` + wiN(-1) + `" is already declared at ` + wi + ".id",
			"missing-field " + at(3, ".bounds"+missing),
			"orphan-envelope $.artifacts[8].id: no Work Item in this bundle names this ExecutionEnvelope/v1 artifact"},
		"unknown-binding-missing":       {"unbound-work-item " + at(0, ".execution_envelope: Work Item names no ExecutionEnvelope/v1 artifact")},
		"unknown-binding-type":          {"invalid-type " + at(0, ".execution_envelope: want string")},
		"unknown-binding-id":            {"invalid-id " + at(0, `.execution_envelope: want xen_<32 lowercase hex>, got "xen_\x1b[2K"`)},
		"unknown-binding-unresolved":    {"unresolved-envelope " + at(0, `.execution_envelope: no ExecutionEnvelope/v1 artifact in this bundle has ID "xen_`+fmt.Sprintf("%032x", 99)+`"`)},
		"unknown-binding-workitem-v2":   {`unsupported-schema $.artifacts[5].schema: artifact schema "WorkItem/v2" is not supported`},
		"unrelated-unsupported-schemas": {`unsupported-schema $.artifacts[5].schema: artifact schema "QualityEvaluation/v2" is not supported`, "orphan-envelope $.artifacts[6].id: no Work Item in this bundle names this ExecutionEnvelope/v1 artifact", `unsupported-schema $.artifacts[7].schema: artifact schema "ExecutionEnvelope/v2" is not supported`},
		"envelope-cardinality": {
			shared(wi+".content", 2, xenID),
			"invalid-id " + at(5, `.execution_envelope: want xen_<32 lowercase hex>, got "xen_\x1b[2K"`),
			"invalid-id " + at(6, `.execution_envelope: want xen_<32 lowercase hex>, got "xen_\x1b[2K"`),
			`duplicate-id $.artifacts[12].id: artifact ID "` + wiN(0) + `" is already declared at $.artifacts[5].id`,
			shared("$.artifacts[2].content", 3, xen2ID), shared(at(0, ""), 2, xenID), shared(at(1, ""), 3, xen2ID), shared(at(2, ""), 3, xen2ID),
			"unresolved-envelope " + at(3, `.execution_envelope: no ExecutionEnvelope/v1 artifact in this bundle has ID "xen_`+fmt.Sprintf("%032x", 99)+`"`)},
		"covered-bounded-passing": {"result: ok manifest_sha256=1bbbc37781b7fa879e88821495a59d841e13302bc8358308c127de8f55fa3a8c (nothing staged or started)"},
		"invalid-content": {
			"invalid-type " + at(5, ".dependencies: want array"),
			"invalid-kind " + at(6, `.kind: want "SLICE" or "ENABLER", got 7`),
			"invalid-content " + at(0, ": want one JSON object with unique keys and exact strings"),
			"invalid-content " + at(1, ": want one JSON object with unique keys and exact strings"),
			"missing-field " + at(2, ".kind"+missing),
			"invalid-kind " + at(3, `.kind: want "SLICE" or "ENABLER", got "slice\x1b[2K"`),
			"missing-field " + at(4, ".dependencies"+missing)},
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
				result := fmt.Sprintf("diagnostics=%d (", len(want))
				if want[len(want)-1] == incomplete {
					result = fmt.Sprintf("diagnostics-listed=%d (list incomplete; ", len(want))
				}
				code, want = 1, append(want, "result: invalid "+result+"nothing staged or started)")
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

// zeroArtifacts writes each file of sizes as that many zero bytes and adds a
// Baseline/v1 entry for each of names, declaring the digest of sizes[name] zero
// bytes, after the valid bundle's five entries (764 bytes of artifacts).
func zeroArtifacts(dir string, sizes map[string]int, names ...string) error {
	errs, entries := []error{}, ""
	for name, n := range sizes {
		errs = append(errs, os.WriteFile(dir+"/artifacts/"+name+".json", make([]byte, n), 0o644))
	}
	for i, name := range names {
		entries += fmt.Sprintf(`, {"id": "bsl_%032x", "revision": 1, "schema": "Baseline/v1", "path": "artifacts/%s.json", "sha256": "%x", "refs": []}`, i, name, sha256.Sum256(make([]byte, sizes[name])))
	}
	return errors.Join(append(errs, replaceIn(dir, "}\n  ", "}"+entries+"\n  "))...)
}

// TestArtifactBytesCap runs inspect once per case, as each reads about 128 MiB,
// and asserts its exact output and the bytes this process reads meanwhile (rchar
// in /proc/self/io): the manifest, the first /proc/self/io read and the artifact
// bytes, one past MaxArtifactBytes once it is passed, plus under 1,024 bytes of
// other reads by the process, which vary between runs, so a read limit 1,024
// bytes too high fails. TestArtifactReadLimit pins each read's limit exactly.
//   - over-cap: $.artifacts[12], 16 MiB, is reached with 8 MiB - 702 B left, and
//     [13] is not read.
//   - at-cap: the artifacts total exactly MaxArtifactBytes, which is not passed.
//   - past-cap: at-cap, then an 8-byte artifact with a wrong digest, which gets
//     the cap diagnostic, and a missing one, which is not read.
func TestArtifactBytesCap(t *testing.T) {
	const over = ` exceeds the 134217728-byte cap on artifact bytes read per bundle
`
	zeros, fill := map[string]int{"zero": 16 << 20, "rest": 16<<20 - 764}, []string{"rest", "zero", "zero", "zero", "zero", "zero", "zero", "zero"}
	for _, c := range []struct {
		name  string
		setup func(dir string) error
		read  int
		want  string
	}{
		{"over-cap", func(dir string) error {
			return zeroArtifacts(dir, map[string]int{"half": 8 << 20, "baseline": 16 << 20}, "half", "baseline", "baseline", "baseline", "baseline", "baseline", "baseline", "baseline", "missing")
		}, bundle.MaxArtifactBytes + 1, `unreadable-artifact $.artifacts[12].path: "artifacts/baseline.json"` + over + `digest-mismatch $.artifacts[1].sha256: declared "` + bslSHA + `", exact bytes hash to 080acf35a507ac9849cfcba47dc2ad83e01b75663a516279c8b9d243b719643e
` + incomplete + "\nresult: invalid diagnostics-listed=3 (list incomplete; nothing staged or started)\n"},
		{"at-cap", func(dir string) error { return zeroArtifacts(dir, zeros, fill...) }, bundle.MaxArtifactBytes, "result: ok"},
		{"past-cap", func(dir string) error {
			return errors.Join(os.WriteFile(dir+"/artifacts/tampered.json", []byte("tampered"), 0o644), zeroArtifacts(dir, zeros, append(fill, "tampered", "missing")...))
		}, bundle.MaxArtifactBytes + 1, `unreadable-artifact $.artifacts[13].path: "artifacts/tampered.json"` + over + incomplete + "\nresult: invalid diagnostics-listed=2 (list incomplete; nothing staged or started)\n"},
	} {
		t.Run(c.name, func(t *testing.T) {
			dir := bundleCopy(t, "valid")
			manifest, err := os.ReadFile(dir + "/bundle.json")
			if err = errors.Join(c.setup(dir), err); err == nil {
				manifest, err = os.ReadFile(dir + "/bundle.json")
			}
			if err != nil {
				t.Fatal(err)
			}
			rchar := func() (n, size int) {
				b, err := os.ReadFile("/proc/self/io")
				if _, scanErr := fmt.Sscanf(string(b), "rchar: %d", &n); err != nil || scanErr != nil {
					t.Fatal(err, scanErr)
				}
				return n, len(b)
			}
			var stdout, stderr bytes.Buffer
			before, size := rchar()
			code := run([]string{"bundle", "inspect", dir}, &stdout, &stderr)
			after, _ := rchar()
			want, wantCode, wantRead := c.want, 1, size+len(manifest)+c.read
			if want == "result: ok" {
				want, wantCode = fmt.Sprintf("result: ok manifest_sha256=%x (nothing staged or started)\n", sha256.Sum256(manifest)), 0
			}
			if code != wantCode || stdout.String() != want || stderr.Len() != 0 || after-before < wantRead || after-before >= wantRead+1024 {
				t.Errorf("exit=%d, %d bytes read, stdout:\n%s\nstderr: %q; want exit %d, %d bytes read (+1,023), stdout:\n%s", code, after-before, stdout.String(), stderr.String(), wantCode, wantRead, want)
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
