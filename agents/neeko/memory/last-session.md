# Last Session Handoff — 2026-04-19

T4: portfolio v0 dashboard design spec (team `portfolio-v0`).

- Delivered spec at `agents/neeko/learnings/2026-04-19-portfolio-v0-design.md` — implementation-grade artifact for Seraphine (T6 blocks on this). Mirrors what should populate the Figma "Strawberry — Portfolio v0" file.
- Reused existing Warm Night tokens from `apps/myapps/portfolio-tracker/src/assets/main.css`. Proposed 3 new semantic tokens: `--positive`, `--negative`, `--warn`.
- Mobile-first 375px / 1024px+ per ADR §3. 14 new Vue components specified (AppShell, AccountSelector, SummaryCard, HoldingsTable/Row, CsvImport, DropZone, CsvPasteArea, ImportPreviewTable, Warn/ErrorBanner, EmptyState, MoneyCell, PlCell, BaseCurrencyPicker).
- Currency model per amended ADR (§3-§5): per-user `baseCurrency` (USD or EUR). Trades stored native; totals/P/L converted. Holdings table shows native avg cost + base market value/P/L. Onboarding modal forces choice on first sign-in.
- Flagged Figma-file standup as Duong-only manual step (no Figma MCP/API in session). QA gate (rule 16) needs Figma to diff against — blocks T7/T8 cleanly until file exists.

Open threads: none from my side. Seraphine has all she needs from the spec.
