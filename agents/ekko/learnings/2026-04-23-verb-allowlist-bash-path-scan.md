# Learnings: Verb-allowlist fix in _lib_bash_path_scan.py (2026-04-23)

## Context

The bash AST path scanner was collecting path arguments for ALL commands, causing
`git add plans/approved/x.md`, `cat plans/approved/x.md`, `ls plans/approved/`, and
`grep foo plans/approved/x.md` to be blocked by the plan-lifecycle guard. This was a
blocker for Talon's current work.

## Fix

Added a verb-allowlist (`_MUTATING_VERBS` frozenset) in `_lib_bash_path_scan.py`.
Before collecting path arguments from a CommandNode, check whether the verb is mutating:

- `mv`, `cp`, `rm`, `touch`, `tee`, `dd`, `install`, `rsync`, `truncate`, `mkdir`, `rmdir` → mutating
- `git` + subverb `mv` or `rm` → mutating; all other `git` subverbs (add, status, diff, log, etc.) → read-only
- `sed` with `-i` or `--in-place` flag → mutating (in-place edit); `sed` without → read-only
- `eval`, `bash -c`, `sh -c` → still re-parsed (handled by existing B7 logic)
- Everything else (cat, ls, grep, awk, echo, printf, find, etc.) → read-only, paths NOT collected

Shell redirects (`>`, `>>`) are ALWAYS collected regardless of verb — this covers
`echo foo >plans/approved/x.md`.

## Key design point

The `_collect_paths` flag controls whether word arguments (i=0,1,2,...) are appended
to `out`. Redirects are a separate code path (`_walk_redirect`) that is always called,
so they are never suppressed by the verb allowlist.

## Test counts

Before: 27 passing. After: 34 passing (+7 V1-V7 verb-allowlist tests).

## What still blocks

- `git mv` still blocks (subverb `mv`)
- `git rm` still blocks (subverb `rm`)
- `rm`, `cp`, `mv`, `touch` still block
- `sed -i` still blocks
- redirects (`>`, `>>`) still block regardless of verb

## Commit SHAs

- Xfail commit: 04e82b8
- Implementation commit: 94f3ccd
- Push: 73f9bc9..94f3ccd on main
