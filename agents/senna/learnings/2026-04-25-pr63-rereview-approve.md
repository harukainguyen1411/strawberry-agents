# PR #63 — Re-review APPROVE (Plan A G1, agent-feedback-system)

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#63
**Head:** `6488f3fc`
**Verdict:** APPROVE (round 2, after CHANGES_REQUESTED at `0bfb2dfb`)
**Lane:** strawberry-reviewers-2

## Context

Round-1 review flagged 4 critical issues: B1 fork-bomb (install-hooks.sh shim ↔ dispatcher recursion), B2 idempotency violated when `--out` lives inside `--dir`, I1 pipe-injection in markdown table, I2 silent overwrite of staged INDEX.md edits. Viktor's three fix commits (`f812d179` xfail tests, `1d70a49a` impl, `6488f3fc` INDEX regen) addressed all four.

## Verification approach

1. Cloned branch into `/tmp/pr63-review` (depth 1).
2. Ran full bats suite: TT2 23/23 + TT3 13/13 green locally.
3. **Reintroduction sanity-check** for each fix: removed the guard, re-ran the relevant test, confirmed it fails. Restored before next test.
   - B2: removing `INDEX.md` + `$out` skip → TT2-B2 fails.
   - I2: removing INDEX-only-staged guard → TT3-I2 fails.
   - I1: removing pipe escape → TT2-I1 **still passes** (test is weak; documented as non-blocking suggestion).
   - B1: code-read only — `core.hooksPath`-equals-dispatcher-dir guard is structurally correct.

## Key learning — test guard strength

**A test that lights up green when the bug is reintroduced is not a regression guard.** TT2-I1 counts data rows (`grep -c '^|'`) and asserts `data_rows == 1`. With pipe injection, the bad output still has exactly 1 data row — the pipe-shift just corrupts columns within the row, doesn't add extra rows. The test passes either way.

**Rule of thumb for re-review:** when validating that an xfail test catches a regression, don't trust the green checkmark alone. Reintroduce the bug locally and confirm the test goes red. If it stays green, flag it as a weak guard even if the underlying fix is correct.

This is a strengthening of my round-1 reflex (write tests that actually exercise the failure mode). Round-2 added: **verify the test exercises the failure mode by reintroducing the bug**.

## Fixes — quality summary

- **B1**: `scripts/install-hooks.sh:147-159` resolves `core.hooksPath` to absolute and short-circuits the shim if it equals the dispatcher dir. Fallback loop remains harmless because guard fires first in production. TT3-B1's macOS-compatible 10s background+poll is a clean replacement for missing `timeout(1)`.
- **B2**: `feedback-index.sh:264-265` skips INDEX.md + `$out` in mtime loop. `mktemp "$out.XXXXXX"` ensures atomic rename on same fs.
- **I1**: `feedback-index.sh:351-355` escapes `|` via `sed 's/|/\\|/g'` for free-form fields (author/slug/cost). Fix is correct; test is weak (see above).
- **I2**: `pre-commit-feedback-index.sh:52-60` rejects commits with only `INDEX.md` staged. Clean error message points user to the source file.

## Macros

- `scripts/reviewer-auth.sh --lane senna gh pr review` — submitted approval cleanly.
- Reintroduce-the-bug pattern with `python3` heredoc for in-place string edits is more reliable than `sed -i` when shell quoting gets in the way.

— Senna
