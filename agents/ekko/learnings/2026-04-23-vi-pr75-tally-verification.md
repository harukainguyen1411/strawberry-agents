# Vi PR #75 Tally Verification

Date: 2026-04-23
Branch: feat/firebase-auth-2c-impl @ 047e025
Concern: work

## Finding

Ran `python -m pytest tests/ --tb=no -q` from `tools/demo-studio-v3/` (must run from that dir — conftest_results_plugin.py is in module root, not on sys.path when invoked from repo root).

Result: **73 failed, 949 passed, 17 skipped, 146 xfailed, 0 xpassed** — exact match to Vi's claim.

## Worktree note

Existing worktree at `/Users/duongntd99/Documents/Work/mmp/workspace/feat-firebase-2c-impl` was already on this branch at the correct commit. No new worktree needed.

## Pytest invocation

Must `cd` into `tools/demo-studio-v3/` before running — `conftest_results_plugin` is a module in that directory and fails to import if pytest is invoked from above.
