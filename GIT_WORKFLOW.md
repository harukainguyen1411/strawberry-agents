# Git Workflow — Strawberry

## Branching Strategy

- **`main`** is the stable branch. Never commit directly to main.
- All work goes through **feature branches** with pull requests.

## Branch Naming

Use prefixes:

| Prefix | Use |
|---|---|
| `feature/` | New features, new agent capabilities |
| `fix/` | Bug fixes |
| `chore/` | Maintenance, cleanup, config changes |
| `docs/` | Documentation only |

Examples: `feature/agent-bootstrap`, `fix/heartbeat-crash`, `chore/update-deps`

## Workflow

1. **Create a branch** from `main`: `git checkout -b feature/my-task main`
2. **Commit** with clear messages — what changed and why
3. **Push** and create a PR: `git push -u origin feature/my-task && gh pr create`
4. **Review** — Lissandra or Rek'Sai review if code changes are involved
5. **Merge** via PR (squash or merge commit, no rebase)
6. **Delete** the branch after merge

## Rules for Agents

- Every task gets its own branch and PR — no exceptions
- Never force-push. Never rebase. Always merge.
- Never commit secrets, credentials, or `.env` files
- Commit messages: imperative mood, concise, explain the why
- One logical change per commit — don't mix unrelated work

## Agent State Commits

Memory, journals, and learnings stay in git — they're durable identity. When an agent updates these files during a session, commit them to the current branch with:

```
chore(agent): update <agent> memory/journal/learnings
```

These commits ride along with whatever branch the agent is on and merge naturally with the PR.

## Operational Files (outside git)

Ephemeral runtime state lives in `~/.strawberry/ops/`, NOT in the git repo:

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats, registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |

These directories are gitignored. The MCP server reads/writes them via the `OPS_PATH` env var.

**Note:** `agents/health/heartbeat.sh` is a tool and stays in the git repo. It writes heartbeat JSON to the ops health directory. Once the MCP server is updated with `OPS_PATH` support (Bard's PR), heartbeat output will go to `~/.strawberry/ops/health/`.

**Rule: never put secrets in inbox messages or conversations.** Use env vars or a secrets manager.

## Branch Protection (main)

Branch protection should be enabled on main requiring:
- Pull request before merging
- No direct pushes

Note: This requires repo admin to configure via GitHub settings or API.
