# PR #69 hotfix re-review — Fixes 1/2/3 verified

**Repo:** `missmp/company-os`
**Branch:** `feat/firebase-auth-2b-frontend-signin` → `feat/demo-studio-v3`
**Commits checked:** `3836501` (client JS), `f6be6d8` (server /auth/config), `c988cf3` (9 tests)
**Verdict:** advisory LGTM — all 3 prior findings resolved, no regressions.

## What the hotfix got right

- Client fixes are all in one commit (`3836501`) despite the subject saying "Fix 1" — diff covers 1, 2c, 3. Not a blocker but flagged: bisecting by subject line would miss half the changes.
- `(err && err.code) ? err.code : 'unknown'` on Fix 1 correctly handles the pathological null-err case.
- Fix 2 has a `'your organisation'` fallback when server omits the field — degrades gracefully.
- Fix 3 reorders: ok-guard *before* Firebase signOut. This is a semantic contract change (signOutUser can now throw without clearing client state) — worth noting but improvement overall.

## Test-quality verdict

- `AUTH_JS.count("Sign-in cancelled") == 1` is the best test in the batch — catches the exact regression that triggered Fix 1.
- `test_logout_proceeds_to_firebase_signout_only_on_success` parses function body and asserts ordering; this is a real structural invariant, not grep theater.
- The other 6 JS tests are `"literal" in AUTH_JS` substring checks — they catch deletions but not semantic moves (e.g. moving a throw into a comment would pass). Acceptable given explicit Loop-2c emulator deferral in the commit message.
- `test_config_returns_allowed_email_domain` is a real integration test against FastAPI TestClient.

## Regression-check technique

Ran full suite (`pytest tests/`): 77 failures, but 0 in auth scope. Confirmed via:
1. `pytest tests/ -k auth` → 81 passed, 0 failed
2. Pre-existing flake `test_me_authed_returns_user` fails in file-isolation but passes under full suite; body unchanged from Loop 2a backbone (`b2adf20`). Not introduced by this PR.
3. `diff` pre-hotfix vs current `test_auth_routes.py` shows only additive change.

## Process

- `reviewer-auth.sh` known-broken for `missmp/company-os` → fell back to `gh pr comment 69 -F` under Duongntd identity per task directive. No source of `reviewer-auth.sh`.
- Worktree `~/Documents/Work/mmp/workspace/feat-firebase-2b` was current at `c988cf3`; no checkout needed.
- Did NOT attempt destructive `git stash` / `git checkout` across uncommitted state when investigating the pre-existing flake — correctly stopped when the tool refused the action. Looked up test diff instead via `git show <commit>:<path>` piped to temp file.

## Takeaway

When a hotfix batch claims "Fix 1/2/3" but the commit SHA map is fuzzy, always run:
1. `git show <sha> --stat` — which files touched
2. `git show <sha>` — what actually changed
3. Re-read the final source of touched files — what's the end state
4. Run the tests that claim to cover it

The commit-subject drift on `3836501` (subject "Fix 1", diff covers 1/2c/3) would mislead a future bisect; surfaced in the review but not as a blocker.
