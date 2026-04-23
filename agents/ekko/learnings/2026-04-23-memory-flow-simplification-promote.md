# 2026-04-23 — Memory flow simplification ADR promote

## What happened

Committed untracked Swain ADR `plans/proposed/personal/2026-04-23-memory-flow-simplification.md`
and promoted it proposed→approved in one clean session.

## Outcomes

- Commit SHA: `32f24be` (ADR commit)
- Orianna sign SHA: `d925e0e` (0 blocks, 0 warns, 17 info)
- Promote SHA: `6840d19`
- Final path: `plans/approved/personal/2026-04-23-memory-flow-simplification.md`

## Patterns that worked

- Well-authored plan: all suppressor markers had reason suffixes (`-- <explanation>`),
  all prospective paths were clearly marked, all Open Questions had explicit Picks.
  Orianna passed first-shot with 0 blocks.
- `git restore --staged .` before each sign/promote call is still good hygiene even
  in a quiet tree — no race condition this session, but the habit pays off.
- `STAGED_SCOPE` auto-derived by orianna-sign.sh from PLAN_REL — no need to export
  separately when the plan path is the only staged file.
