package main

import (
	"context"
	"errors"
	"os"
	"strings"
	"syscall"
	"testing"
)

// selfSignaler is priflyd's stderr under test. Its first write is the startup
// line, which mainImpl prints only after registering its handler, so it then
// signals this process; a signal mainImpl does not handle kills the test binary.
type selfSignaler struct {
	strings.Builder
	sig syscall.Signal
}

func (w *selfSignaler) Write(p []byte) (int, error) {
	if w.Len() == 0 {
		_ = syscall.Kill(os.Getpid(), w.sig)
	}
	return w.Builder.Write(p)
}

func TestMainImplHandlesSignalsAndExitCodes(t *testing.T) {
	failing := func(context.Context) error { return errors.New("hook failed") }
	for _, tc := range []struct {
		sig  syscall.Signal
		hook func(context.Context) error
		code int
		want string
	}{
		{syscall.SIGTERM, shutdown, 0, "priflyd stopped cleanly\n"},
		{syscall.SIGINT, shutdown, 0, "priflyd stopped cleanly\n"},
		{syscall.SIGTERM, failing, 1, "priflyd shutdown error: hook failed\n"},
	} {
		w := &selfSignaler{sig: tc.sig}
		if code := mainImpl(w, tc.hook); code != tc.code || !strings.HasSuffix(w.String(), tc.want) {
			t.Errorf("%v: exit %d, stderr %q; want %d, suffix %q", tc.sig, code, w.String(), tc.code, tc.want)
		}
	}
}
