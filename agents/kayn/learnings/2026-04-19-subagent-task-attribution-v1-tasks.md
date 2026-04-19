# Learning — v1 task breakdown for subagent-task attribution ADR

Date: 2026-04-19
Agent: kayn
Session type: subagent (spawned by Evelynn)

## Task

Produce the v1 tasks plan for the now-approved subagent-task attribution ADR. v1 = capture pipeline only (hook + scanner + aggregate); v2 = Panel 5 UI (out of scope this breakdown).

## Artifacts

- Plan: `/Users/duongntd99/Documents/Personal/strawberry-agents/plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution-tasks.md`
- Commit: `29b7b62` on `main` (pushed).
- Task count: **4** — T0 (hook amendment) + AT.1 (scanner) + AT.2 (build.sh integration) + AT.3 (mtime cache).

## Key calls during breakdown

1. **Task ID scheme** — kept Azir's `AT.N` prefix to mirror the ADR's own `T0/T1/T2/T3/T4` shorthand from the Handoff Notes, but renamed T1→AT.1 etc. to avoid collision with the parent usage-dashboard plan's T1–T10. T0 (the prerequisite hook amendment) kept its name because the ADR uses it verbatim.
2. **Cross-repo split explicit.** T0 lives in `strawberry-agents` (hooks); AT.1–AT.3 live in `strawberry-app` (scripts pipeline). Called out upfront in "Cross-repo operating rules" and again in Risks so the executor doesn't trip on the repo switch.
3. **T0 is xfail-exempt.** Settings-only shell-hook edit; no test harness exists for `.claude/settings.json`. Verification is manual. Noted explicitly so executors don't spin trying to invent a test for it.
4. **AT.3 was kept as a separate task.** ADR lists mtime cache as a first-class v1 component under Phases §v1. Could have been folded into AT.1 but kept separate because (a) it adds a subtle `mtimeCache ↔ retention` lockstep invariant worth its own test, and (b) it can merge in parallel with AT.2 once AT.1 lands.
5. **Sentinel-after-scan race.** Documented as an explicit scanner-level invariant (re-check sentinel on cached hit if prior `closed_cleanly:false`). Without it, every spawn captured within the 10-minute gap between SubagentStop and next scan tick would stay permanently `false`. ADR didn't call this out; surfaced it during breakdown.
6. **`agents.json` decoupling.** AT.1 must tolerate absent `agents.json` to stay unit-testable (test 8). Production always has it per ADR §Scope Delta (build.sh order), but the scanner test shouldn't require the full pipeline.
7. **No Duong-blockers.** All seven ADR open questions resolved in the ADR's §Resolutions Log. Two minor executor-level calls (regex reuse pattern in AT.1, mtime cache placement in AT.3) noted with recommendations — neither blocks dispatch.

## Patterns that carried over from prior sessions

- Task-summary table + dependency graph + parallelism section + explicit "Out of scope" block. Same shape as my tests-dashboard and portfolio-v0 breakdowns.
- xfail-first commit + test-case enumeration inside each task; every test references the plan path per CLAUDE.md rule 12.
- Risk section at the end surfaces invariants executors might miss (lockstep cache, sentinel race, commit-prefix scope).
- No implementer assigned (plan-writers-no-assignment convention; Evelynn's call).

## What went smoothly

- ADR was unusually well-scoped after Azir's v1/v2 phase split — every v1 component already tagged with a Decision ref. Breakdown was mostly "turn Decision refs into atomic tasks + write tests."
- The harness-native data finding (Evelynn's 2026-04-19 learning) meant no instrumentation tasks at all — just a scanner. Kept the task count down to 4.

## What to do differently next time

- When the parent ADR has a Handoff Notes section that already enumerates task slices (like this one did: T0/T1/T2 for v1), use it as the spine of the breakdown and add verification/TDD depth on top. Faster than fresh decomposition. Did that here and it worked well.
- Continue flagging cross-repo splits explicitly at the top. This is the second ADR this week (alongside the public app-repo migration) where v1 straddles repos; executors need that signpost or they'll commit in the wrong tree.
