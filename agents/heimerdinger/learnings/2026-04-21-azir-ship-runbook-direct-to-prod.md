# 2026-04-21 — Azir ship runbook refresh + secrets audit (direct-to-prod)

## Context
Evelynn brief: refresh ship-day checklist for Azir god plan (demo-studio v2) and produce a secrets audit companion. Mid-task Duong clarified: **no separate staging environment exists** — `demo-studio-staging` is a Firestore DB name on the same `mmpt-233505` project, not a deployment environment. Rewrote runbook for single-pass direct-to-prod.

## Key findings

1. **Single-project model.** All three services (`demo-studio`, `demo-factory`, `demo-preview`) deploy to `mmpt-233505/europe-west1`. No stg vs prod split. Rule 17 relaxed to single-environment smoke with blast-radius rationale (internal demo tool, no external users).

2. **Service-name drift (G1).** `tools/demo-studio-v3/deploy.sh` deploys under `SERVICE=demo-studio`, not `demo-studio-v3`. All `gcloud` commands must target `demo-studio`.

3. **Rollback script coverage (G2).** Only rollback.sh in workspace is `company-os-ship-day/tools/demo-studio-v3/scripts/rollback.sh`, hardcoded to S1. S3/S5 rollback is manual `gcloud run services update-traffic`. Recommended generalizing to take `$SERVICE` arg.

4. **Secret-name convention drift (G7).** S1 uses `DS_SHARED_*` (uppercase_underscore); S3/S5 use `ds-shared-*` (lowercase-hyphen). These are two distinct Secret Manager objects per logical secret. Unification is follow-up work.

5. **S3 lacks INTERNAL_SECRET (G6).** Zero `INTERNAL_SECRET` / `X-Internal-Secret` references in current `tools/demo-factory/*.py` HEAD. If PR #61 adds the header-auth surface on S3 inbound, S3's `deploy.sh` must bind the existing `DS_SHARED_INTERNAL_SECRET` — no new secret needed, just IAM + binding.

6. **Zero new secrets for this ship.** Every env-var in Wave 2 resolves to either an already-provisioned secret or a non-secret flag/URL.

## Output paths (absolute)

- `/Users/duongntd99/Documents/Personal/strawberry-agents/assessments/ship-day-azir-option-a-checklist-2026-04-21.md` (runbook refresh #3)
- `/Users/duongntd99/Documents/Personal/strawberry-agents/assessments/ship-day-azir-secrets-audit-2026-04-21.md` (audit companion)
- Commit: `76ad802`

## Pattern reinforced

When Rule 17 says "stg + prod smoke", check the actual environment topology before sequencing. On single-project workloads, the rule's spirit (post-deploy smoke + auto-rollback on failure) still applies — just collapsed to one pass. Always cite the relaxation rationale in the runbook preamble so future readers don't over-interpret the rule.
