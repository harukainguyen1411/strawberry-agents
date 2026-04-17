# Never Auto-Resolve Agent State Conflicts

## Rule
Never use `git checkout --theirs` or `--ours` on agent memory/learnings/journal files. Always manually merge by reading both versions and combining unique content from each side.

## Why
Agent memory files are living documents where both sides of a merge conflict carry unique, non-overlapping content. One side may have newer session entries, the other may have a later memory sweep with different updates. Neither version is a superset of the other.

## What happened
On 2026-04-04, Pyke resolved merge conflicts on 6 agents' memory files by blindly taking main's version. This destroyed session memory from Discord-CLI integration, turn-based conversation design, relay bot builds, and other 2026-04-04 work. Required manual restoration from git history.

## Prevention
- Agent state should only be committed to main, never feature branches (eliminates this class of conflict entirely)
- If conflicts do occur: check session dates on both sides, read both versions, merge manually
- The `commit_agent_state_to_main` MCP tool is the only sanctioned path for agent state into git
