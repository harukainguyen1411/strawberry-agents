# 2026-04-20 — Agent-OS unification day

Process learnings from migrating workspace agent-OS into strawberry-agents.

## Always verify .gitignore before `git add -A`
Workspace uses a deny-all gitignore (`*` + allowlist of tracked paths). `git add -A` appears to respect this, but once files are force-staged or committed, a later `git reset --hard origin/main` deletes them from the working tree because they don't exist in the remote. Today this wiped 25 agent defs + 25 memory folders. Always check `.gitignore` before the first commit in a repo; if it's deny-all, never stage `.claude/` or `secretary/` contents. Reflog saves us here — tag `recovery-point-2026-04-20` pins `af380e7`.

## Time estimates must be AI-native
An ADR written for a human executor said "Budget: 2 hours". I copied that verbatim into a subagent prompt. Realistic AI-native budget for the same task was 3-8 min. Lesson: when lifting estimates from human-authored plans, translate human-hours into agent-minutes. Orianna's new task-estimation-check mode (under migration) enforces this.

## Verify PR scope before merging
Ekko's first TDD-gate PR (#45) bundled 34 unrelated files from prior session state because he branched off a dirty HEAD. Jhin caught it on review. Recovery required a fresh branch (`chore/tdd-gate-clean`) cherry-picking only the 5 in-scope files, then closing #45 and opening #46. Standing rule: any PR-creating agent must `gh pr diff --name-only` against the stated scope before declaring done.

## Coordinator must not delegate its own memory
Tried delegating Sona's session-close to Yuumi. Duong corrected: Sona's memory is Sona's own. Writing session summaries, learnings, and MEMORY.md updates is a first-person task — Yuumi is for errands that don't require the coordinator's perspective.

## Closed PRs are forever
GitHub has no API or UI to delete a PR. Close + branch-delete is the strongest available undo; the PR URL remains in the history list permanently. Support ticket is the only real removal path.
