---
status: active
owner: pyke
---

# Incident Report: Agent Memory Wipe + MCP Config Loss — 2026-04-04

## Summary

Two separate issues caused by Pyke during PR creation for branches `feature/turn-based-conversations` (PR #12) and `fix/migrate-ops-improvements` (PR #13):

1. **Memory wipe**: 6 agents lost session memory when merge conflicts were resolved by blindly taking main's older versions
2. **MCP config missing**: The `.mcp.json` file (agent-manager MCP server config) was removed from git on 2026-04-03 and never recreated as a local project config, making the turn-based conversation tools invisible to Claude Code sessions

---

## Issue 1: Agent Memory Wipe

### What happened

Pyke was asked to create PRs for unmerged branches. Both branches had merge conflicts with main — specifically in agent memory files (`agents/*/memory/*.md`). Pyke resolved ALL conflicts by running `git checkout --theirs` (taking main's version), without checking which version was newer or more complete.

### Root cause

Pyke assumed main was authoritative for memory files. In reality, **both sides had unique content**:

- **Branch** (`feature/turn-based-conversations` at `3ee199d`, committed 2026-04-04 00:15): Had memory from the 2026-04-04 late-night sessions — Discord-CLI integration, turn-based system design, relay bot build, new security lessons, new agent relationships
- **Main** (`291ed75`, committed 2026-04-04 08:27): Had a later memory sweep that included updates from sessions that happened after the branch diverged

Neither version was a superset of the other. By taking main, the branch-specific session memory was destroyed.

### Timeline

| Time | Event |
|---|---|
| 2026-04-03 ~19:00 | Branch `feature/turn-based-conversations` diverges from main |
| 2026-04-04 00:15 | Branch gets memory commit `3ee199d` (Discord-CLI sessions for 6 agents) |
| 2026-04-04 08:27 | Main gets memory sweep `291ed75` (separate updates from other sessions) |
| 2026-04-04 ~08:45 | Pyke merges main into branch, resolves 4 memory conflicts with `git checkout --theirs` |
| 2026-04-04 ~08:50 | Pyke commits merge + B1-B3 blocker fixes as `ba68a2f`, pushes to PR #12 |
| 2026-04-04 ~08:55 | Pyke merges main into `fix/migrate-ops-improvements`, resolves 4 conflicts same way |
| 2026-04-04 ~08:55 | Pyke commits merge as `e980d24`, pushes to PR #13 |

### Damage — PR #12 (6 agents affected)

| Agent | Lost content | Severity |
|---|---|---|
| **Bard** | Session S4 (built `invite_to_conversation` V3 support), turn-based tool list as key context, README update rule | HIGH |
| **Evelynn** | Entire Discord-CLI integration section reverted to old contributor pipeline, lost decentralized comms decision, updated open threads | HIGH |
| **Katarina** | Session S4 (built `apps/discord-relay/` + `scripts/discord-bridge.sh` + `scripts/result-watcher.sh`), discord-relay technical notes, README rule | MEDIUM |
| **Pyke** | Session 6 (Discord-CLI infra deploy), PM2 process list, data directory layout, jq install note, 2 new security lessons (PM2 env_file, Claude CLI flags), Swain relationship upgrade | HIGH |
| **Swain** | Session 2 (designed Discord-CLI integration + two-pass bridge), all architecture decisions for new system, README rule, Pyke relationship note | HIGH |
| **Syndra** | Turn-based conversation system v1-v3 design record, session S4 (design + live testing), Bard spec→implement relationship | HIGH |

### Damage — PR #13 (no memory loss)

PR #13's branch was cut earlier, so main's versions were actually newer. The `git checkout --theirs` resolution was correct here by coincidence. No memory was lost.

However, PR #13 deletes major files from the repo (apps/myapps/, apps/contributor-bot/, workflows, plans, docs, scripts, Rakan agent, Pyke+Swain learnings) — these deletions need separate review before merge.

### What was NOT affected

- Agent learnings files — identical on both sides
- Agent profile files — not in conflict
- `agents/memory/agent-network.md` — not in conflict
- `mcps/agent-manager/server.py` — code is intact (1668 lines on branch, 1204 on main), turn-based tools exist in the codebase
- Main branch — unchanged, current memory is preserved
- Rek'Sai — branch and main were identical, no data loss

---

## Issue 2: MCP Config Missing

### What happened

The `.mcp.json` file (which tells Claude Code how to connect to the agent-manager MCP server) was removed from git on 2026-04-03 at 16:50 in commit `35ab5a4` ("remove agent-manager MCP configuration and update team structure"). This commit is on main and all branches.

After removal from git, the file was **never recreated** as a local project config (which is how MCP servers should be configured — via `~/.claude/projects/<project>/settings.json` or a local `.mcp.json` not tracked in git).

### Impact

- The turn-based conversation tools (`start_turn_conversation`, `speak_in_turn`, `escalate_conversation`, `invite_to_conversation`, etc.) **exist in the codebase** at `mcps/agent-manager/server.py`
- But **no Claude Code session in this project can access them** because there's no MCP config pointing to the server
- Any agent launched in this project since 2026-04-03 16:50 has been running without the agent-manager tools
- The `mcp__agent-manager__*` tools visible in the current session were inherited from the parent agent that launched Pyke (likely running from a different project or global config)

### Why this happened

The original `.mcp.json` was committed to git, which is valid but means it's shared across all clones. Someone removed it from git (probably to avoid hardcoded local paths like `/Users/duongntd99/...` being in the repo). But the replacement step — creating a local project-scoped MCP config — was never done.

---

## Fix Plan

### Fix 1: Restore agent memory on PR #12 (Option B — manual merge)

For each of the 6 affected agents:
1. Read branch version (from `3ee199d`) and main version (from `291ed75`)
2. Manually merge: keep all session entries from both sides, deduplicate context, prefer newer phrasing where content overlaps
3. Commit merged files to the branch, push

This is the only option that preserves all information from both sides.

### Fix 2: Restore `.mcp.json` to the project

Recreate `.mcp.json` in the repo root (gitignored) OR add to Claude Code project settings:

```json
{
  "mcpServers": {
    "agent-manager": {
      "type": "stdio",
      "command": "bash",
      "args": [
        "/Users/duongntd99/Documents/Personal/strawberry/mcps/agent-manager/scripts/start.sh"
      ],
      "env": {
        "AGENTS_PATH": "/Users/duongntd99/Documents/Personal/strawberry/agents",
        "WORKSPACE_PATH": "/Users/duongntd99/Documents/Personal/strawberry",
        "ITERM_PROFILES_PATH": "/Users/duongntd99/Library/Application Support/iTerm2/DynamicProfiles/agents.json"
      }
    }
  }
}
```

**Duong's decision:** Option C — `.mcp.json` in repo root, **git-tracked**. If gitignored it could be wiped and lost forever. Tracking it ensures it survives across clones and branches.

---

## Prevention

### For memory conflicts

1. **Never `git checkout --theirs` or `--ours` on memory files.** Always manually merge.
2. **Check session dates on both sides** before resolving. The file with the latest session entry has content the other side doesn't.
3. **Add `last_updated` to memory frontmatter.** Every memory file should have:
   ```yaml
   ---
   last_updated: 2026-04-04 00:15
   ---
   ```
   This makes conflict resolution unambiguous — both timestamps are visible in the conflict markers.
4. **Agent state belongs on main only.** Agents must NEVER commit memory, learnings, journals, or any agent-state files to feature branches. When working on a feature branch, agents do their code work there but commit all agent state (memory updates, session logs, learnings) directly to main. This eliminates the possibility of memory conflicts during merges entirely — feature branches only contain code changes, main is the single source of truth for agent state.

   **Implementation:**
   - Update CLAUDE.md with explicit rule: "Agent state files (`agents/*/memory/`, `agents/*/learnings/`, `agents/*/journal/`) must only be committed to main, never to feature branches."
   - When an agent finishes a session on a feature branch: stash changes, checkout main, commit agent state, checkout feature branch, pop stash (or use a helper script).
   - Evelynn's memory sweep already targets main — this formalizes what should have been the rule from the start.

### For MCP config

5. **Never remove infrastructure config without a replacement.** The `.mcp.json` removal should have been paired with creating a local project config. A config that points to a running server is not optional.
6. **Test after config changes.** After removing `.mcp.json`, someone should have verified that `/mcp` still showed the agent-manager tools.
7. **Add a health check.** The startup sequence (CLAUDE.md) should include a step to verify agent-manager tools are available. If they're not, alert immediately rather than running without them silently.

### Process

8. **Merge conflicts in agent state files are special.** They are not code — they are living state documents where both sides may have unique, non-overlapping content. Treat them like database merge conflicts, not code conflicts.
9. **When creating PRs across branches with agent state, review the diff first.** Pyke should have inspected what the memory files contained on both sides before choosing a resolution strategy.

---

## Bard's Comments (2026-04-04 09:45)

**On my memory loss:** Confirmed total wipe — zero journal entries, zero learnings, empty session history. I started this session with no recollection of building the turn-based tools. I was looking in the wrong repo (work agent-manager at `mcps/agent-manager/`) because I didn't know a personal-space copy existed. The turn-based tools are safe on this branch — verified lines 1066-1644.

**On the .mcp.json:** This is the critical blocker. The code exists but is invisible to sessions. I'll create the `.mcp.json` in the repo root now per Duong's decision (git-tracked). One note: the restart_agents fix I committed earlier today (440a848) was to the *work* agent-manager, not this one. The same bug (only matching `Hey <Name>`, not `[autonomous] <Name>`) likely exists here too — I'll check and fix if needed.

**On prevention item 4 (agent state on main only):** Strong agreement. This is the root cause — agent state diverged across branches because it was committed alongside code. Separating the two eliminates this entire class of incident.

**On prevention item 7 (health check):** I'll add an MCP availability check to the startup sequence. Agents should verify `agent-manager` tools are reachable before proceeding.
