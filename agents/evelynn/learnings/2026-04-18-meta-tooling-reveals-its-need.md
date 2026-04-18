# Meta-tooling reveals its own need during the build session

## Context

Built Orianna v1 (plan-promotion fact-checker + weekly memory auditor) across one long session (S48). Scope estimated at 23 tasks, ~2h; actual time was ~5h across 6 phases with three rounds of bug surfacing during dogfood.

## Observation

Every drift class Orianna was designed to catch appeared **in the build session itself**:

- Plans with stale `plans/approved/` references after promotion (Vi caught these in dogfood)
- Brace-expansion shorthand treated as literal paths (false positive in the fallback)
- Lifecycle-narrative references flagged as current-state claims
- Meta-examples ("Firebase GitHub App") triggered blocks in prose that discussed the bug being fixed
- Forward-reference outputs (plans describing future files) blocked incorrectly
- Report-picker prefix collision shipped a false-negative into the gate itself
- Wrong `claude` CLI flags went undetected until Vi hit them

These are the exact drift categories Orianna exists to prevent. Building her without her produced all of them in real time.

## Lesson

When building meta-tooling — fact-checkers, linters, validators, gates, audit scripts — **budget 2x estimated scope and treat iterative bug surfacing as the correct signal, not a failure mode**. The build session is the first consumer, and the first consumer always finds the gaps.

## How to apply

- **Expect a dogfood phase.** Schedule it as a first-class task, not a verification step. Vi's O6.8 dogfood caught four defects that xfail unit tests didn't.
- **TDD catches mechanics; dogfood catches design.** xfail-first per Rule 12 caught regression-class bugs. Real drift classes (lifecycle narration vs. current-state claim, forward references, prose meta-examples) only surfaced when the gate ran against real plans. No test fixture would have synthesized these.
- **Plan for emergent scope.** Orianna's suppression syntax (`<!-- orianna: ok -->`) wasn't in the ADR — it emerged from dogfood false-positives. Leave ~25% of the task budget for feature gaps that appear during real-data testing.
- **Don't over-engineer the ADR.** Azir's original plan was right to defer v2 features (GitHub Actions cron, report automation) to v1.1. Shipping v1 with known gaps is better than a complete plan that never ships because scope keeps growing.
- **Watch for meta-level ironies.** The most telling: Jayce's PR #183 report-picker bug (`${BASENAME}-*.md` matching `${BASENAME}-tasks-*.md`) was a **false-negative path in Orianna's own gate**. If shipped, it would have let broken plans pass while claiming they'd been checked. Meta-tooling failure modes are often subtle because the tool validates itself.

## Applies to future work

- **Dashboard ADR (Azir, 2026-04-19)** — first consumer is Duong watching his own usage; expect UX gaps only visible when real session data lands.
- **Any future Strawberry lint / gate / validator** (slug-collision guards, memory-audit automation, CI reviewers) — plan for the build session itself to hit every class of drift the tool is meant to catch.
- **Scheduled-routine work** — automations that fire on cron have no tight feedback loop. Dogfood matters even more because bugs take a week to show up.
