---
title: Peer deploy.sh hardening sweep — dirty-tree guard + git-sha stamp on 6 peer tools
status: in-progress
concern: work
complexity: quick
owner: karma
tests_required: true
orianna_gate_version: 2
created: 2026-04-25
---

## Context

PR #103 (merged) hardened `tools/demo-config-mgmt/deploy.sh` against the S2 PATCH-drift incident by (a) refusing to deploy from a dirty working tree, and (b) stamping the deployed Cloud Run revision with `--labels=git-sha=<short-sha>` so ops can always map a live revision back to a commit. Six sibling `deploy.sh` scripts in the `missmp/company-os` repo still lack both guards: `demo-dashboard`, `demo-factory`, `demo-preview`, `demo-studio-mcp`, `demo-studio-v3`, `demo-verification`.

T.P1.14 is the 100% traffic prod push of S1 + S3, imminent once T.P1.13b lands. `demo-studio-v3` and `demo-factory` are on that critical path; deploying either from a dirty tree would recreate the exact drift mode we just fixed. Residual is tracked in `assessments/work/2026-04-24-deploy-hygiene-residuals.md` §1. Close it now, in one PR, before T.P1.14.

Scope is intentionally narrow: transplant the reference block from `demo-config-mgmt/deploy.sh` verbatim into each of the 6 peers, preserving each script's existing service-specific env/secret wiring. Error-message shape is identical across all 6 so ops sees one guard-failure contract. No refactor, no shared helper — this is a sweep, not an abstraction exercise. Rule 4 applies: plan commits on `main`; implementation (all 6 files in `missmp/company-os`) goes through one PR.

## Reference implementation

File: `tools/demo-config-mgmt/deploy.sh` in `missmp/company-os`, merged via PR #103. The load-bearing lines are 8-15 and the `--labels=git-sha="${GIT_SHA}"` flag appended to the `gcloud run deploy` invocation:

```
if [ -n "$(git status --porcelain)" ] && [ "${FORCE_DIRTY:-0}" != "1" ]; then
    echo "deploy.sh: refuse to deploy from dirty working tree. Offending files:" >&2
    git status --porcelain >&2
    echo "Commit, stash, or re-run with FORCE_DIRTY=1 for explicit local-only debugging." >&2
    exit 1
fi
GIT_SHA=$(git rev-parse --short=12 HEAD)
[ "${FORCE_DIRTY:-0}" = "1" ] && GIT_SHA="${GIT_SHA}-dirty"
```

Talon: read the merged file directly. Do not re-derive. The block above is the contract; the literal tokens `git status --porcelain` and `--labels=git-sha=` are what the xfail test asserts on.

## Tasks

- T1 — kind: test, estimate_minutes: 15, files: `tools/_scripts/test_deploy_hygiene.sh` (new) <!-- orianna: ok -->. Detail: write a shell test that, for each of the 6 peer scripts listed under `tools/` (demo-dashboard, demo-factory, demo-preview, demo-studio-mcp, demo-studio-v3, demo-verification), asserts the presence of both literal tokens: `git status --porcelain` and `--labels=git-sha=`. Script exits non-zero if any target is missing either token; prints which script and which token. Commit FIRST in xfail state (before T2). DoD: committed on the implementation branch as an xfail-tagged commit referencing this plan slug; CI tdd-gate recognizes it; running the script locally against `main` fails with 6 missing-token reports (12 total missing-token lines expected: 6 x 2).

