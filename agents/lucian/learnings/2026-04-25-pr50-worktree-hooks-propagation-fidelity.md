# PR #50 — worktree hooks propagation fidelity

**Date:** 2026-04-25
**Verdict:** APPROVE
**Plan:** `plans/approved/personal/2026-04-25-worktree-hooks-propagation.md`
**Review:** https://github.com/harukainguyen1411/strawberry-agents/pull/50

## Summary

Clean fidelity pass. All 6 tasks (T1–T6) implemented in correct TDD order on a single branch:

1. `6cffb258` — xfail tests for INV-1/2/3 (T1)
2. `33c4f641` — install-hooks.sh switch + dispatchers committed (T2/T3)
3. `dc7ce19f` — worktree-add.sh wrapper + INV-3 test fix (T4)
4. `e164b3b6` — docs (T5/T6)

Rule 12 satisfied: xfail commit lands first, references plan slug.

## Notable design decisions verified

- **Migration logic in install-hooks.sh:** keeps the legacy early-out for `core.hooksPath`, but tightens it so that the old `.git/hooks` default *and* the new default both auto-migrate to the new tracked location. Only a true manual override (anything else) wins. Matches plan §T2 DoD exactly.
- **`git config --local` in wrapper:** plan §T4 stated rationale was that a global gitconfig setting must not mask a missing repo config. Implementation reads with `--local`, satisfying the propagation-correctness requirement.
- **Dispatchers tracked + committed:** plan §Decision explicitly accepted this trade-off; not a drift concern despite being generated artifacts.

## Drift notes (non-blocking, surfaced)

- Wrapper accepts any non-empty `core.hooksPath` value, not strictly `scripts/hooks-dispatchers`. Plan T4 DoD only required "refuses unless set" — matches contract, but worth knowing for future tightening.
- Re-running `install-hooks.sh` after adding a sub-hook produces a tracked dispatcher diff that needs committing. Expected per ADR.

## Pattern: TDD-clean infra/tooling change

This PR is a model example of how an infra-only/tooling plan should ship:

- Three invariants explicitly named in plan §Test plan
- Each invariant maps to a concrete xfail test assertion that flips green only when the impl lands
- Soft-xfail pattern (`exit 0` when target file absent, hard fail when present-but-wrong) keeps pre-push TDD gate happy across the xfail commit
- POSIX-bash discipline maintained throughout (T4 wrapper is 33 lines)

## Review-process notes

- Confirmed identity (`strawberry-reviewers`) before posting via `scripts/reviewer-auth.sh gh api user`.
- Single tool call (`gh pr view --json files,commits,...`) gathered enough context to verify scope and ordering without iterative diff fetches.
