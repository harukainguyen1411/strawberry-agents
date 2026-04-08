---
status: proposed
owner: bard
created: 2026-04-09
supersedes-phase-1: 2026-04-08-mcp-restructure.md
title: MCP Restructure — Phase 1 Detailed Execution Spec (agent-manager → skills + scripts + rules)
---

# MCP Restructure — Phase 1 Detailed Execution Spec

> Executor-ready. Every step has a checkbox and a concrete artifact. No design decisions remain. Phase 1 only. Phases 2–3 are still governed by `plans/proposed/2026-04-08-mcp-restructure.md` and will get their own detailed specs later.
>
> **Rule 7 applies to the plan author.** Bard wrote this; Bard does not execute it. Evelynn delegates execution after approval.
>
> **Rule 6 / delegation note.** Because this plan is detailed and executor-ready, a Sonnet agent may execute it. The executor is forbidden from changing scope, renaming artifacts, or inventing subcommands not listed here. If a step is ambiguous, stop and escalate to Evelynn.

## Decisions already made (do NOT re-ask Duong)

These were absorbed by Evelynn from the rough plan's §8 open questions. Treat them as frozen for Phase 1:

- **D1.** Two external-comms MCPs (telegram + task-board separate). Phase 2 concern, noted here only to set vocabulary.
- **D2.** Archive `mcps/agent-manager/` in Phase 1 (do NOT delete). Deletion is deferred to Phase 3.
- **D3.** No muscle-memory tool carve-outs. Subagent-era naming (`/agent-ops send`) is fine; no aliases required.
- **D4.** `restart_evelynn` is deleted outright. No replacement script. Subagent mode moots the concept.
- **D5.** Marketplace plugin evaluation is Phase 2. Phase 1 touches no plugins.
- **D6.** Skill count stays under the six-skill cap by folding subcommands under umbrellas. Phase 1 ships **exactly one new skill**: `/agent-ops <subcommand>`. No `/new-agent`, no `/delegate`, no `/converse` as standalone top-level skills.
- **D7.** `/end-session` Phase 1 has already landed this week. `scripts/commit-agent-state.sh` is a Phase 2 concern and MUST NOT be introduced here. Phase 1 does not touch `/end-session`, `/end-subagent-session`, or their helpers.

## Cross-platform parity (first-class)

Duong's hard constraint: **Mac and Windows must run similarly.** Phase 1 enforces parity by the following rules, which the executor MUST respect for every artifact in this plan:

- **Skill bodies are POSIX-only.** `SKILL.md` MUST NOT assume macOS, iTerm, `osascript`, or any BSD-specific flag. Any command that differs between macOS and Linux/Windows-Git-Bash MUST be written in the POSIX-portable form (e.g., `date -u +%Y-%m-%dT%H:%M:%SZ`, `find ... -print`, no `stat -f`, no `sed -i ''`).
- **Shell scripts ship as bash (`#!/usr/bin/env bash`) and run under Git Bash on Windows.** No PowerShell siblings are required in Phase 1 because Git Bash is the supported Windows shell for Strawberry. If a script cannot be made POSIX-portable, it is declared macOS-only and placed under `scripts/mac/` with a matching Windows stub under `scripts/windows/` that prints `NOT_SUPPORTED_ON_WINDOWS` and exits 2.
- **Filesystem paths are always constructed from `$REPO_ROOT`** (set via `REPO_ROOT="$(git rev-parse --show-toplevel)"` at the top of every script). No absolute paths, no `~` expansion in committed files, no drive letters.
- **Line endings: LF only.** Every new file in this plan is committed with LF endings. `.gitattributes` already enforces this repo-wide; the executor verifies with `git check-attr text eol -- <new-file>` for each new file and reports any mismatch.
- **Platform-specific affordances are documented in one place:** a new file `architecture/platform-parity.md` (created in Step 9) lists every Mac-only and Windows-only affordance with its counterpart, starting with the `launch-agent-iterm.sh` / subagent-only rows from this phase.
- **Launcher parity rule:** `scripts/launch-agent-iterm.sh` is **explicitly macOS-only** and lives under `scripts/mac/launch-agent-iterm.sh`. The Windows equivalent is **not a script** — it is the documented rule "Windows uses subagents exclusively; there is no Claude-invoked launch path on Windows." This rule is added to `architecture/platform-parity.md` AND as a one-line comment in the Windows stub script `scripts/windows/launch-agent.sh` which prints `Windows mode: launch via Task subagent, not this script` and exits 2.
- **`/agent-ops` itself is platform-neutral.** Every subcommand (`send`, `list`, `new`) uses only `Write`, `Read`, `Bash` (POSIX), `Glob`, `Grep`. No subcommand shells out to iTerm. The only Mac-only touchpoint in Phase 1 is the archived launcher above, which `/agent-ops` does not call.

