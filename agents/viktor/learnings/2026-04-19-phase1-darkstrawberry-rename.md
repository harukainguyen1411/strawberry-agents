# 2026-04-19 — Phase 1: apps/myapps → apps/darkstrawberry-apps rename

## What happened

Executed Phase 1 of `plans/approved/2026-04-19-apps-restructure-darkstrawberry-layout.md` across tasks P1.1–P1.7. The previous session was killed mid-flight (usage cap) after committing all 4 commits but before pushing or opening the PR. Re-dispatch started with a complete branch already present at `/private/tmp/strawberry-app-phase1` on branch `chore/phase1-darkstrawberry-apps-rename`.

## What was found

The prior run's P1.6 sweep missed 11 files. The final grep sweep (after re-dispatch) caught:
- `.github/dependabot.yml` — `directory: /apps/myapps`
- `apps/discord-relay/src/config.ts` — `TRIAGE_TARGET_SUBTREE` default
- `apps/discord-relay/README.md` — two occurrences (context path + env example)
- `apps/coder-worker/src/claude.ts` — hardcoded `cwd` path
- `apps/coder-worker/src/git.ts` — hardcoded `git add apps/myapps/`
- `apps/coder-worker/system-prompt.md` — HARD LIMIT scope + cd command (runtime content sent to Claude)
- `apps/coder-worker/README.md` — system prompt scope description
- `apps/darkstrawberry-apps/triage-context.md` — directory structure description
- `apps/darkstrawberry-apps/functions/README.md` — `cd apps/myapps && npm run dev`
- `apps/darkstrawberry-apps/functions/vitest.config.ts` — comment only
- `apps/darkstrawberry-apps/portfolio-tracker/functions/__tests__/emulator-boot.test.ts` — test description string

Key insight: `package-lock.json` retains old workspace paths until `npm install` is re-run — this is expected and does not need manual fixing.

## TDD hook encounter

The pre-push hook (`scripts/hooks/pre-push-tdd.sh`) fired on the push because `apps/darkstrawberry-apps`, `apps/coder-worker`, and `apps/discord-relay` all have `"tdd": { "enabled": true }` in their `package.json`, and the branch changed `.ts` source files in those packages. The hook Rule 1 check looks for xfail test markers in any commit in the range.

Resolution: added an empty commit with `TDD-Waiver: pure structural rename` trailer per the hook's documented bypass mechanism (line 65 of `pre-push-tdd.sh`). The hook explicitly accepts `TDD-Waiver:` as the bypass trailer. This is correct for a pure rename — no new implementation code was added.

## Lessons

1. **P1.6 sweep scope must include app-source `.ts` files** — config.ts, claude.ts, git.ts all had hardcoded paths. The prior sweep focused on `.yml`, `.sh`, and `.md` but missed runtime source.
2. **`coder-worker/system-prompt.md` is load-bearing** — it's sent verbatim to Claude Code at runtime. The `apps/myapps/` HARD LIMIT inside it would have caused the coder-worker to reject all issues post-rename. Critical to catch.
3. **`dependabot.yml` has `directory:` fields** — these are package-ecosystem directory paths and must be updated with the app rename.
4. **Pre-push TDD hook fires on .ts files in TDD-enabled packages** — a rename touching any `.ts` source in a TDD-enabled package will trigger Rule 1. Always add a `TDD-Waiver:` commit at the tip for pure-rename branches before pushing.
5. **Worktree already existed from prior killed session** — checking `git worktree list` first avoided a wasted attempt to create a new worktree. Always check existing worktrees on re-dispatch.

## PR

PR #62 opened in `harukainguyen1411/strawberry-app`. Branch `chore/phase1-darkstrawberry-apps-rename`. Not self-merged per Rule 18. Awaiting Senna + Lucian review.
