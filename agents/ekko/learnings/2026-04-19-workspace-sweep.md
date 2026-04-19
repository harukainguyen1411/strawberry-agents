# 2026-04-19 Workspace Sweep Learnings

## Task
Full post-migration workspace sweep: /tmp cleanup, strawberry-app worktree teardown, old strawberry clone check.

## Learnings

### Secret file inspection pattern
- `grep -c <pattern>` (count mode) is safe for secret scanning — no values in output.
- Use `awk` with `gsub(/=.*/, "= <REDACTED>")` to show key names while masking values.
- The `strawberry-app-secrets-set.sh` file was a prompt-based script (gh secret set reads from stdin) — no hardcoded values. One false-positive on the 40-char pattern came from the label string `"AGE_KEY` itself.

### Worktree cleanup
- `git worktree remove --force` works cleanly on merged/closed branches.
- `git pull origin main` blocked by untracked file (`functions/package-lock.json`) that was in the incoming commit — safe to `rm -f` since it was a generated file being added by the merge.
- V0.9-app-shell and chore/wire-firebase-service-account were CLOSED (not merged) but still safe to remove as worktrees.
- After worktree removal, `git branch -D` still needed for the local branch refs.
- V0.7 branch (`feature/portfolio-v0-V0.7-csv-ib`) was the main checkout — switch happened cleanly.

### Old repo dirty state
- `/Users/duongntd99/Documents/Personal/strawberry/` had 2 modified files (agents/ekko/memory/MEMORY.md, scripts/install-plugins.sh) and 1 untracked learning file. Did not delete — reported to Duong.
