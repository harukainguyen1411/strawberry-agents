# PR #50 — re-review APPROVE after Talon's fix commit

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/50
**Verdict:** APPROVE (re-review on `f28b57e5`)
**Lane:** Senna (code quality)

## Outcome

C1, I1, I3, S5 all addressed. Test runs 6/6 against PR head; runs 3 PASS / 1 FAIL against pre-T2 main with strict `GIT_CONFIG_GLOBAL=/dev/null` isolation (the FAIL is INV-2 dispatcher-files-existence, exactly the regression guarantee). Lucian already approved on plan-fidelity grounds — this approval satisfies Rule 18 dual-non-author.

## Key technical insight uncovered during re-review

INV-1a alone (the "commit blocked when hooksPath set" leg) does NOT distinguish pre-T2 from PR head on a typical clone, because **git's default fallback when `core.hooksPath` is unset is the common-dir `.git/hooks/`, which IS visible from worktrees**. So the old `install-hooks.sh` (writing to `.git/hooks/`) actually DID give worktrees hook coverage by default — meaning the plan's premise ("worktrees don't inherit hooks") was overstated for modern git.

The regression guarantee in the new test actually rests on **INV-2's dispatcher-files-existence check** (asserts `scripts/hooks-dispatchers/{pre-commit,pre-push,commit-msg}` exist after install). Pre-T2 fails this because the directory doesn't exist on that branch's checkout; PR head passes because T2 ships the directory.

I noted this in the review as a non-blocking follow-up so future maintainers don't accidentally weaken the guard by deleting INV-2 file-checks while keeping only INV-1.

## Process notes

- Used `/tmp/pr50-verify` (PR head clone) and `/tmp/pre-t2-verify` (pre-T2 clone with the new test file copied over) for hands-on verification.
- Initial pre-T2 test run was contaminated by the maintainer's global `core.hooksPath = ~/.config/git/hooks`. Re-ran with `HOME=/tmp/fake-home GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null` for a clean environment.
- `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` → `strawberry-reviewers-2` on both pre-flight and post-submit. APPROVED at 2026-04-25T06:44:10Z.

## Patterns to keep using

- Always run xfail-claimed tests against the pre-change SHA in a controlled env. If they "pass" pre-change, dig deeper — environment leakage (global git config, env vars) is a common confounder.
- When a test asserts behavior across two configurations (block vs. allow), always probe with strict env isolation to confirm the assertion logic doesn't pass via a confounding default.
- Take the time to understand WHY a test passes/fails — if you can't explain the mechanism in one sentence, the test is probably leaking some assumption.
- When a re-review reveals a finding outside the original critical scope (here: the plan's premise itself was overstated), flag it as a non-blocking follow-up rather than re-requesting changes. Keeps the merge moving and lets the team address it deliberately.

## What worked well

- Talon's fix commit was tightly scoped (3 files, surgical changes) and matched the requested rewrites exactly. Easy to review.
- The `-c core.hooksPath=/dev/null/no-hooks` neutralization in INV-1b is a clean way to prove the second-leg succeeds-without-hooks invariant — better than relying on `--unset`, which can be subverted by inherited globals.
- Two iterations from REQUEST CHANGES → APPROVE in the same day. Short feedback loop.
