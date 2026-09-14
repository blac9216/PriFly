# Testing

## Required checks

- `design-docs`

The check is the always-reporting `design-docs` job in
`.github/workflows/docs-checks.yml`. The workflow has no pull-request path filter, so the
check is safe to require on every pull request.

## Commands

PriFly is still in its architecture-to-implementation transition. The current executable
verification surface is the canonical documentation suite:

| Suite | Command | Environment |
|---|---|---|
| Documentation checks | `bash scripts/docs/check-pointers.sh --root . && bash scripts/docs/adr-index.sh --root . --check && bash scripts/docs/audit.sh --root . --out /tmp/prifly-design-doc-gap.md && bash scripts/docs/check-links.sh --root .` | Repository checkout; Bash, Python 3, and standard Unix tools. |
| Integration | No command exists until the first executable Factory scaffold lands. | Not configured. |
| Lint | `bash scripts/docs/check-links.sh --root .` | Repository checkout. |
| Coverage | No command or threshold exists until implementation and a governing Planning Baseline define them. | Not configured. |
| Sanitize scan | No repository-specific command exists yet. | Review diffs for secrets and sensitive identifiers before push. |

Add exact Go unit, integration, vet/lint, coverage, and sanitization commands in the same
change that makes each command real. Any required CI check must always report on every
pull request.

## Isolation on a shared host

No runnable application or shared test service exists yet. Future tests must use the
`prifly-<issue-or-attempt>-<run-id>` resource prefix, unique ports and disposable remote
namespaces. A run removes only its own named resources.

## Live testing

Environment-specific recipes belong in `docs/testing.local.md`, which is untracked.

