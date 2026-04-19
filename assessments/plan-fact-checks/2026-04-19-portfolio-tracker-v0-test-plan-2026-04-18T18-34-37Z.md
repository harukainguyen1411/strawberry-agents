---
plan: plans/proposed/2026-04-19-portfolio-tracker-v0-test-plan.md
checked_at: 2026-04-18T18:34:37Z
auditor: orianna
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 10
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Claim:** `assessments/qa-reports/2026-04-DD-portfolio-v0/` | **Anchor:** line 489 of plan | **Result:** author-suppressed via `<!-- orianna: ok -->` (date placeholder `DD`; path will materialize at QA time) | **Severity:** info

2. **Claim:** `assessments/qa-reports/2026-04-DD-portfolio-v0/report.md` | **Anchor:** line 507 of plan | **Result:** author-suppressed via `<!-- orianna: ok -->` (forward reference to QA report) | **Severity:** info

3. **Claim:** `scripts/test-tdd-gate.sh` | **Anchor:** line 555 of plan | **Result:** author-suppressed via `<!-- orianna: ok -->` (forward reference to V0.19 deliverable) | **Severity:** info

4. **Claim:** unknown path prefix `functions/` (e.g. `functions/__tests__/onSignIn.test.ts`, `functions/portfolio-tools/money.ts`, many others) | **Anchor:** n/a | **Result:** cross-repo path under `harukainguyen1411/strawberry-app/apps/myapps/portfolio-tracker/functions/` per plan Conventions §Path root; prefix `functions/` not in contract routing table | **Severity:** info — add to contract if load-bearing

5. **Claim:** unknown path prefix `src/` (e.g. `src/components/__tests__/MoneyCell.test.ts`, `src/views/__tests__/CsvImport.test.ts`, `src/composables/__tests__/usePortfolio.integration.test.ts`) | **Anchor:** n/a | **Result:** app-relative per Conventions §Path root; prefix `src/` not in contract routing table | **Severity:** info

6. **Claim:** unknown path prefix `test/` (e.g. `test/fixtures/t212-sample.csv`, `test/rules/firestore.rules.test.ts`) | **Anchor:** n/a | **Result:** app-relative per Conventions §Fixture root; prefix `test/` not in contract routing table | **Severity:** info

7. **Claim:** unknown path prefix `e2e/` (e.g. `e2e/v0-happy-path.spec.ts`, `e2e/artifacts/v0-happy/`) | **Anchor:** n/a | **Result:** app-relative; prefix `e2e/` not in contract routing table (contract lists `tests/e2e/` for cross-repo) | **Severity:** info — add to contract if load-bearing

8. **Claim:** unknown path prefix `users/` (e.g. `users/A`, `users/B/trades/...`, `users/A/positions/AAPL`, `users/u1/meta/fx`) | **Anchor:** n/a | **Result:** Firestore document paths, not repo paths; prefix `users/` not in contract routing table | **Severity:** info

9. **Claim:** unknown path prefix `meta/` (e.g. `meta/fx`, `meta/fx missing`) | **Anchor:** n/a | **Result:** Firestore sub-document reference, not a repo path | **Severity:** info

10. **Claim:** unknown path prefix `harukainguyen1411/` (in `harukainguyen1411/strawberry-app/apps/myapps/portfolio-tracker/`) | **Anchor:** n/a | **Result:** repo-qualified path used to establish the Conventions §Path root; not a repo-relative path and not in contract routing table | **Severity:** info
