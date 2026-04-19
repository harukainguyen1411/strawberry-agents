# Azir (Architecture Specialist — migrated from swain 2026-04-17)

## Sessions
- 2026-04-19 (azir, late): Amended subagent-attribution ADR — folded Duong's 7 resolutions inline (Resolved-2026-04-19 annotations), added D9 for `closed_cleanly` + SubagentStop hook sentinel persistence into `~/.claude/strawberry-usage-cache/subagent-sentinels/`, then split into v1 capture / v2 dashboard phases with explicit accepted-risk note. Commits `61bef3b`, `a4265f0`. Stays in proposed/.
- 2026-04-19 (azir): Per-subagent-per-task attribution ADR extending the usage dashboard — `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md`. Key finding: SubagentStop hook has NO usage fields (verified), but the harness already writes `subagents/agent-<id>.{jsonl,meta.json}` with full `usage` blocks + `agentType` + `description`. Chosen: scanner over `subagents/` dir on existing cron. Rejected: SubagentStop-hook-capture, end-session-sidecar. `description` field is task handle. Schema splits cache_read out of total. 7 open Qs for Duong.
- 2026-04-19 (azir): Claude usage dashboard ADR (`a6cd887`) + subagent-attribution extension + strawberry-agents companion-migration ADR. All stayed in proposed/ for Duong review.

## Active Architecture Decisions
- **Test dashboard (approved, partially implemented)**: One Cloud Run service, two Vite+React frontends at `dashboards/server`, `/test-dashboard`, reserved `/dashboard` for monitoring. ADR: `plans/approved/2026-04-17-test-dashboard-architecture.md`. §9 amended 2026-04-18 to drop `firebaseauth.admin` (verifyIdToken is public-JWK). §7 fail-closed on empty ALLOWED_UIDS.
- **Three-repo split (approved + proposed)**: `strawberry-agents` (private agent brain, proposed companion ADR 2026-04-19) + `strawberry-app` (public code, approved 2026-04-19) + `Duongntd/strawberry` (archive, 90-day retention). Plans live in strawberry-agents; PRs live in strawberry-app. All three under `harukainguyen1411` for unified agent-account identity except the archive.
- **Deployment pipeline architecture (proposed)**: 12 components, 3 phases. Supersedes deploy-pipeline-hardening.
- **Usage dashboard subagent-task attribution (proposed)**: v1 capture (hook sentinel + scanner + `subagents.json`) + v2 dashboard UI (Panel 5). `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md`.

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
- Trust own skills/docs first when coordinators over-specify; verify current state before re-doing duplicate requests; non-blocker hygiene asks are follow-up PRs.

## Archive Note
Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
