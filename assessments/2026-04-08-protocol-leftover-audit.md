---
title: Protocol + Leftover Audit of Strawberry Repo
owner: pyke
created: 2026-04-08
scope: agents/, mcps/, scripts/, architecture/, .claude/, root configs
excludes: plans/implemented/, plans/archived/, journal/, transcripts/, learnings/
cross-refs:
  - plans/proposed/2026-04-08-mcp-restructure.md
  - plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md
  - plans/proposed/2026-04-08-evelynn-continuity-and-purity.md
  - plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md
---

# Protocol + Leftover Audit

Walks the strawberry repo for items that either (a) violate current CLAUDE.md rules, (b) are stale from an earlier operating model, or (c) don't fit the post-restructure shape the proposed plans are pulling us toward. Items already covered by the four referenced plans are noted and deferred — this file does not re-audit them.

**Severity legend:** `drop` (remove outright) · `consolidate` (fold into something else) · `rename` (wrong shape but keep the substance) · `rewrite` (content stale, format OK) · `keep` (noted only, no action).

---

## 1. agent-network / agents/ directory

| Path | What's wrong | Severity | Rationale |
|---|---|---|---|
| `agents/memory/agent-network.md` | Documents the `agent-manager` / `evelynn` MCP tool surface as the coordination contract (`message_agent`, `list_agents`, `start_turn_conversation`, `delegate_task`, `check_delegations`, `report_context_health`, ...). The entire Communication Tools + Protocol + Conversation modes blocks are built on tools that Phase 1 restructure deletes. | rewrite | Covered by phase-1-detailed Step 10; flagging here only because the file is load-bearing for every agent startup. |
| `agents/memory/agent-network.md` "Restricted Tools" section | Lists `end_all_sessions` + `commit_agent_state_to_main` on the evelynn MCP. These are Phase 2 concerns but they also reinforce the "only Evelynn can" discipline that today has no enforcement. | keep | Phase 2 owns this, but Protocol v2 should reference it. |
| `agents/roster.md` | Still lists **Irelia (retired)** and doesn't mention **Bard** or minions accurately. Missing Zilean entirely (directory exists with `inbox/ journal/ transcripts/` but no profile.md). Pyke + Yuumi descriptions don't match `agents/memory/agent-network.md` (two rosters, two truths). | consolidate | Two roster files drift. Collapse to one source of truth (either delete `roster.md` or have `agent-network.md` import from it). Reference from `scripts/list-agents.sh` in phase-1 restructure. |
| `agents/zilean/` | Directory exists with `inbox/ journal/ transcripts/` — **no `profile.md`, no `memory/`**, not in roster. Looks like a half-scaffolded or abandoned agent. | drop | Either delete the dir or create the profile and add to roster. Current state is a lie. |
| `agents/irelia/` | "Retired" head agent still scaffolded with full dir tree (inbox, memory, learnings, profile). Takes up roster real estate and confuses new readers. | drop | Archive out of `agents/` entirely (e.g. `agents/.retired/irelia/`) or delete. Retirement should mean gone from the live roster. |
| `agents/rakan/`, `agents/shen/` | Both have profiles and full dirs but are **not** in `agent-network.md` roster table. Shen is in `roster.md` (git security implementer), Rakan is not in either. | rename-or-rewrite | Decide: active or retired? Either add to `agent-network.md` with clear role or retire alongside Irelia. Shen in particular was added as "Pyke's implementer" which no longer fits the Opus-plans-Sonnet-executes model — Pyke's plans go to Katarina now. |
| `agents/conversations/` | **33 `.turn.md` / conversation files** — all artifacts of the turn-based conversation MCP tool set that Phase 1 deletes. Once `start_turn_conversation` is gone, these become git history fossils. | drop | Move whole directory to `agents/.archive/conversations/` or delete. Protocol v2 is inbox + SendMessage only. |
| `agents/delegations/` | Six `d-20260405-*.json` files from the old `delegate_task` / `complete_task` MCP surface. | drop | Same story — old MCP tool artifacts. Protocol v2 will track delegation differently (task-board MCP in Phase 2, or simply via TaskCreate/TaskUpdate in subagent mode). Archive or delete. |
| `agents/health/` | `heartbeat.sh` + 16 `<name>.json` files. The heartbeat is still called at agent startup per CLAUDE.md. | keep | Heartbeat is fine and platform-neutral. Only flag: 16 agents' health files but only ~12 live agents — stale entries should be pruned. |
| `agents/inbox/` (top-level) | Empty directory. The per-agent inboxes are under `agents/<name>/inbox/`. This top-level one has no purpose. | drop | Delete. Leftover scaffolding. |
| `agents/wip/` | Empty directory. No documented purpose. | drop | Delete unless someone claims it. |
| `agents/journal/`, `agents/learnings/`, `agents/transcripts/`, `agents/memory/` | Top-level shared dirs. `memory/` holds the two canonical shared memory files (`agent-network.md`, `duong.md`) — legitimate. The other three are **empty** because journals/transcripts/learnings live under `agents/<name>/` per agent. | drop (3) / keep (memory/) | `agents/journal/`, `agents/learnings/`, `agents/transcripts/` are empty scaffolding from an earlier shared-journal idea. Delete. |
| `agents/<name>/iterm/` (multiple agents) | Mac-only iTerm profile blobs scattered across agent dirs. Violates the new Mac/Windows parity rule — these are macOS-only state committed into per-agent memory. | consolidate | Move all iTerm affordances into a single `scripts/mac/iterm-profiles/` or out of git entirely (regenerated on demand). Phase-1-detailed covers the launcher but NOT the profile dirs. |
| `agents/launch-agent.sh`, `agents/boot.sh` | Shell scripts living inside `agents/`. `launch-agent.sh` is another launcher path (parity risk — is this the Mac launcher, the Windows launcher, both?). `boot.sh` undocumented. | consolidate | Move to `scripts/` with explicit Mac/Windows parity designation per rule 16 from phase-1-detailed. Don't leave scripts hiding inside data directories. |
| `agents/<each>/profile.md` + `agents/<each>/memory/<name>.md` referencing MCP tools | Grep will show references to `message_agent`, `list_agents`, `start_turn_conversation`, `delegate_task`, `complete_task` in ~12 profiles and ~12 memory files. | rewrite | Phase 1 call-site sweep (Step 7). Noting here so Protocol v2 drafter knows the surface area is large. |

