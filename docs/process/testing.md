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
| Go archive digest agreement | `bash scripts/docs/check-go-digest.sh --root .` | Repository checkout; Bash, standard Unix tools. Fails unless the Go toolchain row of the dependency inventory restates exactly `GO_ARCHIVE_SHA256` from `go-checks.yml`; a missing, repeated or malformed value in either file fails. |
| Go digest checker regression tests | `bash scripts/docs/test-check-go-digest.sh` | Repository checkout; Bash, standard Unix tools; mutates only scratch copies of the two files. |
| Readiness-checker regression tests | `bash scripts/process/test-check-readiness.sh` | Repository checkout; Bash, Python 3. |
| Early-probe preflight self-test | `bash scripts/qualification/early/test-preflight.sh` | Repository checkout; Bash, Python 3; no network. Cases plus a mutant pass over scratch copies of `preflight.sh` and its schema under `${TMPDIR:-/tmp}`. |
| Sanitize scan | `gitleaks detect --source . --no-banner` | Repository checkout; `gitleaks` binary on `PATH`. Run before every push — this repository is **public**. |
| Integration | No command exists until a runnable integration surface lands. | Not configured. |

These are exactly the nine `docs-checks.yml` steps plus the sanitize scan; a manifest's
**Command** field lists these (and the Go suite below, if Go changed) in the order the
log actually ran them.

Go suite (`cmd/`, `internal/`): exactly the steps of the always-reporting, not-yet-required
`go` job in `.github/workflows/go-checks.yml`, same order and flags, followed in that job by
the qualification local proofs below.

Toolchain: CI and the local recipe install the same go.dev archive and check it against
the same digest. Both values are pinned once, as `GO_ARCHIVE` and `GO_ARCHIVE_SHA256` on
the `go` job's install step in `go-checks.yml`. That step fails unless the runner is
Linux x86-64, the archive name matches `go.mod`'s `go` directive, and `sha256sum -c`
accepts the download. Only then does it extract the archive and put its `go/bin` first
on `PATH`. CI does not use `actions/setup-go`. Locally, on Linux x86-64, from the
repository root:

```sh
GO_ARCHIVE=$(sed -n 's/^ *GO_ARCHIVE: //p' .github/workflows/go-checks.yml) &&
GO_ARCHIVE_SHA256=$(sed -n 's/^ *GO_ARCHIVE_SHA256: //p' .github/workflows/go-checks.yml) &&
curl -fsSL --proto '=https' --proto-redir '=https' -o "<scratch-path>/$GO_ARCHIVE" "https://go.dev/dl/$GO_ARCHIVE" &&
(cd <scratch-path> && echo "$GO_ARCHIVE_SHA256  $GO_ARCHIVE" | sha256sum -c -) &&
tar -C <scratch-path> -xzf "<scratch-path>/$GO_ARCHIVE"
```

The commands are one `&&` chain, so the block fails closed whether it is pasted or run as a
script: a digest that is not the pinned one makes `sha256sum -c` exit 1, the chain stops
before `tar`, nothing is extracted and the block exits 1. Otherwise
put `<scratch-path>/go/bin` first on `PATH` and export `GOTOOLCHAIN=local` and
`GOFLAGS=-mod=readonly`. The recipe checks the pinned digest, not a live read of the
go.dev index. No digest is pinned for any other OS or architecture. The Go toolchain row
of the dependency inventory in [source-register.md](../reference/source-register.md)
restates both values as the identity it dispositions; the workflow is the source of truth,
and `check-go-digest.sh` above fails the documentation suite if the row's digest differs.
To bump Go, change `go.mod`, `GO_ARCHIVE`, `GO_ARCHIVE_SHA256` and that inventory row in
one change, taking the new digest from `https://go.dev/dl/?mode=json&include=all`.

| Suite | Command | Environment |
|---|---|---|
| Identity | `git rev-parse HEAD`, then `command -v go`, `go version`, `go env GOROOT` | Checkout; pinned `go` first on `PATH`; `git` and an OpenSSH client (`ssh`) on `PATH`, which the `internal/bootstrap` tests run and fail without. Their versions are UNKNOWN pins owned by Q01 (#109). |
| Modules | `go mod verify` | Same; checks downloaded modules, including CI's restored module cache, against `go.sum`. |
| Format | `test -z "$(gofmt -l .)"` | Same; exits 1 if any file is unformatted. |
| Vet | `go vet ./...` | Same. |
| Unit tests | `go test -count=1 -race -v ./...` | Same; uncached; `-race` needs cgo. |
| Build | `go build ./...` | Same; keeps no binaries (add `-o <dir>/` to keep them). |

Qualification local proofs, the last steps of the same `go` job, in this order. They use
fakes and crafted traces only: no harness, provider, credential, network or engine, and
none is a live PASS.

| Suite | Command | Environment |
|---|---|---|
| Runner namespace setting | `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0` | CI only, on the disposable GitHub-hosted runner, whose AppArmor setting otherwise makes `unshare -r` fail (`write failed /proc/self/uid_map: Operation not permitted`). Do not run it on a shared or development host; there, the probe below shows whether the host already allows namespaces. |
| Namespace probe | `unshare -rm mount -t tmpfs none /tmp` | Linux with unprivileged user and mount namespaces; the mount exists only inside the namespace. Exits non-zero where the host denies them (for example an AppArmor user-namespace restriction), and the job fails rather than skipping the harness proof. |
| Evaluator vet | `go vet scripts/qualification/early/result.go` | Pinned `go` first on `PATH`; `result.go` is `//go:build ignore`, so `go vet ./...` skips it. |
| Evaluator proof | `bash tests/qualification/early_harness/test-result.sh` | Same; `jq`. Builds `result.go` under `${TMPDIR:-/tmp}`; prints one `ok` line per case and `failures: 0`. |
| Harness proof | `bash tests/qualification/early_harness/test-harness.sh` | Same; `python3`, `setsid`, `pgrep`, the `en_US.UTF-8` locale, and the namespaces above; `TMPDIR` with no upper case (#240). Prints one `ok` line per check and `failures: 0`. |

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
keep these tables, `docs-checks.yml`, `go-checks.yml` and the `## CI` step list in
[doc-manifest.md](../doc-manifest.md) in agreement.
