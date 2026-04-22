# 2026-04-22 — preview-iframe-staleness-triage plan promote

## Task
Promote `plans/proposed/work/2026-04-22-preview-iframe-staleness-triage.md` through proposed → approved → in-progress.

## Outcome
Both hops completed cleanly in a single session. No blocks, no contamination, no retries.

## Key SHAs
- approved sign commit:    6955ded
- approved promote commit: 338460d (pushed)
- in_progress sign commit: 0279780
- in_progress promote commit: 7bd09d3 (pushed)

## Final path
`plans/in-progress/work/2026-04-22-preview-iframe-staleness-triage.md`

## Why it was clean
- Plan already had all `<!-- orianna: ok -->` suppressors from Karma's rewrite at ef3cb49.
- Orianna gate: 0 blocks both phases (14 info on approved; 0 blocks on task-gate-check).
- No parallel-agent contamination — used `git restore --staged .` before each sign call.
- orianna-sign.sh STAGED_SCOPE auto-derived correctly from PLAN_REL each time.

## Protocol reminder
Always `git restore --staged .` before calling orianna-sign.sh, even in a solo session. The shared working tree can have foreign staged files from prior failed operations.
