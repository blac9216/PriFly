// Command priflyd is the PriFly controller process: it reports build/schema
// identity at startup and performs a bounded shutdown on SIGINT/SIGTERM.
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/blac9216/PriFly/internal/buildinfo"
	"github.com/blac9216/PriFly/internal/controller"
)

func main() {
	os.Exit(mainImpl())
}

func mainImpl() int {
	fmt.Fprintf(os.Stderr, "priflyd starting: %s\n", buildinfo.Current().String())

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	err := controller.Run(ctx, controller.DefaultShutdownBound, shutdown)
	if err != nil {
		fmt.Fprintf(os.Stderr, "priflyd shutdown error: %v\n", err)
		return 1
	}
	fmt.Fprintln(os.Stderr, "priflyd stopped cleanly")
	return 0
}

// shutdown performs priflyd's cleanup. This skeleton has nothing to
// release yet; a later slice wires real teardown through this bounded hook.
func shutdown(context.Context) error {
	return nil
}
