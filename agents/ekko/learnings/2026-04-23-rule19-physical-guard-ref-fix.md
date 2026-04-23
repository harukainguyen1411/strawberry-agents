# 2026-04-23 — Retire stale pre-commit-plan-promote-guard refs

## Context

PR #31 (physical-guard plan) retired two commit-phase hooks:
- `scripts/hooks/pre-commit-plan-promote-guard.sh`
- `scripts/hooks/commit-msg-plan-promote-guard.sh`
- `scripts/hooks/_orianna_identity.txt`

The sole enforcement mechanism is now the PreToolUse hook at
`scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (wired via `.claude/settings.json`).

## What was stale

| File | Location | Issue |
|------|----------|-------|
| `CLAUDE.md` Rule 19 | `plans/proposed/` | Referenced retired `pre-commit-plan-promote-guard.sh`, `_orianna_identity.txt`, and non-existent `Orianna-Bypass:` trailer mechanism |
| `agents/sona/CLAUDE.md` | `rule-sona-plan-gate` | Mentioned `Rule 19 Orianna-Bypass: trailers` as a use-case for `harukainguyen1411` admin identity |
| `architecture/plan-lifecycle.md` | Related table, line ~138 | `_orianna_identity.txt` listed as active infra |
| `architecture/plan-lifecycle.md` | Authorization section | Missing `agent_type` as primary identity source; missing explicit "no Orianna-Bypass trailer" statement |

## Fixes applied

- **CLAUDE.md Rule 19**: Rewrote to describe single PreToolUse gate, full identity resolution order
  (agent_type → CLAUDE_AGENT_NAME → STRAWBERRY_AGENT → fail-closed), admin bypass identities,
  and explicit absence of Orianna-Bypass: trailer and _orianna_identity.txt file.
- **agents/sona/CLAUDE.md**: Removed `Orianna-Bypass:` trailer from list of admin-only use-cases.
  Replaced with "There is no Orianna-Bypass: trailer mechanism — see Rule 19."
- **architecture/plan-lifecycle.md**: Removed `_orianna_identity.txt` from Related table.
  Updated Authorization section to document agent_type-first identity resolution.

## Commit SHAs

- `3e0c3d9` — CLAUDE.md + agents/sona/CLAUDE.md fixes
- `f3dd1f4` — architecture/plan-lifecycle.md fix

## Watch-out

Parallel-agent staging contamination swept the `plans/implemented/personal/2026-04-23-inbox-write-guard.md`
rename into the first commit. The rename was harmless (already executed by the prior session), but it
triggered the pre-commit hook on the second commit attempt. Fix: always `git restore --staged .` before
committing when other sessions are active, or at minimum check `git diff --cached --name-only` before
every `git commit`.
