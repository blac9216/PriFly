// Package buildinfo carries the build-time subject identity (version,
// commit, and supported data-schema identity) that PriFly executables
// report through their "version" command and startup logs.
//
// Version and Commit are overridable at build time via -ldflags -X, e.g.
// `-X .../buildinfo.Version=v0.1.0 -X .../buildinfo.Commit=<sha>`. Values
// not injected fall back to deterministic defaults so a plain "go build"
// never fails or reports a non-deterministic value.
package buildinfo

import "fmt"

// Version is the PriFly release/build version. Overridable via -ldflags -X.
// Defaults to "dev" when not injected.
var Version = "dev"

// Commit is the exact source commit the binary was built from. Overridable
// via -ldflags -X. Defaults to "unknown" when not injected.
var Commit = "unknown"

// SchemaVersion is a placeholder identity: no canonical record family has an
// executable schema or migration baseline yet (docs/reference/schemas.md
// "Common identity and reference rules"; ADR-0020's pre-v1 baseline). It
// will be replaced once the first schema/migration baseline lands, at which
// point it must track that baseline's real identity rather than this fixed
// constant.
const SchemaVersion = "v1"

// Info is the subject identity reported by "version" commands and startup
// diagnostics.
type Info struct {
	Version string
	Commit  string
	Schema  string
}

// Current returns the process's current build identity.
func Current() Info {
	return Info{Version: Version, Commit: Commit, Schema: SchemaVersion}
}

// String renders a deterministic, single-line human-readable form, e.g.
// "version=dev commit=unknown schema=v1".
func (i Info) String() string {
	return fmt.Sprintf("version=%s commit=%s schema=%s", i.Version, i.Commit, i.Schema)
}
