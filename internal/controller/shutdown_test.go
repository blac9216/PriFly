package controller

import (
	"context"
	"errors"
	"testing"
	"time"
)

// TestRunReturnsShutdownResultWithinBound is the positive oracle: a
// shutdown hook that finishes well inside the bound reports its own result,
// not a timeout.
func TestRunReturnsShutdownResultWithinBound(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // simulate an already-delivered SIGINT/SIGTERM

	wantErr := errors.New("boom")
	called := false
	err := Run(ctx, 200*time.Millisecond, func(context.Context) error {
		called = true
		return wantErr
	})
	if !errors.Is(err, wantErr) {
		t.Fatalf("Run() error = %v, want %v", err, wantErr)
	}
	if !called {
		t.Fatal("shutdown hook was not invoked")
	}
}

// TestRunTimesOutPastBound is the negative/adverse oracle: a shutdown hook
// that never returns must not hang the caller past the stated bound, and
// Run must report ErrShutdownTimedOut rather than silently succeeding.
func TestRunTimesOutPastBound(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	blocked := make(chan struct{})
	start := time.Now()
	bound := 30 * time.Millisecond
	err := Run(ctx, bound, func(shutdownCtx context.Context) error {
		<-shutdownCtx.Done() // never returns on its own
		close(blocked)
		return shutdownCtx.Err()
	})
	elapsed := time.Since(start)

	if !errors.Is(err, ErrShutdownTimedOut) {
		t.Fatalf("Run() error = %v, want ErrShutdownTimedOut", err)
	}
	// Deterministic upper bound with slack for scheduler jitter; no
	// unbounded sleep is used to observe this.
	if elapsed > bound+500*time.Millisecond {
		t.Fatalf("Run() took %v, want close to bound %v", elapsed, bound)
	}
	<-blocked // let the leaked goroutine finish before the test exits
}
