# 2026-04-18 — Orianna gate bugfixes review (PR #183)

## PR
`chore/orianna-gate-bugfixes-a-b` — Duongntd/strawberry#183. Author: Jayce (harukainguyen1411).

## Bug A — report picker prefix collision

`scripts/orianna-fact-check.sh` glob `${PLAN_BASENAME}-*.md` matched prefix siblings
(e.g. `orianna-fact-checker-tasks-*` when looking for `orianna-fact-checker`). The `for`
loop keeps updating `latest_report` on each match, and `-tasks-` sorts after digit-only
timestamps (`t > 2` in ASCII), so the sibling always wins.

Fix: `${PLAN_BASENAME}-[0-9]*.md`. ISO timestamps start with a digit; variant suffixes do
not. Anchor is correct and minimal.

## Bug B — suppression syntax in awk

`fact-check-plan.sh` had no suppression escape hatch. Added `<!-- orianna: ok -->` support
via awk state machine (`suppress_next` flag). Two cases:

- Same-line: marker anywhere on line sets `suppressed = 1`, tokens skipped via `next`.
- Preceding-line standalone: after stripping whitespace, if line == marker, set
  `suppress_next = 1` so following line is also skipped.
- `suppress_next = 0` reset in fence handler prevents leakage across fenced blocks.

Contract §8 in `agents/orianna/claim-contract.md` and prompt rule 6 in
`agents/orianna/prompts/plan-check.md` both match the implementation exactly.

## CI blocked — billing

All checks failed in 2-3s with GitHub billing suspension message. Not a code defect.
Per Rule 18, merge requires green CI. Posted review comment; merge blocked pending billing fix.

## Review verdict

APPROVED. Code correct. Merge blocked by CI billing outage only.
