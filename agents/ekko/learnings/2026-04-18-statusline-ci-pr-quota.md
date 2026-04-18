# Statusline Extension: CI, PR Queue, Quota

**Date:** 2026-04-18
**Task:** Add ci, prs, quota fields to `~/.claude/statusline-command.sh` with 60s disk cache

## Cache Pattern

Cache lives at `/tmp/claude-statusline-cache/<field>`. Each file:
```
<unix-timestamp>\n
<value>\n
```

`cache_read` always prints value (line 2+), returns 0=fresh, 1=stale, 2=missing. Key insight: early-return before printing breaks stale-value passthrough — must print unconditionally, then check age for return code.

On stale (rc=1): render stale value + spawn background refresh.
On missing (rc=2): omit field silently + spawn background refresh.

Background spawns use `disown` to detach properly from the shell.

## CI Field

- Cache key is branch-specific: `ci_<branch>` (with `/` → `_`)
- Uses `gh run list --branch <branch> --limit 1 --json status,conclusion`
- Must use `gh repo view --json nameWithOwner` to get repo — CWD-relative, works in any git repo
- Renders: `ci:✓` green (success), `ci:✗` red (failure/cancelled/timed_out/action_required/stale), `ci:~` yellow (in_progress/queued/waiting/pending/requested), `ci:?` dim (unknown)
- Skipped entirely if not in a git repo or `gh` not installed

## PR Queue Field

- `gh pr list --author @me --state open --json number` for authored count
- `gh pr list --search "review-requested:@me" --state open --json number` for review-requested
  - NOTE: `--review-requested` flag does NOT exist in gh CLI — use `--search` with GitHub search syntax
- Format: `prs:A/R`; omit entirely if both zero
- Color: white always

## Quota Field

- Requires `ccusage` (npm package) — graceful skip if not installed
- Uses `ccusage blocks --json` → parse `.blocks[]` for `isActive: true` entry
- Quota % = elapsed time in active block / 5h (18000s) * 100
  - This is time-based (how far through billing window) not token-based
  - No hard token limit exposed in the JSON; time fraction is most useful signal
- Colors: white <60%, yellow 60-85%, red 85%+
- If `ccusage` installed, cache populates on first background refresh; field omitted until then

## Assembly Order

`git │ model │ ctx │ cost │ todos │ ci │ prs │ quota │ idle`

## Testing

Mock with: `printf '%s\n<value>\n' "$(date +%s)" > /tmp/claude-statusline-cache/<field>`
Stale test: `printf '%s\n<value>\n' "$(( $(date +%s) - 120 ))" > ...`
