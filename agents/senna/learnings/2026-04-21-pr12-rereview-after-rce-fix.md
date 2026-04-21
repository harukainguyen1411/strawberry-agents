# 2026-04-21 — PR #12 re-review after RCE fix

Re-reviewed `feat/prelint-shift-left` (PR #12) after Talon's 6-commit fix push. Prior review: CHANGES_REQUESTED for C1 (RCE via awk `cmd | getline`) + I1–I4. All fixes verified. Converted to APPROVED.

## Key techniques used

**Independent RCE reproducer.** For critical security fixes, don't trust the PR's own regression test — run the attack payload in an isolated directory against the fixed hook. I created `/tmp/senna-rce-verify` with a fresh `git init`, copied the fixed `pre-commit-zz-plan-structure.sh` verbatim, staged a plan containing the metacharacter token `` `foo/";{touch,/tmp/senna-rce-independent.flag};:;#` ``, and confirmed no sentinel file was created. This independently validates the fix without relying on the test harness being correct.

**Verify the fix mechanism, not just test pass.** The C1 fix swaps `cmd | getline exists` (which invokes `/bin/sh -c`) for `getline _ < full_path` (awk-native `open(2)`). The latter has no shell interpretation path, so metacharacters are treated as literal filename bytes. Fundamentally different attack surface — not a string-escaping patch but a full removal of the shell exec. This is the right class of fix.

**Cross-check fix commits against xfail commits.** Rule 12 (no impl without preceding xfail) means each fix commit should have a paired xfail commit earlier on the branch. Talon did this cleanly: `bee71be` (xfail tests for C1+I1–I4) precedes `0f5dd15` (C1 fix) and the four I-fix commits. Verifying this chain confirms the tests would have failed before the fixes, which is the load-bearing property of a regression test.

## Observations for future reviews

- `getline < file` in awk can block on FIFOs/special devices, but I3's absolute-path skip makes the practical risk near-zero. Flagged as non-blocking observation.
- I4 only strips `#` on the `tests_required:` branch; other frontmatter fields still accept `"proposed # TODO"` as a valid non-empty value. Not a new bug — original `length(v) > 0` check still works — but worth noting for consistency in a future pass.
- The fixed hook's rule-4 existence check via `getline _ < full_path` is a 1-byte read followed by `close()`. Cheap and safe for regular files; unsafe for special files (FIFOs) which are unlikely in a git-tracked repo.

## Lane hygiene

Preflight `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2` — correct lane. Prior CHANGES_REQUESTED and new APPROVED are both on this lane, so GitHub correctly sees the state transition (not a conflict with Lucian's lane).
