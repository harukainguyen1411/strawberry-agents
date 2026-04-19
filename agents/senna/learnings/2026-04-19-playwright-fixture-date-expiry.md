# Playwright fixture date expiry math

**Date**: 2026-04-19
**PR**: harukainguyen1411/strawberry-app#39 (T10 usage-dashboard e2e)

## Pattern

When a Playwright fixture contains sessions with hardcoded `startedAt` dates and
the test asserts an exact row count based on a relative date-range filter (e.g.
"last 30 days"), the expiry date is determined by when the *earliest session
that contributes a distinct agent/project* rolls out of the window — not when
the *last session* rolls out.

Vi documented expiry as 2026-05-17 (last session + 30 days). Actual breakage:
- Leaderboard count (`toHaveCount(5)`) breaks **2026-05-05** (Viktor's session rolls out).
- Project breakdown count (`toHaveCount(3)`) breaks **2026-05-08** (work/mmp session rolls out).

The mistake: conflating "when the dashboard goes empty" with "when assertions fail."
Assertions on distinct group counts fail the moment any group loses its last session.

## Rule of thumb

For each exact-count assertion, find the session whose agent/project has the
smallest number of sessions in the filter window (often 1). That session's date
+ filter-days is the real breakage date.

## Mitigation

Replace hardcoded `startedAt` values with dates relative to `new Date()` computed
at fixture-install time. The `playwright.config.ts` `webServer.command` one-liner
(which already runs `fs.copyFileSync`) is a natural place to do this via a small
fixture-generator script.
