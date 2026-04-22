# 2026-04-22 — Promote concurrent-coordinator-race-closeout proposed→approved→in-progress

## What happened

Promoted `2026-04-22-concurrent-coordinator-race-closeout.md` through the full
two-hop Orianna gate chain.

## Blocks encountered

### Hop 1: proposed → approved

Two initial block findings from Orianna:
- Both cited `plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md` in
  the frontmatter `related:` and in the References section. The plan actually lives at
  `proposed/`, not `in-progress/`. Fixed both citations.

Pre-commit hook then surfaced additional blocks on the fix commit:
- Bare `.git/` directory tokens (lines 48, 99, 102, 130, 149) crash awk's `getline`
  when the hook tries to check them as file paths. Each needs an inline
  `<!-- orianna: ok -- reason -->` suppressor on the same line.
- Bare `<!-- orianna: ok -->` markers (T11.c enforcement) — all three in Tasks required
  reason suffixes.
- Prospective (not-yet-created) paths: `scripts/__tests__/test-orianna-sign-lock.sh`,
  `scripts/__tests__/test-coordinator-lock-shared.sh`, `scripts/_lib_coordinator_lock.sh`
  needed `<!-- orianna: ok -- prospective ... -->` suppressors.
- Bare script names without full paths (`orianna-sign.sh`, `plan-promote.sh`,
  `_lib_coordinator_lock.sh`, `safe-checkout.sh`) — replaced with full
  `scripts/orianna-sign.sh` etc. and added suppressors for existing scripts.

### Hop 2: approved → in-progress

No blocks. Task-gate-check passed cleanly (7 tasks, all with estimate_minutes,
first two kind: test, Test plan section present).

## Key SHAs

| Action | SHA |
|--------|-----|
| Body/suppressor fix commit | `872c92a` |
| approved sig | `d5aad17` |
| approved promote | `195f8d4` |
| in_progress sig | `23145ab` |
| in-progress promote | `adfd13f` |

## Pattern to remember

When a plan references `.git/<anything>` in backticks, every line with such a token
needs its own `<!-- orianna: ok -- reason -->` suppressor — the suppressor on the
preceding line does not carry over to continuation lines.

Prospective files (test files, new lib files described as "new" in Tasks) always need
`<!-- orianna: ok -- prospective ..., not yet created -->` on the same backtick token.
