package main

import (
	"fmt"
	"io"

	"github.com/blac9216/PriFly/internal/bundle"
)

// runBundle implements "bundle inspect <bundle-dir>", which stages and starts
// nothing. Exit 0: no diagnostics; 1: diagnostics; 2: usage error.
func runBundle(args []string, stdout, stderr io.Writer) int {
	if len(args) != 2 || args[0] != "inspect" {
		fmt.Fprintf(stderr, "prifly: want bundle inspect <bundle-dir> (got %q)\n\n%s", args, usage)
		return 2
	}
	diags, manifestSHA256 := bundle.Inspect(args[1])
	for _, d := range diags {
		fmt.Fprintln(stdout, d)
	}
	if len(diags) > 0 {
		fmt.Fprintf(stdout, "result: invalid diagnostics=%d (nothing staged or started)\n", len(diags))
		return 1
	}
	fmt.Fprintf(stdout, "result: ok manifest_sha256=%s (nothing staged or started)\n", manifestSHA256)
	return 0
}
