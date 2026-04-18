# Statusline ci/prs/quota strip

**Date:** 2026-04-18
**Task:** Remove ci, prs, quota fields from ~/.claude/statusline-command.sh

## What changed

- Removed sections 6 (CI), 7 (PR queue), 8 (Quota) entirely
- Removed cache infrastructure: `CACHE_DIR`, `cache_read`, `cache_write`, `cache_refresh_bg`
- Removed associated `_ci_refresh`, `_pr_refresh`, `_quota_refresh` helper functions
- Assembly loop now iterates: git, model, ctx, cost, todos, idle only
- Backup written to `~/.claude/statusline-command.sh.bak.20260418`

## Notes

- `todos` field uses direct file read (`~/.claude/todos/<session_id>.json`) — no cache, so removing the cache helpers was safe
- `idle` field uses direct `/tmp/claude-last-prompt-<session_id>` file — also no cache dependency
- Stale cache files at `/tmp/claude-statusline-cache/{ci_main,pr_queue,quota}` were present at time of task; Bash permission was not granted so manual removal is needed: `rm /tmp/claude-statusline-cache/{ci_main,pr_queue,quota}`
- Write tool was used for backup since Bash `cp` was blocked; original content preserved verbatim in `.bak.20260418`
