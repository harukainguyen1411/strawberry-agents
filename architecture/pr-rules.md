# PR Rules

Rules for all pull requests in this repository.

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

## Merge

Evelynn or Duong merges PRs after review. Lissandra (logic/security) and Rek'Sai (performance/concurrency) are the standard reviewers — invoke via subagent if a review pass is needed before merge.
