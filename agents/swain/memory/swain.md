# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions (recent only)
- 2026-04-13 (subagent): Deploy caching fix plan for Dark Strawberry. Root cause: missing Cache-Control on HTML in firebase.json.
- 2026-04-12 (subagent): Dark Strawberry platform + deployment architecture. Long session with many revisions.
- 2026-04-11 (subagent): Windows push webhook auto-deploy plan. PR #89 reviewed twice.

## Active Architecture Decisions

- **Dark Strawberry platform**: 3-tier roles (admin/collaborator/user), `maxAppRequests` per user, `personalMode` = operational constraint (bugs only). Forks are fully independent apps. Notifications: per-user email or Discord. Plan: `plans/proposed/2026-04-12-darkstrawberry-platform-architecture.md`.
- **Dark Strawberry deployment**: Independent deployables — each app is its own standalone Vite build on its own Firebase Hosting site (multi-site, free tier). Turborepo for dependency-aware affected detection. Changesets for per-app versioning + changelogs. Plan: `plans/proposed/2026-04-12-darkstrawberry-deployment-architecture.md`.
- **Deploy caching fix**: firebase.json missing Cache-Control on HTML files → 1h stale cache. Fix: `no-cache` on HTML, `immutable` on hashed assets. Plan: `plans/approved/2026-04-13-deploy-caching-fix.md`.

## Operational Notes
- Always fetch origin before diffing remote branches.
- Plans go directly to main, not via PR — use `chore:` prefix.
- Opus agents never implement — write plan, report to Evelynn, stop.
- Never assign implementers in plans.

## Feedback
- If Evelynn over-specifies, trust your own skills and docs first.
- Evelynn sometimes sends duplicate requests for work already done — verify current state before re-doing.
