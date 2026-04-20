# 2026-04-20 — Orianna gate-v2 wiring into plan-promote.sh (T2.4, T6.1, T6.2, T6.4, T6.5)

## Context

Second REFACTOR queue session for
`plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`.
Jayce's BUILDER queue (orianna-sign.sh, orianna-verify-signature.sh) landed as
commits b3dd49a / 1b13f29. Tasks T2.4 + T6.1-T6.5 unblocked.

## Key learnings

### T2.4 — install-hooks.sh dispatcher is already dynamic

The dispatcher in `install-hooks.sh` uses `scripts/hooks/<verb>-*.sh` glob
at call-time — no hardcoded allowlist. New hooks in `scripts/hooks/` are
automatically picked up on every commit without any install-hooks.sh change.
T2.4's "wire" requirement was satisfied by adding a comment block listing all
sub-hooks for operator visibility. The idempotency guarantee is in the
dispatcher replacement logic (lines 37-39: if a strawberry-managed dispatcher
already exists, it's replaced entirely, never appended to).

### Parallel agent index contamination

When Vi (or another agent) runs `git add` in the shared working tree and then
does not commit, those staged files persist in the `.git/index`. A subsequent
`git add scripts/plan-promote.sh` did NOT clear them — they remained staged.
The pre-commit freeze hook then blocked the commit with a false alarm about
"new plan files being created."

Resolution: `git restore --staged -- plans/` to unstage only the plan files,
leaving `plan-promote.sh` staged. Always run `git diff --cached --name-status`
BEFORE committing to see the full staged set.

Pattern to remember:
```sh
git restore --staged -- <path>   # unstage by path, leaves other staged files
git diff --cached --stat          # verify exact staged set before commit
```

### T6.4 — gate-version branch placement

The `orianna_gate_version` read must happen AFTER `gdoc::require_tools` and
`gdoc::require_clean` (so the source file is confirmed present and clean)
but BEFORE the Drive unpublish step (to avoid unpublishing a plan that will
fail gate-v2). The correct insertion point is step 3.5 in the existing script
structure (which is where the legacy fact-check lived).

### T6.1/T6.2 — phase name normalization

`TARGET_STATUS` uses hyphens (`in-progress`) but `orianna_signature_*` field
names use underscores (`orianna_signature_in_progress`) per §D1. A single
`case` statement maps the status to the signature phase name:
```sh
case "$TARGET_STATUS" in
  in-progress) _sig_phase="in_progress" ;;
  *)           _sig_phase="$TARGET_STATUS" ;;
esac
```
`orianna-verify-signature.sh` and `orianna-sign.sh` both expect the underscore
form for phase arguments. Consistent with how phases appear in those scripts.

### T6.5 — behavior preservation is correctness

The task says "retire fact-check call site on v2 path". This is a behavior
change that MUST be accompanied by clarity that fact-check still runs (inside
orianna-sign.sh). The comment in plan-promote.sh explicitly states this. If
someone reads only plan-promote.sh they should understand why there is no
fact-check call on the v2 path — the code comment points at §D2.1 / §D6.4.

### T6.2 — carry-forward loop pattern

Prior phases are enumerated as a space-separated string, not an array, for
POSIX sh compatibility:
```sh
case "$_sig_phase" in
  in_progress)  _prior_phases="approved" ;;
  implemented)  _prior_phases="approved in_progress" ;;
  *)            _prior_phases="" ;;
esac
for _prior in $_prior_phases; do
  "$SCRIPT_DIR/orianna-verify-signature.sh" "$SOURCE" "$_prior" >&2 || ...
done
```
The empty-string case (`approved`) avoids a spurious loop iteration — `for x in ""`
would iterate once with x="", which would call verify with an empty phase. Using
a truly empty string (not quoted) lets the for loop skip entirely.

## Commits

- T2.4: `f81aa35` — install-hooks.sh comment block
- T6.1+T6.2+T6.4+T6.5: `ac168ea` — gate-v2 logic in plan-promote.sh

## Test results

- `bash scripts/hooks/test-plan-promote-guard.sh`: 5/5 PASS before and after
- shellcheck: only pre-existing SC1091 + SC2231 info-level warnings (unchanged)
- Manual gate-logic tests: TEST A (v1 path), TEST B (v2 missing sig blocked),
  TEST C (v2 invalid sig blocked) — all correct
