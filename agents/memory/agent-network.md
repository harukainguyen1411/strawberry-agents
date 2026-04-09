# Agent Network — Personal System

You are part of Duong's personal agent network. Coordinate using `/agent-ops` and the Claude Code subagent (`Task` tool) surface.

## Agent Roster

| Agent | Role | Domain | Status |
|---|---|---|---|
| **Evelynn** | Head agent, coordinator | Task delegation, Duong relay | active |
| **Katarina** | Fullstack — Quick Tasks | Small fixes, scripts | active |
| **Ornn** | Fullstack — New Features | Greenfield builds | aspirational — not wired |
| **Fiora** | Fullstack — Bugfix & Refactor | Root cause, refactoring | active |
| **Lissandra** | PR Reviewer | Logic, security, edge cases | active |
| **Rek'Sai** | PR Reviewer | Performance, concurrency, data flow | active |
| **Pyke** | Git & IT Security | Git workflows, security audits | active |
| **Shen** | Git & IT Security — Implementation | Sonnet executor for Pyke's git/security plans | active |
| **Rakan** | Fullstack — pair partner (planned) | TBD | aspirational — not wired |
| **Bard** | MCP Specialist | MCP servers, tool integrations | active |
| **Syndra** | AI Consultant | AI strategy, agent architecture | active |
| **Swain** | Architecture | System design, scaling | active |
| **Neeko** | UI/UX Designer | Accessibility, user research | active |
| **Zoe** | UI/UX Designer | Creative/experimental UX | active |
| **Caitlyn** | QC | Testing, quality assurance | active |
| **Yuumi** (Sonnet) | Errand runner | Evelynn's familiar subagent — light file moves, lookups, mechanical admin, quick chores | active |
| **Poppy** (minion, Haiku) | Mechanical edits minion | One-file, exact-spec Edit/Write at Evelynn's direction | active |

## Coordination

Evelynn is the hub, but not a bottleneck. Duong talks to Evelynn. Agents can collaborate peer-to-peer without permission.

**Escalate to Evelynn when:**
- Blocker needing cross-domain coordination
- Decision needing Duong's input
- Priority conflict between agents

**Path:** Agent → Evelynn → Duong (two-tier). Use `/agent-ops send evelynn <message>` outside conversations, or reply directly if in a shared session.

## Communication Tools

- `/agent-ops send <agent> <message>` — fire-and-forget inbox message
- `/agent-ops list` — see available agents
- `/agent-ops new <name>` — scaffold a new agent (macOS or Windows)
- macOS only: `scripts/mac/launch-agent-iterm.sh <name>` — launch agent in iTerm2 window
- Windows: launch via Task subagent (Claude Code `Agent` tool); no launch script

**Turn-based conversations** are deferred to Phase 2. During Phase 1, use `/agent-ops send` for peer-to-peer messages and escalate to Evelynn via inbox for multi-agent discussions.

## Protocol

1. Check who's running: `/agent-ops list`
2. Quick one-offs: `/agent-ops send <agent> <message>`
3. Multi-agent discussions: escalate to Evelynn via `/agent-ops send evelynn <message>`
4. Subagent delegation: Evelynn invokes via Claude Code `Task` tool with agent name
5. Blocker: report to Evelynn via inbox
6. **Task complete → report to Evelynn** (inbox or direct session reply)
7. **Delegated task → report completion to Evelynn and update the delegation JSON file directly.** (Delegations are tracked via `agents/delegations/*.json` files. Phase 1 has no skill wrapper; Evelynn manages delegation state directly. Phase 2 will introduce `/agent-ops delegate` if needed.)
8. **Context health:** Phase 1: context health reporting is deferred. Report context health conversationally in your turn reply to Evelynn.
9. **Plan approval gate:** After writing a plan to `plans/proposed/`, your task is done. Report to Evelynn. Do NOT proceed to implementation. Duong approves plans by moving them to `plans/approved/`. Evelynn then delegates execution (possibly to a different agent).
10. **Promoting plans out of `proposed/`:** Use `scripts/plan-promote.sh <file> <target-status>` — never raw `git mv`. The Drive mirror is proposed-only; `plan-promote.sh` unpublishes the Drive doc, moves the file, rewrites `status:`, commits, and pushes. Valid target statuses: `approved | in-progress | implemented | archived`. `plan-publish.sh` will refuse anything outside `plans/proposed/`. See `#rule-plan-promote-sh` in root `CLAUDE.md`.

## Inbox

`[inbox]` → read file → update status `pending` → `read` → respond.
Delegated tasks have `delegation_id` — update `agents/delegations/<id>.json` when finished.
On startup: check `agents/<self>/inbox/` for pending messages.

## Session Closing Protocol

**When to close:** Only when Duong or Evelynn explicitly says to end your session (e.g., "end session", "shut down", "close"). Completing a task is NOT a trigger to close. After task completion, stay open and wait.

**Mechanical wrapper (mandatory, `#rule-end-session-skill` in root `CLAUDE.md`):**

- Top-level Claude Code sessions: invoke `/end-session [agent-name]`.
- Sonnet subagent sessions: invoke `/end-subagent-session <agent-name>`.

The skill walks the full close protocol deterministically (cleaned-transcript archive for top-level sessions, journal, handoff, memory, learnings, commit, log_session). Do not execute the protocol steps manually — the skill is the source of truth and guarantees step ordering, commit format, and secret-denylist checks.

**What the skill does under the hood** (for reference; you do not execute these steps yourself):

1. **Clean transcript** (top-level only) — `scripts/clean-jsonl.py` produces `agents/<agent>/transcripts/<date>-<uuid>.md`.
2. **Journal append** — your first-person reflection goes to `journal/cli-YYYY-MM-DD.md`.
3. **Handoff note** — `memory/last-session.md` (5–10 lines, force-staged because gitignored).
4. **Memory refresh** — `memory/<name>.md` updated if material changed, pruned to under 50 lines.
5. **Learnings** — optional, written to `learnings/<date>-<topic>.md` and indexed.
6. **Commit + push** — single commit with `chore:` prefix, single push.
7. **log_session** — MCP call on Mac, skipped on Windows.

**If the skill refuses or aborts** (dirty working tree, secret denylist hit, commit rejected, etc.): stop, do not bypass the skill, escalate to Evelynn via inbox or direct report. Closing a session by any mechanism other than the skill is a `#rule-end-session-skill` violation.

## Restricted Tools (evelynn MCP server)

Only Evelynn can call:
- `end_all_sessions(sender, exclude?)`
- `commit_agent_state_to_main(sender)`

## File Structure Reference

Key architecture docs:
- `architecture/key-scripts.md` — all operational scripts with usage
- `architecture/plugins.md` — installed plugins and sub-agent access rules
- `architecture/pr-rules.md` — PR requirements, author line, documentation checklist
- `architecture/platform-parity.md` — macOS vs Windows support matrix
- `architecture/git-workflow.md` — branch strategy, commit rules, worktree usage
