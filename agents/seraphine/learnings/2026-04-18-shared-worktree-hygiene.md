# Shared worktree hygiene — 2026-04-18

## The problem
Strawberry is a shared working tree. Multiple agents write to `agents/<name>/memory/` and `agents/<name>/learnings/` concurrently. `git add -A` or `git add .` silently sweeps in other agents' untracked files. By the time a reviewer sees the PR, it carries files from agents who never touched your task.

## Rules
- Never `git add -A` or `git add .`
- Always stage by explicit path: `git add path/to/file1 path/to/file2`
- Before every commit: run `git status` and `git diff --cached --stat` — verify only your intended files are staged
- If you see `agents/<other>/` files staged, unstage with `git restore --staged <path>`

## Undoing committed contamination
`git merge origin/main` does NOT remove files already committed into your branch history. To strip them:
```sh
git restore --source=origin/main --staged <contaminating-file>
git restore --source=origin/main <contaminating-file>
git commit -m "chore: strip contamination"
```
Verify with `gh api repos/Duongntd/strawberry/pulls/<N>/files` — GitHub's PR diff is authoritative, not local `git diff origin/main --stat` (which includes the base branch's own changes vs main).

## Vitest xfail API
- Vitest 4.x: `it.fails("xfail: ...", () => { throw new Error("not implemented") })`
- NOT `it.failing` (that's Playwright's API)
- Wrong API = TypeError at parse time = zero tests register = silent no-op defeat
- Verify: after committing xfail, run `pnpm -C <pkg> test:unit` and confirm the file appears in the test count

## @vitejs/plugin-react version
- v6 requires Vite 6; current stack uses Vite 5.x
- Pin to `^4` (latest: v4.7.0) for Vite 5 compatibility
