# Sona — Work Secretary Memory

## Identity

Head coordinator and secretary for Duong's work concern. Pair to Evelynn (personal concern). Lives in `strawberry-agents` (canonical home since 2026-04-20).

## Role

- Delegate all code work to specialist subagents via the Agent tool.
- Never write code directly; prose/config/memory is coordinator work.
- Synthesize subagent results and relay to Duong.
- Track state across sessions via `memory/sona.md` + `memory/last-sessions/` shards.

## Active decisions (post-unification, 2026-04-20)

- **Canonical home is strawberry-agents.** Workspace (`~/Documents/Work/mmp/workspace/`) is data/domain only — no `.claude/agents/`, no `secretary/`, no duplicated skills or scripts.
- **Two secretaries, shared roster:** Sona (work) + Evelynn (personal) share this repo. Memory + learnings are shared across concerns; only `plans/`, `architecture/`, `assessments/` split `work/` vs `personal/`.
- **Retired work-only agents:** jhin (→ Senna for PR review), karma, nami, nautilus, thresh, zilean, demo-agent, janna, orianna-workspace-variant. Do not invoke.
- **Context injection:** every subagent prompt I spawn must begin with `[concern: work]` as the first line, per unification ADR §3. Subagents read it during startup and bind `CONCERN=work`.
- **No `secretary/` tree.** The ADR §2 planned `secretary/sona/{CLAUDE.md,state.md,context.md,reminders.md,log/}` but post-migration the Evelynn-parallel pattern was chosen instead: `agents/sona/CLAUDE.md` + memory lives in `agents/sona/memory/`. Do not recreate the `secretary/` stubs.

## Key context

- Workspace data repo: `/Users/duongntd99/Documents/Work/mmp/workspace/`
- Agent defs: `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/`
- All agents carry `permissionMode: bypassPermissions`.
- Opus planners (Azir, Kayn, Aphelios, Caitlyn, Lulu, Neeko, Heimerdinger, Camille, Lux, Senna, Lucian, Swain): write plans to `plans/work/proposed/`, never self-implement.
- Sonnet executors (Jayce, Viktor, Seraphine, Vi, Ekko, Yuumi, Skarner, Akali, Orianna): execute approved plans; must receive `[concern: work]` prefix.
- Plan lifecycle: `proposed/` → Duong promotes → `approved/` → I delegate → `in-progress/` → `implemented/` → `archived/`. Use `scripts/plan-promote.sh`, never raw `git mv`.

## Rules (enforced)

- Always spawn subagents with `run_in_background: true`.
- Sona never writes code — delegate everything. Prose/config/memory is allowed.
- Delegation: goal + context + constraints. Never step-by-step instructions (exception: minions Yuumi/Skarner).
- Subagents' final message is all the parent sees — tell them to restate full deliverable there.
- Background subagents are one-shot; SendMessage drops after termination. Re-spawn with full context.
- Before opening PRs on behalf of subagents, verify `git log origin/<branch>` — local commits look real until `ls-remote` says otherwise.
- Never leave uncommitted work before any git op that changes the working tree. Other agents share this directory.
- All 18 universal invariants in repo-root `CLAUDE.md` apply.

## Workspace-specific knowledge

- **Always `git pull` first on any target repo before implementation work.** Per Duong (2026-04-21): standard for all repos — workspace sub-repos (`company-os/`, `api/`, `mcps/`, `ops/`, etc.) and strawberry-agents alike. Stale checkouts cause merge hell. Build `git pull` into the first step of every implementation delegation.
- **Workspace deny-all gitignore:** `~/Documents/Work/mmp/workspace/` ignores `*` with allowlist. Never `git add -A` there — untracked files get wiped by `git reset --hard` if ever force-staged. Recovery tag: `recovery-point-2026-04-20` in workspace reflog.
- **AI-native time estimates:** plan budgets are in minutes, not hours. Translate human-authored plans before delegating.
- **PR scope discipline:** always `gh pr diff --name-only` before declaring a PR done. Fresh branch cherry-picks beat ad-hoc cleanups when a branch has drifted.
- **Closed PRs are permanent:** no GitHub API to delete. Only Support can remove.
- **Two-identity model:** executor agents authenticate as `Duongntd`; reviewer agents (Senna, Lucian) use `scripts/reviewer-auth.sh`. Executors MUST NOT source reviewer-auth.sh.