These parity rules are load-bearing. The executor may not relax any of them during implementation. If a rule cannot be satisfied for a specific artifact, stop and escalate.

## Artifact inventory (what gets created, moved, or deleted)

Single source of truth for the executor. Every path is repo-relative.

**Created:**

1. `.claude/skills/agent-ops/SKILL.md`
2. `scripts/new-agent.sh`
3. `scripts/list-agents.sh`
4. `scripts/mac/launch-agent-iterm.sh` (moved — see "Moved")
5. `scripts/windows/launch-agent.sh` (stub, documents Windows non-support)
6. `architecture/platform-parity.md`
7. `mcps/agent-manager/README.md` (archive pointer, overwrites any existing README)

**Moved:**

8. `scripts/launch-agent-iterm.sh` → `scripts/mac/launch-agent-iterm.sh` (the source file does not currently exist at `scripts/launch-agent-iterm.sh`; if it does not exist, the executor creates it fresh at the Mac path per Step 4. The Mac iTerm launcher logic is ported from `mcps/agent-manager/server.py` `launch_agent` tool during Step 4.)

**Modified:**

9. `CLAUDE.md` — add rule(s) per Step 11.
10. `.mcp.json` — deregister `agent-manager` per Step 12.
11. `agents/memory/agent-network.md` — rewrite "Communication Tools", "Protocol", and "Agent Roster" sections per Step 10.
12. `agents/roster.md` — cross-check and rewrite any `message_agent`/`list_agents` references per Step 10.
13. Every agent profile `.md` under `.claude/agents/<name>.md` that has a `skills:` frontmatter line — add `agent-ops` to the list per Step 8.
14. Every file in the call-site sweep table (Step 7) — replace MCP tool references with the new skill or script form.

**Archived (left in place, not deleted):**

