# Strawberry system audit — post foundational-ADR landing

**Date:** 2026-04-21
**Auditor:** Lux (read-only pass)
**Scope:** Agent system, plan lifecycle v2, hooks, skills, architecture docs — the state on main as the pair-taxonomy + Orianna-gate-v2 ADRs complete their first round of implementation.

---

## Executive summary

### Fix urgently (blocks promotion / will mis-route next caller)

1. **`.claude/_retired-agents/syndra.md` still exists while `.claude/agents/syndra.md` is active.** Claude Code does not load from `_retired-agents/`, but the name collision is a land mine — a future `sync-shared-rules.sh` or `grep .claude/agents` style tool could pick the wrong one. Same for `agents/_retired/syndra/` and `agents/_retired/swain/` (both now-active agents). `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/_retired-agents/syndra.md`, `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/_retired/syndra`, `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/_retired/swain`.
2. **`agents-table.md` is stale by a wide margin** — still lists Karma as `Tier=Quick Model=opus`, missing `effort`, claims Orianna lives at `.claude/agents/orianna.md` (it is at `.claude/_retired-agents/` — no wait, at `.claude/_script-only-agents/orianna.md`), and still shows Jhin with a retired row while the wrongly-pluralized retired lane does not include `.claude/_retired-agents/` entries for fiora/bard/katarina/etc. The table is cited by Evelynn on startup as the authoritative roster; every inconsistency becomes a routing bug. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/memory/agents-table.md:1-38`.
3. **CLAUDE.md rule 5 still instructs `chore:` / `ops:` as if single-choice** while rule 5's sibling text also demands `feat:/fix:/perf:/refactor:` for `apps/**`. The wording "Non-code commits … MUST use `chore:` or `ops:`" is contradicted two lines later ("Code commits that touch `apps/**` MUST use one of …"). Agents reading rule 5 in isolation get different answers depending on where they stop. Rewrite to a single decision-tree. `/Users/duongntd99/Documents/Personal/strawberry-agents/CLAUDE.md:42`.
4. **54 plans still in `plans/approved/`** — the task brief claimed these were demoted to `plans/proposed/`; they were not. If the plan-authoring freeze (`pre-commit-plan-authoring-freeze.sh`) is the gate for Orianna-v2 onboarding, every one of these approved plans is now in a limbo state: no `orianna_gate_version: 2` field means `plan-promote.sh` treats them as grandfathered (legacy), so they will move with NO signature enforcement until Phase D. That is the opposite of the ADR intent. `/Users/duongntd99/Documents/Personal/strawberry-agents/plans/approved/` (54 files), promote branch at `/Users/duongntd99/Documents/Personal/strawberry-agents/scripts/plan-promote.sh:153`.

### Address eventually

5. **Every pre-existing paired agent (11 of them) lacks the `<!-- include: _shared/<role>.md -->` marker.** Hook check #1 silently skips them because the marker is missing — `scripts/hooks/pre-commit-agent-shared-rules.sh:191` comment says "No include marker — skip." The drift-detection guarantee the ADR §D4.3a promises is a lie for all 11 lazy-migrated agents; only the 6 new agents (Xayah, Rakan, Soraka, Syndra, Karma, Talon) have marker-backed enforcement.
6. **Single-lane agents carry no `role_slot:` / `tier:` frontmatter**, so hook check #3's single-lane branches (`qa:single_lane`, `memory:single_lane`, `errand:single_lane`, `devops-exec:single_lane`) are unreachable dead code. The model-family validation that was supposed to prevent Ekko/Akali/Skarner/Yuumi from silently mis-declaring `model: opus` is not running.
7. **`agents-table.md` does not list Karma, Talon, Camille in the correct tier columns** and Sona is missing entirely from the table (she is in `agent-network.md` but not `agents-table.md`). Duong's `.claude/CLAUDE.md` says `agents-table.md` is the consolidated source.
8. **Hook test coverage is opaque** — `scripts/hooks/test-hooks.sh` exists but there is no CI binding and no documentation of how it is run. Vi's currently-in-flight work on test scripts is visible (`test-pre-commit-orianna-signature.sh`, `test-plan-promote-guard.sh`, `test-pre-commit-plan-authoring-freeze.sh`) but they are not wired to anything scheduled.

---

## Per-section findings

### 1. `agents/` directory structure

- **LOW** — `agents/transcripts/` is empty and appears to be a stray from a prior cleanup pass. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/transcripts/`. Recommend: delete or `.gitkeep` with a README line explaining purpose.
- **MEDIUM** — `agents/lux/` is missing `memory/`. Every other paired agent has `memory/` + `learnings/` + `profile.md`; Lux only has `learnings/` + `profile.md`. If the rescope (`§D3.1`) lands as planned, Lux's `/end-subagent-session` Step 3 (memory refresh) will silently fail because the directory does not exist. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/lux/`.
- **HIGH** — `agents/vex/` exists as a full agent directory (learnings/, memory/, profile.md) but there is no `.claude/agents/vex.md` and Vex is not in the taxonomy matrix or `agents-table.md`. Either orphan directory to remove, or orphan definition to create. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/vex/`.
- **BLOCK** — `agents/_retired/swain/` and `agents/_retired/syndra/` are retired directories for agents that are now active with the same names. Per taxonomy ADR, Swain and Syndra are first-class active agents (matrix rows 1 and 8). Retired directories with matching names will cause memory-retrieval or `end-session` lookups to ambiguate. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/_retired/swain`, `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/_retired/syndra`. Recommend: rename the retired dirs to `_retired/swain-old/` and `_retired/syndra-old/` or move to a timestamped archive.
- **LOW** — Orianna's operational-files exception is clearly intentional; layout looks right (`allowlist.md`, `claim-contract.md`, `inbox.md`, `prompts/`, `runbook-reconciliation.md`). No issue.
- **LOW** — Only Evelynn and Sona carry a root `CLAUDE.md`; consistent with coordinator exception.

### 2. `.claude/agents/*.md` defs

- Roster count: 28 files (not 27 as the task brief states). The extra is `akali.md` which the audit brief did not list.
- **MEDIUM** — Akali lacks `tier:`, `role_slot:`, and `permissionMode:` frontmatter. Per §D1.3 she is intentionally single-lane, but the ADR §D4.3a is silent on whether single-lane agents should carry `tier: single_lane` or omit the field. The hook treats either case ambiguously (lines 269–291 of `pre-commit-agent-shared-rules.sh`). Pick one convention and enforce it. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/akali.md:1-8`.
- **HIGH** — All 9 single-lane agents (Akali, Heimerdinger, Ekko, Senna, Lucian, Camille, Yuumi, Skarner, plus the script-only Orianna) omit `tier:` and `role_slot:`. The hook's `is_sonnet_slot()` function (lines 65–92) hard-codes single-lane slot names like `qa:single_lane` that **no actual agent declares**. Dead matrix branches; no live enforcement of Sonnet-vs-Opus for Ekko, Akali, Skarner, Yuumi. Fix: either add `tier: single_lane` + `role_slot: <slot>` to each single-lane agent, or simplify the hook to check model-vs-role by name lookup.
- **MEDIUM** — Frontmatter field order is inconsistent across files (some put `name:` first, others `effort:` first; Xayah/Rakan/Soraka/Syndra all have `tier:`/`pair_mate:`/`role_slot:` below `description:`, while Azir/Kayn/Caitlyn have them above). Aesthetic only, but when `sync-shared-rules.sh` (Lux hasn't written it yet?) runs it will need a canonical order. Recommend: lock field order in `_shared/` README or in the hook as a warn.
- **MEDIUM** — Senna, Lucian, Heimerdinger, Camille, Ekko are Opus but correctly omit `model:` — verified clean. Swain correctly omits `model:` and declares `effort: xhigh`. Evelynn/Sona correctly use `concern:` — clean.
- **HIGH** — **Lazy-migration debt**: only 6 of the 14 paired-agent files carry the `<!-- include: _shared/<role>.md -->` marker (xayah, rakan, soraka, syndra, karma, talon). The 8 pre-existing pair-mates (azir, kayn, aphelios, caitlyn, vi, jayce, viktor, neeko, lulu, seraphine, lux) do not. The hook's drift check at `pre-commit-agent-shared-rules.sh:191` says "No include marker — skip" — so those 8 agents' shared-rule content drifts invisibly. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/azir.md`, `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/swain.md:37-45` (Swain even retains old `BEGIN CANONICAL OPUS-PLANNER RULES` markers from a prior rule-shepherding pass).
- **LOW** — Viktor's H1 heading still reads "Viktor — Refactoring Agent" and opens with "refactoring and optimization builder" prose despite §D3.2 rescoping him to complex-track feature builder. The frontmatter `description:` is correctly updated, but the body conflicts. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/viktor.md:24-26`.
- **LOW** — Azir's startup chain references `/Users/duongntd99/Documents/Personal/strawberry/CLAUDE.md` (note: `strawberry`, not `strawberry-agents`). Broken path, will silently read nothing. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/azir.md:28`.
- **LOW** — Pair-mate symmetry spot-checks: Azir↔Swain, Kayn↔Aphelios, Caitlyn↔Xayah, Vi↔Rakan, Viktor↔Jayce, Neeko↔Lulu, Seraphine↔Soraka, Lux↔Syndra, Karma↔Talon — all symmetric. Hook check #2 works.

### 3. `.claude/agents/_shared/*.md`

- 10 files present; all exist and are non-empty.
- **MEDIUM** — Content quality is uneven. `architect.md` (37 lines) and `builder.md` (37 lines) have clear principles+process+boundaries. `frontend-design.md` (34) and `frontend-impl.md` (35) feel thinner; `frontend-design.md` has an abbreviated "Strawberry rules" section (only 2 bullets) vs `architect.md`'s 4 bullets. Standardize the minimum bullet-set per §D4.2 spec. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/agents/_shared/frontend-design.md:28-31`.
- **LOW** — `ai-specialist.md:16` references `architecture/platform-parity.md` as a justification doc for new MCP servers — the doc exists. Clean.
- **LOW** — `test-impl.md:31` says "`tools/decrypt.sh` only" which is the right phrasing, but `builder.md:32` says "`tools/decrypt.sh`" without the "only" qualifier. Minor consistency nit.
- **LOW** — `quick-planner.md:17` instructs the author to include `complexity: quick` AND `orianna_gate_version: 2` in every quick-lane plan — good, matches the Orianna ADR's §D1 field name.
- **LOW** — None of the shared files reference their paired role's agent names by LoL champion callsign (the ADR §D4.2 says personality lives in the per-agent file, so this is intentional and correct).

### 4. `.claude/_script-only-agents/orianna.md`

- **LOW** — Correctly omits `model:` (Opus default), carries `effort: medium`, documents signer responsibilities. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/_script-only-agents/orianna.md:2-12`.
- **MEDIUM** — The ADR v2 gives Orianna a **signing identity** (`orianna@agents.strawberry.local`, §D1.1 of the gate ADR) and four new gate checks (D2.1–D2.3). **This agent definition has not been updated to describe the signing responsibilities.** The "Modes" section (lines 21–23) still lists only `plan-check` and `memory-audit` — no mention of `orianna-sign.sh`, `approved → in-progress` gate, `in-progress → implemented` gate, or the signing-commit shape requirement. Orianna, invoked fresh, would not know she signs anything. `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/_script-only-agents/orianna.md:21-33`.
- **MEDIUM** — Reflective: the description in frontmatter claims "Single-lane Opus-medium per agent-pair-taxonomy ADR §D1 row 13" — row 13 in the taxonomy ADR is indeed Orianna, so this is accurate, but the v2 gate ADR §D2.1–D2.3 should be referenced here so a reader finds her updated responsibilities.

### 5. `agents/memory/agent-network.md` + `agents-table.md`

- **HIGH** — `agent-network.md` Section "Quick Lane" (lines 62–69) is present and correct for Karma + Talon.
- **HIGH** — `agent-network.md` Section "Universal Invariants" (lines 132–147) lists rules 1–11 and **stops** — missing rules 12–19. Rules 12–18 are CLAUDE.md-enforced; rule 19 (Orianna gate) is the whole point of this week's work. An agent reading `agent-network.md` thinks the invariant list is complete. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/memory/agent-network.md:132-147`.
- **HIGH** — `agent-network.md` delegation chain (lines 75–84) still uses **pre-rescope** agent names: "Azir (architecture)" without Swain on the complex lane, "Kayn/Aphelios" without tier labels, "Vi" without pairing to Rakan. The ADR §D8.2 Phase B was supposed to update this. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/memory/agent-network.md:75-84`.
- **HIGH** — `agent-network.md` claims `.claude/_retired-agents/jhin.md` is the retired location — that path does exist — but there are 13 files under `.claude/_retired-agents/` total (bard, fiora, jhin, katarina, lissandra, lux-frontend-sonnet, ornn, poppy, pyke, reksai, shen, syndra, zoe), of which **`syndra.md` is a collision** with the now-active `.claude/agents/syndra.md`. The retired copy must be deleted or renamed.
- **BLOCK** — `agents-table.md` tier column uses `Opus | Sonnet` values, not the taxonomy's `complex | normal | quick | single_lane`. Ekko/Akali/Senna/Lucian/Heimerdinger all render as tier=Opus or tier=Sonnet with no effort/pairing. Karma is labeled `Tier=Quick Model=opus` (free-form string, not enum). The table is now effectively incompatible with the taxonomy ADR's frontmatter contract. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/memory/agents-table.md:7-37`.
- **HIGH** — `agents-table.md` is missing Sona entirely. `agent-network.md` introduces her as first-class coordinator (line 19); `agents-table.md` does not. `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/memory/agents-table.md`.
- **HIGH** — `agents-table.md:31` says Orianna lives at `.claude/agents/orianna.md` — she does not. She lives at `.claude/_script-only-agents/orianna.md`. Agent-table rows 24–37 use `new-2026-04-20` / `new-2026-04-21` status values which are correct.
- **MEDIUM** — `agents-table.md` does not include Xayah's effort/pairing (just "Opus"), Rakan's pair (just "Sonnet"), etc. The ADR §D5 frontmatter contract has `tier:` + `pair_mate:` + `role_slot:` + `effort:` — the table should surface them.

### 6. CLAUDE.md (repo-root)

- **BLOCK** — Rule 5 wording is internally contradictory (see Executive Summary #3). Same file, same rule, first sentence vs third sentence. `/Users/duongntd99/Documents/Personal/strawberry-agents/CLAUDE.md:42`.
- **MEDIUM** — Rule 7 does not mention the **Drive mirror removal**. Previous versions of rule 7 said "plan-promote.sh unpublishes the Drive doc"; the current (shipped) rule 7 drops the Drive language (line 48 reads only "runs the Orianna gate, moves the file, rewrites `status:`, commits, and pushes"). Good — but then `architecture/platform-parity.md:28` still references `scripts/plan-fetch.sh` and "Drive mirror fetch path" — orphan reference. `/Users/duongntd99/Documents/Personal/strawberry-agents/architecture/platform-parity.md:28`. The script `scripts/plan-fetch.sh` also still exists.
- **MEDIUM** — Rule 8 mentions `disable-model-invocation: true` for `/end-session`, but the actual skill header (line 4 of `.claude/skills/end-session/SKILL.md`) declares `disable-model-invocation: false`. Contradiction between rule text and shipped skill. `/Users/duongntd99/Documents/Personal/strawberry-agents/CLAUDE.md:51` vs `/Users/duongntd99/Documents/Personal/strawberry-agents/.claude/skills/end-session/SKILL.md:4`.
- **LOW** — Rule 9 says "Haiku is retired; do not introduce new Haiku agents." Correct and unambiguous.
- **LOW** — Rule 19 is well-written and precise. The bypass rule (`Orianna-Bypass: <reason>` + admin author) matches the hook implementations exactly. Clean.
- **LOW** — Rule 5's conventional-prefix list is missing `ops:` from the apps/** track — the first sentence says non-code uses `chore:` or `ops:`, the second sentence omits `ops:` from the apps/** list. Likely intentional (ops belongs to infra), but the reader has to infer. Explicit is better.
- **LOW** — The rules use `<!-- #rule-… -->` anchor comments for rules 1–11 but **rules 12–19 have no anchor comments**. Makes `agents/<name>/*.md` files unable to reference rule 12+ by anchor. `/Users/duongntd99/Documents/Personal/strawberry-agents/CLAUDE.md:63-101`.

### 7. Skills

- **LOW** — `end-session/SKILL.md` and `end-subagent-session/SKILL.md` are both well-structured. The conditional-writes rewrite of `end-subagent-session` is clean (lines 24–34) and the "bar is high" philosophy paragraph at the bottom is a good rudder.
- **MEDIUM** — `end-session/SKILL.md:159` uses `Claude Opus 4.6 (1M context)` in the commit footer; the session's current model is Opus 4.7. Drift since model upgrade. Fix: template the version or say "Claude Opus" without version.
- **MEDIUM** — `end-session/SKILL.md:14` defaults `$ARGUMENTS` to `evelynn` if empty — but if a Sona session (work-concern coordinator) invokes `/end-session` with no arg, it silently closes as Evelynn. Default should be derived from concern or refuse.
- **LOW** — `end-subagent-session/SKILL.md:14` excludes Evelynn, Sona, Yuumi, Skarner correctly. No issues with the conditional branches.

### 8. Hooks

- **HIGH** — `pre-commit-agent-shared-rules.sh:65-92` hard-codes the Sonnet-slot matrix. After today's bug fixes the matrix says:
  - `ai-specialist:normal` → Sonnet (Syndra) — correct
  - `ai-specialist:complex` is absent (Lux is Opus) — correct
  - `quick-executor:quick` → Sonnet (Talon) — correct
  - Single-lane Sonnet slots (`qa`, `memory`, `errand`, `devops-exec`) listed but **never reached** because no agent declares `tier: single_lane`. Dead code today.
- **MEDIUM** — `pre-commit-agent-shared-rules.sh:191` silently skips drift-check for any agent missing an include marker — which is **11 of 14 paired agents today**. The hook claims to enforce drift; it does not. Either require the marker (error if missing) or gate the skip behind a documented lazy-migration opt-out (with a deadline for removal).
- **MEDIUM** — `pre-commit-orianna-signature-guard.sh` is tight. It correctly requires single-file diff + single-line addition + all three trailers + phase consistency. Good guard. `/Users/duongntd99/Documents/Personal/strawberry-agents/scripts/hooks/pre-commit-orianna-signature-guard.sh`.
- **LOW** — `pre-commit-plan-promote-guard.sh` has legacy behavior: it accepts any fact-check report matching the plan's basename as sufficient evidence. Per the v2 gate ADR §D2, the fact-check report gets replaced by a signature — this hook still checks for the old report file. Consistent only as long as grandfathered plans carry legacy reports. Add a v2 branch that checks for `orianna_signature_<phase>` frontmatter instead.
- **LOW** — `pre-commit-plan-authoring-freeze.sh` is clean — POSIX-portable, GIT_AUTHOR_EMAIL fallback, admin-identity allowlist matches the promote-guard. Temporary hook, clear lift path (§D12).
- **HIGH** — `test-*.sh` test scripts exist but have no CI binding. `test-hooks.sh` dispatch is unclear. Vi's in-flight T11.1 smoke is pending; until it is wired, the hook behavior has no regression coverage.
- **LOW** — `install-hooks.sh` was not audited in this pass; recommend Vi verify every new hook is in the installer before T11.2 closes.

### 9. Architecture docs

- **MEDIUM** — `architecture/agent-pair-taxonomy.md` §1.1 matrix (lines 17–48) is **accurate** to the ADR. No internal contradiction with the source ADR. Clean.
- **MEDIUM** — `architecture/agent-network.md` exists alongside `agents/memory/agent-network.md` — **two files with the same content owner**. Risk of drift. Confirm which is authoritative.
- **HIGH** — `architecture/platform-parity.md:28` retains `scripts/plan-fetch.sh` + "Drive mirror fetch path" reference. The Drive mirror was explicitly removed per the task brief ("Drive mirror was just removed — verify no stragglers"). This is a straggler. The script itself at `/Users/duongntd99/Documents/Personal/strawberry-agents/scripts/plan-fetch.sh` should also be removed or its purpose re-documented.
- **LOW** — `architecture/plan-lifecycle.md:3` anchors to the source ADR correctly. Phase table (lines 13–23) matches `plans/` directory structure. Clean.
- **LOW** — `architecture/key-scripts.md` and `architecture/agent-system.md` were Viktor-edited today; spot-checked: no contradiction with the taxonomy ADR. I did not read them end-to-end — a follow-up by Jayce or Viktor is warranted to confirm no stale Drive references.
- **LOW** — `architecture/plan-frontmatter.md` (Jayce today) — not read in this pass.

### 10. Plans on disk

- **BLOCK** — `plans/approved/` holds **54 plans**. Task brief claimed all demoted to `proposed/`; they are not. If the Orianna gate v2 is meant to be live, every one of these is a grandfathered plan (no `orianna_gate_version: 2` field) and will move with no signature enforcement when next promoted. The ADR §D8 migration plan does not spell out demotion of the approved backlog. Either: (a) demote all 54 to `proposed/` as the task brief implied, (b) add `orianna_gate_version: 2` + retroactive signatures, or (c) document the grandfather decision as a one-time tech-debt bucket with a sunset date.
- **LOW** — `plans/in-progress/` holds the orianna ADR (`2026-04-20-orianna-gated-plan-lifecycle.md`) plus 9 other plans. The orianna ADR is correctly in-progress. Other 9 plans are pre-v2 and grandfathered.
- **LOW** — `plans/implemented/` holds the taxonomy ADR (`2026-04-20-agent-pair-taxonomy.md`) and prior implemented plans. Correct.
- **LOW** — `plans/proposed/` holds 73 plans — many old, many of unclear staleness. A cleanup sweep is overdue, but is orthogonal to this audit.

---

## Scalability assessment

### 5× agent count (current 28 → 140)

**First strain point: `agents-table.md` as a flat markdown table.** At 140 rows it becomes unreadable and drifts instantly. Move to a generated doc sourced from `.claude/agents/*.md` frontmatter.

**Second: the hook's matrix hard-coding.** `pre-commit-agent-shared-rules.sh:65-92` uses a case statement per slot-tier pair. At 5× roles this is 50+ cases. Move to a data file (`.claude/agents/_matrix.yml`) read by the hook.

**Third: `sync-shared-rules.sh` (not audited; assumed to exist given the hook references it).** If it rewrites each paired agent file per shared-file change, `O(agents × roles)` — not a problem at 140, but the drift-check also runs `O(staged × dir-scan)` so full-tree commits (rare) get expensive.

### 5× plan throughput (current ~ 5 plans/day → 25 plans/day)

**First strain point: Orianna's serial signing.** If every plan transition requires a signing commit from her (+ carry-forward verification of prior signatures), a busy day produces ~75 signing commits. `plan-promote.sh` runs signature verification on every transition — verification walks `git log` for each prior phase. `O(phases²)` per promote. At 3-phase plans × 25/day this is fine; at 10-phase compound ADRs it is not.

**Second: fact-check reports under `assessments/plan-fact-checks/`.** If grandfathered plans keep writing reports while v2 plans do not, the assessment directory gets a two-class citizenship problem. Sunset the legacy report path on a date.

**Third: plan-authoring freeze.** The freeze blocks `A`-status files in `plans/proposed/`. If 25 plans/day need to be authored and the freeze is still active, throughput is zero. Lift criterion (T11.1 smoke pass) is a hard critical-path. Prioritize.

### Where it strains first

- **Routing decisions inside Evelynn.** The delegation table grows linearly with roster; complexity classification (§D6) stays constant. The bottleneck is cognitive: Evelynn's startup read of `agent-network.md` + `agents-table.md` + `CLAUDE.md` is ~400 lines today; at 5× it is 2000+ lines. Move some of this behind skills or a loadable reference.
- **Retired-agents collision surface.** Every retired agent lives in two places (`.claude/_retired-agents/` + `agents/_retired/`). At 5× retirements this compounds; the Swain/Syndra collision problem happens at every revival.

---

## Lazy migration debt — enumerated

1. **11 paired agents missing `<!-- include: _shared/<role>.md -->` marker** (azir, swain, kayn, aphelios, caitlyn, vi, jayce, viktor, neeko, lulu, seraphine, lux). Drift enforcement is bypassed for all 11 until added.
2. **9 single-lane agents missing `tier: single_lane` + `role_slot:` frontmatter** (akali, heimerdinger, ekko, senna, lucian, camille, yuumi, skarner, plus Orianna). Hook check #3 single-lane matrix is dead code until these are added.
3. **`agents-table.md` tier column uses `Opus|Sonnet` instead of `complex|normal|quick|single_lane`.** Breaking schema change — needs full rewrite.
4. **Sona missing from `agents-table.md`** despite being first-class coordinator per §D8.1 Phase A item 4.
5. **Orianna script-only def (`.claude/_script-only-agents/orianna.md`) not updated for gate v2 responsibilities** — still describes only plan-check and memory-audit modes.
6. **Viktor's body prose still describes "Refactoring Agent"** despite frontmatter rescope.
7. **Azir's startup chain references broken path** `/Users/duongntd99/Documents/Personal/strawberry/CLAUDE.md` (missing `-agents`).
8. **`agent-network.md` Universal Invariants list stops at rule 11** — missing rules 12–19 including the entire Orianna-gate rule.
9. **`agent-network.md` delegation chain not updated** for complex/normal pairs (still pre-rescope language).
10. **`agent-network.md` agent roster lists Swain at Opus-high**, not Opus-xhigh (pre-§D3.3 wording).
11. **CLAUDE.md rules 12–19 lack `<!-- #rule-... -->` anchor comments** while rules 1–11 have them. Inconsistent referenceability.
12. **CLAUDE.md rule 8 claims `/end-session` is `disable-model-invocation: true`** but the skill ships with `false`.
13. **`end-session/SKILL.md:159` hardcodes `Opus 4.6`** in commit footer; session model is 4.7.
14. **`end-session/SKILL.md:14` defaults to Evelynn** even when invoked from a Sona session.
15. **`architecture/platform-parity.md:28` retains "Drive mirror fetch path" reference** post-removal.
16. **`scripts/plan-fetch.sh` still exists post-Drive-removal** — confirm purpose or delete.
17. **`agents/_retired/swain/` and `agents/_retired/syndra/` are name-collisions** with active agents. Rename to `*-old/` or timestamp.
18. **`.claude/_retired-agents/syndra.md` same problem** — same-name collision with active agent.
19. **`agents/vex/` exists with no `.claude/agents/vex.md`** — orphan.
20. **`agents/lux/` missing `memory/` subdirectory** — end-session Step 3 will silently no-op.
21. **`agents/transcripts/` empty top-level stray.**
22. **`plans/approved/` holds 54 un-demoted plans** — grandfathered bucket of indeterminate size with no sunset date.
23. **Hook test scripts exist but have no CI binding or scheduled run.**
24. **Frontmatter field order is inconsistent across agent defs** — no canonical order enforced.
25. **Pre-commit-plan-promote-guard.sh accepts legacy fact-check reports** — will stay permissive for all grandfathered plans indefinitely.
26. **Two `agent-network.md` files** (`architecture/` + `agents/memory/`) — dual-source-of-truth risk.
27. **Shared-files content depth is uneven** — `frontend-design.md` has abbreviated Strawberry-rules section vs `architect.md`. Standardize.
28. **Rule 5's diff-scope decision is contradictory on first/second read** — single-sentence rewrite needed.

---

## Recommendations — ordered by leverage

1. **Fix rule 5 and the name collisions (retired-agents `syndra`, retired dirs `swain`/`syndra`) in a single `chore:` commit today.** These are the lowest-effort, highest-consequence bugs on the list.
2. **Resolve `agents-table.md` schema mismatch before any more agents are added.** Every future agent row compounds the problem.
3. **Decide the `plans/approved/` backlog policy** (demote vs grandfather vs retro-sign). The ADR did not speak to it, and the Phase D optional enforcement clause will inherit this bucket.
4. **Add the `<!-- include: ... -->` markers to the 11 pre-existing paired agents** and run `sync-shared-rules.sh` once. Either this week or schedule as a Syndra-sized task. Without it, the drift hook is cosmetic.
5. **Update Orianna's script-only def** to describe the gate-v2 signing responsibilities. She is the signer; her agent file must teach her that.
6. **Wire the hook tests to CI** (GitHub Actions workflow `hook-tests.yml`) before T11.2 lifts the freeze.
7. **Sunset `scripts/plan-fetch.sh` + the Drive-mirror reference in `platform-parity.md:28`.** One commit.

---

**Total findings:** BLOCK 4 · HIGH 9 · MEDIUM 13 · LOW 13 · (lazy-debt items: 28)

The system is structurally sound. The two foundational ADRs land on solid principles, and the hook infrastructure is the right shape. What is missing is the **discipline work** — the inlining, the table rewrite, the stale-directory cleanup, the test-wiring. None of it is architectural; all of it is execution. If T11.1 smoke lands and T11.2 lifts the freeze, the backlog above should be prioritized as a dedicated Syndra-sized sweep before the next major ADR.
