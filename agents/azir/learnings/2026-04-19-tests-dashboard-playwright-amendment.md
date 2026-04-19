# 2026-04-19 — tests-dashboard ADR amendment: Playwright E2E as first-class v1 writer

## Context

Scoped amendment to `plans/proposed/2026-04-19-tests-dashboard.md`. Duong asked to elevate Playwright E2E from a v2 concern to a first-class v1 writer, on par with Vitest and pytest. The original ADR only named Vitest reporter + pytest plugin as writers and left Playwright undefined.

## What changed

- Added **D4b** — custom Playwright reporter decision, mirroring D4's shape. Same Reporter-API-based approach (reject `--reporter=json`, reject JUnit XML), same atomic-write contract, same golden-file test strategy, same peerDep pin rule, same TDD-enabled gate under Rule 12.
- Extended **D3**'s `runner` enum to include `"playwright"`.
- Added Playwright-specific optional `playwright` sub-object on test entries (project, browser, retries, trace.zip path, video, screenshots) — kept as optional nested key so pytest/Vitest entries simply omit it. This preserves top-level schema parity while carrying E2E-only enrichment.
- Moved Playwright adapter into v1 in the Features table and added a Playwright-enrichment-rendering row (browser/project filter, trace deep-links, retry count, video/screenshot links).
- Added a Playwright version-pinning risk row mirroring the Vitest one.
- Updated Handoff notes: three writers now (Vitest, Playwright, pytest patch). Added Task-1b for the Playwright reporter package, explicitly noted as parallelizable with Task-1 (no ordering dependency between the two reporter packages).
- Updated intro language: "two writers" → "three writers" in Goal section and Context gap paragraph.

## Why Playwright is v1, not v2

The load-bearing argument that justified the elevation: Rule 15 (from the deployment-pipeline plan) makes Playwright E2E a required check on every PR to main. E2E is arguably the **highest-signal** red/green surface in the system because it catches integration regressions that unit tests miss. A dashboard that cannot render E2E on day one fails to answer "is the app broken right now" for the most expensive-to-debug failure mode. Elevating it to v1 costs one more reporter package (parallelizable with Vitest reporter) and zero additional schema churn because the shared schema already handles multi-runner fan-out via D3.

## Design notes worth remembering

- **Schema parity across three writers** is maintained by keeping the top-level schema identical and putting runner-specific enrichment in optional nested sub-objects (e.g., `playwright.{project,browser,retries,trace,...}`). This pattern scales to a future bash/TAP adapter without top-level schema churn.
- **Reporter-API-based writers are the right default** across test frameworks — same tradeoff table applies to Vitest and Playwright, and would apply to Jest/Mocha/etc. if ever added. Post-processing `--reporter=json` is always strictly more plumbing because you lose the in-process hook for atomic writes and the history-ring read.
- **Parallel tasks in handoff.** Kayn can start Task-1 (Vitest reporter) and Task-1b (Playwright reporter) simultaneously. They share design-token tests (golden-file snapshots) but are independent packages with independent peerDep pins. This shortens critical path.

## Constraints respected

- Scoped amendment — no re-litigation of settled decisions (D1, D2, D5, D6, D7, D8, D9, D10 untouched).
- Repo scope unchanged: strawberry-app + strawberry-agents only.
- Did not promote the plan — stays in `plans/proposed/` per Duong's instruction.
- Commit on main with `chore:` prefix (non-code commit per Rule 5).

## Follow-up for Kayn (when plan gets promoted)

- Three writer packages, not two. Task-1 and Task-1b parallelizable. Task-2 (aggregator + shared schema) depends on the shared schema being authored first but not on either reporter shipping.
- Playwright reporter package name: `@strawberry/playwright-reporter-tests-dashboard`, sibling to `@strawberry/vitest-reporter-tests-dashboard`.
- peerDep: `@playwright/test` pinned to strawberry-app's current major at implementation time.
- Golden-file tests for Playwright reporter must cover: pass, fail with stack, retry-to-pass, retry-to-fail, timeout, skip, project/browser metadata, attachment paths (trace.zip, video, screenshots).
