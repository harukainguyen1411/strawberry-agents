# CLAUDE.md & Boot Protocol — Signal-to-Noise Audit

*Prepared by Syndra, 2026-04-05*

## Files Audited

1. **Global CLAUDE.md** (`~/.claude/CLAUDE.md`) — 45 lines
2. **Project CLAUDE.md** (`strawberry/CLAUDE.md`) — 85 lines
3. **agent-network.md** (`agents/memory/agent-network.md`) — 116 lines

**Total: ~246 lines of instructions loaded before an agent does anything.**

Plus each agent reads: profile.md, memory, last-session, duong.md, duong-private.md, learnings/index.md. That's 6+ more files.

---

## Problem 1: Duplicated Startup Sequence

The startup sequence is defined in **two places** with conflicting versions:

**Global CLAUDE.md (8 steps):**

1. profile.md
2. memory/name.md
3. memory/last-session.md
4. agents/memory/duong.md
5. memory/duong-private.md
6. **agents/memory/work.md** ← wrong file for personal system
7. agents/memory/agent-network.md
8. learnings/index.md

**Project CLAUDE.md (7 steps):**

1. profile.md
2. memory/name.md
3. memory/last-session.md
4. agents/memory/duong.md
5. memory/duong-private.md
6. agents/memory/agent-network.md
7. learnings/index.md

**Issues:**

- Global includes `agents/memory/work.md` (step 6) — this is the **work** agent system file. Personal agents don't need it and it may not even exist in this workspace.
- The two lists are almost identical but subtly different, which means agents may follow either one depending on how Claude resolves conflicts.
- Global says "Then greet Duong in character." Project says "If in direct mode, greet. If autonomous, proceed silently." These conflict.

**Recommendation:** Remove the startup sequence from global CLAUDE.md entirely. Project CLAUDE.md is the authority for this workspace. Global should only contain cross-project rules (if any exist).

---

## Problem 2: Duplicated Session Closing

Session closing is also defined in **two places**:

**Global CLAUDE.md** — detailed (15+ lines), references `end_session` MCP tool with parameter table, detailed journal/handoff/memory/learnings instructions.

**Project CLAUDE.md** — compact (8 lines), references `log_session`, simpler instructions.

**Issues:**

- Global says `end_session` (from `usage-tracker` server). Project says `log_session` (from `end-session` server). These are likely the same tool renamed, but the inconsistency will confuse agents.
- Global includes a full parameter table. Project doesn't.
- Both say steps 1-4 mandatory, step 5 optional — this part is consistent.
- The detail level is wildly different. An agent might follow the sparse project version and miss the parameter requirements.

**Recommendation:** Keep ONE version. The detailed version belongs in agent-network.md (the operational manual), not in either CLAUDE.md. Both CLAUDE.md files should just say "Follow session closing protocol in agent-network.md."

---

## Problem 3: Duplicated Content Between Project CLAUDE.md and agent-network.md

These two files share significant overlap:


| Topic                | Project CLAUDE.md                     | agent-network.md                |
| -------------------- | ------------------------------------- | ------------------------------- |
| Coordination model   | "Evelynn is the head agent" (4 lines) | "Evelynn is the hub" (10 lines) |
| Inbox system         | 1 line                                | 3 lines + delegation detail     |
| Git safety           | 5 rules                               | 6 rules + code example          |
| System documentation | "architecture/ is source of truth"    | Same, word for word             |
| Plans description    | "Plans are for execution..."          | Same, word for word             |


**The problem:** An agent reads BOTH files at startup. Every duplicated line is wasted context and a potential contradiction point. When two sources say the same thing slightly differently, the agent has to reconcile — that's cognitive overhead with no benefit.

**Recommendation:** Clear separation of concerns:

- **Project CLAUDE.md** = identity + routing + file structure (what this repo IS)
- **agent-network.md** = operational protocol (how agents WORK)
- Zero overlap between them

---

## Problem 4: agent-network.md is Overloaded

This file is trying to be four things at once:

1. **Tool reference** (11 tools documented with parameters)
2. **Agent roster** (13 agents with roles)
3. **Operational protocol** (8 numbered rules)
4. **Policy manual** (git safety, PR docs, attribution, secrets, restricted tools)

At 116 lines, it's the longest single document agents read at boot. The tool reference section alone is ~20 lines that most agents rarely need — they'll use the tools they need when they need them, and the MCP tool descriptions are already available via the tool system itself.

**Recommendation:** Split into:

- **agent-network.md** (slim) — roster, coordination model, escalation, core protocol (rules 1-7). ~50 lines.
- Move tool reference details out — agents discover tools via MCP; they don't need a manual in their boot context.
- Move policies (git, PR, secrets, attribution) to project CLAUDE.md where they belong — these are repo-level rules, not network-level rules.

---

## Problem 5: Global CLAUDE.md Conflicts with Project CLAUDE.md

The global file is designed for the **work** agent system and contains work-specific references:

- `agents/memory/work.md` — work context file
- Agent names like "Azir", "Sona" in examples — these are work agents
- `usage-tracker` server reference — may not match personal system

