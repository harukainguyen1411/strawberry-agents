# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions (recent only)
- 2026-04-13 (subagent, s3): Deploy pipeline hardening plan after blank-page incident. Plan at plans/proposed/2026-04-13-deploy-pipeline-hardening.md.
- 2026-04-13 (subagent, s2): Advisory role on caching-fix deploy team. Deploy completed successfully.
- 2026-04-13 (subagent): Deploy caching fix plan for Dark Strawberry. Root cause: missing Cache-Control on HTML in firebase.json.
- 2026-04-12 (subagent): Dark Strawberry platform + deployment architecture. Long session with many revisions.

## Active Architecture Decisions

- **Dark Strawberry platform**: 3-tier roles, `maxAppRequests` per user, `personalMode`. Plan: `plans/proposed/2026-04-12-darkstrawberry-platform-architecture.md`.
- **Dark Strawberry deployment**: Independent deployables, Turborepo, Changesets. Plan: `plans/proposed/2026-04-12-darkstrawberry-deployment-architecture.md`.
- **Deploy pipeline hardening**: Post-incident patch plan. Plan: `plans/proposed/2026-04-13-deploy-pipeline-hardening.md`.
- **Deployment pipeline architecture**: Comprehensive pipeline plan. 12 components, 3 phases. Supersedes the hardening plan. Plan: `plans/proposed/2026-04-13-deployment-pipeline-architecture.md`. Key finding: existing CI/preview/release workflows are more advanced than initially reported (env vars in CI, preview channels, environment protection, deploy tags, changesets). Main gaps: no staging, no smoke tests, no env validation, turbo cache blind to env, duplicate conflicting workflows.
- **Deploy caching fix**: IMPLEMENTED 2026-04-13.

## Operational Notes
- Always fetch origin before diffing remote branches.
- Plans go directly to main, not via PR — use `chore:` prefix.
- Opus agents never implement — write plan, report to Evelynn, stop.
- Never assign implementers in plans.

## Feedback
- If Evelynn over-specifies, trust your own skills and docs first.
- Evelynn sometimes sends duplicate requests for work already done — verify current state before re-doing.
