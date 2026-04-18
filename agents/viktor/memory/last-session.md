# Last Session — 2026-04-18 (testing-process team, wave 4+5 boundary)

## PRs open at session close

- **#153** (`chore/f1-f2-f4-auth`) — F1+F2 auth middleware. Tip `c9020c0`. Jhin LGTM. Awaiting Duong merge.
- **#180** (`chore/i1-deploy-dashboards`) — I1 deploy script fixes. Tip `1b4673b`. Jhin LGTM R40 + Azir LGTM. Awaiting Duong merge.
- **#182** (`chore/f3-cors-middleware`) — F3 CORS middleware. Tip `a5f9fde`. Jhin R39 LGTM + Azir LGTM. Awaiting Duong merge.

## Key decisions this session

1. **#159 already merged** — all fix commits went to new PR #180. Always check `gh pr view <n> --json state` before pushing to a merged branch.
2. **xfail files renamed** — `*.xfail.test.ts` → `*.test.ts` after impl flips them to passing. Done on #153 (`f5da253`). Attempted on #182 but blocked by pre-push hook false positive — merge as-is.
3. **Pre-push TDD hook gap** — hook scans push delta only, not branch history. Rename-only commits to `dashboards/server` after xfail is already on remote get incorrectly blocked. Flagged to Evelynn as Ekko follow-up.
4. **F3 cherry-picked from Vi's xfail-seed-cluster** — `a3386e0` + `fb9ad3e`. Avoids reimplementation, preserves TDD chain.
5. **I1 deploy script fixes**: gcr.io → AR host (`$REGION-docker.pkg.dev/$PROJECT/strawberry-images/$SERVICE_NAME`), `#!/bin/sh` + `set -eu`, `--allow-unauthenticated` comment, `--service-account dashboards-cloudrun@...`, `pnpm --filter` → `npm run build --workspace`.

## Wave-5 queue (next spawn)

- H2 — smoke test reporter wiring (post-deploy)
- I4 — smoke extension for test-dashboard surface
- H1 — unit reporter wiring (once C2+D1+D2 all land)
