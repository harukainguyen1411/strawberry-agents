# 2026-04-20 — Agent folder cleanup

## What I learned

- `git rm` only works on tracked files. Untracked dirs (inbox dirs that were never committed) must be removed with plain `rm`.
- When looping in bash via Bash tool, `rm` may not be found as a bare command — use `/bin/rm` explicitly.
- The `git ls-files <path> | xargs git rm -f` pattern is efficient for bulk-removing tracked files that match a path.
- `_retired/` agents also accumulate inbox/journal/transcripts/`_archive` — scope cleanup instructions apply there too.
- `reksai` has no `learnings/` dir at all (skipped creating one since task only said create `index.md` if `learnings/` exists).
