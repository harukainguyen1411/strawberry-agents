---
status: proposed
owner: syndra
---

# AI Stack Setup & Agent System Roadmap

*Based on: assessment/personal-ai-stack.md, assessment/agent-system-assessment.md*

This plan covers two tracks: (A) setting up Duong's personal AI stack, and (B) transitioning the agent system from foundation phase to production phase.

---

## Track A: Personal AI Stack Setup

### A1. Agent model assignment ✅ (API keys already configured)

Per-agent API keys are already in place. Remaining action: verify model assignment in each agent's `settings.local.json`.

**Model assignment:**

| Model | Agents |
|---|---|
| Opus | Evelynn, Syndra, Swain, Pyke |
| Sonnet | Katarina, Ornn, Fiora, Bard, Lissandra, Rek'Sai, Neeko, Zoe, Caitlyn |

**Rationale:** Opus for planning, architecture, security, and coordination. Sonnet for execution — following plans, building features, reviewing code.

**Can Evelynn launch agents with a specific model?** No — `launch_agent` doesn't accept a model parameter. Model is set per-agent in `settings.local.json`, which is the correct design. Model assignment is a configuration decision, not a runtime decision. Evelynn doesn't need to override it — each agent's role determines its model tier, and that's set once.

**Who:** Bard — verify all `settings.local.json` files have correct model set per table above.

### A2. Gemini Advanced subscription

**When:** Today
**Who:** Duong (manual)
**Steps:**

1. Subscribe to Google One AI Premium ($20/month) — includes Gemini Advanced
2. On Galaxy S24 Ultra: Settings → Google → Gemini → set as default assistant
3. Test voice activation: long-press power button → speak
4. Set up daily habits:
   - Morning: "What's on my calendar today?"
   - Walking/commuting: voice-dump ideas — "Remember that I want to..."
   - Evening: "What did I ask you to remember today?"
5. Explore Gemini extensions: Calendar, Gmail, Google Maps, YouTube

**Done when:** Gemini is the daily-use voice assistant for reminders, ideas, and casual learning.

### A3. ChatGPT Plus (deferred)

**When:** After 2 weeks of Gemini-only usage
**Trigger:** Only if Gemini is insufficient for deeper learning conversations
**No action needed now.**

---

## Track B: Foundation → Production Transition

### B1. Infrastructure-to-output tracking

**When:** Now
**Who:** Pyke (implement)
**Deadline:** April 10 — after which infrastructure commits must be < 30% of total.

Pyke builds a simple, visible tracking mechanism. Requirements:
- Evelynn can check the current ratio at any time (tool or script)
- Classifies commits as `infra` or `output` (can be tag-based, commit prefix, or a lightweight script that parses commit messages)
- Weekly summary visible to Evelynn

**What counts as infrastructure:**
- Agent coordination tooling (MCP tools, conversation protocol changes)
- Ops scripts (heartbeat, health, safe-checkout)
- Agent memory/journal/protocol changes
- Git workflow tooling

**What counts as output:**
- Features in myapps or any other app
- New apps or services for end users
- Client/friend project deliverables
- Discord bot features that serve community users

### B2. Smart session protocol (Evelynn-triaged)

**When:** After B1
**Who:** Syndra (design), Bard (implement)

Instead of a fixed time-based threshold, Evelynn decides which agents need full session protocol and which can run lightweight. This is a triage decision, not a rule.

**Mandatory full protocol (always):**
- Evelynn, Syndra, Swain, Pyke — these agents hold strategic context that must be persisted

**Evelynn-triaged (full or lightweight):**
- All other agents — Evelynn decides at delegation time based on task significance
- Duong can override if needed

**Lightweight protocol skips:**
- Journal entry
- Learnings check
- Detailed memory rewrite (just append key facts if any)
- `log_session` call

**Lightweight protocol keeps:**
- Read profile + memory on startup
- Heartbeat
- Handoff note update

**Implementation:**
- Add `session_protocol: full | lightweight` field to inbox task metadata
- Evelynn sets this when delegating
- Update agent CLAUDE.md closing sequence to check this field
- Give Evelynn a tool or convention to mark sessions (could be as simple as including "lightweight" in the task message)

### B3. First product sprint — Myapps task list

**When:** Today or tomorrow (April 5-6)
**Who:** Evelynn (coordination), Katarina/Ornn (build), Lissandra (review)
**What:** Task list feature in myapps for Evelynn and Duong.

**Success criteria:**
- Shipped and usable
- End-to-end agent workflow: Evelynn delegates → engineer builds → reviewer reviews → merge → deploy
- Track total token cost for the sprint

### B4. Cost tracking

**Status:** Already in place (per-agent API keys → Anthropic Console breakdown)
**Enhancement:** Extend `log_session` to capture token usage from `/cost` for the 4 mandatory-logging agents (Evelynn, Syndra, Swain, Pyke). Other agents only log when Evelynn decides the session warrants it.

### B5. Discord triage layer

**When:** Later — after B3 and after community access is planned
**Who:** Syndra (design), builder agent (implement)
**No action needed now.**

---

## Timeline

| Date | Action |
|---|---|
| April 5 (today) | A1: Bard verifies model assignment in settings |
| April 5 (today) | A2: Duong sets up Gemini Advanced |
| April 5-6 | B1: Pyke implements infra/output commit tracking |
| April 5-6 | B3: First product sprint begins (myapps task list) |
| April 7-8 | B2: Smart session protocol design + implementation |
| April 10 | B1 deadline: infra < 30% from here on |
| April 12 | B4: Review sprint cost |
| April 14+ | B5: Discord triage (when planned) |
| April 19 | A3: Evaluate ChatGPT Plus need |

---

## Success Metrics (end of April)

1. Gemini Advanced is daily-use voice assistant
2. Model assignment verified — Opus for strategic agents, Sonnet for executors
3. Myapps task list shipped and in use
4. Infra commits < 30% for second half of April
5. Session protocol overhead reduced for non-strategic agents
6. Cost-per-sprint baseline established
