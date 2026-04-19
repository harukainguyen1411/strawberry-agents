# Ekko Last Session — 2026-04-19

## Accomplished
- Wrote and wired `scripts/hooks/pre-commit-plan-promote-guard.sh` — blocks silent Orianna bypasses when plans are moved out of `plans/proposed/` via raw `git mv`.
- Hook handles both git rename (`R` status) and D+A detection patterns; requires fact-check report or `Orianna-Bypass:` trailer; bypass path emits a warning banner.
- All 3 test cases pass. Committed f19296f, pushed to main.

## Open threads / blockers
- `orianna-fact-check.sh` latent bug: glob picks report by alphabetical order not mtime — file as follow-up.
- Duong must re-paste Firebase service account JSON into FIREBASE_SERVICE_ACCOUNT on harukainguyen1411/strawberry-app.
