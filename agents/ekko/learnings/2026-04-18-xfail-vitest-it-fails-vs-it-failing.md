---
date: 2026-04-18
topic: Vitest xfail API — it.fails not it.failing
---

# Vitest xfail: it.fails, not it.failing

## The defect
Vitest 4.x exports `it.fails` (not `it.failing`). `it.failing` is Playwright's API.
When Vitest encounters `it.failing(...)` it throws `TypeError: it.failing is not a function`,
the file fails to parse, zero tests register, and the suite appears green — a silent defeat.

## Fix applied (2026-04-18, commit 11d4566)
Both xfail detectors updated to accept `it\.fails|it\.failing`:
- `.github/workflows/tdd-gate.yml` line 74
- `scripts/hooks/pre-push-tdd.sh` line 72

`it.failing` remains valid for Playwright E2E tests; `it.fails` is the canonical Vitest form.

## Verification step
After seeding an xfail in a Vitest file, always run `pnpm -C <pkg> test:unit` locally.
Confirm the xfail file appears in the test count with "failing as expected" status.
If the count is 0 or the file is absent, the API call silently failed — fix before committing.
