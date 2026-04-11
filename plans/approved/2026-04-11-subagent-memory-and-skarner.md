---
title: Sub-agent memory/learnings persistence + Skarner memory-retrieval minion
status: approved
owner: syndra
created: 2026-04-11
---

# Sub-agent memory/learnings persistence + Skarner memory-retrieval minion

## 1. Problem

Sub-agents (katarina, fiora, lissandra, shen, yuumi, poppy) currently have `memory/` directories but no systematic mechanism to populate them. The `/end-subagent-session` skill references the same journal/memory/learnings steps as `/end-session`, but in practice sub-agents rarely invoke it, and when they do, the memory files they produce are inconsistent. Meanwhile, there is no agent dedicated to retrieving memories and learnings when needed — Evelynn or the requesting agent must manually grep through `agents/*/memory/` and `agents/*/learnings/`, which is slow and incomplete.

This plan addresses both gaps as a single coherent change.

## 2. Feature A — Sub-agent memory and learnings persistence

### 2.1 Directory scaffold

Ensure every sub-agent has the following structure (some already exist, some do not):

```
agents/<name>/memory/<name>.md     # operational memory (like evelynn.md)
agents/<name>/learnings/index.md   # learnings index
```

Agents that already have `memory/` but no `<name>.md` inside it get a seed file. Agents missing `learnings/` get the directory and an empty `index.md`.

Agents in scope: katarina, fiora, lissandra, shen, yuumi, poppy.

### 2.2 Seed memory file format

Each `agents/<name>/memory/<name>.md` follows Evelynn's pattern, scaled down:

```markdown
# <Name>

## Role
- <one-line from profile>

## Key Knowledge
- (empty — populated by session closes)

## Sessions
- (empty — populated by session closes)
```

Keep it minimal. The point is to have a file that `/end-subagent-session` can append to.

### 2.3 `/end-subagent-session` skill update

The skill already references steps 5-8 from `/end-session` (journal, handoff, memory, learnings). The problem is twofold: (a) sub-agents often don't get explicitly closed via the skill, and (b) the skill says "same as /end-session step N" without adapting for sub-agent realities.

Changes to `.claude/skills/end-subagent-session/SKILL.md`:

**Step 3 (Memory refresh)** — Replace "Same as /end-session step 7" with inline instructions:

- Review `agents/<agent>/memory/<agent>.md`.
- Append a session row: `- YYYY-MM-DD: <one-line summary of what was accomplished>`.
- If the agent learned a new working pattern or discovered a system constraint, add it to `## Key Knowledge`.
- Prune if over 30 lines (sub-agents get a tighter budget than Evelynn's 50).
- Stage the file.

**Step 4 (Learnings)** — Replace "Same as /end-session step 8" with inline instructions:

- If this session produced a generalizable lesson, write `agents/<agent>/learnings/YYYY-MM-DD-<topic>.md` and append to `agents/<agent>/learnings/index.md`.
- Format: one-line summary in index, full lesson in the file (3-10 lines typical).
- Stage both files.

**Step 2 (Handoff)** — Replace "Same as /end-session step 6" with:

- Write `agents/<agent>/memory/last-session.md` with a 3-5 line terse handoff: date, what was done, open threads.
- Stage the file.
- Skip the `remember:remember` skill (sub-agents don't own their own remember state).

### 2.4 Sub-agent startup reads

Each sub-agent's `.claude/agents/<name>.md` definition should include a startup instruction to read their memory file if it exists. Add to each agent definition file:

```
Before starting work, read `agents/<name>/memory/<name>.md` if it exists — it contains your operational memory from previous sessions.
```

This is a one-line addition to each of the 6 agent definition files.

### 2.5 Evelynn's role

Evelynn should invoke `/end-subagent-session <name>` before dismissing any sub-agent whose session produced meaningful work. This is already implied by CLAUDE.md rule 8 but is not consistently practiced. Add a reminder to `agents/evelynn/CLAUDE.md` under the delegation tracking section:

> After receiving a sub-agent's final report, invoke `/end-subagent-session <name>` to persist their memory and learnings before the session context is lost.

## 3. Feature B — Skarner (memory-retrieval minion)

### 3.1 Concept

Skarner is a Haiku minion whose sole job is memory retrieval. Given a query (agent name, topic, or both), Skarner searches the relevant memory and learnings files and returns a structured digest. This replaces ad-hoc grepping and gives Evelynn a clean delegation target for "what does X agent know about Y?"

### 3.2 Agent definition

File: `.claude/agents/skarner.md`

```yaml
---
model: haiku
description: Memory retrieval minion. Searches agent memories and learnings for relevant context. Returns structured digests, never modifies files.
allowed-tools: Read, Glob, Grep, Bash
---
```

Skarner is read-only by design — no Write, no Edit. Cannot modify memories, only retrieve them.

### 3.3 Input format

Skarner receives a task string from Evelynn (or any delegating agent) with:

- **query**: what information is needed (free text)
- **scope** (optional): which agent(s) to search. Defaults to "all agents".
- **include** (optional): what to search — `memory`, `learnings`, `journal`, or `all`. Defaults to `memory,learnings`.

Example delegation: "Skarner, find what Katarina knows about the myapps deployment pipeline. Scope: katarina, fiora. Include: memory, learnings."

### 3.4 Search procedure

1. Glob for relevant files based on scope and include parameters.
2. Read each file and grep for query-relevant content.
3. Return a structured digest:

```markdown
## Memory retrieval: <query>

### katarina
**Memory:** <relevant excerpts or "nothing found">
**Learnings:** <relevant excerpts or "nothing found">

### fiora
**Memory:** <relevant excerpts or "nothing found">
**Learnings:** <relevant excerpts or "nothing found">

---
Sources searched: <N> files across <M> agents.
```

### 3.5 Profile

File: `agents/skarner/profile.md`

Skarner is a scorpion-like creature from League of Legends — ancient, patient, methodical. He digs through layers of buried knowledge. In this system, he is quiet, precise, and exhaustive. He does not editorialize — he retrieves and presents. His personality is minimal: he serves the query, returns the answer, and departs.

### 3.6 Directory scaffold

```
agents/skarner/
  profile.md
  memory/
    skarner.md
  transcripts/
```

Skarner himself gets a memory file (he is an agent, after all), but given his stateless retrieval nature, it will rarely be populated.

### 3.7 Delegation flow

Evelynn's delegation table gets a new row:

| Work type | Agent |
|-----------|-------|
| Memory/learnings retrieval across agents | **Skarner** (Haiku minion) |

### 3.8 Roster update

Add Skarner to `agents/roster.md` with role "Memory retrieval minion (Haiku)".

## 4. Implementation order

1. Directory scaffolding for all 6 sub-agents (memory files, learnings dirs)
2. Update `/end-subagent-session` skill with inline instructions
3. Update 6 `.claude/agents/<name>.md` files with startup memory read
4. Add reminder to `agents/evelynn/CLAUDE.md`
5. Create Skarner: profile, agent definition, directory scaffold
6. Update roster and Evelynn's delegation table

## 5. Resolved decisions

1. **Journal step for sub-agents** — Mandatory. The journal step is required for all sub-agent session closes, not optional. Every `/end-subagent-session` invocation must produce a journal entry regardless of session length.

2. **Skarner and GoodMem** — Deferred. Skarner launches as grep-based only. GoodMem MCP tool access will be added later when the GoodMem integration plan lands. Do not include GoodMem tools in Skarner's initial agent definition.

3. **Memory budget** — Confirmed at 30 lines per sub-agent. This is more compact than Evelynn's 50-line budget, reflecting the narrower scope of sub-agent work.
