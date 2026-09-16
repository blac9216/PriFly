# Testing

## Required checks

- `design-docs` — the single required status check on `workflow-main`
  (`gh api repos/blac9216/PriFly/rulesets/23306001`, read live 2026-09-16).

The check is the always-reporting `design-docs` job in
`.github/workflows/docs-checks.yml`. That workflow has no pull-request path filter, so
the check is safe to require on every pull request, including a documentation-only one.

`.github/workflows/go-checks.yml` adds an always-reporting `go` job (gofmt/vet/test/build)
for the executables under `cmd/` and `internal/`, on the same no-path-filter basis. It is
not yet in the required-checks ruleset above; whether it should become required is a
repository-configuration decision left to the owner/orchestrator, not made by this change.

## Commands

PriFly is still in its architecture-to-implementation transition. The current executable
verification surface is the canonical documentation suite, run from the repository root:

| Suite | Command | Environment |
|---|---|---|
| Rationale pointers | `bash scripts/docs/check-pointers.sh --root .` | Repository checkout; Bash, standard Unix tools. |
| ADR index | `bash scripts/docs/adr-index.sh --root . --check` | Repository checkout. |
| Mechanical audit | `bash scripts/docs/audit.sh --root . --out <scratch-path>/gap.md` | Repository checkout; writes an ephemeral gap report outside the repository tree — never commit it. |
| Markdown links/fragments | `bash scripts/docs/check-links.sh --root .` | Repository checkout; Python 3. |
| Link-checker regression tests | `bash scripts/docs/test-check-links.sh` | Repository checkout; Python 3. |
| Sanitize scan | `gitleaks detect --source . --no-banner` | Repository checkout; `gitleaks` binary on `PATH`. Run before every push — this repository is **public**. |
| Integration | No command exists until a runnable integration surface lands. | Not configured. |

These are exactly the five `docs-checks.yml` steps plus the sanitize scan; a manifest's
**Command** field for a docs-only round lists these, in this order, as the log actually
ran them.

The `cmd/prifly` CLI and `cmd/priflyd` controller (issue #57 / A06) add a Go suite, run
from the repository root with a pinned toolchain (see `go.mod`'s `go` directive; do not
rely on a system Go install matching it):

| Suite | Command | Environment |
|---|---|---|
| Format | `gofmt -l .` (expect empty output) | Repository checkout; pinned `go` toolchain on `PATH`. |
| Vet | `go vet ./...` | Same. |
| Unit tests | `go test ./...` (add `-race` when the toolchain/platform supports the race detector) | Same. |
| Build | `go build ./...` (or `go build -o <scratch-path>/bin/ ./...` to avoid writing binaries into the checkout) | Same. |

These are exactly the four `go-checks.yml` steps; a manifest's **Command** field for a
Go-touching round lists these, in this order the log actually ran them, alongside the
docs suite above and the sanitize scan.

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

No runnable application or shared test service exists yet. Future tests must use the
`prifly-<issue-or-attempt>-<run-id>` resource prefix, unique ports, and disposable remote
namespaces. A run removes only its own named resources — see
[maintenance.md](maintenance.md).

## Live testing

Environment-specific recipes belong in untracked `*.local.md` guidance (for example
`docs/testing.local.md`); none is committed. The inputs a live check needs, and the
blocker reported when one is missing, are in [validation.md](validation.md).

Go unit tests, `go vet` and `gofmt` are now real (above) and mirrored in
`.github/workflows/go-checks.yml`. Add exact Go integration and coverage commands in the
same change that makes each real; keep this table and both
`.github/workflows/docs-checks.yml` and `.github/workflows/go-checks.yml` in agreement.
