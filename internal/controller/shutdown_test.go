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
// that honours its context and returns once notified must not hang the
// caller past the stated bound, and Run must report ErrShutdownTimedOut
// rather than silently succeeding.
func TestRunTimesOutPastBound(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	blocked := make(chan struct{})
	start := time.Now()
	bound := 30 * time.Millisecond
	err := Run(ctx, bound, func(shutdownCtx context.Context) error {
		<-shutdownCtx.Done() // returns once notified of the deadline
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

// TestRunTimesOutWhenHookIgnoresContext is the negative/adverse oracle for a
// hook that never watches shutdownCtx at all: unlike
// TestRunTimesOutPastBound (whose hook returns via <-shutdownCtx.Done()),
// this hook blocks on something the deadline cannot touch, so it never
// returns on its own. Run must still report ErrShutdownTimedOut within the
// bound rather than hanging on the leaked goroutine.
func TestRunTimesOutWhenHookIgnoresContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	neverSent := make(chan struct{}) // nothing ever sends on this channel
	start := time.Now()
	bound := 30 * time.Millisecond
	err := Run(ctx, bound, func(shutdownCtx context.Context) error {
		<-neverSent // ignores shutdownCtx entirely; never returns on its own
		return nil
	})
	elapsed := time.Since(start)

	if !errors.Is(err, ErrShutdownTimedOut) {
		t.Fatalf("Run() error = %v, want ErrShutdownTimedOut", err)
	}
	if elapsed > bound+500*time.Millisecond {
		t.Fatalf("Run() took %v, want close to bound %v", elapsed, bound)
	}
	// The hook's goroutine is intentionally leaked for the rest of the
	// process's life: it ignores its context by construction, so nothing
	// short of process exit reclaims it. That is the scenario under test.
}

// TestRunTimesOutDeterministicallyAtDeadline is the regression oracle for
// the race described in #138: when a hook honours its context and returns
// at (or fractionally after) the deadline, Run's internal select must not
// nondeterministically choose between the hook's own result and
// ErrShutdownTimedOut depending on which channel happens to ready first. A
// reviewer probe at a 1us bound observed the wrong result (a bare
// context.DeadlineExceeded instead of ErrShutdownTimedOut) in 3 of 2000
// runs before the fix in shutdown.go; this test re-runs the same shape at
// -count=2000 under -race to prove the fix holds.
func TestRunTimesOutDeterministicallyAtDeadline(t *testing.T) {
	const iterations = 2000
	for i := 0; i < iterations; i++ {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		bound := time.Microsecond
		err := Run(ctx, bound, func(shutdownCtx context.Context) error {
			<-shutdownCtx.Done()
			return shutdownCtx.Err()
		})
		if !errors.Is(err, ErrShutdownTimedOut) {
			t.Fatalf("iteration %d: Run() error = %v, want ErrShutdownTimedOut", i, err)
		}
	}
}
