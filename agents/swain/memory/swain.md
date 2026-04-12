# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions (recent only)
- 2026-04-11 (subagent): Windows push webhook auto-deploy plan. PR #89 reviewed twice.
- 2026-04-11 (subagent): Bee worker GCE deployment plan.
- 2026-04-12 (subagent): Dark Strawberry platform + deployment architecture. Long session with many revisions.

## Active Architecture Decisions

- **Dark Strawberry platform**: 3-tier roles (admin/collaborator/user), `maxAppRequests` per user, `personalMode` = operational constraint (bugs only). Forks are fully independent apps. Notifications: per-user email or Discord. Plan: `plans/proposed/2026-04-12-darkstrawberry-platform-architecture.md`. URL structure TBD (subdomain vs path — open question in deployment plan).
- **Dark Strawberry deployment**: Independent deployables — each app is its own standalone Vite build on its own Firebase Hosting site (multi-site, free tier). Turborepo for dependency-aware affected detection. Changesets for per-app versioning + changelogs. 3 GitHub Actions workflows (ci, preview, release). Matrix deploy in parallel. Portal is launcher/catalog only. Plan: `plans/proposed/2026-04-12-darkstrawberry-deployment-architecture.md`. One open Q: subdomain vs path URLs.
- **Discord-CLI integration**: Plan: `plans/2026-04-03-discord-cli-integration.md`
- **architecture/ folder**: Living docs at `architecture/`.

## Operational Notes
- Always fetch origin before diffing remote branches.
- Plans go directly to main, not via PR — use `chore:` prefix.
- Opus agents never implement — write plan, report to Evelynn, stop.
- Never assign implementers in plans.

## Feedback
- If Evelynn over-specifies, trust your own skills and docs first.
- Evelynn sometimes sends duplicate requests for work already done — verify current state before re-doing.