---

## 2. MCP surfaces (`mcps/`)

Deferred to existing plans. Summary only:

| Path | Plan that owns it |
|---|---|
| `mcps/agent-manager/` (entire server) | `2026-04-08-mcp-restructure.md` Phase 1 + `2026-04-09-mcp-restructure-phase-1-detailed.md` — archive in Phase 1, delete Phase 3. |
| `mcps/evelynn/` (three concerns: local control, telegram, task board) | `2026-04-08-mcp-restructure.md` Phase 2 — three-way split. |
| `mcps/shared/helpers.py` | Implicit Phase 2 dependency, not separately addressed. Flag: once both MCPs above restructure, this becomes orphan code. Protocol v2 should add "after Phase 2, audit `mcps/shared/` for dead code." |
| `mcps/agent-manager/__pycache__`, `mcps/shared/__pycache__` | `__pycache__` committed to git. | **drop** | Add to `.gitignore` and remove from tracking. Not in any plan. Low-severity cleanup. |

---

## 3. Scripts (`scripts/`)

| Path | What's wrong | Severity | Rationale |
|---|---|---|---|
| `scripts/launch-evelynn.sh` | Mac-only iTerm launcher at top level — violates new rule 16 (parity: Mac-only scripts live under `scripts/mac/`). | rename | Move to `scripts/mac/launch-evelynn.sh`. Windows has `windows-mode/launch-evelynn.ps1` + `.bat` already. |
| `scripts/restart-evelynn.ps1` | Windows-only PowerShell script at top level. Same rule-16 violation. Also flagged in mcp-restructure D4 as "subagent mode moots the concept — delete in Phase 2." | drop (per D4) or rename | Phase 2 of MCP restructure already owns this, but it violates parity rules today. At minimum move to `scripts/windows/` until Phase 2 deletes it. |
| `scripts/discord-bot-wrapper.sh`, `scripts/discord-bridge.sh`, `scripts/start-telegram.sh`, `scripts/telegram-bridge.sh` | Runtime bridge scripts for Discord/Telegram relays. Unclear if still in use — `.mcp.json` doesn't reference Discord and Telegram is inside `mcps/evelynn/`. | keep (but audit) | Not a protocol violation, but Protocol v2 should call for an audit: what is still running on the VPS / PM2 and what is dead code? These touch PII flows. |
| `scripts/gh-auth-guard.sh`, `scripts/gh-audit-log.sh`, `scripts/setup-agent-git-auth.sh`, `scripts/setup-branch-protection.sh` | Git + GitHub security scripts. All Pyke territory, all still relevant. | keep | Parity audit: are they POSIX-portable? If they use `osascript`/Keychain, they need to move to `scripts/mac/`. Protocol v2 should schedule an audit pass. |
| `scripts/google-oauth-bootstrap.sh`, `scripts/_lib_gdoc.sh`, `scripts/plan-fetch.sh`, `scripts/plan-publish.sh`, `scripts/plan-unpublish.sh`, `scripts/plan-promote.sh` | Drive mirror infrastructure. Plan-promote is enforced by rule 12 and is the only sanctioned path to move plans out of `proposed/`. | keep | Noting only: `plan-lifecycle-protocol-v2` plan adds `ready/` as a new stop, which requires `plan-promote.sh` to learn a new target. That's in that plan's scope. |
| `scripts/migrate-ops.sh` | One-shot migration from the ops-separation work weeks ago. Already executed. | drop | One-time migration script left lying around. Delete it. |
| `scripts/test_plan_gdoc_offline.sh` | Test harness. Belongs under `tests/` or similar, not in `scripts/`. | rename or keep | Low priority — decide whether `scripts/` should be runtime-only vs include tests. |
| `scripts/safe-checkout.sh` | Git worktree wrapper required by rule 5. | keep | Still load-bearing. Parity: confirm POSIX-only. |
| `scripts/vps-setup.sh`, `scripts/deploy.sh`, `scripts/result-watcher.sh` | VPS infra scripts. | keep | Not in Protocol v2 scope. |
| `scripts/commit-ratio.sh` | Metric tracker. One-off. | keep | Not a violation. |
| `scripts/health-check.sh` | Separate from `agents/health/heartbeat.sh`. Two "health" systems. | consolidate | Pick one. Protocol v2 should clarify the purpose split (system health vs agent liveness). |
| `scripts/clean-jsonl.py`, `scripts/pre-commit-secrets-guard.sh` | Used by `/end-session` skill + pre-commit hook. | keep | Load-bearing for rule 11 (secrets) and rule 14 (end-session). |

