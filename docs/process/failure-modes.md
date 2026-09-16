# Repo-specific failure modes

General workflow failure modes live in the canonical `github-workflow` skill's own
`failure-modes.md`; this file holds only failure modes actually observed in this
repository.

- **Project scope missing from the active owner token** — repository API calls can
  succeed while Project field/board inspection fails silently. Guard: run
  `gh auth status` and confirm `project` is listed among the active account's token
  scopes before changing Project fields or views (verified present for both
  `blac9216` and `machine-blac9216` on 2026-09-16 — recheck after any credential
  rotation).
- **Planning metadata predates the canonical label set** — an earlier backlog iteration
  used ad hoc size/priority values before `configure-workflow`'s label set was
  provisioned. Guard: read [labels.md](labels.md) and `gh label list` directly before
  trusting an issue's own label text, and keep issue size in the issue's own Estimate
  section as the fallback source.
- **No distinct reviewer identity is configured** — see
  [work-tracking.md](work-tracking.md)'s "Known identity limitation": the
  `workflow-main` ruleset requires zero approving reviews, lets the Admin role bypass it
  always, and both configured accounts share `project`/`repo` scope, so `author ≠ merger`
  is a role-separation and review-record convention today, not a GitHub-enforced identity
  check (follow-up [#123](https://github.com/blac9216/PriFly/issues/123)). Guard: never
  treat a passing required check alone as proof of independent review; check the PR's
  own review/comment history for a distinct-round Reviewer verdict.