- T2 — kind: impl, estimate_minutes: 25, files: `tools/demo-dashboard/deploy.sh`, `tools/demo-factory/deploy.sh`, `tools/demo-preview/deploy.sh`, `tools/demo-studio-mcp/deploy.sh`, `tools/demo-studio-v3/deploy.sh`, `tools/demo-verification/deploy.sh`. Detail: insert the reference dirty-tree guard block verbatim immediately before the first `gcloud run deploy` invocation in each script (after any existing `: "${VAR:?...}"` precondition blocks, so the guard runs after input validation but before network I/O). Append `--labels=git-sha="${GIT_SHA}"` as the final flag on each script's `gcloud run deploy` call. Preserve every other line (service name, region, secrets mapping, env-vars flags) untouched. Error-message string must be byte-identical across all 6 to keep the ops-facing guard-failure contract single-shape. DoD: T1 test passes; each script diffs cleanly against reference (guard block is char-for-char identical); `bash -n` parses all 6; manual dry-read confirms `--labels=git-sha=` is on the `gcloud run deploy` line, not a stray continuation.

- T3 — kind: impl, estimate_minutes: 5, files: `assessments/work/2026-04-24-deploy-hygiene-residuals.md`. Detail: mark §1 (the 6-peer-scripts residual) as resolved, linking the PR that lands T2. DoD: residual §1 shows status resolved with PR link; no other sections touched.

## Test plan

Single xfail-first check, authored in T1 and satisfied by T2.

- **Invariant protected**: every Cloud Run `deploy.sh` under `tools/*/` in `missmp/company-os` refuses to deploy from a dirty working tree AND stamps the revision with a `git-sha` label.
- **Shape**: shell script at `tools/_scripts/test_deploy_hygiene.sh` <!-- orianna: ok --> iterates the 6 target scripts, `grep -q` for each of the two literal tokens per file, aggregates failures, exits non-zero on any miss with a line-per-miss report.
- **xfail-first**: T1 commit lands the test with all 6 targets still unpatched — script exits 1 with 12 missing-token lines. This is the xfail state. T2 commits make the test green.
- **CI wiring**: the script is picked up by the existing `tdd-gate.yml` convention (shell tests under `tools/_scripts/test_*.sh`); no new workflow file needed. Talon: if that convention does not in fact auto-discover, add a one-line invocation to the existing CI job rather than creating a new workflow.

Out of scope for this plan (explicit non-goals):
- No extraction of a shared `_deploy_guard.sh` helper. Six independent transplants is the correct granularity for this sweep; any abstraction is a separate follow-up.
- No change to `gcloud` auth, project, region, or any service-specific flag.
- No change to `demo-config-mgmt/deploy.sh` (already hardened).
- No change to non-Cloud-Run `tools/*/deploy.sh` peers if any exist (all 6 targets above are Cloud Run).

## References

- `assessments/work/2026-04-24-deploy-hygiene-residuals.md` §1 — residual this plan closes.
- `tools/demo-config-mgmt/deploy.sh` in `missmp/company-os` (PR #103 merged) — reference implementation.
- CLAUDE.md Rule 4 — plans go direct to main; implementation goes through a PR.
- CLAUDE.md Rules 12 & 14 — xfail-first TDD gate, pre-commit hook enforcement.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (karma), concrete sized tasks with per-task DoD, `tests_required: true` is honored by T1 as an explicit xfail-first shell test asserting the two literal tokens across all 6 peer scripts, and no TBDs or unresolved decisions remain in gating sections. Reference implementation is cited verbatim with load-bearing tokens identified so Talon cannot re-derive drift. Non-goals are explicit — notably the deliberate refusal to extract a shared helper, which correctly keeps the sweep at the right granularity. Urgency is legitimate: closes assessment residual §1 ahead of T.P1.14 prod push on the demo-studio-v3 critical path.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → in-progress
- **Rationale:** Tasks are actionable with explicit file paths and per-task DoD. T1 delivers the required xfail-first shell test (asserting literal `git status --porcelain` and `--labels=git-sha=` tokens across the 6 peer scripts) satisfying the `tests_required: true` contract before T2 impl. T2 specifies verbatim-transplant semantics with a byte-identical error-message requirement so the ops guard-failure shape stays single-contract. T3 is trivial residual bookkeeping. Sona has accepted the approved plan and is dispatching Talon; moving to in-progress is a pure coordinator phase hop.
