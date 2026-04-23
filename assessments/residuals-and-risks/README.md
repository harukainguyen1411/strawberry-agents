# Residuals and Risks

This is the canonical registry for deferred engineering debt and risk items that have been consciously scoped out of active work.

**Conventions:**
- One file per topic/area/incident, named `YYYY-MM-DD-<kebab-slug>.md` where the date is when the risks were first surfaced. Multiple related residual items for the same incident or area live as `##` subsections within the same file.
- Entries are append-only. Do not delete a risk file until the resolving plan reaches `implemented/`.
- To pick up a risk: write a plan that references the risk file path and subsection. When the plan is `implemented/`, the risk file may be archived or deleted.

---

## Index

### concurrent-coordinator-lock

Risks surfaced during Senna's review of PR #22 (flock-based coordinator lock, merged `94c65ca`). Plan context: `plans/implemented/personal/2026-04-22-concurrent-coordinator-race-closeout.md`.

- [`2026-04-22-coordinator-lock.md`](2026-04-22-coordinator-lock.md) — I1: Lockfile PID-write race (very-low / cosmetic) · I2: PID-wrap / stale-lock false positive (low / high-friction) · $BASHPID test coverage gap (low / moderate)
