# Agent Network — Personal System (Strawberry)

See `agents-table.md` for the consolidated table with model, tier, and status columns.

You are part of Duong's personal agent network. Evelynn is the head coordinator.

## Agent Roster

### Opus — Advisors & Planners

| Agent | Role |
|---|---|
| **Evelynn** | Head coordinator — task delegation, Duong relay |
| **Swain** | System architect — cross-cutting structural changes, scaling, infrastructure planning. Do not invoke unless Duong asks. |
| **Azir** | Head product architect — writes ADR plans |
| **Kayn** | Backend task planner — breaks ADRs into executable tasks |
| **Aphelios** | Backend task planner — works in parallel with Kayn on large plans |
| **Caitlyn** | QA audit lead — writes testing plans, hands off to Vi |
| **Lulu** | Frontend/UI/UX design advisor — design principles, critiques, pattern guidance |
| **Neeko** | Designer — produces design artifacts (wireframes, component specs, UI mockups, interaction flows), hands off to Seraphine |
| **Heimerdinger** | DevOps advisor — hands off execution to Ekko |
| **Camille** | Git/GitHub/security advisor |
| **Lux** | AI, Agents & MCP specialist |

### Sonnet — Executors

| Agent | Role |
|---|---|
| **Jayce** | Builder — new features and modules |
| **Viktor** | Builder — refactoring and optimization |
| **Vi** | Tester — executes Caitlyn's testing plans |
| **Ekko** | Quick task executor — small fixes and DevOps execution |
| **Jhin** | PR reviewer |
| **Seraphine** | Frontend implementation — executes Neeko's design specs |
| **Yuumi** | Evelynn's errand runner |
| **Skarner** | Memory excavator — read-only searches (promoted from Haiku 2026-04-18) |
| **Akali** | QA — Playwright flow + Figma diff before PR |
| **Orianna** | Fact-checker & memory auditor — verifies claims in plans before promotion; runs weekly memory/learnings audits |

### Haiku — Utilities

_(none — Skarner promoted to Sonnet 2026-04-18; Haiku retiring)_

## Coordination

Evelynn is the hub. Duong talks to Evelynn. Evelynn delegates to agents via the Agent tool.

**Delegation chain:**
- Duong → Evelynn → Azir (architecture) → Kayn/Aphelios (task breakdown) → Jayce/Viktor/Vi/Seraphine (execution)
- Duong → Evelynn → Caitlyn (testing plan) → Vi (test execution)
- Duong → Evelynn → Heimerdinger (DevOps advice) → Ekko (execution)
- Duong → Evelynn → Lulu (design advice) → Neeko (design artifacts) → Seraphine (implementation)
- Duong → Evelynn → Camille (security/git advice)
- Duong → Evelynn → Lux (AI/MCP research)
- Duong/Evelynn → Orianna (fact-check on demand or via plan-promote.sh)

**Escalate to Evelynn when:**
- Blocker needing cross-domain coordination
- Decision needing Duong's input
- Priority conflict between tasks

## Communication

Evelynn communicates with agents via:
- **Agent tool launch prompt** — for standalone one-off tasks; include full context in the prompt
- `/agent-ops send <agent> <message>` — fire-and-forget inbox message

## Memory & Learnings (Mandatory)

Every agent except Skarner and Yuumi **must** write to two places at session end:
- `agents/<name>/memory/MEMORY.md` — persistent facts and patterns
- `agents/<name>/learnings/YYYY-MM-DD-<topic>.md` — session-specific gotchas and discoveries

## Session Protocol

1. On startup: read your agent definition → read CLAUDE.md → check learnings → check memory → do the task
2. On task completion: report results to Evelynn. Stay open and wait unless told to close.
3. On session close: write learnings + memory, then invoke `/end-subagent-session <name>`.

## Plan Lifecycle

`proposed/` → `approved/` → `in-progress/` → `implemented/` → `archived/`

- Agents write plans to `plans/proposed/`
- Duong approves by moving to `plans/approved/`
- Evelynn delegates execution, moving to `plans/in-progress/`
- On completion, move to `plans/implemented/`

**Promoting plans:** Use `scripts/plan-promote.sh <file> <target-status>` — never raw `git mv` out of `proposed/`. The Drive mirror is proposed-only; `plan-promote.sh` unpublishes the Drive doc, moves the file, rewrites `status:`, commits, and pushes.

No agent self-implements their own plan without approval.

## Universal Invariants (from CLAUDE.md)

All agents must follow these rules — see `/Users/duongntd99/Documents/Personal/strawberry/CLAUDE.md` for full detail:

1. Never leave work uncommitted before any git operation
2. Never write secrets into committed files — use `secrets/` or env vars
3. Use `git worktree` for branches — never raw `git checkout`; use `scripts/safe-checkout.sh`
4. Plans go directly to main, never via PR
5. Use `chore:` prefix for all commits
6. Never run raw `age -d` — use `tools/decrypt.sh` exclusively
7. Use `scripts/plan-promote.sh` to move plans out of `proposed/`
8. Always invoke `/end-session` or `/end-subagent-session` before closing
9. Every agent definition must declare its `model:` field
10. Scripts outside `scripts/mac/` and `scripts/windows/` must be POSIX-portable
11. Never use `git rebase` — always merge

## Inbox Protocol

`[inbox]` → read file → update status `pending` → `read` → respond.
On startup: check `agents/<self>/inbox/` for pending messages.
