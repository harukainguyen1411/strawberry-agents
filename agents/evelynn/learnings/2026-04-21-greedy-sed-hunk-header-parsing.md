# Greedy sed on @@ hunk headers

**Date:** 2026-04-21
**Source:** PR #15 (rule-4 staged-diff scoping fix) — Senna review, Talon fix

## Finding

`sed 's/.*+\([0-9,]*\).*/\1/'` applied to unified diff `@@` hunk headers is **greedy**: it matches the last `+<digits>` in the line, not the one in the hunk range. Hunk headers with trailing context of the form `@@ -a,b +c,d @@ functionName(+param)` will return the wrong number because the trailing `+param` component matches instead of `+c`.

## Canonical fix

Anchor to the start of the hunk header format:

```
sed 's/^@@ -[0-9,]* +\([0-9,]*\) @@.*/\1/'
```

The `^@@ ` anchor ensures only the hunk range portion is captured.

## Silent failure mode

The bug did not error — it returned a wrong number silently. The pre-push hook accepted the malformed range and either skipped the diff-scope check entirely or evaluated it against a garbage range. 39 regression tests now cover this; one test explicitly exercises a hunk header with trailing context including `+`.

## Context

Discovered during Senna's second review pass on PR #15 after the BSD awk silent failover (see companion learning: bsd-awk-vs-gawk-silent-failover) exposed that the sed fallback was the real execution path on macOS.
