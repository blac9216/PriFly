// Command prifly-bootstrap runs the restricted bootstrap sequence for an
// owner-selected private bootstrap repository revision: fetch and verify,
// decrypt into protected transient storage, then discover existing remote
// Factory state. It never initializes a Factory. Its output carries no secret,
// identity, locator, credential reference or provider text.
package main

import (
	"cmp"
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/blac9216/PriFly/internal/bootstrap"
)

const usage = `usage: prifly-bootstrap -repository URL -revision COMMIT -factory-id ID
    -fetch-ssh-auth-sock PATH -age-identity-file PATH -work-dir DIR

-fetch-ssh-auth-sock is required: the absolute path of the SSH agent socket that
holds the separately held fetch credential. Git inherits no environment. It gets
exactly PATH, HOME set to a private work directory, fixed LC_ALL,
GIT_CONFIG_NOSYSTEM, GIT_CONFIG_GLOBAL and GIT_TERMINAL_PROMPT, and SSH_AUTH_SOCK
from this flag. Every input is a reference; never pass a credential or key value.
`

// discoverer is the admitted remote-discovery provider. None is admitted yet (the
// real provider awaits live qualification), so discovery reports missing
// configuration and bootstrap blocks.
var discoverer bootstrap.Discoverer

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	code := run(ctx, os.Args[1:], os.Stdout, os.Stderr, discoverer)
	stop()
	os.Exit(code)
}

func run(ctx context.Context, args []string, stdout, stderr io.Writer, d bootstrap.Discoverer) int {
	fs := flag.NewFlagSet("prifly-bootstrap", flag.ContinueOnError)
	fs.SetOutput(io.Discard) // only the fixed usage text is printed
	var req bootstrap.Request
	var identity, work string
	fs.StringVar(&req.Repository, "repository", "", "")
	fs.StringVar(&req.Revision, "revision", "", "")
	fs.StringVar(&req.FactoryID, "factory-id", "", "")
	fs.StringVar(&req.SSHAuthSock, "fetch-ssh-auth-sock", "", "")
	fs.StringVar(&identity, "age-identity-file", "", "")
	fs.StringVar(&work, "work-dir", "", "")
	if fs.Parse(args) != nil || fs.NArg() != 0 || req.Repository == "" || req.Revision == "" ||
		req.FactoryID == "" || identity == "" || work == "" {
		fmt.Fprint(stderr, usage)
		return 2
	}
	if !filepath.IsAbs(req.SSHAuthSock) {
		fmt.Fprintln(stderr, "prifly-bootstrap: blocked: an explicit fetch credential reference (-fetch-ssh-auth-sock, absolute path) is required")
		return 1
	}
	v, err := bootstrap.Fetch(ctx, req, work)
	if err == nil {
		var discoverErr error
		err = bootstrap.Decrypt(v, identity, work, func(path string) error {
			discoverErr = bootstrap.Discover(ctx, d, v.Manifest, path)
			return discoverErr
		})
		err = cmp.Or(discoverErr, err)
	}
	if err != nil {
		fmt.Fprintf(stderr, "prifly-bootstrap: blocked: %v\n", err)
		return 1
	}
	fmt.Fprintf(stdout, "prifly-bootstrap: existing Factory state discovered at revision %s; recovery requires the separate explicit takeover\n", v.Revision)
	return 0
}
