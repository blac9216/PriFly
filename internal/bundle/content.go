// Execution Envelope and Quality Evaluation content checks: finite envelope
// bounds, and results that are present and neither blocking FAIL/UNKNOWN nor
// NOT_APPLICABLE without an applicability path (C1 "finite envelopes, and
// absence of blocking FAIL/UNKNOWN"; ADR-0021 item 5). Only these fields are
// read; structural validation of the rest is #181.

package bundle

import (
	"encoding/json"
	"fmt"
)

// boundNames are the per-Work-Item Execution Envelope bounds (P9): total
// attempts, serialization repairs per attempt, minutes per attempt and active
// Worker minutes. No numeric limit is chosen here; each must be an integer >= 1.
var boundNames = []string{"attempts", "repairs_per_attempt", "attempt_minutes", "worker_minutes"}

// content decodes the artifact content at path p (reported as p.content),
// returning nil after reporting invalid-content unless it is one JSON object.
func (c *checker) content(p string, content []byte) map[string]any {
	doc, ok := DecodeJSON(content)
	m, isObject := doc.(map[string]any)
	if !ok || !isObject {
		c.add(p+".content", "invalid-content", "want one JSON object with unique keys and exact strings")
		return nil
	}
	return m
}

// text reports code at path.key unless m[key] is a non-empty string; a present
// value of another type is invalid-type instead.
func (c *checker) text(m map[string]any, path, key, code, detail string) {
	if s, ok := c.str(m, path, key); s == "" {
		if _, present := m[key]; ok || !present {
			c.add(path+"."+key, code, "%s", detail)
		}
	}
}

// envelope rejects an ExecutionEnvelope/v1 content at p whose bounds object
// is absent, lacks a bound, has an unknown bound or a bound not an integer >= 1.
func (c *checker) envelope(p string, content []byte) {
	m, bp := c.content(p, content), p+".content.bounds"
	if _, present := m["bounds"]; m != nil && !present {
		c.add(bp, "missing-field", "required field is absent")
	} else if m != nil {
		bounds := c.object(m["bounds"], bp, "ExecutionEnvelope/v1", boundNames...)
		for _, k := range boundNames {
			if v, present := bounds[k]; present && !revisionRE.MatchString(numberText(v)) {
				c.add(bp+"."+k, "invalid-bound", "want integer >= 1, got %s", Quote(v))
			}
		}
	}
}

// numberText is v's literal when v is a JSON number, else "".
func numberText(v any) string {
	n, _ := v.(json.Number)
	return n.String()
}

// evaluation rejects every FAIL or UNKNOWN result in a QualityEvaluation/v1
// content at p: no reviewed descriptor mapping makes an imported criterion
// non-blocking yet (P14; ADR-0021 item 5; B02 split ruling, conflict 2). An
// empty results array (#281 ruling) and a NOT_APPLICABLE result without a
// non-empty applicability string (#288 ruling) are unresolved and rejected too.
func (c *checker) evaluation(p string, content []byte) {
	m, cp := c.content(p, content), p+".content"
	if _, present := m["results"]; m != nil && !present {
		c.add(cp+".results", "missing-field", "required field is absent")
	}
	results := c.list(m, cp, "results")
	if results != nil && len(results) == 0 {
		c.add(cp+".results", "empty-evaluation", "evaluation reports no result; absence of evidence rejects admission")
	}
	for k, r := range results {
		rp := fmt.Sprintf("%s.results[%d]", cp, k)
		o, isObject := r.(map[string]any)
		switch v, present := o["result"]; {
		case !isObject:
			c.add(rp, "invalid-type", "want object")
		case !present:
			c.add(rp+".result", "missing-field", "required field is absent")
		case v == "FAIL" || v == "UNKNOWN":
			c.add(rp+".result", "blocking-result", "imported %s result rejects admission", Quote(v))
		case v == "NOT_APPLICABLE":
			c.text(o, rp, "applicability", "missing-applicability", "NOT_APPLICABLE result states no applicability path")
		case v != "PASS":
			c.add(rp+".result", "invalid-result", `want "PASS", "FAIL", "NOT_APPLICABLE" or "UNKNOWN", got %s`, Quote(v))
		}
	}
}