**The fundamental issue:** Global CLAUDE.md applies to ALL projects (work and personal). But the startup/closing sequences are system-specific. A personal agent shouldn't be reading work-system instructions.

**Recommendation:** Global CLAUDE.md should contain ONLY truly global rules that apply everywhere:

- No startup sequence (project-specific)
- No session closing (project-specific)
- Only: cross-project preferences, Duong's general interaction style, etc.

If there are no truly global rules, the file should be minimal or empty for the personal system.

---

## Problem 6: Rules Buried in Prose

Several critical rules are buried in paragraphs rather than being scannable:

- **"Never leave work uncommitted"** — appears in both files, but inside paragraphs. This is the #1 rule for a shared directory and should be visually prominent.
- **Delegation completion is mandatory** — buried in the inbox section of agent-network.md
- **Context health reporting every ~10 turns** — buried as rule #8 in a numbered list

Agents (LLMs) process instructions better when critical rules are:

- At the top, not the bottom
- Formatted as standalone callouts, not inline text
- Short and imperative, not explanatory

---

## Concrete Recommendations

### 1. Gut global CLAUDE.md for this workspace

Remove startup/closing sequences. Keep only truly cross-workspace rules. If none exist, leave it as just the agent protocol header with a pointer: "See project CLAUDE.md for workspace-specific protocol."

Alternatively, use `~/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry/CLAUDE.md` (the project-specific user file) to override global settings for this workspace.

### 2. Restructure project CLAUDE.md as identity + routing + policies

```
# Strawberry — Personal Agent System
## Scope (keep)
## Agent Routing (keep)
## Operating Modes (keep)
## Startup Sequence (keep — this is the ONE source of truth)
## Session Closing → pointer to agent-network.md
## Critical Rules (NEW — top-3 rules, visually prominent)
  - Never leave work uncommitted
  - Complete delegated tasks (complete_task is mandatory)
  - Report back to Evelynn when done
## Git Rules (move FROM agent-network.md)
## PR & Attribution Rules (move FROM agent-network.md)
## Secrets Policy (move FROM agent-network.md)
## File Structure (keep: architecture/, plans/, assessments/, learnings/)
```

### 3. Slim down agent-network.md to coordination only

```
# Agent Network
## Agent Roster (keep)
## Coordination Model (keep — remove duplication with CLAUDE.md)
## Communication Tools (keep but compress — just tool names + one-line descriptions)
## Escalation (keep)
## Protocol (keep rules 1-8, but front-load the critical ones)
## Session Closing Protocol (move detailed version HERE — single source of truth)
## Inbox System (keep)
```

### 4. Front-load critical rules

In both files, put the 3-5 most-violated or most-important rules at the very top, before any structural content. Format them as a "Rules That Matter" block:

```
## Rules That Matter
1. Never leave work uncommitted — commit before any git operation
2. When delegated a task, call complete_task when done
3. Report task completion to Evelynn
4. Never write secrets into committed files
5. Use git worktree, never raw git checkout
```

Agents are LLMs. Earlier content gets more attention weight. Put the rules that agents keep breaking at the top.

### 5. Reduce boot file count

Current boot reads: **8+ files** before doing anything.

- profile.md ← necessary
- memory/name.md ← necessary
- memory/last-session.md ← necessary
- agents/memory/duong.md ← could be absorbed into agent-network.md (it's 17 lines)
- memory/duong-private.md ← rarely exists, fine // can be removed
- agents/memory/agent-network.md ← necessary
- learnings/index.md ← often empty or irrelevant // But learnings are important. Should keep.

**Candidate for consolidation:** Merge `duong.md` (17 lines) into the top of `agent-network.md`. That's one fewer file read at boot. Small win, but boot overhead is multiplicative across all sessions.

---

## Expected Impact


| Change                                      | Tokens saved per boot     | Risk                                   |
| ------------------------------------------- | ------------------------- | -------------------------------------- |
| Remove global CLAUDE.md duplication         | ~400 tokens               | Low — project CLAUDE.md has everything |
| Deduplicate CLAUDE.md ↔ agent-network.md    | ~300 tokens               | Low — clearer separation               |
| Compress tool reference in agent-network.md | ~200 tokens               | Low — tools self-document via MCP      |
| Merge duong.md into agent-network.md        | ~100 tokens + 1 file read | Low                                    |
| **Total**                                   | **~1000 tokens per boot** |                                        |


At ~1000 tokens saved per agent boot, across 5-10 agent launches per day, that's 5,000-10,000 tokens/day. Not massive, but it compounds — and the real win is **clarity**, not tokens. Agents that read cleaner instructions follow them more reliably.

---

## Priority Order

1. **Fix global CLAUDE.md** — highest impact, stops conflicting instructions immediately
2. **Deduplicate CLAUDE.md ↔ agent-network.md** — clear ownership of each topic
3. **Front-load critical rules** — improves compliance without changing content
4. **Compress tool reference** — reduces noise in agent-network.md
5. **Merge duong.md** — minor optimization, do last

