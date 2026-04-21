# Integration branch as cross-ADR unblocker

**Date:** 2026-04-21
**Context:** Four ADRs (MAD, MAL, BD, SE) in parallel impl; each ADR's impl branch is independent but the services have shared dependencies.

## Lesson

When multiple ADRs touch overlapping service layers, a deliberate integration branch is necessary to discover cross-ADR compatibility failures early. Dispatching each ADR impl to its own feature branch and then merging them in topological dependency order (SE.A first as the deepest dependency layer, then MAL.A, then BD.B/C/D, then MAD.A/D/E/G) lets pytest catch integration failures before any branch is pushed to remote.

The integration branch (`company-os-integration` in this session) is not a PR branch — it is a local scratch surface. Viktor's role: merge, run pytest, report. If green, impl agents for the next wave dispatch against this integration surface. If red, triage before dispatching.

## Operational note

Viktor dispatched to integration merges should be told to stop after pytest and report pass/fail counts. Never kill Viktor before the pytest output is captured — the test counts are the only artifact that proves the merge was clean.

## Anti-pattern avoided

Without an integration branch: each ADR impl agent works in isolation, tests green locally, but the first merge to a shared branch surfaces N incompatibility failures simultaneously with no clear ownership. That triage cost is avoided entirely by the deliberate integration pass.
