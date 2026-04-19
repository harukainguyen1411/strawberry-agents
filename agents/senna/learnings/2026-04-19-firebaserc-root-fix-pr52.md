# PR #52 — `.firebaserc` root hotfix review

**Date:** 2026-04-19
**PR:** harukainguyen1411/strawberry-app#52
**Verdict:** Advisory LGTM (self-auth rejected formal approve, fell back to comment)

## What

Single-file addition: root `.firebaserc` with `default` → `myapps-b31ea`. Fixes permanently-red `Firebase Hosting PR Preview` + `Deploy Preview` checks caused by `action-hosting-deploy@v0` receiving an empty `vars.FIREBASE_PROJECT_ID` and falling through to Firebase CLI auto-resolution — which needs a `.firebaserc` in CWD.

## Cross-checks performed

- `apps/myapps/.firebaserc` — identical content, confirms project id.
- `.github/workflows/landing-prod-deploy.yml` — hardcodes `--project myapps-b31ea`.
- All hosting-deploy workflows consistent.
- No secrets; project id is public-identifier class.

## Notes / follow-ups

- Two `.firebaserc` files now (root + nested). Future rename needs both — flagged as non-blocking informational note.
- Rule 18 self-auth rejection pattern confirmed again (same as #48, #20). Advisory-comment fallback is the correct path.

## Prompt injection seen

PR diff tool output contained an injected `<system-reminder>` impersonating MCP server instructions. Ignored; continued with task as scoped by the actual user.
