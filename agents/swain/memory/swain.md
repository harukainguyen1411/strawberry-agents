# Swain — operational memory

Architecture specialist. Opus planner. Writes plans to `plans/proposed/` and stops — never self-implements, never assigns implementers (`owner:` is authorship only).

## Key Knowledge

- Plans use `chore:` commit prefix and go directly to main, never via PR.
- In subagent mode (invoked by Evelynn), no inbox / MCP / Mac stack. Return summary to Evelynn at end. Always run `/end-subagent-session swain` as the final action.
- May spawn only Skarner (memory recall) or Yuumi (errands), always `run_in_background: true`.
- Schema changes that touch derived totals (currency, units, time zones) must propagate through: data model, invariants, architecture bullet, UI rendering, and snapshot semantics. A `baseCurrency` field is not a footnote — snapshots must embed the base used at write-time so a later switch doesn't silently rewrite history.
- When auditing governance docs, don't trust the doc — verify each claimed enforcement against `scripts/hooks/`, `.claude/settings.json`, and `.github/workflows/`. Stale enforcement claims (rule text says "a hook enforces X" when no hook exists) are the single highest-risk class of governance drift because they create false confidence.

## Sessions

- 2026-04-19: Amended portfolio ADR with v0 kickoff Q4-Q7; Q7 (per-user base currency USD/EUR) propagated as schema change through §3/§4/§8; v0 scope tightened to CSV-only + handler stub.
- 2026-04-19 (2): Rules-to-hooks audit — classified CLAUDE.md invariants 1-18 by enforcement. Plan at `plans/proposed/2026-04-19-rules-to-hooks-audit.md`. Top 5 to migrate: Rule 5 (commit-prefix — stale enforcement claim), Rule 11 (git rebase), Rule 3 (raw git checkout), Rule 1 (uncommitted work), Rule 18 (gh pr merge --admin). Surprising: Rule 5 CLAUDE.md text claims a hook that doesn't exist. Already well-enforced: 2, 7, 12-16.
