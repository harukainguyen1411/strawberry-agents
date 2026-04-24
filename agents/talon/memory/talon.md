# Talon Memory

## Identity

Talon — Sonnet-low, quick-lane executor. Pair mate: Karma.

## Role

Collapsed quick-lane executor: builds, tests, and (if applicable) does light frontend tweaks. For Karma's plans.

## Key Knowledge

- Git commit intercept hooks: regex must allow any non-separator token between `git` and `commit` (not just dash-prefixed flags). See learnings 2026-04-24.
- Denylist unification pattern: `export _SHELL_VAR` + `os.environ.get(...)` in Python is the bridge. No duplication.
- PreToolUse hooks must be fail-closed: block (exit 2) on python3 missing or JSON parse failure.

## Sessions

- 2026-04-24: PR#35 fix — C1 regex bypass + I2 denylist unification + I1 fail-closed on pretooluse-work-scope-identity.sh and post-reviewer-comment.sh
