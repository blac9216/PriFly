# Testing

## Required checks

- `design-docs` — the single required status check on `workflow-main`
  (`gh api repos/blac9216/PriFly/rulesets/23306001`, read live 2026-09-16).

The check is the always-reporting `design-docs` job in
`.github/workflows/docs-checks.yml`. That workflow has no pull-request path filter, so
the check is safe to require on every pull request, including a documentation-only one.

## Commands

The executable verification surface is the canonical documentation suite below, run from
the repository root, plus the Go suite that follows it:

| Suite | Command | Environment |
|---|---|---|
| Rationale pointers | `bash scripts/docs/check-pointers.sh --root .` | Repository checkout; Bash, standard Unix tools. |
| ADR index | `bash scripts/docs/adr-index.sh --root . --check` | Repository checkout. |
| Mechanical audit | `bash scripts/docs/audit.sh --root . --out <scratch-path>/gap.md` | Repository checkout; writes an ephemeral gap report outside the repository tree — never commit it. |
| Markdown links/fragments | `bash scripts/docs/check-links.sh --root .` | Repository checkout; Python 3. |
| Link-checker regression tests | `bash scripts/docs/test-check-links.sh` | Repository checkout; Python 3. |
| Readiness-checker regression tests | `bash scripts/process/test-check-readiness.sh` | Repository checkout; Bash, Python 3. |
| Sanitize scan | `gitleaks detect --source . --no-banner` | Repository checkout; `gitleaks` binary on `PATH`. Run before every push — this repository is **public**. |
| Integration | No command exists until a runnable integration surface lands. | Not configured. |

These are exactly the six `docs-checks.yml` steps plus the sanitize scan; a manifest's
**Command** field lists these (and the Go suite below, if Go changed) in the order the
log actually ran them.

Go suite (`cmd/`, `internal/`): exactly the steps of the always-reporting, not-yet-required
`go` job in `.github/workflows/go-checks.yml`, same order and flags. Use the toolchain
`go.mod`'s `go` directive pins: read the `sha256` of `go<version>.<os>-<arch>.tar.gz` from
`https://go.dev/dl/?mode=json&include=all`, download `https://go.dev/dl/<that file>`, run
`echo "<sha256>  <that file>" | sha256sum -c -`, extract it outside the checkout, put its
`go/bin` first on `PATH`, and export `GOTOOLCHAIN=local` and `GOFLAGS=-mod=readonly`:

| Suite | Command | Environment |
|---|---|---|
| Identity | `git rev-parse HEAD`, then `go version` | Checkout; pinned `go` first on `PATH`. |
| Format | `test -z "$(gofmt -l .)"` | Same; exits 1 if any file is unformatted. |
| Vet | `go vet ./...` | Same. |
| Unit tests | `go test -count=1 -race -v ./...` | Same; uncached; `-race` needs cgo. |
| Build | `go build ./...` | Same; keeps no binaries (add `-o <dir>/` to keep them). |

## Lint state

`not installed — review-only` (`command -v markdownlint` → exit `1`;
`command -v markdownlint-cli2` → exit `1`, checked 2026-09-16). No markdown linter is
part of the documented suite or CI; Markdown structure/link correctness is instead covered
by `check-links.sh` and `check-pointers.sh` above. Whether a given machine has one
installed belongs in `*.local.md` guidance.

## Coverage

none — no coverage command or threshold is wired into CI yet; a governing Planning
Baseline still needs to fix a coverage threshold before one becomes required.

## Isolation on a shared host

No shared test service exists yet, and the Go suite starts none. Future tests must use the
`prifly-<issue-or-attempt>-<run-id>` resource prefix, unique ports, and disposable remote
namespaces. A run removes only its own named resources — see
[maintenance.md](maintenance.md).

## Live testing

Environment-specific recipes belong in untracked `*.local.md` guidance (for example
`docs/testing.local.md`); none is committed. The inputs a live check needs, and the
blocker reported when one is missing, are in [validation.md](validation.md).

Add exact Go integration and coverage commands in the same change that makes each real;
keep these tables, `docs-checks.yml` and `go-checks.yml` in agreement.
