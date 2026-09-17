// Command prifly is the PriFly owner/operator CLI. This initial cut supports
// "version" and "bundle inspect"; any other input, including no arguments, fails clearly
// with a non-zero exit and usage text rather than a silent no-op.
package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/blac9216/PriFly/internal/buildinfo"
	"github.com/blac9216/PriFly/internal/bundle"
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
			fmt.Fprintf(stderr, "prifly: version takes no arguments (got %s)\n\n", quoteArgs(args[1:]))
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
	fmt.Fprintf(stderr, "prifly: unknown command %s\n\n", bundle.Quote(cmd))
	fmt.Fprint(stderr, usage)
	return 2
}

// quoteArgs renders args the way fmt's %q renders a []string — the elements
// quoted, space separated, in brackets — but through bundle.Quote, which is
// strconv.QuoteToASCII. %q is strconv.Quote, which escapes what is not
// printable and leaves printable non-ASCII alone, so an argument carrying a
// homoglyph or a combining mark reaches the operator's terminal as itself.
// Argv is operator-supplied, and a script iterating a hostile bundle
// directory's entries supplies names that directory chose.
//
// bundle.Quote takes any and has no []string case — it would return the string
// "object" for a slice — so the elements are rendered one at a time.
func quoteArgs(args []string) string {
	quoted := make([]string, len(args))
	for i, arg := range args {
		quoted[i] = bundle.Quote(arg)
	}
	return "[" + strings.Join(quoted, " ") + "]"
}
