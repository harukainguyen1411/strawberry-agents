# Azir (Architecture Specialist — migrated from swain 2026-04-17)

## Sessions
- 2026-04-19 (azir): Per-subagent-per-task attribution ADR extending the usage dashboard — `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md`. Key finding: SubagentStop hook has NO usage fields (verified), but the harness already writes `subagents/agent-<id>.{jsonl,meta.json}` with full `usage` blocks + `agentType` + `description`. Chosen: scanner over `subagents/` dir on existing cron. Rejected: SubagentStop-hook-capture, end-session-sidecar. `description` field is task handle. Schema splits cache_read out of total. 7 open Qs for Duong.
- 2026-04-19 (azir): Claude Code usage dashboard ADR — `plans/proposed/2026-04-19-claude-usage-dashboard.md` commit `a6cd887`. v1 = static HTML local-only, wraps `ccusage -j`, adds agent-scan.mjs for per-roster attribution (the wedge vs. ccusage/Reddit dashboard). Key finding: Strawberry agents run as top-level sessions — no `isSidechain`, no Task tool — so attribution comes from first-user-message regex (`Hey X` / `[autonomous] X,` / `You are X`). 7 open questions for Duong.
- 2026-04-19 (azir): Companion ADR for strawberry-agents private-infra split — `plans/proposed/2026-04-19-strawberry-agents-companion-migration.md`. Mid-flight rename from dark-strawberry → strawberry-agents. Three-repo end state. D1-D10 open decisions for Duong. Only disagreement with brief: 90-day archive window (not 7).
- 2026-04-18 (azir): Testing-dashboard Phase 1 review session — architecture-reviewed 16 PRs, self-amended ADR §9 (dropped firebaseauth.admin) + §7 (UID redaction + fail-closed) in `3c0dc77`. Zero open holds at close.
- 2026-04-18 (azir): Public app-repo migration plan — `plans/proposed/2026-04-19-public-app-repo-migration.md` SHA `c1a0311`. Now promoted to approved/.
- 2026-04-13 (s5): Bee multi-format IO plan.
- 2026-04-13 (s4): Feature flags — Firebase Remote Config for per-user app visibility.
- 2026-04-13 (s3): Deploy pipeline hardening post-incident.

## Active Architecture Decisions
- **Test dashboard (approved, partially implemented)**: One Cloud Run service, two Vite+React frontends at `dashboards/server`, `/test-dashboard`, reserved `/dashboard` for monitoring. ADR: `plans/approved/2026-04-17-test-dashboard-architecture.md`. §9 amended 2026-04-18 to drop `firebaseauth.admin` (verifyIdToken is public-JWK). §7 fail-closed on empty ALLOWED_UIDS.
- **Three-repo split (approved + proposed)**: `strawberry-agents` (private agent brain, proposed companion ADR 2026-04-19) + `strawberry-app` (public code, approved 2026-04-19) + `Duongntd/strawberry` (archive, 90-day retention). Plans live in strawberry-agents; PRs live in strawberry-app. All three under `harukainguyen1411` for unified agent-account identity except the archive.
- **Feature flags (Remote Config, approved)**: Per-user via Firebase Remote Config + custom signals. First flag `bee_visible` gated to Haruka.
- **Dark Strawberry platform (proposed)**: 3-tier roles, `maxAppRequests`, `personalMode`.
- **Dark Strawberry deployment (proposed)**: Independent deployables, Turborepo, Changesets.
- **Deployment pipeline architecture (proposed)**: 12 components, 3 phases. Supersedes deploy-pipeline-hardening.
- **Bee multi-format IO (proposed)**: Input docx/xlsx/pptx/pdf + output format selection. Claude gets extracted text, returns JSON schemas per output type.

## Key Knowledge
- **Subagent attribution data path**: `~/.claude/projects/<slug>/<session>/subagents/agent-<id>.jsonl` has full per-turn `usage` blocks; sibling `.meta.json` has `{agentType, description}`. SubagentStop hook payload has NO usage fields — always reach for on-disk JSONL for token attribution, not the hook.
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

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
