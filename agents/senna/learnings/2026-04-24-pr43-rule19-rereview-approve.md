# PR #43 Rule 19 guard-hole — re-review APPROVE

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents#43
**Branch:** talon/rule-19-guard-hole
**Fix commit:** 3c64ec1b
**Verdict:** APPROVED

## Summary

Re-reviewed Talon's fix for the must-fix env-leak in `test-pre-commit-plan-lifecycle-guard.sh`
Case 3, plus four nice-to-haves from the prior CHANGES_REQUESTED round.

All addressed in one commit:

- `invoke_hook_directly` wraps with `env -u CLAUDE_AGENT_NAME -u STRAWBERRY_AGENT -u STRAWBERRY_AGENT_MODE`
  so the test scaffold is hermetic from outer-shell env. Validated by exporting all three
  vars and running the suite — Case 3 still passes (4/4).
- `_found_violation` flag removed; reject paths exit directly.
- `run_case` / `attempt_commit` dead helpers deleted.
- Reject message wording reworked to "add files to" / "delete files from" / "rename/copy files involving".
- `is_admin()` carries a comment about the `env -i` bypass with a pointer to PreToolUse.
- `--diff-filter=ACDRM` carries a comment explaining T-exclusion.

## Pattern: hermetic test scaffolds

The right fix for "test passes in CI but fails locally because outer shell exports
`CLAUDE_AGENT_NAME`" is to bake the `env -u` clear into the test invocation helper itself,
not to require the caller to remember. Talon's chosen pattern — `env -u VAR1 -u VAR2 ... "$@" bash "$HOOK"`
where the `"$@"` slot lets cases pass `NAME=VALUE` overrides — is the cleanest expression
of "explicit-only env, no inheritance" without forcing every case to repeat the unset list.

Key validation move: re-run the test with the exact failure-mode env vars exported in
the outer shell. If it still passes, the fix is real.

## Re-review review-loop hygiene

When re-reviewing a fix-commit:
1. Pull only the new commit's diff (don't re-evaluate the unchanged hook code).
2. Map each prior finding to a specific diff hunk; if any finding has no
   corresponding hunk, that's the report.
3. Run the failing scenario yourself; if the test framework is the thing being
   fixed, run with the exact bad env that previously broke it.
4. Note pre-existing unrelated failures in the broader runner so you don't
   accidentally request changes for orthogonal breakage.
