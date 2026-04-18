# PR #25 + #26 Review Fixes — 2026-04-19

## Context
Jhin returned REQUEST_CHANGES on both PRs. All four items were in test code owned by Vi.

## Key Learnings

### bats-core: `run --separate-stderr` is required to populate `$stderr`
Without `run --separate-stderr`, `$stderr` is always empty/undefined. Tests asserting
`[[ "${stderr:-}" != *"PATTERN"* ]]` silently pass whether or not stderr has content.
Fix: always use `run --separate-stderr` when the test needs to inspect stderr output.
This generates a BW02 warning (informational only) suggesting `bats_require_minimum_version 1.5.0`.

### Vacuous pass pattern: negative-output tests need LIB existence guards
Any test that asserts "this value is NOT in output" will vacuously pass when the lib is
absent because there's no output at all. Add `[ -f "${LIB}" ] || return 1` before the
`run` block in all such tests (T4, T8b confirmed; T6c/T8d already had it).

### Pre-commit hook catches `age -d` in bats test names
The secrets guard scans staged file content for `age[[:space:]]+-d` after stripping
comment lines. Bats test names (inside double-quotes after `@test`) are NOT stripped.
If a test name includes `age -d` as literal text, the hook fires.
Fix: rephrase test names to avoid the literal `age -d` pattern. Use "decrypt flag" or
"backslash-continuation decrypt bypass" instead.

### Multiline `age -d` detection: awk join before grep
Single-line grep cannot detect `age \\\n  -d` split across physical lines.
Use awk to join backslash-continued lines first, then grep the joined output.
The pre-commit hook's own pattern does NOT catch this bypass (it uses single-line grep).

### check-no-bare-deploy.sh: false-positive filtering needed for narrowed exclusion
When the exclusion is narrowed from `--exclude __tests__` to `--exclude __tests__/fixtures/`,
the gate starts picking up `firebase deploy` strings in:
- bats test names (`@test "... bare firebase deploy ..."`)
- single-quoted string args (`'firebase deploy --project ...'`)
- printf format strings (`printf 'PASS... firebase deploy ...'`)
- shell comment lines (after `#`)
Solution: add grep -v filters for each case after the main grep pipeline.

### C1 rewrite: test real auth guard behavior, not constant equality
BEE_INTRO_MESSAGE constant equality is a tautology — the test duplicates the definition.
Better: mock `onCall` to return the raw handler function (instead of void), then call
the handler directly with a no-auth request and assert `HttpsError("unauthenticated", ...)`.
This tests a real behavioral contract (auth guard rejects unauthenticated callers) without
hitting Firebase, Gemini, or Firestore.

### I1 (pinning vitest version) blocked by package.json ownership
Review item I1 asks to pin `"vitest": "^4.0.18"` to exact. But `package.json` is Jayce's
file (implementation owner). Vi does not touch it. Flag to Evelynn for Jayce to handle.
