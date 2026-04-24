# Learning: STAGED_SCOPE is NEWLINE-separated, not comma or space

**Date:** 2026-04-24
**Trigger:** Plan-lifecycle staged-scope guard debugging — mid-session S66

## What happened

When composing `STAGED_SCOPE` for the staged-scope guard (pre-commit hook), an agent encoded the value using commas to separate file paths. The guard failed to match the expected files. Investigation confirmed: the guard reads `STAGED_SCOPE` as NEWLINE-delimited (`\n`), not comma-delimited or space-delimited.

## The rule

When injecting `STAGED_SCOPE` per-commit, use the NEWLINE separator:

```bash
STAGED_SCOPE="$(printf '%s\n' file1 file2 file3)"
```

Not:
```bash
STAGED_SCOPE="file1,file2,file3"  # WRONG
STAGED_SCOPE="file1 file2 file3"  # WRONG
```

## Where this matters

Every agent that composes an explicit `STAGED_SCOPE` for a commit must use the NEWLINE format. Include this fact in any delegation prompt where the agent will be committing files under the staged-scope guard.

## Reference

PR #20 merged the staged-scope guard. The NEWLINE encoding is baked into the guard's parsing logic in `scripts/hooks/pretooluse-staged-scope-guard.sh` (or equivalent).