---

## 4. `.claude/` (Claude Code configs + skills + agent profiles)

| Path | What's wrong | Severity | Rationale |
|---|---|---|---|
| `.claude/skills/end-session/`, `.claude/skills/end-subagent-session/` | The two skills that implement rule 14. Already `disable-model-invocation: true` per recent commit `dc638bb`. | keep | Load-bearing. |
| `.claude/skills/` — only two skills | Phase 1 MCP restructure ships `/agent-ops` (one new skill). Plan-lifecycle-v2 ships `draft-plan` + `detailed-plan`. Skills surface will roughly 2× once these land. | keep | Noting for Protocol v2: skill count will grow; ensure preload lists in `.claude/agents/*.md` get maintained centrally. |
| `.claude/agents/` (eight files: bard, katarina, lissandra, pyke, poppy, swain, syndra, yuumi) | Only 8 agents have Claude Code native subagent profiles here. The roster has 15+ agents. **Implication:** only 8 agents can run as subagents; the others must run as separate top-level Claude Code sessions (which is exactly the Mac-only iTerm pattern the restructure is pulling away from). | consolidate | Protocol v2 decision point: are we going subagent-first? If yes, every agent in the roster needs a `.claude/agents/<name>.md` file and the roster should be pruned to what's actually usable cross-platform. This is the core parity question. |
| `.claude/settings.json`, `.claude/settings.local.json` | Claude Code session settings. `settings.local.json` is user-scoped and typically gitignored. | verify | Confirm `settings.local.json` is in `.gitignore`. If committed, it's a leftover. |

