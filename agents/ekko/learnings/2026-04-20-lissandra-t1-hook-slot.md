# Learning: Lissandra T1 — hook matrix slot registration pattern

Date: 2026-04-20
Task: T1 from 2026-04-20-lissandra-precompact-consolidator.md

## Pattern

When adding a new single-lane Sonnet agent, the xfail test strategy for T1-type tasks is:
- Existing bats file is at `scripts/__tests__/pre-commit-agent-shared-rules.xfail.bats`
- Add two xfail cases: one proving `model: sonnet` on the new slot exits 0, one proving `model: opus` exits non-zero (error)
- Before impl, case 1 fails (hook sees unknown slot → treats as Opus → rejects sonnet) and case 2 fails (produces only a warning, not an error)
- After adding to `is_sonnet_slot()`, both flip to passing

## File locations

- Hook: `scripts/hooks/pre-commit-agent-shared-rules.sh` — `is_sonnet_slot()` function around line 65
- Tests: `scripts/__tests__/pre-commit-agent-shared-rules.xfail.bats`

## Note

The test file name uses `.xfail.bats` but the tests in it are NOT all xfail — only the new T1 cases were xfail; they graduate to passing after impl. The file is a living test file, not a snapshot.
