# PR #50 — worktree hooks propagation: test-unsoundness finding

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/50
**Verdict:** REQUEST CHANGES
**Lane:** Senna (code quality / correctness)

## Top finding (critical)

`scripts/hooks/tests/test-worktree-hooks-propagation.sh` claims to test INV-1 (a guard installed on main fires inside a worktree) but invokes the guard directly via `bash "$HOOK"` rather than via `git commit`. So the test never exercises the dispatcher mechanism or `core.hooksPath` — the very things T2 changes. I confirmed by checking out pre-T2 main (`b6321bcd`) and running the PR-head test against it: it printed PASS with exit 127 (a hook *crash*, not a guard rejection). The test is unsound: it gives no protection against future regressions in the propagation mechanism.

Pattern to flag in future xfail-style tests: **the assertion must distinguish between "test under test produced expected non-zero exit because of the invariant" vs "test under test produced non-zero exit because of an unrelated crash."** Bare `[ $rc -ne 0 ]` is rarely sufficient; pair it with a `grep` of stderr/stdout for the expected error message, or assert a specific exit code.

Generally: if a test is supposed to validate a *propagation* / *integration* property, it must drive the system end-to-end (here: real `git commit`, not direct hook invocation). Unit-testing the guard separately is fine but doesn't cover the propagation invariant.

## Important findings

- **Relative `core.hooksPath` silently disables hooks on branches that don't contain `scripts/hooks-dispatchers/`.** Branches forked from main pre-merge will have no hook coverage in their worktrees until rebased forward. Git emits a warning to stderr when the dispatcher dir is missing but does not block. Worth documenting in the architecture doc.

- **Migration check `_old_default = "$_git_common_dir/hooks"` is brittle from a worktree.** `git rev-parse --git-common-dir` returns `.git` from the main checkout but absolute path from a worktree. The literal-string comparison can fail unexpectedly. The whole `_old_default` clause defends against a non-existent state (the OLD install never wrote `core.hooksPath`); recommended to drop it.

## What worked well

- The runtime code (install-hooks.sh new logic, worktree-add.sh, dispatchers) is correct, idempotent, and fails loud where it should.
- Switch to `git config --local` correctly insulates from the user's global `core.hooksPath = ~/.config/git/hooks` — verified manually that the global setting no longer masks the install.
- Dispatcher pattern-matching (`pre-commit-*.sh` etc.) correctly skips library files like `_lib_reviewer_anonymity.sh`.
- Wrapper INV-3 test is properly designed (real wrapper invocation, distinguishes exit code from stderr content).

## Process notes

- Used `git fetch origin pull/50/head:pr-50-review` then created two `/tmp/` clones to verify install-hooks.sh idempotency hands-on.
- Identity preflight: `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2`. Posted with `--lane senna`. CHANGES_REQUESTED at https://github.com/harukainguyen1411/strawberry-agents/pull/50 (review 2026-04-25T06:10:58Z).
- C1 reproduction was load-bearing for the verdict. Without running the test against pre-T2 main I might have shipped LGTM on the assumption that "xfail tests work because they're labeled xfail." Don't trust the label — verify the assertion logic.

## For future PR reviews

- Always run xfail-claimed tests against the pre-change SHA. If they pass, the test is broken. This is a 30-second verification that catches a class of "test that doesn't test what it says" bugs.
- When reviewing test code: read the assertion, then mentally simulate "what conditions other than the intended invariant would cause this assertion to pass?" If there are too many, the test is too loose.
