# 2026-04-23 — orianna-gate-simplification plan rewrite

## Task

Rewrote plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md to reflect
what actually shipped (PR #31 + PR #32) rather than the stale commit-phase design.

## Key hook blockers hit (fixed)

1. `h)` pattern detection: the pre-commit-t-plan-structure.sh hook uses `index(prose, "h)")` to
   block alternative time units. Any word ending in `h` followed by `)` anywhere in the Tasks
   section triggers this. Affected words: "approach)", "dispatch)". Fix: rephrase to avoid the
   pattern ("pre-commit design" instead of "pre-commit approach)", "subagent call" instead of
   "subagent dispatch)").

2. Backtick-enclosed directory tokens crash awk: `plans/proposed/` in backticks causes awk i/o
   error when the hook tries getline on what it interprets as a directory path. Fix: unquote
   the directory and add an inline suppressor comment.

3. Non-existent path tokens need suppressors: `scripts/hooks/pre-commit-plan-promote-guard.sh`,
   `_orianna_identity.txt`, `commit-msg-plan-promote-guard.sh` referenced as "never wired"
   descriptions still block the hook. Fix: remove backticks and add inline `<!-- orianna: ok --
   reason -->` suppressors.

4. `.tool_input.command` looks like a file path to the hook. Fix: rephrase to "the
   `.tool_input.command` field" and add suppressor.

5. PreToolUse guard itself blocks the git commit heredoc when the heredoc body contains
   plan path tokens and the command string has "plans" in it (bashlex parse error on heredoc
   syntax). Fix: use a simple flat -m string for the commit message.

## What was preserved vs rewritten

Preserved: Context, T1, T2, T4 (renamed from T3), T5, T7, goal/design philosophy, References.

Rewritten: T3 (now describes PreToolUse physical guard, PR #31, identity chain, admin bypass,
bashlex AST walker, verb allowlist); T6 (now notes shipped CLAUDE.md + architecture doc updates,
strips _orianna_identity.txt / Orianna-Bypass: references); T8 (now describes actual 37-test
suite in scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh with coverage breakdown);
Test plan (now describes the 6 invariants the physical guard protects, not the old commit-phase
tests); added "Implementation divergence" subsection near top.

## SHA

6c18579
