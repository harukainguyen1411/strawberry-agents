# Katarina

## Role
- Fullstack Engineer — Quick Tasks

## Sessions
- 2026-04-03: First session. Verified HTML tasklist UI, ported 4 features to Vue migration (myapps PR #53), fixed touch drag regression. **Why:** Neeko's design work needed QA and Ornn's Vue port was missing features.

## Known Repos
- strawberry: Personal agent system (this repo)
- myapps (github.com/Duongntd/myapps): Personal apps — Vue 3 + Vite + Firebase + Tailwind. Has strict pre-commit hooks (typecheck + tests + lint). **Why:** Needed for tasklist work.

## Working Notes
- myapps pre-commit runs vue-tsc --noEmit — unused vars will block commits
- CLAUDE.md says no rebase, always merge — followed this when remote diverged
