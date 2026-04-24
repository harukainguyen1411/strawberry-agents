---
date: 2026-04-24
concern: work
kind: residuals-and-followups
source_plan: plans/proposed/work/2026-04-24-s2-patch-drift-deploy-hygiene.md
---

# Deploy-hygiene residuals — deferred from the S2 PATCH-drift plan

Per Duong's 2026-04-24 directive to keep the S2 PATCH-drift plan minimal, the following items were pruned from scope and parked here as explicit follow-ups. They are *not* in-flight work — they are risk we are knowingly carrying until someone picks them up.

## Pruned items

1. **Peer-tool deploy.sh sweep.** Only `demo-config-mgmt/deploy.sh` is hardened in this PR. The other six `tools/*/deploy.sh` scripts (`demo-dashboard`, `demo-factory`, `demo-preview`, `demo-studio-mcp`, `demo-studio-v3`, `demo-verification`) use the same `gcloud run deploy --source .` shape and are susceptible to identical dirty-tree drift. Exposure: whoever runs any of these deploys with uncommitted local changes ships those changes without the code being in git. Inert until it isn't. Follow-up: one PR covering all 6 with the same guard + `--labels=git-sha=...` stamp as demo-config-mgmt.

2. **Negative-regression xfail for the stripped PATCH handler.** The original Karma plan included a `test_patch_removed.py` asserting `PATCH /v1/config/{sid}` returns 405 once the handler is gone. Dropped because we do not usually write tests that assert dead code stays dead. Exposure: someone could re-introduce a PATCH handler in a future refactor without anyone noticing. Low — the caller-side POST+RMW workaround from PR #87 would silently no-op the new handler, making the re-introduction visible via an obvious contract drift.

3. **Static-text smoke test for the deploy guard.** Dropped the `test_deploy_guard.py` that asserted `deploy.sh` contains `git status --porcelain` and `--labels=git-sha=` literal tokens. Exposure: someone could silently revert the guard without a signal. Low — every deploy would still succeed, but the next drift would be observable and the git history would show the revert.

4. **SSE schema-additivity contract test (W3 config-architecture, OQ-K2).** The W3 leg of the config-architecture ADR adds a `configVersion` field to SSE events. The original proposal included a `tests/test_sse_schema_compat.py` contract test asserting both producer and consumer tolerate unknown additive fields. Dropped in favor of documenting schema-additivity in the ADR prose only. Exposure: future W4/W5 SSE schema additions could break strict-parsing consumers and the failure mode would be a runtime exception mid-stream, not a test failure. Medium. Follow-up: revisit before the next SSE field lands, or when a consumer breakage is actually observed.

## Principle

Every item here is a known unknown — a risk we have decided to carry rather than spend engineering time on preemptively. If any of these follow-ups reach the top of the queue on their own merits, pick them up then. Until that point, this file is the audit trail.

## Pointers

- S2 plan (slimmed): `plans/proposed/work/2026-04-24-s2-patch-drift-deploy-hygiene.md`
- Observed drift: deployed `demo-config-mgmt-00014-2bn` vs local `tools/demo-config-mgmt/main.py` PATCH handler
- Caller-side workaround: PR #87 (merged)
- W3 config-architecture ADR: `plans/in-progress/work/2026-04-23-demo-studio-config-architecture.md`
