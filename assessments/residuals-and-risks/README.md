# Residuals and Risks

This is the canonical registry for deferred engineering debt and risk items that have been consciously scoped out of active work. Each risk lives in its own file so it can be linked, tracked, and resolved independently.

**Conventions:**
- One file per risk, named `YYYY-MM-DD-<kebab-slug>.md` where the date is when the risk was first surfaced.
- Entries are append-only. Do not delete a risk file until the resolving plan reaches `implemented/`.
- To pick up a risk: write a plan that references the risk file path. When the plan is `implemented/`, the risk file may be archived or deleted.

---

## Index

### concurrent-coordinator-lock

Risks surfaced during Senna's review of PR #22 (flock-based coordinator lock, merged `94c65ca`). Plan context: `plans/implemented/personal/2026-04-22-concurrent-coordinator-race-closeout.md`.

- [`2026-04-22-coordinator-lock-pid-write-race.md`](2026-04-22-coordinator-lock-pid-write-race.md) — I1: Lockfile PID-write race (very-low / cosmetic)
- [`2026-04-22-coordinator-lock-pid-wrap.md`](2026-04-22-coordinator-lock-pid-wrap.md) — I2: PID-wrap / stale-lock false positive (low / high-friction)
- [`2026-04-22-coordinator-lock-bashpid-test-gap.md`](2026-04-22-coordinator-lock-bashpid-test-gap.md) — $BASHPID test coverage gap (low / moderate)
