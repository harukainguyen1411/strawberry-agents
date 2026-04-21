# Backtick-enclosed directory paths crash awk in pre-commit-zz-plan-structure.sh

## Date
2026-04-21

## Summary
When `pre-commit-zz-plan-structure.sh` checks path claims in a plan file, it extracts backtick-enclosed tokens and calls `awk getline` on each. If the token is a path to an EXISTING DIRECTORY (e.g. `plans/pre-orianna/` or `plans/pre-orianna`), `awk getline` on a directory causes an i/o error crash: `awk: i/o error occurred on <dir>`. This happens even if an `<!-- orianna: ok -->` suppressor is on the same line — the crash precedes the suppressor check.

## Root cause
The hook's awk parser crashes when it tries to read a directory as a file. A missing file (e.g. `plans/foo/bar/`) returns "file not found" gracefully. An existing directory crashes.

## Fix options (pick one per affected token)
1. **Remove backticks**: Use bare prose instead: `plans/pre-orianna/` → `plans/pre-orianna/`. Bare tokens (not backtick-enclosed) are handled differently and don't trigger the getline crash.
2. **Use a non-directory path**: `plans/pre-orianna` → `plans/pre-orianna/subdir` or use a specific file path that doesn't exist as a directory.
3. **Hook fix** (long-term): add `if (result < 0) { print "WARN: could not read " p > "/dev/stderr"; next }` error handling in the path-check awk block.

## Example from this session
Line: `` `plans/pre-orianna/` <!-- orianna: ok --> ``
Hook crashes at input record 163 with `i/o error occurred on .../plans/pre-orianna/`

Fix applied: Changed to prose form `plans/pre-orianna/ <!-- orianna: ok -->` (no backticks).

## Note
This is a hook bug (not a plan authoring requirement). Plans created before `plans/pre-orianna/` existed were not affected because the non-existent directory returns "not found" gracefully. After the directory was created (by PR #14), the hook started crashing.

## Related
- `agents/senna/learnings/2026-04-21-sed-greedy-hunk-header-parsing.md` (separate awk issue)
- `agents/ekko/learnings/2026-04-21-parallel-agent-sign-contamination.md`
