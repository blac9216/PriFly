// Command prifly is the PriFly owner/operator CLI. This initial cut supports
// "version" and "bundle inspect"; any other input, including no arguments, fails clearly
// with a non-zero exit and usage text rather than a silent no-op.
package main

import (
	"fmt"
	"io"
	"os"

	"github.com/blac9216/PriFly/internal/buildinfo"
)

const usage = `Usage: prifly <command>

Commands:
  version                      Print the subject identity (version, commit, schema) for this build.
  bundle inspect <bundle-dir>  Validate a local external planning bundle; stages or starts nothing.
`

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run implements the CLI's dispatch against injected argv/streams and
// returns the process exit code, so it is unit testable without a
// subprocess.
func run(args []string, stdout, stderr io.Writer) int {
	if len(args) >= 1 && args[0] == "version" {
		if len(args) > 1 {
			fmt.Fprintf(stderr, "prifly: version takes no arguments (got %q)\n\n", args[1:])
			fmt.Fprint(stderr, usage)
			return 2
		}
		fmt.Fprintln(stdout, buildinfo.Current().String())
		return 0
	}

	if len(args) >= 1 && args[0] == "bundle" {
		return runBundle(args[1:], stdout, stderr)
	}

	cmd := "<none>"
	if len(args) > 0 {
		cmd = args[0]
	}
	fmt.Fprintf(stderr, "prifly: unknown command %q\n\n", cmd)
	fmt.Fprint(stderr, usage)
	return 2
}
