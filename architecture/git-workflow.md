# Git Workflow

## Three-Tier Commit Policy

| Tier | Scope | Policy | Prefix |
|---|---|---|---|
| **1 — Agent State** | `agents/*/memory/`, `learnings/`, `journal/` | Direct to main, no PR | `chore:` |
| **2 — Operational Config** | `agents/memory/agent-network.md`, `.mcp.json`, `plans/`, `architecture/`, minor MCP tweaks | Direct to main | `chore:` / `ops:` |
| **3 — Feature Work** | New MCP servers, new tools, breaking changes, GHA workflows, new apps, architecture changes | Feature branch + PR | `feature:` / `fix:` |

### Rule of Thumb

- Changes how agents communicate or adds new capabilities → **PR**
- Updating config, docs, or agent state → **direct to main**

## Branch Naming

| Prefix | Use |
|---|---|
| `feature/` | New features, capabilities |
| `fix/` | Bug fixes |
| `chore/` | Maintenance, cleanup, config |
| `docs/` | Documentation only |

## PR Workflow (Tier 3)

1. Create branch from `main`
2. Commit with clear messages (what + why)
3. Push and create PR
4. Review — Lissandra or Rek'Sai for code changes
5. Merge via PR (squash or merge commit, no rebase)
6. Delete branch after merge

## Hard Rules

- Never force-push. Never rebase. Always merge.
- Never commit secrets, `.env` files
- Agent state belongs on main only — never on feature branches
- Never auto-resolve agent state merge conflicts
- One logical change per commit
- Delete branches after merge
- No AI authoring references in commits
- Avoid shell-unfriendly characters in commit commands
- PRs with significant changes must update relevant READMEs
- **Gitignore-on-first-use:** When creating a new tool or app directory, add its build output patterns to `.gitignore` in the same commit that creates the directory. Build artifacts (`.turbo/`, `dist/`, `lib/`, `node_modules/`, `__pycache__/`) must never appear in `git status`.

## Build Artifact Guard (pre-commit hook)

`scripts/hooks/pre-commit-artifact-guard.sh` blocks commits that include build artifact paths. It runs as part of the pre-commit hook dispatcher installed by `scripts/install-hooks.sh`.

To install (if not already active):

```bash
bash scripts/install-hooks.sh
```

Patterns blocked: `node_modules/`, `.turbo/`, `.firebase/`, `__pycache__/`, `apps/functions/lib/`.

## Agent Attribution

Every PR must identify the agent who created it. Include `Author: <agent-name>` in the PR description. This applies to all agents — if Bard opens a PR, the description says `Author: Bard`.

## Review Protocol

Reviewers (Lissandra, Rek'Sai) must verify the documentation checklist in the PR:
- If the PR touches `mcps/`, `architecture/`, or `agents/memory/agent-network.md` — corresponding docs must be updated
- If the PR adds/removes features — `README.md` must reflect the change
- Block the PR if docs are missing for qualifying changes

## Git Safety — Shared Working Directory

**Never leave work uncommitted.** If you create or modify a file, commit it before doing anything else with git (checkout, stash, pull, merge). Uncommitted files in a shared working directory WILL be lost when another agent switches branches.

**Concurrent branch work:** Use `git worktree` instead of `git checkout`:
```bash
git worktree add /tmp/strawberry-feature-xyz feature/xyz
# Work in /tmp/strawberry-feature-xyz — doesn't touch the main working tree
git worktree remove /tmp/strawberry-feature-xyz
```

**Branch switching:** Never use raw `git checkout`. Use `scripts/safe-checkout.sh` instead — it checks for uncommitted changes before switching.

## Operational Files (outside git)

Ephemeral runtime state in `~/.strawberry/ops/` (gitignored):

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats, registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |
