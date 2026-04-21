# Learning: plan-structure hook — directory path causes awk I/O error

Date: 2026-04-21
Topic: pre-commit-zz-plan-structure.sh awk getline on directories

## Observation

`pre-commit-zz-plan-structure.sh` uses awk `getline _ < full_path` to check
whether a backtick-quoted path token exists on disk. On macOS awk, opening a
directory path (e.g. `plans/proposed/work/`) with getline produces a fatal I/O
error that aborts the entire awk run — the file is de-staged and the commit fails.

The error message format is:
  awk: i/o error occurred on <full/path/to/dir>
   input record number N, file <plan-file>
   source line number M

This is **not** a BLOCK finding — it is a hard awk crash and the exit code is non-zero.

## Fix

Any backtick token that is a directory path (trailing `/`) must have
`<!-- orianna: ok -->` on the same line, same as cross-repo file paths.
The suppressor (checked at awk line 324 before getline) prevents the open attempt.

## Lines requiring suppression

- `plans/proposed/work/` — directory path used in Handoff sections
- Any `company-os/tools/<service>/` style directory references
- Pattern: any backtick token matching `[path]/` where the directory exists locally

## Lesson

When adding `<!-- orianna: ok -->` suppressors, scan for trailing-slash directory
tokens in backticks, not just file paths. The hook does not distinguish — it tries
to getline any path-like token that passes the is_path heuristic.
