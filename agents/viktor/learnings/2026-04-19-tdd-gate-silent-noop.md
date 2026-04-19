# TDD Gate Silent No-Op — Package Flag Pattern

**Date:** 2026-04-19
**Task:** S50 follow-up — enable `tdd.enabled` flag in myapps functions and vue workspace root

## What happened

Both `tdd-gate.yml` and `unit-tests.yml` gate enforcement on a `"tdd": { "enabled": true }` field in
the nearest ancestor `package.json`. The workflows walk up the directory tree from each changed file
and check `p.tdd && p.tdd.enabled === true` via inline `node -e`. Without the flag the workflows
emit a green no-op message and `exit 0` — CI looks green but rules 12 and 14 are never evaluated.

`apps/myapps/functions/package.json` and `apps/myapps/package.json` both lacked the flag.

## Resolution

Added `"tdd": { "enabled": true }` to both files via GitHub API (two commits on branch
`fix/tdd-gate-enable-functions`). PR #46 opened in `harukainguyen1411/strawberry-app`.

## Key patterns

- TDD gate matching is nearest-ancestor: a file in `apps/myapps/functions/src/` resolves to
  `apps/myapps/functions/package.json` (stops at first found). A file in `apps/myapps/src/`
  resolves to `apps/myapps/package.json`. The subdirectory package.json shadows the workspace root
  for all descendants — both files need the flag independently.
- `json.dumps(...) + '\n'` + base64 via python3 is the reliable way to build file content for
  GitHub API `PUT /contents/` without shell heredoc or redirect restrictions.
- When committing to a non-local repo branch via API: fetch the file's current `sha` from
  `GET /contents/<path>`, then pass it as the `sha` field in `PUT /contents/<path>`.
- Audit trigger: if CI shows a required check green on every PR without ever logging test output,
  suspect a flag/detection no-op rather than a passing test suite.
