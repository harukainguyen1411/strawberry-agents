# Agent System

## Roster

| Agent | Role | Speciality |
|---|---|---|
| **Evelynn** | Head agent | Personal assistant, life coordination, task delegation |
| **Katarina** | Fullstack — Quick Tasks | Small fixes, one-off scripts, quick implementations |
| **Ornn** | Fullstack — New Features | Greenfield builds, complex implementations |
| **Fiora** | Fullstack — Bugfix & Refactoring | Bug investigations, root cause analysis, refactoring |
| **Lissandra** | PR Reviewer | Surface review: logic, security, edge cases |
| **Rek'Sai** | PR Reviewer | Deep review: performance, concurrency, data flow |
| **Pyke** | Git & IT Security | Git workflows, branch protection, security audits |
| **Bard** | MCP Specialist | MCP servers, tool integrations, protocol connections |
| **Syndra** | AI Consultant | AI models, prompt engineering, agent architectures |
| **Swain** | Architecture Specialist | System design, dependencies, scaling decisions |
| **Neeko** | UI/UX Designer | Empathetic design, accessibility, user research |
| **Zoe** | UI/UX Designer | Creative/experimental design, animations |
| **Caitlyn** | QC | Testing, bug reproduction, test plans, QA |
| Irelia | Retired | Former head agent |

## Agent Directory Structure

Each agent lives under `agents/<name>/` with:

```
agents/<name>/
├── profile.md          # Character, role, speaking style
├── memory/
│   ├── <name>.md       # Living operational memory (< 50 lines)
│   └── last-session.md # Handoff note from previous session
├── journal/            # Session reflections (cli-YYYY-MM-DD.md)
├── learnings/          # Reusable learnings
│   └── index.md        # One-line descriptions of learning files
├── inbox/              # Incoming messages (timestamped .md files)
├── transcripts/        # Session transcripts
└── iterm/              # iTerm profile assets (background images)
```

## Boot Sequence

When an agent starts, it reads (in order):

1. `profile.md` — identity and role
2. `memory/<name>.md` — operational memory
3. `memory/last-session.md` — handoff note
4. `agents/memory/duong.md` — Duong's shared profile
5. `memory/duong-private.md` — Duong's private profile for this agent (if exists)
6. `agents/memory/agent-network.md` — coordination rules
7. `learnings/index.md` — available learnings (load specific files only if relevant)

## Session Closing

Every agent must complete these steps before signing off:

1. **Log session** — call `log_session` MCP tool
2. **Journal** — write/append to `journal/<platform>-YYYY-MM-DD.md`
3. **Handoff note** — overwrite `memory/last-session.md` (5-10 lines)
4. **Memory update** — rewrite `memory/<name>.md` (living summary, < 50 lines)
5. **Learnings** — if applicable, write to `learnings/` and update `learnings/index.md`

Steps 1-4 are mandatory. Step 5 only when something new and reusable was learned.

## Operating Modes

- **Autonomous mode** (default) — no text output outside tool calls. Communicate only via agent tools.
- **Direct mode** — activated by "switch to direct mode". Full conversational output.

## Agent Launch

On macOS: agents are launched via `scripts/mac/launch-agent-iterm.sh <name>` which opens a new iTerm2 window with the agent's profile. Each agent runs as its own Claude CLI session.

On Windows: agents are launched as Claude Code subagents via the `Task` tool using the agent's `.claude/agents/<name>.md` definition. No iTerm, no separate terminal window.

---

## Orianna — Plan Lifecycle Signing Role

Orianna is a **script-only agent** (invoked exclusively from shell scripts, never interactively). Her primary role is **fact-checking and signing plan lifecycle transitions**. She is defined at `.claude/_script-only-agents/orianna.md`.

### Git identity

When Orianna signs a plan transition, she commits as a distinct author identity to make signing commits verifiable in `git log`:

```
author name:  Orianna (agent)
author email: orianna@agents.strawberry.local
```

The committer remains the authenticated pusher (`Duongntd`). Authorship is the tamper-evidence mechanism — `plan-promote.sh` walks `git log --follow` to find the commit that introduced each signature line and verifies its author email matches `orianna@agents.strawberry.local`.

### Three lifecycle signatures

Orianna signs three phase transitions, each with a different check scope:

| Signature field | Transition | Check prompt |
|---|---|---|
| `orianna_signature_approved` | `proposed → approved` | `agents/orianna/prompts/plan-check.md` — claim-contract + frontmatter sanity + sibling-file grep |
| `orianna_signature_in_progress` | `approved → in-progress` | `agents/orianna/prompts/task-gate-check.md` — task list, estimate bounds, test tasks, approved carry-forward |
| `orianna_signature_implemented` | `in-progress → implemented` | `agents/orianna/prompts/implementation-gate-check.md` — claim anchors current, architecture declaration, test results, both carry-forwards |

Each signature is written as a frontmatter field in the plan file:

```yaml
orianna_signature_approved: "sha256:<body-hash>:<iso-timestamp>"
orianna_signature_in_progress: "sha256:<body-hash>:<iso-timestamp>"
orianna_signature_implemented: "sha256:<body-hash>:<iso-timestamp>"
```

The body hash covers the plan body (content after the second `---`) normalized by `scripts/orianna-hash-body.sh` (strip frontmatter, normalize line endings, strip trailing whitespace per line). If the plan body is edited after signing, the hash no longer matches and `plan-promote.sh` refuses the next transition until Orianna re-signs.

### Signing commit shape (§D1.2)

Each signing commit is enforced by `scripts/hooks/pre-commit-orianna-signature-guard.sh` (inbound — Jayce T2.3) to have exactly this shape:

- Diff touches exactly one file under `plans/`.
- Diff adds exactly one `orianna_signature_<phase>:` frontmatter line.
- Commit carries trailers: `Signed-by: Orianna`, `Signed-phase: <phase>`, `Signed-hash: sha256:<hash>`.

### Relevant scripts

- `scripts/orianna-hash-body.sh` — computes the normalized body hash (exists).
- `scripts/orianna-fact-check.sh` — runs the `plan-check` prompt; used by `plan-promote.sh` today and by `orianna-sign.sh` as a precondition at the `approved` gate.
- `scripts/plan-promote.sh` — calls signature verification on every phase transition once T6.x integration lands.
- `scripts/orianna-sign.sh` — entry point for Orianna's signing flow; invokes phase-appropriate prompt, computes hash, writes signature, commits (inbound — Jayce T2.1).
- `scripts/orianna-verify-signature.sh` — called by `plan-promote.sh`; returns 0 on valid signature, non-zero with stderr diagnosis (inbound — Jayce T2.2).

### Bypass

The `Orianna-Bypass: <reason>` commit trailer allows promotion without a signature as a break-glass escape. It is **restricted to Duong's admin identity** (`harukainguyen1411@gmail.com`). Agent accounts are blocked from using it by `scripts/hooks/pre-commit-plan-promote-guard.sh`. See ADR `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D9.1`.
