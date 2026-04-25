# Key Scripts

Reference table for operational scripts. See `architecture/platform-parity.md` for platform coverage.

## Core Lifecycle Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| Orianna agent (`.claude/agents/orianna.md`) | Invoke via Agent tool with `PLAN_PATH` and `TARGET_STAGE` | Promote a plan — reads plan, renders APPROVE or REJECT, on APPROVE moves file, rewrites `status:`, commits with `Promoted-By: Orianna` trailer, pushes. Valid stages: `approved`, `in-progress`, `implemented`, `archived`. Never use raw `git mv` for this. |
| `scripts/safe-checkout.sh <branch>` | `bash scripts/safe-checkout.sh my-branch` | Safe branch switch — never use raw `git checkout` |
| `scripts/worktree-add.sh <path> [options]` | `bash scripts/worktree-add.sh /tmp/my-worktree -b my-branch` | Safe worktree creation — thin wrapper around `git worktree add`. Fails loudly if `core.hooksPath` is not set in repo-local config; run `install-hooks.sh` first. All worktrees created via this wrapper automatically inherit hooks via `core.hooksPath`. |
| `scripts/install-hooks.sh` | `bash scripts/install-hooks.sh` | Install git hook dispatchers into `scripts/hooks-dispatchers/` (tracked, in-repo) and set `core.hooksPath = scripts/hooks-dispatchers` so all worktrees of this clone share the same hooks. Re-run after pulling new sub-hooks. Idempotent. |
| `tools/decrypt.sh` | Called internally by scripts needing secrets | Decrypt age-encrypted secrets; keeps plaintext in child process env only. Never call `age -d` directly. |

## Quality / Security Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/hooks/commit-msg-no-ai-coauthor.sh` | Installed via `scripts/install-hooks.sh` dispatcher (commit-msg phase) | Rejects commits whose message contains AI co-author trailers — `Co-Authored-By:` lines matching Claude/Anthropic/AI/bot/assistant (word-boundary) or `@anthropic.com`/`@claude.com` domains. Enforces global CLAUDE.md rule "Never include AI authoring references in commits." Escape hatch: `Human-Verified: yes` (exact case) anywhere in the message. Exit `0` = clean or escape hatch; `1` = AI trailer detected (offending line echoed to stderr). |
| `scripts/hooks/pre-commit-secrets-guard.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Guards: `BEGIN AGE` outside encrypted/, raw `age -d` outside helper, bearer-token shapes, decrypt-and-scan staged files |
| `scripts/hooks/pre-commit-staged-scope-guard.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Prevents cross-agent commit sweeping (incidents: Syndra co-author sweep, Ekko `10f7581`). When `STAGED_SCOPE` env var (or `.git/COMMIT_SCOPE` file) is set, any staged path outside the declared list causes a hard reject (exit 1) with offending paths echoed. Unscoped commits warn (exit 0) if >10 files or >3 top-level dirs. `STAGED_SCOPE='*'` (exact asterisk) is the bulk-operation escape hatch. Follow-up adoption plan: `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md`. | `0` = pass/escape hatch/warning; `1` = out-of-scope paths found |
| `scripts/hooks/pre-commit-zz-plan-structure.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Pre-commit structural lint for staged `plans/**/*.md`. Enforces 5 Orianna-parity rules at `git commit` time (see `architecture/plan-lifecycle.md` §Pre-commit structural lint): (1) canonical `## Tasks` heading required — variant spellings like `## Task breakdown (Foo)` rejected; (2) per-task `estimate_minutes: <int in [1,60]>` key:value required on task line; (3) test-task qualifiers (`xfail`/`test`/`regression`) require approved action verb (`Write`/`Add`/`Create`/`Update`) or `kind: test` token; (4) cited backtick paths must exist on disk (`<!-- orianna: ok -->` suppresses for prospective paths); (5) forward self-references (plan citing its own promoted path) require `<!-- orianna: ok -->`. Skips `plans/archived/**` and `plans/_template.md`. Grandfathering: hook only inspects staged diffs; quiet-on-disk plans are unaffected until next edit. |
| `scripts/hooks/pre-commit-t-plan-structure.sh` | Installed via dispatcher (legacy) | Legacy pre-commit linter enforcing rules 1–2 only (frontmatter + estimates). Superseded by `pre-commit-zz-plan-structure.sh` which extends coverage to rules 3–5. |
| `scripts/lint-subagent-rules.sh` | `bash scripts/lint-subagent-rules.sh` | Diff canonical inline rule blocks in `.claude/agents/*.md` against Sonnet-executor and Opus-planner reference sets, reporting drift |
| `scripts/list-agents.sh` | Via `/agent-ops list` | List all agents (TSV or JSON) |
| `scripts/new-agent.sh <name>` | Via `/agent-ops new <name>` | Scaffold a new agent directory |

## Orianna v2 — Plan Promotion

Orianna is a callable agent. She promotes plans. No signing scripts needed.

| Item | Usage | Purpose |
|------|-------|---------|
| `.claude/agents/orianna.md` | Invoked via Agent tool | Reads plan + requested stage, renders APPROVE or REJECT, on APPROVE does the git mv + commit + push |
| `agents/orianna/memory/git-identity.sh` | Run at session start | Sets `user.email = orianna@strawberry.local` and `user.name = Orianna` |
| `scripts/hooks/pre-commit-plan-promote-guard.sh` | Via dispatcher | Enforces promotion authorization (Orianna identity + `Promoted-By:` trailer, or admin identity) |
| `scripts/hooks/_orianna_identity.txt` | Read by hook | Single-line canonical email for the hook's identity check |

See `architecture/plan-lifecycle.md` for the full promotion flow.

**v1 scripts archived at** `scripts/_archive/v1-orianna-gate/` and `scripts/hooks/_archive/v1-orianna-gate/`. Reference: `architecture/archive/v1-orianna-gate/key-scripts-excerpt.md`.

## Hooks — Dispatcher Location and Propagation

Hooks live at `scripts/hooks-dispatchers/` (tracked in-repo, committed). This directory is set as the git `core.hooksPath` for the repo, which means:

- All worktrees of any clone share the same dispatchers automatically — no per-worktree hook installation needed.
- New worktrees created via `scripts/worktree-add.sh` confirm hook inheritance at creation time.
- Re-run `bash scripts/install-hooks.sh` after pulling a commit that adds or removes sub-hooks (in `scripts/hooks/*.sh`) to regenerate the dispatchers.
- The stale `.git/hooks/` and `.git/worktrees/*/hooks/` directories are inert once `core.hooksPath` is set; they may be deleted manually but are harmless.
- **Feature branches forked before this PR merged lack the `scripts/hooks-dispatchers/` directory.** Because `core.hooksPath = scripts/hooks-dispatchers` is a relative path resolved against the worktree root at hook-trigger time, any worktree checked out to such a branch will silently have no hooks fire (git emits a warning to stderr but does not block). Mitigation: `git merge main` (or `git rebase main`) on any open feature branch to pick up the `scripts/hooks-dispatchers/` directory. Worktrees on un-merged branches have no hook coverage until then.

## Notes

- Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) must be POSIX-portable bash — runnable on both macOS and Git Bash on Windows.
- Platform-specific scripts live under `scripts/mac/` (iTerm, launchd) and `scripts/windows/` (Task Scheduler, PowerShell wrappers).
- Full platform matrix: `architecture/platform-parity.md`.
