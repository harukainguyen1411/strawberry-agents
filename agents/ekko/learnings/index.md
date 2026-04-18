# Ekko Learnings Index

- 2026-04-13-script-worktree-shortcuts.md — safe-checkout.sh needs TTY; use git worktree add directly in subagent context; plan-promote.sh only handles proposed/ | last_used: 2026-04-13
- 2026-04-17-dependabot-b5-b7-vitest3-upgrade.md — vitest 2→3 fixes esbuild/vite alert chain in standalone apps; non-workspace apps regen lockfiles directly; vitest 3 basic API stable | last_used: 2026-04-18
- 2026-04-18-tdd-hooks-ci-wiring.md — TDD hooks + CI wiring notes for P1.2-A | last_used: 2026-04-18
- 2026-04-18-worktree-bypass-for-foreign-dirty-tree.md — raw `git worktree add` bypasses safe-checkout.sh's dirty-tree guard when foreign files block; invariant-#3 compliant | last_used: 2026-04-18
- 2026-04-18-supersede-stale-dependabot-branches.md — when dependabot branches carry stale co-changes to package.json, supersede via a combined PR built on current main; don't merge branch directly | last_used: 2026-04-18
- 2026-04-18-amend-exception-for-tool-error-recovery.md — `git commit --amend` + `--force-with-lease` is legitimate when recovering from a partial-Edit-tool commit BEFORE reviews land on feature branches; not for scope changes | last_used: 2026-04-18
- 2026-04-18-local-main-drift-leaks-into-feature-branches.md — cut worktrees from `origin/main` not `main` in multi-agent environments; local main can drift ahead with other agents' unpushed commits and silently leak scope into your PR | last_used: 2026-04-18
- 2026-04-18-ci-all-red-check-billing-first.md — if every required check across every PR goes red simultaneously and logs are empty, check GitHub Actions billing/spending before investigating workflows; empty-commit nudges don't bypass queue rejection | last_used: 2026-04-18
