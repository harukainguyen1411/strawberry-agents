## Migrated from swain (2026-04-17)
# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions (recent only)
- 2026-04-18 (azir): Public app-repo migration plan — strawberry/strawberry-app split for unlimited Actions minutes. `plans/proposed/2026-04-19-public-app-repo-migration.md` SHA `c1a0311`.
- 2026-04-13 (subagent, s5): Bee multi-format IO plan — xlsx/pptx/pdf input + output format selection.
- 2026-04-13 (subagent, s4): Feature flags plan — Firebase Remote Config for per-user app visibility.
- 2026-04-13 (subagent, s3): Deploy pipeline hardening plan after blank-page incident.
- 2026-04-13 (subagent, s2): Advisory role on caching-fix deploy team.

## Active Architecture Decisions

- **Two-repo split (2026-04-18, proposed)**: strawberry (private agent-infra) + strawberry-app (public code). Driven by exhausted Actions minutes; Duong won't raise budget. Plan `plans/proposed/2026-04-19-public-app-repo-migration.md` has 7 open decisions in §8 that must be captured before approval. Cross-repo convention: plans stay in strawberry, PRs move to strawberry-app.

- **Feature flags (Remote Config)**: Per-user app visibility via Firebase Remote Config + custom signals. Plan: `plans/approved/2026-04-13-feature-flags-firebase-remote-config.md`. First flag: `bee_visible` gated to Haruka's email.

- **Dark Strawberry platform**: 3-tier roles, `maxAppRequests` per user, `personalMode`. Plan: `plans/proposed/2026-04-12-darkstrawberry-platform-architecture.md`.
- **Dark Strawberry deployment**: Independent deployables, Turborepo, Changesets. Plan: `plans/proposed/2026-04-12-darkstrawberry-deployment-architecture.md`.
- **Deploy pipeline hardening**: Post-incident patch plan. Plan: `plans/proposed/2026-04-13-deploy-pipeline-hardening.md`.
- **Deployment pipeline architecture**: Comprehensive pipeline plan. 12 components, 3 phases. Supersedes the hardening plan. Plan: `plans/proposed/2026-04-13-deployment-pipeline-architecture.md`. Key finding: existing CI/preview/release workflows are more advanced than initially reported (env vars in CI, preview channels, environment protection, deploy tags, changesets). Main gaps: no staging, no smoke tests, no env validation, turbo cache blind to env, duplicate conflicting workflows.
- **Bee multi-format IO**: Input (docx/xlsx/pptx/pdf) + output format selection. Plan: `plans/proposed/2026-04-13-bee-multi-format-io.md`. 3 phases: P0=input parsers, P1=output rendering, P2=polish. Key design: Claude gets pre-extracted text (not raw files), returns intermediate JSON schemas per output type.
- **Deploy caching fix**: IMPLEMENTED 2026-04-13.

## Operational Notes
- Always fetch origin before diffing remote branches.
- Plans go directly to main, not via PR — use `chore:` prefix.
- Opus agents never implement — write plan, report to Evelynn, stop.
- Never assign implementers in plans.

## Feedback
- If Evelynn over-specifies, trust your own skills and docs first.
- Evelynn sometimes sends duplicate requests for work already done — verify current state before re-doing.
