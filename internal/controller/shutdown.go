// Package controller implements priflyd's bounded-shutdown lifecycle: run
// until a cancellation signal, then stop within a fixed deadline rather than
// hanging indefinitely or being killed uncleanly.
package controller

import (
	"context"
	"fmt"
	"time"
)

// DefaultShutdownBound is the maximum duration priflyd allows its shutdown
// hook to run after SIGINT/SIGTERM before giving up and returning an error.
//
// The owner fixed this bound at 10 seconds, matching Docker's default stop
// grace period and P9b's 10 s attempt-container grace
// (https://github.com/blac9216/PriFly/issues/136#issuecomment-5715010263).
const DefaultShutdownBound = 10 * time.Second

// ErrShutdownTimedOut is returned by Run when the shutdown hook did not
// complete within the bound.
var ErrShutdownTimedOut = fmt.Errorf("controller: shutdown did not complete within bound")

// testHookBeforeSelect, when non-nil, runs just before Run waits for the
// shutdown result or the deadline. Tests use it to make both outcomes ready
// at the same moment, so the tie is exercised deterministically instead of
// depending on goroutine scheduling. It is always nil outside tests.
var testHookBeforeSelect func(shutdownCtx context.Context, done <-chan error)

// Run blocks until ctx is done (for example, cancelled by a SIGINT/SIGTERM
// signal.NotifyContext), then calls shutdown with a context bounded by
// `bound`. It returns ErrShutdownTimedOut if shutdown does not return before
// the bound elapses, or shutdown's own error otherwise.
func Run(ctx context.Context, bound time.Duration, shutdown func(context.Context) error) error {
	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), bound)
	defer cancel()

	done := make(chan error, 1)
	go func() {
		done <- shutdown(shutdownCtx)
	}()

	if testHookBeforeSelect != nil {
		testHookBeforeSelect(shutdownCtx, done)
	}

	select {
	case err := <-done:
		// shutdown returned around the same instant the deadline elapsed.
		// Report the timeout deterministically in that case rather than
		// racing against the shutdownCtx.Done() branch below: whichever
		// channel this select happened to observe first must not change
		// the caller-visible result.
		if shutdownCtx.Err() != nil {
			return ErrShutdownTimedOut
		}
		return err
	case <-shutdownCtx.Done():
		return ErrShutdownTimedOut
	}
}
