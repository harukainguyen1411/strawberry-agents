# PR Rules

Rules for all pull requests. Implementation PRs live in `harukainguyen1411/strawberry-app` (code). Plans commit directly to `Duongntd/strawberry` main (never via PR).

## Required Fields

- **Author line** — include `Author: <agent-name>` in the PR description body (not the title). This identifies which agent did the implementation.
- **Documentation checklist** — check the PR template documentation checklist before submitting. If the template doesn't render automatically, use `gh pr create --template` or paste the checklist manually.

## Documentation Updates

If your change touches any of the following, update the relevant docs **in the same PR**:

- `architecture/` — system architecture, platform parity, MCP servers, git workflow
- `.claude/agents/*.md` — subagent definitions
- `scripts/` — key scripts table in `architecture/key-scripts.md`
- Plugins — update `architecture/plugins.md` if new plugins are added or removed
- Features or integrations — update the relevant `README.md`

## Branch and PR Flow

- Use `scripts/safe-checkout.sh <branch>` to create a branch — never raw `git checkout -b`.
- Use `git worktree` for isolation. See `architecture/git-workflow.md` for full branch strategy.
- Implementation work goes through a PR. Plans commit directly to main (never via PR).
- Never `git rebase` — always merge.
- Never push `--force` to main.

## Commit Prefix

All commits (including on feature branches) use `chore:` or `ops:` prefix. The pre-push hook enforces this on main. See `#rule-chore-commit-prefix` in root `CLAUDE.md`.

## Account Roles for PRs

| Account | Role |
|---------|------|
| `Duongntd` | Agent pusher — opens PRs, pushes commits, manages branches in `strawberry-app` |
| `harukainguyen1411` | Human reviewer — approves PRs, merges. Has admin bypass (break-glass only). |

PRs are opened in `harukainguyen1411/strawberry-app`. The `harukainguyen1411` account is the designated approver for agent-authored PRs (per commit 80cd16f and plan §8 decision 8). Agents must not merge their own PRs — see `CLAUDE.md` rule 18.

## Review Team Protocol

Every PR goes through a three-agent review team (TeamCreate):

| Role | Agent | Responsibility |
|---|---|---|
| Implementer | Katarina (or executor who built the PR) | Fixes all issues raised by reviewer |
| Plan author | Whoever wrote the plan (Swain, Syndra, Pyke, etc.) | Verifies implementation matches plan intent |
| Reviewer | Lissandra | Logic, security, edge cases — loops until clean |

**Loop:**
1. Lissandra reviews → posts findings as `gh pr comment`
2. If issues: messages Katarina with the list
3. Katarina fixes → pushes → messages Lissandra "fixes pushed, please re-review"
4. Repeat until Lissandra confirms clean
5. Lissandra messages Evelynn: "PR #N is clean — ready to merge"
6. Evelynn merges + shuts down the team via SendMessage shutdown_request

Evelynn creates the team with TeamCreate, spawns all three agents with `team_name`, and waits for Lissandra's clean signal before merging.

## Merge

Evelynn merges after Lissandra confirms clean. Never merge before the review loop completes.