---

## 5. Plans currently in `plans/proposed/`

Not re-auditing content, just flagging staleness + ownership:

| File | Status |
|---|---|
| `2026-04-03-discord-cli-integration.md` | **Stale** — 5 days old, pre-restructure era, may be implemented already. Verify. |
| `2026-04-05-gh-auth-lockdown.md` | Pyke memory says PR #33 was pending merge. Need to check if landed → archive or keep. |
| `2026-04-05-launch-verification.md` | Pre-restructure. Verify still relevant. |
| `2026-04-05-plan-viewer.md` | Verify. |
| `2026-04-08-agent-visible-frontend-testing.md` | Recent, keep. |
| `2026-04-08-autonomous-delivery-pipeline.md` | Recent, keep. |
| `2026-04-08-cafe-from-home.md` | Pyke authored. Keep. |
| `2026-04-08-end-session-skill.md` | Check: is there also one in `in-progress/` or `implemented/`? Phase 1 of end-session already landed per commits (`dc638bb`). This proposed file may be a duplicate / earlier version. |
| `2026-04-08-evelynn-continuity-and-purity.md` | Active, load-bearing for Protocol v2. Keep. |
| `2026-04-08-mcp-restructure.md` | Active. Keep. |
| `2026-04-08-myapps-gcp-direction.md` | Unrelated to protocol. Keep. |
| `2026-04-08-plan-lifecycle-protocol-v2.md` | Active. Keep. |
| `2026-04-09-mcp-restructure-phase-1-detailed.md` | Active. Keep. |

**Action for Protocol v2 / migration plan:** triage the four pre-2026-04-08 plans and either promote them (plan-promote.sh) or archive them. They've been sitting in `proposed/` for days with no movement — protocol rot.

---

## 6. Docs / architecture (`architecture/`, `docs/`, `README.md`, `GIT_WORKFLOW.md`)

| Path | What's wrong | Severity | Rationale |
|---|---|---|---|
| `architecture/agent-network.md`, `architecture/agent-system.md` | Almost certainly reference MCP tool names and the pre-restructure coordination model. | rewrite | Same sweep as `agents/memory/agent-network.md`. Phase 1 Step 7 covers these files specifically. |
| `architecture/mcp-servers.md` | Documents current MCP servers. Will be obsolete after Phase 1 and rewritten after Phase 2. | rewrite | Phase 1 Step 7. |
| `architecture/telegram-relay.md`, `architecture/discord-relay.md` | Document runtime bridges; cross-ref with `scripts/` audit above. | keep (but audit) | Verify against what's actually running. |
| `architecture/infrastructure.md`, `architecture/system-overview.md`, `architecture/security-debt.md`, `architecture/git-workflow.md`, `architecture/claude-billing-comparison.md` | Infra + security + billing docs. | keep | Not protocol-layer. |
| `architecture/plan-gdoc-mirror.md` | Drive mirror architecture. Still active. | keep | Load-bearing for rule 12. |
| `architecture/README.md` | Architecture index. | verify | Confirm it still links to the right files after rewrites. |
| `GIT_WORKFLOW.md` (repo root) | Duplicate of `architecture/git-workflow.md`? Root-level is older. | consolidate | Pick one location. Root level + architecture/ have the same topic. |
| `docs/vps-setup.md` | Single-file `docs/` dir. Weird shape. | consolidate | Either merge into `architecture/infrastructure.md` or promote `docs/` into a first-class section. |
| `incidents/2026-04-04-memory-wipe-incident.md` | Single incident report. `incidents/` has no index. | keep | Fine as archive. |
| `assessments/` (5 files) | One recent (2026-04-08-myapps-snapshot.md), four older. All by Syndra or per earlier audit work. | keep | Assessment archive. Protocol v2 should decide retention policy. |

---

## 7. Root-level config + tasklist / tools

