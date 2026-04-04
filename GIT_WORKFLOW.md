# Git Workflow — Strawberry

## Branch Naming

| Prefix | Use |
|---|---|
| `feature/` | New features, new agent capabilities |
| `fix/` | Bug fixes |
| `chore/` | Maintenance, cleanup, config changes |
| `docs/` | Documentation only |

## Three-Tier Commit Policy

### Tier 1 — Agent State
**Scope:** `agents/*/memory/`, `agents/*/learnings/`, `agents/*/journal/`
**Policy:** Direct to main. No PR.
**Prefix:** `chore:`
**Notes:** Evelynn sweeps agent state via `commit_agent_state_to_main` after sessions. Agent-scoped files — PRs add zero review value.

### Tier 2 — Operational Config
**Scope:** `agents/memory/agent-network.md`, `.mcp.json`, `plans/`, minor MCP server tweaks (docs, descriptions, non-breaking parameter changes)
**Policy:** Direct to main with a descriptive commit message.
**Prefix:** `chore:` or `ops:`
**Notes:** Living docs that change frequently. PR ceremony adds no value for a solo setup.

### Tier 3 — Feature Work
**Scope:** New MCP servers, new tools, breaking changes to `mcps/*/server.py`, GitHub Actions workflows, new apps, architecture changes
**Policy:** Feature branch + PR.
**Prefix:** `feature/`, `fix/`
**Notes:** PRs provide a diff to review, a rollback point, and a record of what changed. Anything that changes how agents communicate or introduces new capabilities must go through a PR.

## Rule of Thumb

If it changes how agents talk to each other or adds new capabilities → **PR**.
If it's updating config, docs, or agent state → **direct to main**.

## Workflow (Tier 3)

1. Create a branch from `main`
2. Commit with clear messages — what changed and why
3. Push and create a PR — include `Author: <agent-name>` in the PR description
4. Review — Lissandra or Rek'Sai review if code changes are involved
5. Merge via PR (squash or merge commit, no rebase)
6. Delete the branch after merge

## Agent Attribution

Every PR must identify the agent who created it. Include `Author: <agent-name>` in the PR description. This applies to all agents — if Bard opens a PR, the description says `Author: Bard`.

## Hard Rules

- Never force-push. Never rebase. Always merge.
- Never commit secrets, credentials, or `.env` files
- Agent state belongs on main only — never commit `agents/` to feature branches
- Never auto-resolve agent state merge conflicts — always manually merge
- One logical change per commit — don't mix unrelated work
- Delete branches after merge

## Operational Files (outside git)

Ephemeral runtime state lives in `~/.strawberry/ops/`, NOT in the git repo:

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats, registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |

These directories are gitignored. The MCP server reads/writes them via the `OPS_PATH` env var.

## Commit Messages

- Imperative mood, concise, explain the why
- No AI authoring references
- Avoid shell-unfriendly characters in commit commands
