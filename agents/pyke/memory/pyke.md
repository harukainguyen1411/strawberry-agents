# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 AM (CLI, opus-4.6): Set up git workflow, created 4 PRs, designed ops separation with Syndra.
- 2026-04-03 PM (CLI, opus-4.6): Main branch audit + housekeeping execution. PR #8 created.
- 2026-04-03 late PM (CLI, opus-4.6): Main audit for memory commits + monorepo migration analysis + plan.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main (except agent state).
  **Why:** Duong wanted PR discipline so nothing gets lost.
- Ops separation (Option 3b): ephemeral files (inbox, conversations, health) → ~/.strawberry/ops/. Durable files (memory, learnings) stay in git.
  **Why:** Ephemeral ops files cause conflicts during branch switches. Separate by lifespan, not type.
- Journal/ and last-session.md → gitignored. Not in git, not in ops (stay local).
  **Why:** High churn, no git value. Cuts session noise from ~20 files to ~6.
- Agent memory commits: direct to main, no PRs. Prefix `chore(agent):`. Pull --rebase before commit.
  **Why:** Files are agent-scoped (no overlap), PRs add zero review value for internal state.
- Memory commit responsibility: Evelynn sweeps and commits all agent memory after sessions end.
  **Why:** Individual agents weren't committing during session close. Single sweeper is simpler.
- Monorepo migration: git filter-repo into apps/myapps/, Firebase config stays in app dir.
  **Why:** Preserves full history with clean blame. Option A (app-scoped Firebase) avoids root pollution.

## Open items
- PR #8 (migrate-ops-improvements) ready to merge
- Chore commit on main needs push to origin
- 7 remote merged branches to delete
- Branch protection on main — needs Duong manual GitHub config
- Monorepo migration plan at plans/2026-04-03-myapps-monorepo-migration.md — awaiting decision

## Working relationships
- Syndra: sharp, principled. Good design partner for architecture decisions.
- Lissandra: thorough reviewer. Approved PR #8 with clean observations.
- Evelynn: coordinator. Reports go to her.
