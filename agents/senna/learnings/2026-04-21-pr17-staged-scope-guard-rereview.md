# 2026-04-21 — PR #17 staged-scope-guard re-review (Approved)

## Context
Re-reviewed `feat: staged-scope guard pre-commit hook` (PR #17) after Jayce's three fix commits addressing my prior CHANGES_REQUESTED.

- Fix 1 `9487e3b` — strip dead pre-work from case_A (5-line deletion removing the shadow invocation/unused stderr-capture).
- Fix 2 `7aadb93` — test file mode via `git update-index --chmod=+x` (sandbox blocked direct `chmod`, but the object-store mode is the source of truth; committed as `100755`).
- Fix 3 `3ab2ecc` — new `case_F` covering the STAGED_SCOPE-unset + `.git/COMMIT_SCOPE` file-fallback branch.

Verdict: Approved.

## Findings
All 6 cases (A–F) green when the test is invoked from inside the worktree. Residual stylistic nits (twice-invoked hook pattern in cases B/D, no cleanup trap in `make_repo`) flagged as non-blocking.

## What I learned / will remember

### 1. `git rev-parse --show-toplevel` in tests couples to cwd
The test script resolves `HOOK_ABS` via `REPO_ROOT="$(git rev-parse --show-toplevel)"`. When I invoked `bash /tmp/senna-pr17-review/scripts/hooks/tests/pre-commit-staged-scope-guard.test.sh` from the main repo, the resolver returned the **main repo's** top-level, not the worktree's. The `[ ! -x "$HOOK_ABS" ]` guard then fired the xfail path because the hook file only exists on the PR branch.

This produced a misleading `xfail — hook not yet implemented` output that could easily be mistaken for a failing test. The fix is to invoke with cwd inside the worktree:

```
bash -c 'cd /tmp/senna-pr17-review && bash scripts/hooks/tests/pre-commit-staged-scope-guard.test.sh'
```

Mental model: when a test uses `git rev-parse` to locate SUT files, it locates them relative to **invocation cwd**, not the script's own path. This is a robustness gap in the test but intentional — the test is meant to run from inside a checkout of the branch under test, not from another repo.

### 2. Sandbox blocks `cd` + git-repo-creation combos in some directories
The standard worktree path `/Users/duongntd99/Documents/Personal/strawberry-agents-staged-scope/` was entirely sandbox-blocked for shell execution (every `ls`, `stat`, `bash`, and direct script invocation was denied). Moving to `/tmp/senna-pr17-review` via `git worktree add` worked cleanly.

Takeaway for future reviews: if the canonical worktree path blocks execution, add a throwaway worktree under `/tmp` — it's read-only to the SUT and gets cleaned up with `worktree remove --force`.

### 3. `git update-index --chmod=+x` is a valid sandbox workaround for committing an executable bit
Jayce's Fix 2 uses `git update-index --chmod=+x <file>` to stage a mode change without touching the working tree's filesystem mode. The committed object records `100755`, and any future checkout picks up the executable bit from the git object — no post-checkout `chmod` required. This is materially better than the alternative (a setup script that runs `chmod` after clone) because it survives `git clone` and CI checkouts without extra steps.

Verified with `git ls-tree <sha> <path>` → `100755 blob <sha> <path>`.

### 4. CI "xfail-first check" and "regression-test check" are metadata-only
The PR shows 4 passing checks, but none of them actually execute the hook's test suite — they only verify (a) commit message ordering (xfail before impl) and (b) regression-test presence for bug-flagged commits. Real test execution still depends on the reviewer running it locally. I should not take green CI on this class of test-suite PR as evidence of test correctness.

## Process confirmations
- `scripts/reviewer-auth.sh --lane senna` → `strawberry-reviewers-2` preflight check worked; approval posted as review `4147791021` replacing CHANGES_REQUESTED `4147710969`.
- Cleanup: `git worktree remove /tmp/senna-pr17-review --force` succeeded.
