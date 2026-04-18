# Migration Phase 1 Real Run Learnings

## Session: 2026-04-18 P1 real run

### Global pre-commit hook blocks orphan commits

The global git hook at `~/.config/git/hooks/pre-commit` runs `gitleaks protect --staged` on every commit — including commits in `/tmp/` scratch clones. When the cursor skills file `apps/myapps/.cursor/skills/github-issue-implementation/reference.md` had placeholder `YOUR_TOKEN` strings, gitleaks flagged them as `curl-auth-header` findings and blocked the commit.

**Fix:** Delete `apps/myapps/.cursor/` before the orphan commit. Cursor skills are agent-infra and don't belong in the public repo anyway.

### `gitleaks detect --log-opts="--all"` scans origin's history too

After a `git clone`, the working clone can still reach all of origin's commits via remote tracking refs. `gitleaks detect --log-opts="--all"` scans every commit reachable from ANY ref, including `origin/main`. This produces findings from old commits that will never be pushed to the new public repo.

**Fix:** For the orphan-squash migration pattern, use `--log-opts="HEAD"` to scan only the single orphan commit. The `--all` scan is still valuable to run for awareness, but findings in old origin commits do not block the migration since the orphan has no ancestry to those commits.

### `.mcp.json` contained a real Telegram bot token in old history

`Duongntd/strawberry` private history at `0fe111c2` had a real Telegram bot token in `.mcp.json`. This file was deleted before the squash. The token is not in the public tree but should be rotated per R1 convention.

### Firebase Web API keys are not secrets

Old commit `6311a59d` had a hardcoded Firebase Web API key in `apps/myapps/src/firebase/config.ts`. Current code uses env vars. Firebase Web API keys are intentionally public (required by browser SDK); security is enforced via Firebase Security Rules.

### Additional paths to delete not in the plan's explicit list

- `.mcp.json` — MCP server configs with API tokens
- `.claude/` — Agent definitions and skills (private infra)
- `apps/myapps/.cursor/` — Cursor skills (agent tooling)

These should be added to the Phase 1 deletion checklist for the strawberry-agents migration.
