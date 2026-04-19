# PR #46 E2E Failure Diagnosis — 2026-04-19

## Context
Branch: `fix/tdd-gate-enable-functions`, HEAD commit `beca79d` (Duong's Firebase boot fix).
E2E (Playwright) and CI both still red on `beca79d`.

## Two Distinct Failures

### Failure A — Missing linux snapshots (7 tests)
`visual-regression.spec.ts` calls `toHaveScreenshot()` expecting linux PNG baselines.
The committed snapshots are named `*-chromium-darwin.png` (generated on macOS).
CI runner is linux; Playwright expects `*-chromium-linux.png`.
All 7 visual tests fail with:
> "A snapshot doesn't exist at …/home-dark-chromium-linux.png, writing actual."

Root cause: snapshots were generated locally on macOS (my T10 session) and committed without
linux counterparts. This is my commit from the T10 session (in `598d0eb`).

### Failure B — Navigation test for non-existent link (1 test)
`navigation.spec.ts:69` does:
```
await page.getByRole('link', { name: 'MyApps' }).click()
```
AppHeader.vue has no link with the text "MyApps". The home link uses `$t('common.home')`
(i18n key rendering as "Home" or locale equivalent). There is no "MyApps" branded link in the header.
Test times out after 30 s across 3 retries.

Root cause: the navigation test references a link that does not exist in the actual component.
The test was written speculatively and was never validated against the real header markup.
This is also from my `598d0eb` commit (T10 session).

## Relationship to Duong's beca79d Commit
Duong's commit correctly fixed the Firebase boot crash (VITE_E2E guard) and the portfolio-tracker
lint error. These were NOT the cause of the current failures. The current failures pre-date `beca79d`
and were present on `4310c4c` too (visible in CI: the `CI` job also failed on `4310c4c` for the same
reasons).

## Proposed Fix

### Fix A — Generate linux snapshots
Run `playwright test visual-regression.spec.ts --update-snapshots` in a linux environment
(GitHub Actions ubuntu runner, or docker --platform linux/amd64). Commit the resulting
`*-chromium-linux.png` files under `apps/myapps/e2e/visual-regression.spec.ts-snapshots/`.

Shortcut: add `--update-snapshots` flag to the CI run once, let it write the baselines,
download the artifacts, commit them. Then remove the flag.

### Fix B — Fix the navigation test locator
In `apps/myapps/e2e/navigation.spec.ts:69`, change:
```ts
await page.getByRole('link', { name: 'MyApps' }).click()
```
to target the actual header home link — either by the i18n text or by the router-link's aria-label:
```ts
await page.getByRole('link', { name: 'Dark Strawberry home' }).click()
// OR: await page.locator('a[href="/"]').first().click()
// OR: await page.getByRole('link', { name: /home/i }).first().click()
```
Then verify the test passes locally before committing.

## Classification
- Failure A: regression introduced by my `598d0eb` commit (T10 session) — snapshots generated on wrong OS platform.
- Failure B: new bug introduced by my `598d0eb` commit (T10 session) — locator written against non-existent UI element.
- Duong's `beca79d`: unrelated fix; did not cause either failure; did not regress earlier work.
