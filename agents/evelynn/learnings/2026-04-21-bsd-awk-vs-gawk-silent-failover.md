# BSD awk vs gawk silent failover

**Date:** 2026-04-21
**Source:** PR #15 (rule-4 staged-diff scoping fix) — Senna review, Talon fix

## Finding

gawk-only 3-arg `match($0, /pattern/, m)` syntax errors on macOS's BSD awk **at compile time**, which silently promotes the fallback path. If the fallback path also has a bug, the primary path's ostensibly-correct code hides it completely — you see the fallback bug, not the primary code.

Shell scripts that use "try primary (gawk), fall back to sed" patterns should assume the **fallback is the real path** on any macOS machine unless gawk is explicitly installed and verified.

## Heuristic

When reviewing a shell script with `if gawk ... ; then ... ; else <sed fallback>; fi` or equivalent:

1. Treat the fallback as the canonical path on macOS.
2. Test the fallback path in isolation on macOS, not just end-to-end.
3. If the primary uses gawk-specific extensions (3-arg match, OFMT, etc.), add a `gawk --version` check at the top of the script with an explicit "fallback mode" log line.

## Root cause in PR #15

The pre-push hook's `get_diff_line_ranges()` used gawk 3-arg match. On macOS, BSD awk silently failed to compile that branch, fell through to `sed 's/.*+\([0-9,]*\).*/\1/'`. That sed pattern was greedy and broke on hunk headers with trailing context (see companion learning: greedy-sed-hunk-header).

## Fix

Anchored sed: `sed 's/^@@ -[0-9,]* +\([0-9,]*\) @@.*/\1/'`. Removes the gawk dependency entirely for this use case.
