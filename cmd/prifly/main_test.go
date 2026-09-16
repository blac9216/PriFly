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

// TestRunVersionRejectsExtraArguments guards against "version" with extra
// arguments being reported as an unknown command: it must instead name the
// unexpected argument(s) and print usage.
func TestRunVersionRejectsExtraArguments(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := run([]string{"version", "extra"}, &stdout, &stderr)

	if code != 2 {
		t.Fatalf("exit code = %d, want 2; stderr=%q", code, stderr.String())
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout = %q, want empty on failure", stdout.String())
	}
	if strings.Contains(stderr.String(), `unknown command "version"`) {
		t.Fatalf("stderr = %q, must not report version as unknown", stderr.String())
	}
	if !strings.Contains(stderr.String(), "version takes no arguments") {
		t.Fatalf("stderr = %q, want a message naming the unexpected argument(s)", stderr.String())
	}
	if !strings.Contains(stderr.String(), "extra") {
		t.Fatalf("stderr = %q, want the unexpected argument %q named", stderr.String(), "extra")
	}
	if !strings.Contains(stderr.String(), "Usage:") {
		t.Fatalf("stderr = %q, want usage text", stderr.String())
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
