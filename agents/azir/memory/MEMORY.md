# Azir (Architecture Specialist — migrated from swain 2026-04-17)

## Sessions
- 2026-04-18 (azir): Testing-dashboard Phase 1 review session — architecture-reviewed 16 PRs, self-amended ADR §9 (dropped firebaseauth.admin) + §7 (UID redaction + fail-closed) in `3c0dc77`. Zero open holds at close.
- 2026-04-18 (azir): Public app-repo migration plan — `plans/proposed/2026-04-19-public-app-repo-migration.md` SHA `c1a0311`.
- 2026-04-13 (s5): Bee multi-format IO plan.
- 2026-04-13 (s4): Feature flags — Firebase Remote Config for per-user app visibility.
- 2026-04-13 (s3): Deploy pipeline hardening post-incident.

## Active Architecture Decisions
- **Test dashboard (approved, partially implemented)**: One Cloud Run service, two Vite+React frontends at `dashboards/server`, `/test-dashboard`, reserved `/dashboard` for monitoring. ADR: `plans/approved/2026-04-17-test-dashboard-architecture.md`. §9 amended 2026-04-18 to drop `firebaseauth.admin` (verifyIdToken is public-JWK). §7 fail-closed on empty ALLOWED_UIDS.
- **Two-repo split (proposed)**: strawberry (private) + strawberry-app (public) for Actions minutes. 7 open §8 decisions. Plans stay in strawberry; PRs move to strawberry-app.
- **Feature flags (Remote Config, approved)**: Per-user via Firebase Remote Config + custom signals. First flag `bee_visible` gated to Haruka.
- **Dark Strawberry platform (proposed)**: 3-tier roles, `maxAppRequests`, `personalMode`.
- **Dark Strawberry deployment (proposed)**: Independent deployables, Turborepo, Changesets.
- **Deployment pipeline architecture (proposed)**: 12 components, 3 phases. Supersedes deploy-pipeline-hardening.
- **Bee multi-format IO (proposed)**: Input docx/xlsx/pptx/pdf + output format selection. Claude gets extracted text, returns JSON schemas per output type.

## Key Knowledge
- **Stale-view discipline**: always `gh api repos/.../pulls/<n> --jq '.head.sha'` before re-reviewing. Cached `gh pr view` output burned real cycles. Standing rule adopted: "architecture LGTM extends to future tips absent architectural changes."
- **Silent-defeat classes in TDD pipeline**: vitest `exclude: ["**/*.xfail.test.ts"]` glob, `it.failing` (Playwright) vs `it.fails` (Vitest), `git add -A` contamination in shared worktree. All three seen this workstream.
- **Firebase Admin SDK verifyIdToken needs NO IAM role** — public JWK verification. Don't grant firebaseauth.admin.

## Operational Notes
- Fetch origin before diffing remote branches.
- Plans direct to main via `plan-promote.sh`, never PR. `chore:` prefix.
- Opus agents never implement — plan, report, stop.
- Commit only explicit `agents/azir/**` paths; never `git add -A`.

## Feedback
- Trust own skills/docs first when coordinators over-specify.
- Coordinators sometimes send duplicate requests — verify current state before re-doing.
- Non-blocker hygiene asks (dead code, filename cosmetics) are fine as follow-up PRs — don't hold merges for them.
