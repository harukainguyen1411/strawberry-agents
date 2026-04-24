# 2026-04-24 — Cross-repo MCP migration review (PR #36)

## Context

PR #36 in strawberry-agents was a 3-file diff (`.mcp.json`, Ekko MEMORY, duong memory) renaming the Slack MCP from dual `slack-bot`/`slack-user` entries to a single `slack` entry. The substantive code (`server.ts`, `tokens.ts`, tests, `start.sh`) lives in a SEPARATE local-only repo at `/Users/duongntd99/Documents/Personal/strawberry/mcps/slack/`.

## Lessons

1. **Cross-repo PRs require explicit source-tree inspection.** The PR diff showed only config/memory changes — the actual implementation being migrated to lives outside the repo. Without reading the sibling repo I would have rubber-stamped a config rename without ever seeing the code the config now points at.

2. **The local strawberry/ repo had the implementation commits (36fd2b4, 146da13, e337328, 51a62a7) present as git objects but not on any checked-out branch.** HEAD was at `2efb12c` (pre-Jayce), which is why the working tree only showed `scripts/start.sh`. I had to `git show <sha>:path` or `git worktree add <sha>` to inspect. Always run `git log --all --oneline` when content seems missing — dangling-but-reachable commits are common when a developer switches branches mid-session.

3. **Vitest `it.fails()` makes xfail semantics tricky to verify independently.** Jayce's "40/40 xfail-red at C2" read as a contradiction to "40/40 tests pass" on the C2 worktree. The resolution: `it.fails()` = expected-failure = "passes" in vitest output when the body throws. Always inspect the test source before calling a test-count claim inconsistent.

4. **Reusing `node_modules` across worktrees fails due to symlink/path-embedding in `.bin/` shims.** When I copied `/tmp/slack-mcp-review/mcps/slack/node_modules` into the C2 worktree, `vitest` blew up because its shim pointed back to the first worktree's `dist/cli.js`. Always `npm install` per worktree.

5. **On cross-repo migrations, grep the BROADER codebase for stale tool references** (`mcp__slack-bot__*`, etc.) — not just the PR diff. This was the only "important" finding in my review and it's only visible if you look beyond the diff.

## Mechanics

- `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` → `strawberry-reviewers-2` (confirmed). Posted review as `CHANGES_REQUESTED`.
- HEREDOC body preserved formatting including the `-- reviewer` sign-off.
