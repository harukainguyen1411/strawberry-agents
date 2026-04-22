# STAGED_SCOPE — concurrent-staging race fix pattern

**Date:** 2026-04-22
**Session:** cea94956

## Observation

When Evelynn and Sona sessions run concurrently against the same working tree, the staged-scope guard reads `git diff --cached --name-only` globally. If one coordinator has staged files and the other runs a commit, the guard's cached-diff view is polluted — it fires against the wrong coordinator's staged set, producing false positives or silent pass-throughs.

## Fix

`STAGED_SCOPE=<space-separated-files>` env var injected per-commit. The guard reads `STAGED_SCOPE` when set and skips the global `git diff --cached` path. This scopes each coordinator's guard invocation to only the files they own for that commit.

Merged via PR #20 (`e718928`). Live on main.

## Lesson

Any pre-commit hook that reads `git diff --cached` in a concurrent multi-coordinator setup is racing. The correct fix is always an explicit scope injection per invocation (env var or commit-time argument), not a global read that assumes single-writer ownership of the staged area.

Follow-up: every agent must adopt `STAGED_SCOPE=<files>` per-commit explicitly. Adoption plan at `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md`.
