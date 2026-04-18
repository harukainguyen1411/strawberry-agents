# 2026-04-18 — strawberry-app clone

## Task
Clone `harukainguyen1411/strawberry-app` to `~/Documents/Personal/strawberry-app`.

## Result
- Clone succeeded cleanly via `gh repo clone`.
- HEAD: `dc64379` (Merge PR #18 smoke-test-migration).
- `apps/` contains 10 subdirectories: `coder-worker`, `contributor-bot`, `deploy-webhook`, `discord-relay`, `landing`, `myapps`, `platform`, `private-apps`, `shared`, `yourApps`.
- No `bee` directory present — either renamed or never migrated.
- Repo is public; remote is `https://github.com/harukainguyen1411/strawberry-app.git`.

## Notes
- `gh repo clone <owner>/<repo> <path>` works correctly for this account/repo combo.
- Local checkout path `~/Documents/Personal/strawberry-app` is now the canonical working directory for strawberry-app code sessions (matches CLAUDE.md spec).
