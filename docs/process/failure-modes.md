# Repo-specific failure modes

General workflow failure modes live in the canonical `github-workflow` skill. These have
already occurred in PriFly:

- **Project scope missing from the active owner token** — repository API calls succeeded,
  but Project inspection failed. Guard: verify `gh auth status` includes `project` before
  changing Project fields or views.
- **Planning metadata predates the canonical label set** — the initial backlog used
  `priority:p0`, `priority:p1`, and `size:*`. Guard: run the configure-workflow label audit
  before dispatch and keep issue size in the issue's Estimate section.
- **Planned issues exist outside the Project** — connector-created issues initially had no
  Project item. Guard: maintenance audits every open issue for Project membership.

