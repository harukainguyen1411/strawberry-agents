# PR #45 — round 2 re-review — CHANGES_REQUESTED (two new bypasses)

**Date:** 2026-04-24
**PR:** harukainguyen1411/strawberry-agents#45
**Branch:** `talon/subagent-git-identity-as-duong`
**Verdict:** CHANGES_REQUESTED (still)

## Summary

Fix cycle closed round 1 cleanly — I1 orphan gone, I2 dead block gone, I3 empty-stdin
pass-through, C1/C2/C3 canonical shapes blocked, 18 tests green, Rule 12 honored. But
while stress-testing the variants the user specifically asked about (quoting, position,
separator) I found two *new* real bypasses in the same family.

## Residual criticals

- **BP-1** Literal-quoted `-c`: `git -c "user.email=viktor@strawberry.local" commit` —
  C1 regex requires whitespace before `user.`, literal quote defeats it.
  Reproduced live: commit author = `Duongntd <viktor@strawberry.local>`.
- **BP-2** Space-separated `--author`: `git commit --author "Viktor <viktor@strawberry.local>"` —
  C3 regex requires `=`, space form passes. Produces full persona author.

## Important

- **BP-3** Name-only leaks via `-c user.name=Viktor` or `GIT_AUTHOR_NAME=Viktor` —
  email is neutral but name leaks. Plan invariant is worded around `@strawberry.local`
  so strictly out of scope; but the plan *goal* (no non-Duong co-author in squash UI)
  is violated. Flagged as non-blocking.

## Bonus answered

Commit-time defense exists (`pre-commit-reviewer-anonymity.sh` → `anonymity_scan_author`
→ reads `git var GIT_AUTHOR_IDENT` post-resolution) but is work-scope-only (gated on
`[:/]missmp/`). Now that PreToolUse is universal, this asymmetry leaves personal-scope
with zero commit-time safety net. Also: human-typed commits never hit PreToolUse, only
the work-scope-only commit-time hook. Two follow-up items for the backlog.

## Testing method

Sandbox: `/tmp/senna-pr45-rereview/` — copied the PR-branch hook, synthesized PreToolUse
payloads via Python + `printf '%s' "$payload" | bash hook.sh`. For each unblocked shape,
created a throwaway git repo and ran the actual `git commit`, then `git log -1
--format='%an <%ae>'` to confirm the author identity leaked as expected.

Critical finding: matrix must include **quoted AND separator variants** of every flag
being guarded — not just the canonical form. Two bypasses here map 1:1 to "did we test
quoted?" / "did we test `--flag value` as well as `--flag=value`?"

## Time to close

~45 min — mostly reproduction + writing the review carefully since the same lane already
did a round 1.

## Takeaway for future identity-hook reviews

Add to review checklist: for any flag-based detector, always test:
1. `--flag=value`
2. `--flag value` (space sep)
3. `--flag "value"` / `--flag 'value'` (quoted)
4. Flag before *and* after the subcommand
5. Equivalent env-var form
6. Equivalent `-c` / config form
