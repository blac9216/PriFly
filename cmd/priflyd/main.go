// Command priflyd is the PriFly controller process: it reports build/schema
// identity at startup and performs a bounded shutdown on SIGINT/SIGTERM.
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"github.com/blac9216/PriFly/internal/buildinfo"
	"github.com/blac9216/PriFly/internal/controller"
)

func main() {
	os.Exit(mainImpl(os.Stderr, shutdown))
}

// mainImpl registers SIGINT/SIGTERM before printing the startup line (tests
// rely on that order), then maps the bounded shutdown result to an exit code.
func mainImpl(stderr io.Writer, hook func(context.Context) error) int {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	fmt.Fprintf(stderr, "priflyd starting: %s\n", buildinfo.Current().String())

	if err := controller.Run(ctx, controller.DefaultShutdownBound, hook); err != nil {
		fmt.Fprintf(stderr, "priflyd shutdown error: %v\n", err)
		return 1
	}
	fmt.Fprintln(stderr, "priflyd stopped cleanly")
	return 0
}

// shutdown performs priflyd's cleanup. This skeleton has nothing to
// release yet; a later slice wires real teardown through this bounded hook.
func shutdown(context.Context) error {
	return nil
}