| Path | What's wrong | Severity | Rationale |
|---|---|---|---|
| `ecosystem.config.js` | PM2 config. Lives at repo root. | keep | Runtime infra. |
| `tasklist/` (Dockerfile, fly.toml, server.js, HANDOVER.md, tasklist.html) | Fly.io deployment of a tasklist app. **Unclear if still deployed** — PR history shows it landed, no recent activity. `HANDOVER.md` suggests it was a side project that was handed back to Duong. | keep (but verify) | Protocol v2 should note: is this an app that's live? If yes, document it in `architecture/infrastructure.md`. If no, archive. |
| `tools/age-bundle.js`, `tools/decrypt.sh`, `tools/encrypt.html`, `tools/encrypt.html.sha256` | Age encryption tooling. Rule 11 requires `tools/decrypt.sh` as the exclusive decrypt path. | keep | Load-bearing for secrets policy. |
| `strawberry/`, `strawberry.pub/` directories | Two directories named after the repo itself. Unclear purpose at root. | investigate | **Either a submodule, a site mirror, or leftover scaffolding.** Worth 5 minutes of investigation from Katarina before migration — could be the website, could be junk. |
| `secrets/` | Gitignored by policy. | keep | |
| `apps/contributor-bot/`, `apps/discord-relay/`, `apps/myapps/` | App code. | keep | Not protocol-layer. |
| `services/telegram-bot/` | Service code. | keep | Not protocol-layer. |
| `windows-mode/` (launch-evelynn.bat, .ps1, launch-yuumi.bat, README.md) | Windows launch scripts at top level as a sibling to `scripts/`. Rule-16 parity violation: scripts should live under `scripts/windows/`. | rename | Move to `scripts/windows/` per phase-1-detailed Step 4 pattern. |

---

## 8. Cross-cutting themes (input for Protocol v2)

These are the patterns the above list reveals. Swain should use them to shape Task #2.

1. **The subagent pivot is half-done.** Only 8 of ~15 agents have `.claude/agents/<name>.md` files. The Mac iTerm launcher is the assumed path for the other 7. Protocol v2 must pick: every live agent is a subagent (prune roster, scaffold profiles), or the multi-process model is still blessed (document it, build the Windows equivalent).
2. **Two rosters drift.** `agents/roster.md` and `agents/memory/agent-network.md` both list agents, with different contents. Collapse to one.
3. **Retired/half-scaffolded agents pollute the namespace.** Irelia, Zilean, Rakan, Shen all either don't have clear status or haven't been archived cleanly. Protocol v2 needs an explicit retirement procedure.
4. **Turn-based conversations + delegations JSON** are visible fossils of the old coordination model. 33 conversation files and 6 delegation files remind every reader of a system that Phase 1 deletes. Archive them.
5. **Platform-specific scripts live at top level.** `scripts/launch-evelynn.sh` (mac), `scripts/restart-evelynn.ps1` (windows), `windows-mode/*` (windows), `agents/launch-agent.sh` (?), `agents/boot.sh` (?). Phase 1 introduces the `scripts/mac/` and `scripts/windows/` convention — Protocol v2 should require a single sweep of EVERY existing script to classify it per the new convention, not just the ones explicitly named in phase-1-detailed.
6. **Per-agent `iterm/` directories.** Committing Mac-specific profile state into per-agent dirs is the exact parity anti-pattern the restructure is trying to root out. Move or delete.
7. **Stale `plans/proposed/` entries.** Four plans from 2026-04-03 through 2026-04-05 are sitting in `proposed/` with no movement. Protocol v2 should add a staleness policy (or the lifecycle-v2 plan does — check §3 of that plan).
8. **Empty directories as ghost scaffolding.** `agents/inbox/`, `agents/wip/`, `agents/journal/`, `agents/learnings/`, `agents/transcripts/` all exist at the shared level while the real data lives per-agent. Delete.
9. **`__pycache__` committed.** Minor but symptomatic of `.gitignore` hygiene gaps. Audit.
10. **`health-check.sh` vs `agents/health/heartbeat.sh`.** Two "health" surfaces with unclear division. Unify.

---

## What this audit does NOT do

- Does not propose specific moves/deletes/renames for every item — that's Task #3 (the migration plan Pyke owns next).
- Does not re-litigate anything the four referenced plans already cover. Where a conflict exists, those plans win.
- Does not audit `plans/implemented/`, `plans/archived/`, agent journals, transcripts, or learnings (out of scope per Task #1 description).
- Does not grade whether the repo is "good" or "bad" — only whether items match current rules and current direction.