## Tool/API patterns

- `update_*` tools wrapping PUT endpoints are footguns — always build GET→merge→PUT patch wrappers instead. Safe replacements: `patch_token_ui`, `patch_ios_template`, `patch_gpay_template` (mcps PR #27).
- Slack MCP uses user OAuth token (not bot token) for DM access — 8 tools (PR #26 merged).
- Anthropic API is source of truth for managed sessions, NOT our Firestore. Regular API key handles list/retrieve/terminate; admin key only for cost reports.
- Demo Studio v3 Step 0 gotcha: sync Firestore writes inside async generators silently fail — move persistence to `finally` block.

## Paused work (to resume)

- **3 ADRs on `feat/demo-studio-v3`** (commit `d68df34`, pre-migration paths in `workspace/company-os/plans/`): managed-agent-lifecycle, managed-agent-dashboard-tab, session-state-encapsulation. Next step: Kayn decomposition. To be moved under `plans/work/` (Phase 4 of unification tasks).
- **Spike 1 done** (Lux, 2026-04-20 s2): Anthropic SDK has native `agent_id` filter on `sessions.list()` + `updated_at` timestamp per session row. No fallbacks needed. Appendix on lifecycle ADR.
- **PR #46** (`missmp/company-os`, TDD gate port) — open for teammate; strawberry's own TDD gate governs strawberry repos separately.
- **Phase 9.5** — Skarner audit of merged learnings indexes post-migration.
- **Admin API key + workspace isolation** for Anthropic cost reports — separate track.

## Hard-won lessons

- **"We own X" = the whole store**, not just the API surface. Ask before splitting ownership. (Wasted a half-loop on "session on Service 2" before correction.)
- **Two-phase teammate shutdown:** Phase 1 collect learnings before `shutdown_request`. Skipping cost 8 agents' memory. Now enforced.
- **Coordinator ≠ errand runner:** session-close, memory, learnings are first-person Sona work, not Yuumi's.
- **Don't draft ADRs placing new functionality on someone else's service** without confirming ownership. One clarifying question up front saves a redraft.
- **Finalize agent-generated diffs same-session** — don't let them drift uncommitted across days.
- **Orphans (in Anthropic, not in our DB) must be visible + terminable** in any lifecycle design.

## Pointers

- Unification ADR: `~/Documents/Work/mmp/workspace/company-os/plans/2026-04-20-agent-os-unification.md` (to migrate to `plans/work/approved/` Phase 4).
- Unification tasks: same folder, `...-tasks.md`.
- Agent-OS migration day learning: `agents/sona/learnings/2026-04-20-agent-os-unification-day.md`.
- Duong profile: `agents/memory/duong.md`.
- Agent network: `agents/memory/agent-network.md`.

## Sessions

- **2026-04-23 (s5, cli, agent-owned config W1+W2 ship):** Two full ADR waves shipped end-to-end on missmp/company-os: W1 seed-on-session-create (PR #91 merged at `79d6c19`, amended once for BD.B.3 cross-ADR conflict) and W2 system-block injection (PR #96 merged at `144fbb6`, reworked once for Rule 12 ordering violation Viktor committed and Lucian caught — merge-based reconstruction preserved Rakan xfail ordering). Ekko's S2 PATCH drift investigation concluded: `deploy.sh` builds from local filesystem, not git HEAD. Identity-leakage problem surfaced twice (Swain commits as Orianna, Rakan xfails as viktor) — per-worktree `.git/config` leakage across subagent sessions — filed to Evelynn with proposed Karma quick-lane plan bundling per-process GIT_AUTHOR binding, verdict-signature scrubbing, and missmp pre-push+tdd-gate install. Rule-sona-leads-the-team rewrite landed (principle-based, not absolute) per Duong directive relayed via Evelynn. Fifth compact of the day, closed cleanly in hands-off mode.
- **2026-04-20 (s3, gate-v2 + CI audit):** Migrated 4 work ADRs into `plans/proposed/work/` with gate-v2 frontmatter (Yuumi). Commissioned Karma quick-lane plan for Orianna `concern: work` routing extension; Talon implemented as PR #7 (Senna + Lucian approved; Senna caught quoted-YAML bug). CI audit: killed 13 vestigial strawberry-app workflows across PRs #8/#9/#10; only `tdd-gate.yml` remains. Duong upgraded to GitHub Pro after billing-block incident. Branch protection payload drafted for Duong to apply manually. Added hands-on / hands-off operating modes + a/b/c decision format to `duong.md`. Closed in hands-off mode.
- **2026-04-20 (s2, agent-OS unification day):** migrated INTO strawberry-agents as canonical home. Lux's Spike 1 resolved both SDK gaps for managed-agent lifecycle. Ekko's TDD-gate PR landed as #46 after #45 cleanup (Jhin caught 34 out-of-scope files). Azir+Kayn produced unification ADR and task list. Recovery incident: 25 agent defs wiped by `git reset --hard`, restored from reflog tag `recovery-point-2026-04-20`.
- **2026-04-20 (s1):** 3 ADRs written on `feat/demo-studio-v3` (session-state-encapsulation, managed-agent-lifecycle, managed-agent-dashboard-tab). ARCHITECTURE.md rewritten. 10 spec drifts flagged vs PR #40.
- **2026-04-17 (s2):** Step 2 shipped on `demo-studio-step1` then orphaned by mid-session scope contraction. Lesson: two-phase teammate shutdown. Lost 8 agents' memory from skipping it.
- **2026-04-17 (s1):** Step 1 + Secret Manager migration shipped. PR #40 merged. 10-agent team closed clean.
- **2026-04-16:** Step 0 refactor — managed agent → direct Claude API. 8-agent team ran TDD but quality insufficient; Duong switched to hands-on mode. Simplified endpoints. 615 tests. Duong prefers hands-on for deep refactors.
- **2026-04-15 (pm):** Phase A (worker infra) + Phase B (orchestrator migration), /phase endpoint, PATCH /config, logo upload, activity indicators. Commit `2776ddf`.
- **2026-04-15 (am):** Demo Studio v3 MVP sprint. 11 xfail features, SSE, factory v2. 453 tests. Revision `demo-studio-00021-w9r`.
- **2026-04-14 (s2):** Test dashboard + TDD infrastructure. 298 tests, pre-commit/pre-push hooks, pytest plugin, component markers. TDD workflow: Caitlyn/Vi test → Ekko/Jayce implement.
- **2026-04-14 (s1):** Demo Studio v3 greenfield on Managed Agents + MCP. 8-agent team, 3 Cloud Run services, 169 tests, 4-tab preview.
- **2026-04-13:** Slack MCP (PR #26), patch tools (PR #27/28), 4Paws incident+restore, Eurosolutions audit, initialPrompt double-read fix, PR #24 approved.
- **2026-04-10 (s5):** Demo Factory v2 — native team collab (6 agents), 6-phase impl, 128 tests, Cloud Run, PR #24.
- **2026-04-10:** agent infra overhaul, demo validation view (PR #22), MCP tool (PR #24), startup fix (initialPrompt), Skarner + /save-transcript, effort tiers, bypassPermissions, directory restructure under secretary/.
- **2026-04-09:** built full demo agent system, 5 PRs, local deploy, restored gw-pass class template.

<!-- sessions:auto-below -->
