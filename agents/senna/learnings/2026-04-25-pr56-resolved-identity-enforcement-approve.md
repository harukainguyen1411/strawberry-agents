# PR #56 review — resolved-identity enforcement (post-PR#45 pivot)

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/56
**Branch:** `talon/resolved-identity-enforcement`
**Verdict:** APPROVE with two notes (one important, one suggestion)
**Review URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/56#pullrequestreview (id PRR_kwDOSGFeXc743mhT)

## Summary

The architectural pivot away from the PR #45 PreToolUse Bash-source scanner (which had 9 unbounded bypasses NEW-BP-4..12) to two-layer resolved-identity enforcement is correct and complete:

- **Pre-commit** reads `git var GIT_AUTHOR_IDENT` / `GIT_COMMITTER_IDENT` — post-expansion ground truth. Catches every shell-indirection bypass class (line-cont, backtick, $(), eval, sh -c, bash -c, $V, cat /file, env-var).
- **Pre-push** reads `git cat-file commit <sha>` for each pushed commit. Closes the `git commit-tree` plumbing path (the only one that skips pre-commit hooks).
- PR #45's PreToolUse scanner is preserved verbatim with an "advisory defense-in-depth" header — fine, as it shortens feedback loop for trivial cases.

All 8 commits authored by `Duongntd <103487096+...>`. The filter-branch rewrite Talon ran on T1 produced clean history.

## Findings

### Important — Orianna env-var case inconsistency across hooks

The new `pre-commit-resolved-identity.sh` checks `CLAUDE_AGENT_NAME = "orianna"` (lowercase, exact). The existing `pretooluse-subagent-identity.sh` checks `= "Orianna"` (capitalized, exact). The plan-lifecycle guard does case-insensitive (lowercases first). Canonical case in actual use is lowercase (verified across all `test-pretooluse-plan-lifecycle-*.sh` and `test-pre-commit-plan-lifecycle-guard.sh`).

Failure mode: depending on caller's env-var case, Orianna's legitimate plan-promotion commit might be blocked by one hook but bypass the other. Recommend lowercasing once and comparing to `"orianna"` everywhere — match the plan-lifecycle guard pattern.

### Suggestion — persona regex misses persona-in-email-localpart

`PERSONA_PATTERN='(^|[[:space:]])+(Viktor|Lucian|...)([[:space:]]|$|[^[:alnum:]])'` requires whitespace or start-of-string before the persona token. So `Duongntd <viktor@example.com>` evades the regex (the `<` is non-space/non-alnum, doesn't satisfy the leading anchor) AND evades `EMAIL_PATTERN='@strawberry\.local'` (different domain). I verified this with grep against the live regex.

Not a currently observed attack — every PR #45 incident put the persona name in the display-name field. But it's the obvious next move. Easy fix: widen leading char class to `[<._-]` or scan email local-part separately.

Lucian's parallel review independently flagged this same gap (his DN-3) from a slightly different angle — his framing was the allowlist should require *exact* email match else fall through to "non-allowlisted email → block." Both fixes converge.

## Minor (non-blocking)

- `setup_env_author` in pre-commit test file is dead code — defined but never called.
- Tests use `bash "$HOOK"` despite hook's `#!/bin/sh` shebang — won't catch bash-vs-sh portability bugs.
- Pre-push hook silently skips refs when `git rev-list` fails (e.g., force-push race); reasonable for local-machine threat model.
- Pre-push hook treats annotated tag refs as commits and `git cat-file commit` warns-and-skips — tag pushes bypass.
- Most BP-4..9, 11, 12 setup_fns just `git config user.name "Persona"` directly without exercising the bypass technique. Test logic is sound (all bypasses converge to same observable), but test names oversell what's verified. The exception is BP-10 in pre-push which genuinely calls `commit-tree`.

## Convergence with Lucian

Lucian approved on plan-fidelity grounds (PRR_kwDOSGFeXc743mEE) before I posted. His DN-3 (persona-named emails on non-strawberry.local domains) is the same gap as my Suggestion. Useful alignment — the gap is real and worth a future hardening plan, but it's outside this PR's contract.

## Process notes

- Reviewer auth identity verified: `strawberry-reviewers-2` via `scripts/reviewer-auth.sh --lane senna gh api user`.
- Used `git fetch origin talon/resolved-identity-enforcement && git cat-file -p <blob>` to read PR contents without checkout (since main doesn't have these files yet). FETCH_HEAD-based access via `git ls-tree -r origin/talon/resolved-identity-enforcement` worked when raw `git show FETCH_HEAD:` did not (probably refs/refs cache state issue).
- Live regex verification via `printf '...' | grep -iqE '...'` was the load-bearing evidence for the email-localpart finding — wouldn't have caught it just by reading the regex.

## Pattern reminder

For shell-source vs resolved-value enforcement: the right gate runs *after* shell expansion is complete. PreToolUse is structurally pre-execve and cannot be the primary gate. Pre-commit and pre-push hooks read post-expansion ground truth. This generalizes — any policy that depends on values rather than syntax must run at or after the execve boundary, not before.
