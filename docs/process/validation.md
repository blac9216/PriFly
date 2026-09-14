# Live validation

PriFly has no executable or deployed Factory stack yet. Current pull requests can prove
documentation and repository configuration, but they cannot claim runtime durability,
provider, recovery, security, planning, or end-to-end product conformance.

When implementation introduces a runnable stack, define the exact live systems,
read-only versus mutating operations, evidence paths, admitted dependency versions, and
zero-workaround conditions here or in the governing Planning Baseline before using live
results as acceptance evidence. Use a batch threshold of five `pending-live` merges once
live validation exists.

Evidence belongs in the session scratch directory outside the repository. Credentials
are supplied through the `with-secrets` skill, with environment inventory and current
authorization recorded in `*.local.md` guidance.

