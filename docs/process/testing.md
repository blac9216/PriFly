# Testing

## Required checks

- `design-docs` — the single required status check on `workflow-main`
  (`gh api repos/blac9216/PriFly/rulesets/23306001`, read live 2026-09-16).

The check is the always-reporting `design-docs` job in
`.github/workflows/docs-checks.yml`. That workflow has no pull-request path filter, so
the check is safe to require on every pull request, including a documentation-only one.

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
| Integration | No command exists until the first executable Factory scaffold lands. | Not configured. |

These are exactly the five `docs-checks.yml` steps plus the sanitize scan; a manifest's
**Command** field for a docs-only round lists these, in this order, as the log actually
ran them.

## Lint state

`not installed — review-only` (`command -v markdownlint` → exit `1`;
`command -v markdownlint-cli2` → exit `1`, checked 2026-09-16). No markdown linter is
part of the documented suite or CI; Markdown structure/link correctness is instead covered
by `check-links.sh` and `check-pointers.sh` above. Whether a given machine has one
installed belongs in `*.local.md` guidance.

## Coverage

none — no coverage command or threshold exists until implementation and a governing
Planning Baseline define them.

## Isolation on a shared host

No runnable application or shared test service exists yet. Future tests must use the
`prifly-<issue-or-attempt>-<run-id>` resource prefix, unique ports, and disposable remote
namespaces. A run removes only its own named resources — see
[maintenance.md](maintenance.md).

## Live testing

Environment-specific recipes belong in untracked `*.local.md` guidance (for example
`docs/testing.local.md`); none is committed. The inputs a live check needs, and the
blocker reported when one is missing, are in [validation.md](validation.md).

Add exact Go unit, integration, `go vet`/lint, coverage, and sanitization commands in the
same change that makes each real; keep this table and `.github/workflows/docs-checks.yml`
in agreement.
