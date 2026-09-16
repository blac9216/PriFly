package controller

import (
	"context"
	"errors"
	"runtime"
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
// the deadline tie: when a hook honours its context and its result is
// already waiting at the moment the deadline has also elapsed, Run must
// report ErrShutdownTimedOut, never the hook's own result. The test hook
// holds Run until both outcomes are ready before it selects, so a select
// that picks between them at random fails this test with probability
// 1-2^-iterations at any GOMAXPROCS, with or without -race.
func TestRunTimesOutDeterministicallyAtDeadline(t *testing.T) {
	const iterations = 100
	calls := 0
	testHookBeforeSelect = func(shutdownCtx context.Context, done <-chan error) {
		calls++
		<-shutdownCtx.Done()
		for len(done) == 0 {
			runtime.Gosched()
		}
	}
	t.Cleanup(func() { testHookBeforeSelect = nil })

	for i := 0; i < iterations; i++ {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		err := Run(ctx, time.Millisecond, func(shutdownCtx context.Context) error {
			<-shutdownCtx.Done()
			return shutdownCtx.Err()
		})
		if !errors.Is(err, ErrShutdownTimedOut) {
			t.Fatalf("iteration %d: Run() error = %v, want ErrShutdownTimedOut", i, err)
		}
	}
	if calls != iterations {
		t.Fatalf("test hook ran %d times, want %d: Run no longer reaches the tie under test", calls, iterations)
	}
}
