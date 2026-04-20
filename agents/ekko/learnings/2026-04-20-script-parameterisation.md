# 2026-04-20 — Script Parameterisation (memory-consolidate, filter-last-sessions)

## What was done
Replaced the Evelynn-hardcoded `scripts/evelynn-memory-consolidate.sh` with a generic
`scripts/memory-consolidate.sh <secretary>`. Refactored `scripts/filter-last-sessions.sh`
to accept the same `<secretary>` argument instead of hardcoding Evelynn paths.

## Key decisions
- Secretary name validated with a POSIX case-glob (`*[!a-z]*`) — no regex dependency.
- Memory file existence check (`agents/<secretary>/memory/<secretary>.md`) provides a second
  guard before any git or file operations start.
- All messages now include `[<secretary>]` tag for clarity in multi-coordinator environments.
- Temp file prefix changed from `evelynn-sessions-` to `${SECRETARY}-sessions-` for clarity.

## Blocker encountered
Edit to `.claude/agents/evelynn.md` was denied by the harness permission system. The
initialPrompt still calls the old `scripts/evelynn-memory-consolidate.sh` and
`scripts/filter-last-sessions.sh` (no arg). Duong needs to either grant permission to edit
`.claude/agents/*.md` or make the two-line change manually:
- `bash scripts/evelynn-memory-consolidate.sh` → `bash scripts/memory-consolidate.sh evelynn`
- `bash scripts/filter-last-sessions.sh` → `bash scripts/filter-last-sessions.sh evelynn`

The old `scripts/evelynn-memory-consolidate.sh` was NOT deleted since evelynn.md still
references it. Once evelynn.md is updated, the old script can be removed with `git rm`.

## Smoke test results
- `bash scripts/memory-consolidate.sh evelynn` → no shards older than 48h, clean no-op
- `bash scripts/filter-last-sessions.sh evelynn` → sentinel OK, 20 shards listed
- `bash scripts/memory-consolidate.sh sona` → no shards older than 48h, clean no-op
- `bash scripts/filter-last-sessions.sh sona` → sentinel OK, 1 shard listed
- Invalid name `invalid-name` → rejected with clear error
- Missing secretary `nonexistent` → rejected with clear error
