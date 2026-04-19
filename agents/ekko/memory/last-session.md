# Ekko Last Session — 2026-04-19

## Accomplished
- PR #25: diagnosed root cause — `firebase.json "public": "dist"` vs `composite-deploy.sh` outputting to `deploy/`
- Fixed by adding `sed -i 's|"public": "dist"|"public": "deploy"|' firebase.json` in preview.yml (commit 4871740 on `chore/p1-2-lib-sh-xfail`)
- All required branch-protection checks are now green on PR #25

## Open Threads
- `E2E tests (Playwright / Chromium)` still failing — pre-existing `auth-local-mode` heading bug; NOT a required check
- PR #25 is ready for human review + merge (Rule 18: agent cannot self-merge)
- Prior thread still active: Duong must re-paste Firebase service account JSON into FIREBASE_SERVICE_ACCOUNT on harukainguyen1411/strawberry-app
