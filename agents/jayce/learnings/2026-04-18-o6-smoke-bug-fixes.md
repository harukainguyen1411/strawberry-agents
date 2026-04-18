# 2026-04-18 — O6 smoke bug fixes (orianna CLI flags + brace-expansion)

## What was fixed

Three bugs caught by Vi during O6 smoke testing of Orianna:

### Bug 1 — orianna-fact-check.sh: invalid claude CLI flags
- `--non-interactive` does not exist in the claude CLI. The script already had `--print`
  which is sufficient (alias `-p`). Removed `--non-interactive`.
- `--system` is not a valid flag; the correct flag is `--system-prompt`.

### Bug 2 — orianna-memory-audit.sh: multiple invalid flags
- `--subagent orianna` → `--agent orianna`
- `--non-interactive` → removed (use `-p` / `--print`)
- `--prompt "$TASK_PROMPT"` → positional argument `"$TASK_PROMPT"` (no flag needed)
- Added `--dangerously-skip-permissions` for consistency with orianna-fact-check.sh

### Bug 3 — fact-check-plan.sh: brace-expansion false positives
- Tokens like `agents/orianna/{profile.md,memory/MEMORY.md,learnings/index.md,inbox.md}`
  were treated as literal paths and flagged as BLOCK findings.
- Fix: added `*\{*|*\}*` case to the token-skip block (same block as glob/template/bracket
  filters). One line, no other changes needed.

## Actual claude CLI flag names (verified via `claude --help`)

| Old (wrong)         | Correct             |
|---------------------|---------------------|
| `--non-interactive` | `-p` / `--print`    |
| `--system "..."`    | `--system-prompt "..."` |
| `--subagent <name>` | `--agent <name>`    |
| `--prompt "..."`    | positional arg      |

## TDD process

xfail tests committed first (tests 8-13 in orianna-fact-check.xfail.bats):
- Tests 8, 9: grep for invalid flags in orianna-fact-check.sh
- Tests 10-12: grep for invalid flags in orianna-memory-audit.sh
- Test 13: temp plan with brace-expansion token, expects exit 0

All tests failed before the fix; all 13 pass after.

## Smoke results

- `fact-check-plan.sh` on known-clean plan: exit 0, block: 0, warn: 0, info: 15
- `orianna-fact-check.sh` (fallback path) on known-clean plan: exit 0, block: 0
- `orianna-memory-audit.sh`: runs past all prerequisite checks into claude invocation
  (no longer exits immediately with unknown-flag error)
