# Statusline idle-time extension (2026-04-18)

## What was done
- Added `UserPromptSubmit` hook to `~/.claude/settings.json` that writes `date +%s` to `/tmp/claude-last-prompt-<session_id>` on every user prompt. Uses `$CLAUDE_HOOK_INPUT` env var (JSON piped by Claude Code to hook commands).
- Extended `~/.claude/statusline-command.sh` with section 6 (idle time): reads the timestamp file, computes elapsed seconds, formats as `Ns` / `Nm` / `Nh Nm`, and colors dim grey (<1m), white (1-5m), yellow (5-30m), red (30m+).

## Key learnings
- Claude Code passes hook input as JSON in the `$CLAUDE_HOOK_INPUT` env var — the hook command does not receive stdin. The hook JSON contains `session_id` at top level.
- `date -v -10M` works on macOS for offset timestamps; Linux needs `date -d '10 minutes ago'` — for test scripts, arithmetic `$(( $(date +%s) - 600 ))` is portable.
- The statusline assembly loop iterates over a positional list — adding a new section just means appending the variable name to the `for PART in ...` list.

## Files changed
- `~/.claude/settings.json` — added `UserPromptSubmit` hook block
- `~/.claude/statusline-command.sh` — added section 6 + appended `$IDLE_PART` to assembly loop
