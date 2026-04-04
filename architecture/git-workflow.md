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

## Operational Files (outside git)

Ephemeral runtime state in `~/.strawberry/ops/` (gitignored):

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats, registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |

Canonical reference: `GIT_WORKFLOW.md` at repo root.
