# Ekko Last Session — 2026-04-19

## Accomplished
- Promoted `plans/proposed/2026-04-19-tests-dashboard-tasks.md` → approved (commit 82aee96, pushed clean).
- Promoted `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md` → approved (commit 8e7e794, pushed clean). Required: adding `<!-- orianna: ok -->` annotation on the proposed-new script path and deleting a stale fact-check report that was confusing the script's glob-based "latest report" logic.

## Open threads / blockers
- `orianna-fact-check.sh` latent bug: glob picks report by alphabetical order, not mtime. If a new report has a lexicographically earlier timestamp than an old stale one, the old one wins and causes a false failure. File as a follow-up task.
- Prior thread still active: Duong must re-paste Firebase service account JSON into FIREBASE_SERVICE_ACCOUNT on harukainguyen1411/strawberry-app.
