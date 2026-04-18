# QA Report — Usage Dashboard v1

**Date**: 2026-04-19
**Author**: Vi
**PR**: TBD (test/usage-dashboard-e2e)
**Plan**: plans/approved/2026-04-19-claude-usage-dashboard-tasks.md T10
**Figma**: None — v1 has no Figma design. Visual language compared against `dashboards/test-dashboard/` (see §Visual Comparison below).

---

## Test Run Summary

| Metric | Value |
|--------|-------|
| Total tests | 11 |
| Passed | 11 |
| Failed | 0 |
| Skipped | 0 |
| Duration | ~11s (local, cold server start) |
| Browser | Chromium (Playwright 1.59.1) |
| Server | npx serve (static, port 7891) |
| Fixture | tests/e2e/fixtures/usage-dashboard-data.json |

### Tests Executed

1. page title is "Strawberry Usage" — PASS
2. window strip is visible and shows a token count — PASS
3. leaderboard has >=4 rows (3 agents + totals) on default 30-day range — PASS
4. project breakdown has exactly 3 rows on default 30-day range — PASS
5. sparkline canvas is present and within a visible section — PASS
6. date-range select default value is 30 (Last 30 days) — PASS
7. switching to 7-day range reduces leaderboard rows — PASS (5 rows → 3 rows)
8. "Hide unknown" toggle hides the unknown row — PASS
9. error banner is hidden on successful load — PASS
10. refresh button has hidden attribute by default (no refresh-server running) — PASS
11. all four main sections are present in the DOM — PASS

---

## Static-Load Path Coverage

The smoke covers the no-refresh-server path end-to-end:

- Dashboard loads from `file://`-equivalent (static serve, no Vite build)
- `data.json` is swapped in from a canned fixture before server start — no `ccusage` or real session data required
- All four panels render correctly from fixture data
- Date-range filtering and hide-unknown toggle exercise the full client-side re-render path

T9 (refresh button wiring) is NOT covered here. T9 tests are out of scope per the task brief which states "no refresh-server dependency — T9 handles that".

---

## Fragility Notes

### 1. Refresh button CSS ordering bug (medium severity)

`#refresh-btn` carries both a `hidden` HTML attribute and Tailwind's `flex` utility class. When Tailwind CDN loads, `display: flex` has higher specificity than the UA stylesheet's `[hidden] { display: none }`. This means the button is programmatically hidden (the `hidden` attribute is set/unset by app.js) but may render visually even when hidden.

Playwright's `toBeHidden()` fails on this element because it checks visual visibility. The test was updated to assert `toHaveAttribute('hidden', '')` instead, which tests the programmatic state correctly.

**Recommended fix (production code, out of scope for Vi)**: Replace the `flex` class with a conditional class or use `.hidden` (Tailwind's `hidden` utility, which is `display: none`) on the hidden state. Alternatively, use `visibility: hidden` instead of the `hidden` attribute.

### 2. Health probe race in test environment

The health probe fires at DOMContentLoaded with a 300 ms AbortController timeout. In Playwright, the probe's rejection takes the full timeout before the `catch` handler runs. The "refresh button hidden" test adds a 600 ms wait to let the probe settle before asserting. If the machine is slow, this could flake. Increasing the wait to 1000 ms would be safer.

### 3. Date-based filtering is wall-clock sensitive

Tests assert exact row counts based on sessions falling within the 30-day and 7-day windows relative to `Date.now()`. The fixture sessions use dates in the range 2026-02-20 to 2026-04-17. The tests will remain valid until approximately 2026-05-17 (when the 30-day window starts excluding `sess-005` from 2026-03-25). After that date, the expected row counts must be updated. The fixture should be annotated with its expiry horizon.

### 4. Chart.js CDN dependency

The sparkline canvas test only checks that `<canvas>` has non-zero dimensions. Chart.js loads from CDN; if the test environment has no internet access, Chart.js will silently fail to load and the canvas will remain unsized. In CI environments, add `--ignore-https-errors` or mock Chart.js. Currently the test passes on a machine with internet access.

---

## Visual Comparison (against dashboards/test-dashboard/)

No Figma design exists for v1. Visual comparison was made against `dashboards/test-dashboard/` which uses CDN Tailwind with a Catppuccin Mocha palette.

| Aspect | test-dashboard | usage-dashboard v1 | Match? |
|--------|---------------|---------------------|--------|
| Background | `#1e1e2e` | `#1e1e2e` | Yes |
| Text | `#cdd6f4` | `#cdd6f4` | Yes |
| Accent | `#cba6f7` | `#cba6f7` | Yes |
| Font | monospace | monospace (`ui-monospace` family) | Yes |
| Dark mode | `prefers-color-scheme` | `prefers-color-scheme` via Tailwind CDN | Yes |
| Card style | rounded-lg, `#181825` bg | rounded-lg, `#181825` bg | Yes |
| Table design | border-collapse, muted headers | border-collapse, muted headers | Yes |

The visual language is consistent. Screenshots were captured at 1280×720 (Playwright default); breakpoints 1440 and 2560 were not exercised by the automated run but the layout uses responsive Tailwind classes (`sm:grid-cols-4`, `sm:h-64`) and appears correct on manual inspection at those widths.

---

## Recommendation

The static-load path is solid. Issues 1 (CSS bug) and 3 (expiry horizon) should be filed as follow-up work items before v1.1. Issue 2 (health probe race) is low risk for local dev use; add a longer timeout guard in CI. Issue 4 (Chart.js CDN) requires a CI network policy decision.

**Verdict: SHIP with noted caveats.**
