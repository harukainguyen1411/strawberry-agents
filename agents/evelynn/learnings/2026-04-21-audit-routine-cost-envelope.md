# Claude Code Routines — cost envelope for scheduled audit runs

**Date:** 2026-04-21
**Source:** Lux's audit-routine ADR design session; Duong's explicit cost constraint

## The number

A single Claude Code Routine run (one full pass of the daily-agent-repo-audit-routine) costs approximately **20% of the Claude Max Pro daily context quota**. This is a Duong-supplied calibration from prior Routine experiments.

## Implications for scheduling

| Schedule | Daily quota consumed |
|----------|---------------------|
| Once/day | 20% |
| Twice/day | 40% |
| Three times/day | 60% — leaves only 40% for interactive sessions |

Scheduled routines compete directly with Evelynn's interactive coordinator budget. At 20%/run, twice-daily is likely the practical ceiling before interactive sessions are noticeably degraded.

## Design constraints this imposes

1. **Audit scope must be bounded.** The routine must NOT expand its scope dynamically (e.g., by chasing every linked file it finds). Bounded scope = predictable cost.
2. **No-op runs should be cheap.** If the repo is clean, the routine should terminate early. A routine that does full analysis even when nothing has changed wastes quota.
3. **Parallelism doesn't help.** Context quota is shared across the account. Running two audit routines in parallel burns 40% just as fast as running them serially.
4. **Manual invocation preferred for initial tuning.** Do not automate the schedule until one manual run has been observed and its actual cost measured. The 20% figure is an estimate.

## When this learning matters

Before commissioning any Claude Code Routine that runs on a recurring schedule (audit, heartbeat, memory-consolidation, inbox processing), front-load the cost calculation. 20% per run is the reference envelope; more complex routines will be higher.