15. `mcps/agent-manager/` — everything stays except a new `README.md` at the root (artifact #7 above) pointing at this plan.

**Deleted:**

16. Nothing in Phase 1. Deletion of `mcps/agent-manager/` is Phase 3 per D2.

## Step-by-step execution

Every step is a checkbox. The executor ticks the box in their commit message or report when the step is done. Steps MUST be executed in order except where explicitly marked "parallelizable."

### Step 0 — Preflight

- [ ] Confirm working tree is clean: `git status --short` returns empty.
- [ ] Confirm current branch is `main` (Rule 9: plans and their execution land directly on main for coordination work; the executor may branch if Evelynn instructs, but default is main).
- [ ] Confirm `mcps/agent-manager/server.py` exists and is the version under plan. If not, stop.
- [ ] Read `.claude/skills/end-session/SKILL.md` front-matter to confirm skill format conventions still match what this plan assumes (name, description, disable-model-invocation, allowed-tools). If the conventions have drifted, stop and escalate.

### Step 1 — Inventory the `agent-manager` tool surface (read-only)

- [ ] Read `mcps/agent-manager/server.py` end-to-end and produce a flat list of every `@mcp.tool()`-decorated function. Save this list in the commit message for traceability; do NOT commit a separate file.
- [ ] Cross-check the list against the rough plan §2.1 enumeration: `list_agents`, `get_agent`, `create_agent`, `launch_agent`, `message_agent`, plus turn-based conversations, delegations, health registry, context-health. Report any tool present in `server.py` but not covered here — if any exist, stop and escalate to Evelynn for a scope decision (do not improvise).

### Step 2 — Write `scripts/list-agents.sh`

- [ ] Create `scripts/list-agents.sh` with the following exact contract:
  - Shebang: `#!/usr/bin/env bash`
  - `set -euo pipefail`
  - Resolves `REPO_ROOT="$(git rev-parse --show-toplevel)"`.
  - Iterates `"$REPO_ROOT"/agents/*/` and for each directory that contains a `memory/` subdirectory (the `_is_agent_dir` rule from `agent-manager`), prints one line: `<agent-name>\t<role-first-line-from-profile.md-or-unknown>`.
  - Supports `--format json` for machine-readable output (array of `{name, role}` objects). Default output is TSV.
  - Exits 0 on success, 1 on any I/O error.
  - No dependencies beyond `bash`, `find`, `awk`, `sed`, `grep`. No `jq`.
- [ ] `chmod +x scripts/list-agents.sh`.
- [ ] Smoke test: `bash scripts/list-agents.sh` lists at least bard, evelynn, katarina, syndra. Record the output count in the commit message.

### Step 3 — Write `scripts/new-agent.sh`

- [ ] Create `scripts/new-agent.sh` with the following exact contract:
  - Shebang: `#!/usr/bin/env bash`
  - `set -euo pipefail`
  - Usage: `scripts/new-agent.sh <agent-name> [--role "<short role string>"] [--profile-text-file <path>]`.
  - Validates `<agent-name>` matches `^[a-z][a-z0-9_-]{1,31}$`. Rejects otherwise with exit 2.
  - Refuses if `agents/<agent-name>/` already exists (exit 3).
  - Creates the directory layout (matching the current `agents/<existing>/` shape):
    - `agents/<name>/profile.md` (from `--profile-text-file` if provided, else a minimal stub with name + role)
    - `agents/<name>/memory/<name>.md` (empty stub with `# <Name>` heading)
    - `agents/<name>/memory/` (subdirectory guaranteed so `_is_agent_dir` sees it)
    - `agents/<name>/journal/` (empty, with `.gitkeep`)
    - `agents/<name>/learnings/` (empty, with `.gitkeep`)
    - `agents/<name>/transcripts/` (empty, with `.gitkeep` — end-session skill expects this)
    - `agents/<name>/inbox/` (empty, with `.gitkeep`)
  - Does NOT create iTerm profiles, does NOT touch `ITERM_PROFILES_PATH`. iTerm setup is a manual Mac step documented in `architecture/platform-parity.md`.
  - Prints the created directory tree to stdout on success.
  - Exits 0 on success.
- [ ] `chmod +x scripts/new-agent.sh`.
- [ ] Smoke test: run against a throwaway name `scripts/new-agent.sh __testagent` in a scratch worktree; verify the tree; `rm -rf agents/__testagent` before committing. The executor must NOT commit the test agent.

### Step 4 — Port the Mac iTerm launcher to `scripts/mac/launch-agent-iterm.sh`

- [ ] Create directory `scripts/mac/`.
- [ ] Create `scripts/mac/launch-agent-iterm.sh`:
  - Shebang: `#!/usr/bin/env bash`
  - `set -euo pipefail`
  - Refuses to run if `uname` is not `Darwin` (exit 2 with `launch-agent-iterm: macOS only`).
  - Usage: `scripts/mac/launch-agent-iterm.sh <agent-name> [initial-task]`.
  - Ports the iTerm spawn + grid positioning logic from `mcps/agent-manager/server.py` `launch_agent`. The executor reads the current Python implementation and produces a faithful bash + `osascript` equivalent. If the Python implementation references helper state (iTerm profile JSON at `ITERM_PROFILES_PATH`), the bash port preserves that reference via the same env var.
  - If the port requires more than ~150 lines of bash or any non-trivial `osascript` scripting block the executor is uncertain about, STOP and escalate to Evelynn rather than guess. Rough plan §2.2 explicitly allowed this script to remain imperfect in Phase 1; correctness is more important than completeness.
- [ ] `chmod +x scripts/mac/launch-agent-iterm.sh`.
- [ ] Create `scripts/windows/launch-agent.sh`:
  - Shebang: `#!/usr/bin/env bash`
  - Body is exactly:
    ```
    #!/usr/bin/env bash
    # Windows mode: Strawberry uses Claude Code subagents (Task tool) for all agent
    # spawning. There is no Windows equivalent of the Mac iTerm launcher by design.
    echo "Windows mode: launch via Task subagent, not this script" >&2
    exit 2
    ```
- [ ] `chmod +x scripts/windows/launch-agent.sh`.

### Step 5 — Write `.claude/skills/agent-ops/SKILL.md`

- [ ] Create directory `.claude/skills/agent-ops/`.
- [ ] Create `.claude/skills/agent-ops/SKILL.md` with the following exact structure:
  - Frontmatter:
    - `name: agent-ops`
    - `description:` — one sentence stating this skill is the entry point for local agent operations: send an inbox message, list agents, scaffold a new agent. Replaces the former `agent-manager` MCP. Model-invocable.
    - `disable-model-invocation: false`
    - `allowed-tools: Bash Read Write Edit Glob Grep`
  - Body sections (in this order):
    1. **Subcommand dispatch.** `$ARGUMENTS` is parsed as `<subcommand> <rest...>`. Supported subcommands (**this is the exact set, no more, no less**):
       - `send <agent> <message...>` — writes an inbox file at `agents/<agent>/inbox/<timestamp>-<shortid>.md` with the exact schema the current `message_agent` MCP tool uses (the executor reads the current schema from `mcps/agent-manager/server.py` and mirrors it exactly). Sender is derived from the caller's CLAUDE.md context (`$CLAUDE_AGENT_NAME` if set, otherwise the skill asks the caller to state who they are and refuses if unclear). Prints the path of the created inbox file.
       - `list [--json]` — shells out to `scripts/list-agents.sh` (with `--format json` if `--json` is given) and prints the result.
       - `new <agent-name> [--role "<role>"]` — shells out to `scripts/new-agent.sh` with the same arguments.
       - **No other subcommands.** No `delegate`, no `converse`, no `launch`. Those are not in Phase 1 scope per D6.
    2. **Refusal rules.**
       - If `$ARGUMENTS` is empty, print the subcommand help (one line per supported subcommand) and exit 0.
       - If the subcommand is unrecognized, refuse with `agent-ops: unknown subcommand <name>` and exit 2.
       - If `send` cannot determine a sender, refuse with `agent-ops send: sender unknown` and exit 2.
       - If `send` target agent directory does not exist, refuse with `agent-ops send: unknown agent <name>` and exit 2.
    3. **Platform note.** One paragraph stating this skill runs identically on macOS and Windows (POSIX-only bash), and that agent launching is macOS-only via `scripts/mac/launch-agent-iterm.sh` and not available from this skill.
    4. **Cross-references.** Link to `architecture/platform-parity.md` and to this plan under `plans/proposed/`.

### Step 6 — Call-site sweep: enumerate references

- [ ] Produce the grep table. The executor runs these exact greps (POSIX-portable) from repo root and saves the combined output to `/tmp/agent-manager-callsites.txt` for use in Step 7:
  - `grep -rn --include='*.md' -E '\b(list_agents|get_agent|create_agent|launch_agent|message_agent|start_turn_conversation|speak_in_turn|pass_turn|end_turn_conversation|read_new_messages|get_turn_status|invite_to_conversation|escalate_conversation|resolve_escalation|delegate_task|complete_task|check_delegations|report_context_health)\b' agents/ plans/ CLAUDE.md architecture/ .claude/ windows-mode/ assessments/ incidents/`
  - The set of 53 files from Bard's startup grep is a starting point; the executor re-runs to catch anything added since.

- [ ] Confirm none of the matches live under `mcps/` — `mcps/agent-manager/` is being archived and its internal references to its own tool names are expected; do not touch them.

### Step 7 — Call-site sweep: replacement table

The executor applies the following replacement table. All replacements are **documentation/profile text** — these are user-facing references to tool names, not actual code calls, because agents invoke these via MCP and there are no `.py` or `.ts` call sites to rewrite in agent profiles or plans.

| Old reference | New reference |
|---|---|
| `message_agent(name, message)` / "use `message_agent`" | `/agent-ops send <name> <message>` |
| `list_agents()` / "use `list_agents`" | `/agent-ops list` |
| `create_agent(...)` | `/agent-ops new <name>` |
| `launch_agent(name)` | "macOS only: `scripts/mac/launch-agent-iterm.sh <name>`. Windows: use Task subagent." |
| `start_turn_conversation`, `speak_in_turn`, `pass_turn`, `end_turn_conversation`, `read_new_messages`, `get_turn_status`, `invite_to_conversation`, `escalate_conversation`, `resolve_escalation` | Replace the entire "Conversation modes" bullet block in `agents/memory/agent-network.md` with: "Turn-based conversations are deferred to Phase 2. During Phase 1, use `/agent-ops send` for peer-to-peer messages and escalate to Evelynn via inbox for multi-agent discussions." Remove every standalone reference to the turn-conversation tool names in other files. |
| `delegate_task`, `complete_task`, `check_delegations` | Replace with a single line: "Delegations are tracked via `agents/delegations/*.json` files. Phase 1 has no skill wrapper; Evelynn manages delegation state directly. Phase 2 will introduce `/agent-ops delegate` if needed." Update the Protocol §7 bullet in `agents/memory/agent-network.md` from "Delegated task → call `complete_task`" to "Delegated task → report completion to Evelynn and update the delegation JSON file directly." |
| `report_context_health` | Replace with "Phase 1: context health reporting is deferred. Report context health conversationally in your turn reply to Evelynn." |

Rules for applying the table:

- [ ] **Exact-string, no-regex-drift replacements.** The executor uses `Edit` per file; no `sed -i` sweeps, because `sed -i` has macOS/Linux portability differences and the executor must preserve exact surrounding Markdown formatting.
- [ ] **Skip `plans/implemented/*` and `plans/archived/*`.** Historical plans are frozen; do not rewrite them. The executor verifies via `git log` that each edited file is NOT in `implemented/` or `archived/`.
- [ ] **Skip learnings files under `agents/*/learnings/`.** Learnings are historical.
- [ ] **Skip transcripts under `agents/*/transcripts/`.** Transcripts are verbatim history.
- [ ] **Do edit:** `CLAUDE.md`, `agents/memory/agent-network.md`, `agents/roster.md`, `architecture/mcp-servers.md`, `architecture/agent-network.md`, `architecture/agent-system.md`, every `agents/*/memory/*.md` that contains a reference, every `plans/proposed/*.md` that contains a reference (except this plan and the rough plan it supersedes — leave those intact for provenance), every `plans/approved/*.md` that contains a reference, every `plans/in-progress/*.md` that contains a reference, every `.claude/agents/*.md` that contains a reference, `windows-mode/README.md`.
- [ ] The executor produces a per-file edit list in the commit message of the form `edited: <path> (<n> replacements)`.

### Step 8 — Agent profile `skills:` frontmatter updates

- [ ] For each file under `.claude/agents/*.md`, read the current `skills:` frontmatter line (if present). If the line exists, append `agent-ops` to the list. If no `skills:` line exists, add one immediately after the `name:` line with value `skills: [agent-ops]`.
- [ ] Apply this to **every** agent file in `.claude/agents/` (the startup listing showed: `bard.md`, `katarina.md`, `lissandra.md`, `pyke.md`, `swain.md`, `syndra.md`, `yuumi.md`, `poppy.md`, plus any others present at execution time — the executor enumerates via `ls .claude/agents/*.md`).
- [ ] Also apply to any agent-definition markdown under `agents/*/profile.md` IF and only if that file already uses a `skills:` frontmatter. If it does not, leave it alone — Phase 1 does not introduce frontmatter where none existed.

### Step 9 — Create `architecture/platform-parity.md`

- [ ] Create `architecture/platform-parity.md` with sections:
  1. **Intent.** One paragraph: Strawberry runs on macOS (primary) and Windows (Git Bash + Claude Code subagents). All skills and scripts are POSIX-portable by default. Platform-specific affordances are listed explicitly here and only here.
  2. **Skill parity.** Table with columns `skill | macOS | Windows | notes`. Row for `/agent-ops`: both supported, POSIX-only. Row for `/end-session`: both supported. Row for `/end-subagent-session`: both supported. (Any other skill present at execution time is added.)
  3. **Script parity.** Table with columns `script | macOS | Windows | notes`. Rows:
     - `scripts/list-agents.sh` — both supported.
     - `scripts/new-agent.sh` — both supported.
     - `scripts/mac/launch-agent-iterm.sh` — macOS only. Windows counterpart: "use Task subagent; no launch script."
     - `scripts/windows/launch-agent.sh` — stub, prints non-support message.
     - `scripts/launch-evelynn.sh` — unchanged by this phase, macOS only. Windows counterpart: subagent.
     - `scripts/restart-evelynn.ps1` — unchanged by this phase; noted as Windows-only historical artifact, marked for deletion in Phase 2 per D4.
  4. **MCP parity.** Line stating `agent-manager` is archived in Phase 1; `/agent-ops` replaces it on both platforms.
  5. **Cross-references.** Link to this plan, to the rough plan, to `CLAUDE.md` rule 14, and to `.claude/skills/agent-ops/SKILL.md`.

### Step 10 — Rewrite `agents/memory/agent-network.md`

- [ ] Rewrite the **Communication Tools** section to list only:
  - `/agent-ops send <agent> <message>` — inbox message
  - `/agent-ops list` — roster
  - `/agent-ops new <name>` — scaffold a new agent (macOS or Windows)
  - macOS-only: `scripts/mac/launch-agent-iterm.sh` — launch in iTerm
  - Windows: launch via Task subagent
- [ ] Remove the **Conversation modes** block entirely and replace with the Phase 1 deferral note from Step 7.
- [ ] Rewrite Protocol §1–§10 so that all references to MCP tool names use the new skill forms. Preserve the numbering and the load-bearing content (e.g., §9 plan approval gate, §10 plan-promote.sh) exactly — only tool-name phrasing changes.
- [ ] Delete the **Restricted Tools (evelynn MCP server)** section IF AND ONLY IF it refers exclusively to `agent-manager` surfaces. If it still references `end_all_sessions` / `commit_agent_state_to_main`, leave that section intact (it is Phase 2 scope).

### Step 11 — CLAUDE.md rule additions

- [ ] Add the following rule verbatim to `CLAUDE.md` under "Critical Rules", appended at the next available number (expected to be rule 15; the executor verifies the current highest rule number and uses `N+1`):
  - **Rule 15 (exact text):** "Project MCPs are only for external system integration. Local coordination, state management, and procedural discipline belong in skills, CLAUDE.md rules, and shell scripts. Before adding a new MCP, confirm it talks to a stateful or protocol-heavy external system per `architecture/platform-parity.md` and the decision tree in `plans/proposed/2026-04-08-mcp-restructure.md` §1. The `agent-manager` MCP is archived as of Phase 1 of the MCP restructure; use `/agent-ops` instead."
- [ ] Add (same rule block, next number, expected rule 16):
  - **Rule 16 (exact text):** "All skills and scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) MUST be POSIX-portable bash runnable on both macOS and Git Bash on Windows. Platform-specific affordances live under `scripts/mac/` or `scripts/windows/` and are listed in `architecture/platform-parity.md`."
- [ ] Do NOT renumber existing rules. Do NOT touch rules 1–14.

### Step 12 — Deregister `agent-manager` MCP

- [ ] Read `.mcp.json`.
- [ ] Remove the `agent-manager` entry (and only that entry).
- [ ] Verify the JSON is still valid: `python -c "import json; json.load(open('.mcp.json'))"` exits 0.
- [ ] Do NOT touch the `evelynn` entry. Phase 2 owns that.

### Step 13 — Archive `mcps/agent-manager/` with README pointer

- [ ] Write `mcps/agent-manager/README.md` (overwriting any existing README) with exact text:

  ```
  # agent-manager (archived — Phase 1 of MCP restructure)

  This MCP server is archived as of the Phase 1 MCP restructure.

  Replacement surfaces:

  - `/agent-ops send <agent> <message>` — inbox messaging
  - `/agent-ops list` — agent roster
  - `/agent-ops new <agent-name>` — scaffold a new agent
  - `scripts/mac/launch-agent-iterm.sh` — macOS-only launcher
  - Windows: launch via Task subagent (no script)

  See:

  - `plans/implemented/2026-04-09-mcp-restructure-phase-1-detailed.md` (once this plan lands)
  - `plans/proposed/2026-04-08-mcp-restructure.md` (rough plan, governs Phases 2–3)
  - `.claude/skills/agent-ops/SKILL.md`
  - `architecture/platform-parity.md`

  The Python source remains in this directory as reference. Deletion is scheduled for Phase 3.
  ```

- [ ] Do NOT modify `mcps/agent-manager/server.py` or any other file inside `mcps/agent-manager/` beyond the README. The source is preserved verbatim per D2.

### Step 14 — Same-commit ordering guarantee

- [ ] Steps 5, 6, 7, 8, 10, 11, 12, 13 MUST land in **one single commit**. This is the rough plan's §7.2 mandatory failure-mode guard: the MCP deregistration (Step 12), the call-site sweep (Step 7), the CLAUDE.md rule updates (Step 11), the skill creation (Step 5), and the archive README (Step 13) must be atomic. If the executor splits them across commits, any intermediate state will leave agents pointing at missing tools.
- [ ] Steps 2, 3, 4, 9 (scripts and architecture doc) MAY land in an earlier separate commit if the executor prefers to stage the work — but only if that earlier commit leaves the MCP fully registered and the call sites untouched (i.e., the repo is still in "pre-migration" state). Recommended: land everything in one commit to match the rough plan's guidance.
- [ ] Commit message (exact text, single-commit path):
  `chore: mcp restructure phase 1 — agent-manager → /agent-ops + scripts + parity docs`
  The commit body MUST include:
  - A bulleted list of every file created, modified, moved, or archived (see artifact inventory).
  - The `list_agents.sh` smoke-test agent count from Step 2.
  - The per-file replacement counts from Step 7.
  - A line: `Refs: plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md`

### Step 15 — Exit criteria test (executor MUST perform)

One full delegation round-trip using only the new skill, with no `agent-manager` MCP calls:

- [ ] Close any Evelynn session first (she has `agent-manager` in her context from before the deregistration). The executor does NOT need to end-session Evelynn mid-execution — but the exit test MUST be run from a fresh Claude Code top-level session started AFTER Step 12 lands and AFTER `.mcp.json` is re-read.
- [ ] From the fresh session, Evelynn uses `/agent-ops send bard "round-trip ack"` to write to Bard's inbox.
- [ ] Verify the inbox file exists at `agents/bard/inbox/<timestamp>-*.md` with the expected schema.
- [ ] From the fresh session (still Evelynn), run `/agent-ops list` and verify Bard, Katarina, Syndra, and Evelynn appear.
- [ ] From the fresh session, run `/agent-ops new __exittest --role "exit criteria test agent"` and verify the scaffold. Then remove the scratch agent: `rm -rf agents/__exittest` and commit the removal as a follow-up `chore: remove exit-test scratch agent` commit (NOT part of the Phase 1 commit).
- [ ] If any step of the exit test fails, the executor rolls forward with a fix rather than reverting — Phase 1 is designed to be fixable in place because the archived `mcps/agent-manager/` directory is still present and can be re-registered by reversing Step 12 in a single commit if needed.

### Step 16 — Report

- [ ] The executor reports completion to Evelynn via inbox (using the new `/agent-ops send evelynn ...` surface — meta-test of the round-trip). Report includes: commit hash, files touched count, exit-test result, any deviations from this plan.
- [ ] Executor does NOT end their session. They wait for Evelynn's acknowledgment per Rule 13.

## Out of scope for Phase 1 (do NOT do these)

Explicit non-goals. If the executor is tempted to do any of these, STOP:

- Do not touch `mcps/evelynn/`. Phase 2 owns it.
- Do not introduce `scripts/commit-agent-state.sh`. Phase 2 per D7.
- Do not modify `/end-session` or `/end-subagent-session`.
- Do not add `/delegate`, `/converse`, `/new-agent`, or any skill other than `/agent-ops`.
- Do not delete `mcps/agent-manager/`. Archive only per D2.
- Do not create PowerShell siblings for scripts. Git Bash is the Windows shell.
- Do not evaluate marketplace plugins. Phase 2 per D5.
- Do not create `scripts/restart-evelynn-*`. Phase 2 deletes the old one per D4.
- Do not rewrite historical plans, learnings, transcripts.

## Rollback

If any step blocks and cannot be fixed in place:

1. Revert the single Phase 1 commit (`git revert <hash>`).
2. Confirm `.mcp.json` re-lists `agent-manager`.
3. Confirm `mcps/agent-manager/` is untouched (it should be, except for the README — `git revert` handles it).
4. Report the block to Evelynn with the exact failing step number and the command output.

Rollback is intentionally cheap because the archived MCP source is preserved in place throughout Phase 1.

## Open questions (executor-facing only)

None. All design questions were absorbed into decisions D1–D7 above. If the executor encounters a situation this plan does not cover, the rule is: **stop, escalate to Evelynn, do not improvise.**

## Supersession

This plan is the detailed Phase 1 spec for `plans/proposed/2026-04-08-mcp-restructure.md`. When this plan lands (moves to `plans/implemented/`), the rough plan's Phase 1 section is considered implemented. The rough plan itself remains in `plans/proposed/` until Phases 2 and 3 each get their own detailed specs and land.
