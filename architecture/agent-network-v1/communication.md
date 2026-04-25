# Agent Communication — v1

**Live roster source of truth: `agents/memory/agent-network.md`.** This file documents the *protocols and contracts* of agent communication. The live participant list (agents, status, pair-mate links) is data, not architecture — it lives in `agents/memory/`.

---

## Dispatch shape (primary)

Evelynn and Sona coordinate by launching subagents via the **Agent tool**. Every subagent receives a task prompt on startup that includes:

1. `[concern: personal]` or `[concern: work]` as the first line.
2. A pointer to the relevant plan file under `plans/in-progress/` or `plans/approved/`.
3. Full context the subagent needs — Agent tool subagents only see their launch prompt and their own memory; they have no access to the coordinator session's prior turns.

Every subagent's **final message** is the only output the coordinator receives. Intermediate output is invisible. Subagents must restate their complete deliverable (commit SHAs, findings, gating questions) in their final message.

All background subagents run with `run_in_background: true`. Foreground dispatch is reserved for results strictly needed before any further action can be taken.

---

## Inbox — fire-and-forget messages

`/agent-ops send <agent> <message>` writes a fire-and-forget message to `agents/<agent>/inbox/`. Use this for:

- Coordinator-to-coordinator FYI (Evelynn ↔ Sona cross-concern notification — see `agents/memory/agent-network.md` §Coordinator-to-Coordinator FYI for triggers and message shape).
- Lightweight handoff notes that don't require a full Agent tool dispatch.
- Status pings from subagents to their dispatching coordinator.

Inbox files use YAML frontmatter: `from`, `to`, `priority`, `timestamp`, `status`. Protocol on receipt:

1. Read the file.
2. Update `status: pending` → `status: read`.
3. Respond as appropriate.

`priority: info` for coordinator FYIs. `priority: normal` for task-related messages. `priority: urgent` only when genuinely blocking.

---

## Handoff protocol (subagent → coordinator)

When a subagent completes work:

1. Write session memory and learnings (`/end-subagent-session <name>`).
2. Restate the complete deliverable in the final message: commit SHAs, file paths, PR URL, blockers, and any gating questions.
3. The coordinator reads the final message as the task result, then updates its delegation state.

Background subagent branches are merged back into main by the coordinator via `scripts/subagent-merge-back.sh <branch>`. The script handles fast-forward, merge commit, and conflict-abort cases automatically.

---

## Decision-feedback contract

When a coordinator makes a structural decision (plan approval, architecture choice, agent routing call), it may write a decision record to `feedback/` via the decision-feedback skill. These records are read by the retrospection dashboard (Phase 2). Format and triggers are defined in the decision-feedback plan (`plans/in-progress/personal/2026-04-25-coordinator-decision-feedback-plan.md`).

---

## Slack — pointer-only surface

Slack is a **pointer surface, not a content surface**. This is a load-bearing policy (established 2026-04-25):

- **CLI is the source of truth.** All substantive agent output — plans, commit SHAs, findings, task results, analysis — lives in the CLI session and is committed to the repo.
- **Slack receives pointers only.** A Slack ping may contain: a one-line summary, a link or path to where the full content lives, and a "see CLI for details" note. Never paste full agent output, plan text, or multi-line analysis into Slack.
- **Rationale:** Slack content is not referenceble from git history, not searchable by future agents, and creates a split-brain where some decisions are recoverable and others are not. Keeping Slack as pointer-only preserves the commit log as the single authoritative record.

Enforcement: agent defs do not include `mcp__slack__*` tool calls that post substantive content. Coordinators are responsible for enforcing this boundary when dispatching subagents that have Slack MCP access.

---

## Coordinator-to-coordinator FYI

Evelynn (personal concern) and Sona (work concern) run side-by-side. Cross-concern observation triggers a mandatory unprompted info-level FYI to the other coordinator. Full protocol (triggers, message shape, discipline, when NOT to send) is in `agents/memory/agent-network.md` §Coordinator-to-Coordinator FYI.

---

## Escalation path

Agent → coordinator → Duong (two-tier). Escalate to the coordinator when:

- Blocker requiring cross-domain coordination.
- Decision needing Duong's input.
- Priority conflict between tasks.

Coordinators escalate to Duong when: the blocker cannot be resolved within the current plan's scope, or when a numbered Rule in `CLAUDE.md` needs amendment.

---

## Runtime state (gitignored)

Ephemeral agent state lives under `~/.strawberry/ops/` (gitignored):

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages (also mirrored in `agents/<name>/inbox/`) |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats and registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |

Only committed artifacts (memory, learnings, plans, architecture) are persistent across sessions.
