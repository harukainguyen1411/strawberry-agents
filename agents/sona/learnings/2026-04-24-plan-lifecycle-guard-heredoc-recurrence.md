# Plan lifecycle guard fires fail-closed on heredoc Bash blocks — third recurrence, elevated to high severity

**Date:** 2026-04-24
**Severity:** high
**Session:** 84b7ba50 (post-compact round 4)

## What happened

The PreToolUse plan-lifecycle guard (`scripts/hooks/pretooluse-plan-lifecycle-guard.sh`) uses a bashlex AST path scan to detect Bash commands that touch plan-directory paths. The scan incorrectly fires on heredoc-style Bash blocks that happen to contain plan-directory strings as content (e.g., `cat <<'EOF'` with a plan path in the body).

This happened three times today:
1. Aphelios during task decomposition (`0314b7cc`) — write blocked mid-task.
2. Me (Sona coordinator) — attempting a plan status update.
3. Lucian during a plan-fidelity review — blocked from reading a plan-directory file via Bash.

Each hit required a workaround (use Read tool instead of Bash cat, or restructure the heredoc). Context interruption on each.

## Root cause

The bashlex AST scan matches path strings in heredoc bodies as if they were Bash command arguments. The guard cannot distinguish between `mv plans/proposed/...` (the dangerous operation it should block) and `echo "See plans/proposed/..."` in a heredoc (which is safe).

## Fix needed

Evelynn inbox'd with high-severity flag. The guard needs to:
1. Distinguish heredoc bodies from active Bash command paths.
2. Only fire on `mv`, `cp`, `rm`, `tee`, `touch` operations targeting protected plan directories — not on all path string occurrences.
3. Alternatively: scope the bashlex scan to the command portion only, not heredoc content.

## Interim workaround

When the guard blocks a legitimate Bash operation involving a plan-directory path:
1. Use the Read tool (not Bash `cat`) to read plan files.
2. Restructure heredocs to omit plan-directory path strings from the body.
3. Use explicit `--no-path-scan` opt-out if/when that's implemented (not yet available).

## Related

Existing learning: `2026-04-24-plan-lifecycle-guard-staged-commit-hole.md` (different failure mode — staged-commit bypass).
