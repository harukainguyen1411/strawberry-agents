---
agent: senna
date: 2026-04-26
topic: PR review — statusline claude-usage shell script (PR #85)
verdict: advisory LGTM (commented)
---

# PR #85 — Talon's `scripts/statusline/claude-usage.sh`

Concern: personal. Lane: `strawberry-reviewers-2`. Verdict: COMMENTED (advisory
LGTM — Lucian had already APPROVED on plan-fidelity grounds).

## Verified

- Rule 12: `df36d0b1` (xfail) precedes `802da708` (impl). xfail marker
  `# xfail: <plan> T2` is on line 2 of the test file. T1 commit adds *only* the
  test, no impl files.
- shellcheck clean on both files.
- 9/9 test cases pass post-impl (5 documented + helper assertions).
- macOS + Git-Bash portability: `date -r` BSD → `date -d "@$epoch"` GNU
  fallback. Both branches probed.
- No shell injection: `display_name` like `$(touch /tmp/pwned)` rendered
  literally, no command-sub. JSON parse delegated to `jq`.

## Minor flags I posted (none blocking)

1. Non-numeric `used_percentage` → `printf '%.0f'` fallback yields ugly
   `5h 0abc%`. On a TTY, downstream `[ -le 50 ]` emits "integer expression
   expected" to stderr. Suggested a numeric clamp.
2. Newline in `display_name` → rendered verbatim, breaks one-line invariant.
   Low risk (locally generated JSON) but `tr -d '\n\r'` on MODEL would be
   defensive.
3. `OUT_B=$(NO_COLOR=1 printf ... | bash "$SUBJECT")` scopes `NO_COLOR=1` to
   `printf`, not `bash`. Tests still pass because the pipe-capture defeats
   `[ -t 1 ]` color detection — but intent is misexpressed.

## Patterns worth keeping

- Statusline scripts MUST never exit non-zero (Claude Code surfaces errors as
  visual breakage). This impl uses `set -uo pipefail` (note: no `-e`) plus a
  `_degraded` fallback on parse failure. Correct pattern.
- BSD/GNU `date` epoch conversion: try `date -r "$epoch"` first, fall through
  to `date -d "@$epoch"` on stderr-suppressed failure. Returns from helper on
  first success.
- When reviewing shellcheck-claimed scripts: actually run shellcheck, then run
  the tests, then probe injection vectors with `$(...)` and newline-in-field.
  Three minutes total, catches the difference between "syntactically clean"
  and "robust".
