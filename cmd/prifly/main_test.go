package main

import (
	"bytes"
	"strings"
	"testing"

	"github.com/blac9216/PriFly/internal/buildinfo"
)

func TestRunVersionPrintsSubjectIdentity(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := run([]string{"version"}, &stdout, &stderr)

	if code != 0 {
		t.Fatalf("exit code = %d, want 0; stderr=%q", code, stderr.String())
	}
	if got, want := strings.TrimSpace(stdout.String()), buildinfo.Current().String(); got != want {
		t.Fatalf("stdout = %q, want %q", got, want)
	}
	if stderr.Len() != 0 {
		t.Fatalf("stderr = %q, want empty", stderr.String())
	}
}

// TestRunUnrecognizedInputFailsClearly is the negative control for the CLI's
// dispatch: an unknown command or missing command must exit non-zero with
// usage on stderr and nothing on stdout, never a silent success.
func TestRunUnrecognizedInputFailsClearly(t *testing.T) {
	for name, args := range map[string][]string{
		"unknown command": {"bogus-command"},
		"no arguments":    {},
	} {
		t.Run(name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			code := run(args, &stdout, &stderr)

			if code == 0 {
				t.Fatalf("exit code = %d, want non-zero", code)
			}
			if !strings.Contains(stderr.String(), "Usage:") {
				t.Fatalf("stderr = %q, want usage text", stderr.String())
			}
			if stdout.Len() != 0 {
				t.Fatalf("stdout = %q, want empty on failure", stdout.String())
			}
		})
	}
}
