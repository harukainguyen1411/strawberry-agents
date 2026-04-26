---
status: approved
concern: personal
owner: swain
created: 2026-04-25
tests_required: false
complexity: complex
tags: [architecture, consolidation, canonical-v1, archival, doc-tree]
related:
  - plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
  - plans/in-progress/personal/2026-04-23-memory-flow-simplification.md
  - architecture/agent-pair-taxonomy.md
  - architecture/agent-network.md
  - architecture/agent-routing.md
  - architecture/agent-system.md
  - architecture/system-overview.md
architecture_impact: refactor
---

# Architecture-doc consolidation into canonical v1

## 1. Problem & motivation

The `architecture/` tree has grown to 30 files (3209 lines) covering agents, plan lifecycle, git, deployment, infrastructure, MCP, relays, billing, security debt, and more. Three problems compound:

1. **Spread.** The agent network alone is documented across `agent-network.md`, `agent-system.md`, `agent-pair-taxonomy.md`, `agent-routing.md`, `system-overview.md` (top-half), and partly `coordinator-boot.md` / `coordinator-memory.md`. To answer "what is the current roster + how do dispatches route?", a reader must reconcile five files with overlapping but inconsistent claims.
2. **Stale claims that look authoritative.** `agent-system.md` (top-half) names a roster — Katarina/Ornn/Fiora/Lissandra-as-PR-reviewer/Rek'Sai/Pyke/Bard/Zoe/Irelia — that has been retired in entirety. `system-overview.md` references the `agent-manager` MCP that was archived in Phase 1. `git-workflow.md` and `pr-rules.md` describe a Lissandra-Rek'Sai-Katarina review loop with `TeamCreate` that no longer exists. `mcp-servers.md` lists `agent-manager` as merely "archived Phase 1" alongside `evelynn`, but in fact `evelynn` MCP itself is no longer the dispatch surface for any current behavior. This is the worst class of doc drift — confidently wrong (`#rule-audit-the-doc-not-the-rule`).
3. **No archival flow for `architecture/`.** Plans have a working `plans/archived/` lifecycle. `architecture/` has only one ad-hoc precedent: `architecture/archive/v1-orianna-gate/` (created 2026-04-23 when the v1 Orianna gate was retired). There is no policy, no convention, no tooling. Stale docs sit in the canonical surface alongside live ones with no signal of which is which.

The `2026-04-25-retrospection-dashboard-and-canonical-v1.md` cornerstone plan answers "what is in v1" by pinning agent defs / hooks / invariants by SHA into `architecture/canonical-v1.md`. That manifest answers a *content* question. This plan answers a *structural* question: **where does v1 live, and what is no longer part of it?** Both must land before the canonical-v1 lock activates (Phase 2 dashboard ship), so the lock baseline is over a clean tree.

## 2. Decision

Establish a single canonical subfolder `architecture/agent-network-v1/` that holds the consolidated source-of-truth docs for the agent network as of v1. Move all stale material to `architecture/archive/<retirement-tag>/` (extending the existing `archive/v1-orianna-gate/` precedent into a general policy). Adopt a written canonical-source policy that distinguishes law-of-the-land docs from research/exploratory docs. Pin folder paths (not individual file SHAs) into the canonical-v1 lock manifest.

**Scope — out:**
- Agent-def restructure under `.claude/agents/`. That is Lux's lane; this plan only consolidates docs that *describe* the network.
- `plans/in-progress/` graduate-or-close pass. Bigger ask, separate plan if Duong wants it (see §10 OQ-6).
- New ADR-format conventions or template changes. Existing `plans/_template.md` is fine.
- Anything under `agents/` (memory/learnings/journals — these are agent-owned, not architecture).

### Scope — in

- All 30 files currently under `architecture/` (excluding the existing `archive/v1-orianna-gate/`).
- `agents/memory/agent-network.md` — the canonical roster file. Decision: it stays in `agents/memory/` (agent-owned data surface) but is **referenced** from the canonical folder, not duplicated. See §6.
- One sweep over `plans/implemented/` and `plans/archived/` for content that should be promoted into architecture canon. Decision after sweep: keep both directories as historical record; promotion-into-canon is exceptional and case-by-case; see §6.4.

## 3. Survey: every architecture/ file classified

The classification axis is:

- **canonical-keep** — content is current, factually accurate, and load-bearing. Move into `architecture/agent-network-v1/` (or a sibling subfolder for non-network concerns) and update internal cross-refs.
- **canonical-merge** — content is current but overlaps another file. Merge into a target file; delete the source.
- **rewrite** — content is stale enough that it needs a rewrite, not a move; the file becomes a stub that points to the rewritten canon.
- **archive** — content describes a retired regime or surface. Move to `architecture/archive/<tag>/` with no rewrite.
- **flag** — Duong's input needed before classifying.

| # | File | Lines | Classification | Notes |
|---|------|-------|---------------|-------|
| 1 | `README.md` | 22 | rewrite | Index references files that are about to move; rewrite to be the index of the new structure. |
| 2 | `system-overview.md` | 75 | rewrite | "13 agents" + Bard/Zoe/Irelia roster + agent-manager MCP all retired. Rewrite into `agent-network-v1/overview.md`. |
| 3 | `agent-network.md` | 71 | archive | Whole-file content is Phase-1 protocol description (`/agent-ops`, agent-manager replacement, delegation JSON files). Stale framing. Replaced by `agent-network-v1/communication.md` derived from `agents/memory/agent-network.md`. |
| 4 | `agent-system.md` | 129 | rewrite + split | Top half = retired roster (canonical archive material). Bottom half = Orianna §"Plan Lifecycle Signing Role" describes the v1 signature regime that was retired (see `archive/v1-orianna-gate/`). Whole file should be archived; new `agent-network-v1/agents.md` derived from `agent-pair-taxonomy.md` matrix. |
| 5 | `agent-pair-taxonomy.md` | 283 | canonical-keep | Currently the most-accurate single-file source on the roster. Becomes the anchor for `agent-network-v1/taxonomy.md`. |
| 6 | `agent-routing.md` | 49 | canonical-keep | Routing lookup table. Becomes `agent-network-v1/routing.md`. |
| 7 | `coordinator-boot.md` | 115 | canonical-keep | Current and load-bearing. Becomes `agent-network-v1/coordinator-boot.md`. |
| 8 | `coordinator-memory.md` | 145 | canonical-keep | Current. Becomes `agent-network-v1/coordinator-memory.md`. |
| 9 | `compact-workflow.md` | 70 | canonical-keep | Current. Becomes `agent-network-v1/compact-workflow.md`. |
| 10 | `plan-lifecycle.md` | 179 | canonical-keep | Current (v2 callable-Orianna regime, post-PR #45). Becomes `agent-network-v1/plan-lifecycle.md`. |
| 11 | `plan-frontmatter.md` | 199 | rewrite | Half-stale: `orianna_signature_<phase>` and `orianna_gate_version` fields no longer apply (v2 regime has no signatures). `tests_required`, `architecture_changes`, `architecture_impact` still apply. Rewrite to drop the v1 signature sections; archive the original at `archive/v1-orianna-gate/plan-frontmatter.md`. |
| 12 | `git-workflow.md` | 159 | rewrite | Tier 3 PR matrix references retired Lissandra/Rek'Sai/Bard. Three-tier commit policy describes `feature:`/`fix:` prefixes that contradict current Rule 5 (`chore:`/`ops:` only outside `apps/**`). Branch-protection section + worktree section are accurate — keep those. Rewrite into `agent-network-v1/git-workflow.md`. |
| 13 | `git-identity-enforcement.md` | 105 | canonical-keep | Current as of 2026-04-25 (resolved-identity three-layer model). Becomes `agent-network-v1/git-identity.md`. |
| 14 | `pr-rules.md` | 127 | rewrite | "Review Team Protocol" (Katarina/Lissandra/TeamCreate) is fully retired. Work-scope-anonymity section + QA gate (Rule 16) section + commit-prefix section + account roles section are current. Rewrite into `agent-network-v1/pr-rules.md`, archive the original. |
| 15 | `cross-repo-workflow.md` | 128 | canonical-keep | Current. Becomes `agent-network-v1/cross-repo.md`. |
| 16 | `key-scripts.md` | 57 | canonical-keep | Current. Becomes `agent-network-v1/key-scripts.md`. |
| 17 | `platform-parity.md` | 57 | canonical-keep | Current. Becomes `agent-network-v1/platform-parity.md`. |
| 18 | `platform-split.md` | 45 | canonical-keep | Current (Mac/Windows/GCE contract). Becomes `agent-network-v1/platform-split.md`. |
| 19 | `mcp-servers.md` | 51 | **archive** | `mcps/evelynn/` is retired (OQ-1 resolved 2026-04-25). Archive whole file. `architecture/mcp/` subdir is NOT created. |
| 20 | `plugins.md` | 32 | canonical-keep | Current plugin list. Becomes `agent-network-v1/plugins.md`. |
| 21 | `testing.md` | 131 | canonical-keep | Current TDD/Rule-12-15 enforcement description. Becomes `agent-network-v1/testing.md`. |
| 22 | `deployment.md` | 98 | canonical-keep | Current Firebase/`strawberry-app` deploy flow. Sits awkwardly in agent-network folder — see §4 on sub-organization. |
| 23 | `firebase-storage-cors.md` | 75 | canonical-keep (relocate) | App-domain knowledge, not network. Stays under architecture root or moves to `architecture/apps/`; see §4. |
| 24 | `infrastructure.md` | 75 | rewrite | VPS section is current (Hetzner CX22 / PM2 / Discord-relay PM2 processes). MCP servers section names "agent-manager, evelynn" — partially stale. Telegram bridge section is "Planned" since 2026-04-04 and shows no progress; classify as planned-and-stalled (flag). Rewrite to drop dead claims. |
| 25 | `discord-relay.md` | 64 | **archive** | Stalled (OQ-3 resolved 2026-04-25). Archive whole file. |
| 26 | `telegram-relay.md` | 62 | **archive** | Stalled / abandoned (OQ-4 resolved 2026-04-25). Archive whole file. |
| 27 | `claude-billing-comparison.md` | 118 | archive | "Current Setup (as of 2026-04-05)" describes team-plan transition and recommends API. Decision-record-style content; the *decision* (team plan via Claude Code OAuth) is in effect, the comparison itself is stale market research. Move to `archive/billing-research/` or just `archive/2026-04-05-billing-comparison.md`. |
| 28 | `claude-runlock.md` | 84 | **archive** | No live participants, stalled (OQ-5 resolved 2026-04-25). Archive whole file. |
| 29 | `security-debt.md` | 7 | canonical-keep | Current 1-paragraph debt note. Stays. |
| 30 | `archive/v1-orianna-gate/plan-lifecycle.md` | 372 | already-archived | No change. Existing `archive/` precedent. |
| 31 | `archive/v1-orianna-gate/key-scripts-excerpt.md` | 25 | already-archived | No change. |

**Tally:**

- canonical-keep (verbatim or near-verbatim relocation): **15** files — items 5, 6, 7, 8, 9, 10, 13, 15, 16, 17, 18, 20, 21, 22, 23, 29.
- rewrite (current concept, stale execution): **6** files — items 1, 2, 11, 12, 14, 24.
- rewrite + split: **1** file — item 4 (rewrite + split).
- archive (whole file outdated): **6** files — items 3, 19, 25, 26, 27, 28. (Items 19/25/26/28 resolved 2026-04-25; see §10 OQ-1/3/4/5.)
- flag (Duong input needed): **0** — all flags resolved.
- already-archived (no change): **2** files — items 30, 31.

Total: 30 active + 2 already-archived = 32 entries (item 4 is one file with two classifications).

## 4. Target structure

### Decision: sub-organization, not flat

A flat `agent-network-v1/` with 22+ docs reproduces the readability problem at one directory level deeper. Sub-organize by concern.

```
architecture/
├── README.md                         # rewritten — index of new structure + canonical policy
├── canonical-v1.md                   # SHA-pinned manifest (cornerstone-plan deliverable)
├── agent-network-v1/                 # CANONICAL — v1 agent network source of truth
│   ├── README.md                     # entry index for the canonical folder
│   ├── overview.md                   # rewritten system-overview (one screen, no roster table)
│   ├── agents.md                     # rewritten roster + role table (replaces agent-system.md top half)
│   ├── taxonomy.md                   # was agent-pair-taxonomy.md
│   ├── routing.md                    # was agent-routing.md
│   ├── communication.md              # was agent-network.md (rewritten — points at agents/memory/agent-network.md)
│   ├── coordinator-boot.md           # was coordinator-boot.md
│   ├── coordinator-memory.md         # was coordinator-memory.md
│   ├── compact-workflow.md           # was compact-workflow.md
│   ├── plan-lifecycle.md             # was plan-lifecycle.md
│   ├── plan-frontmatter.md           # rewritten — v2 fields only
│   ├── git-workflow.md               # rewritten — drops Lissandra/Rek'Sai
│   ├── git-identity.md               # was git-identity-enforcement.md
│   ├── pr-rules.md                   # rewritten — drops TeamCreate
│   ├── cross-repo.md                 # was cross-repo-workflow.md
│   ├── key-scripts.md                # was key-scripts.md
│   ├── platform-parity.md            # was platform-parity.md
│   ├── platform-split.md             # was platform-split.md
│   ├── plugins.md                    # was plugins.md
│   ├── testing.md                    # was testing.md
│   └── security-debt.md              # was security-debt.md
├── apps/                             # APP-DOMAIN — not part of agent network canon
│   ├── deployment.md                 # was deployment.md
│   ├── firebase-storage-cors.md      # was firebase-storage-cors.md
│   └── infrastructure.md             # was infrastructure.md (rewritten — drops agent-manager)
│   # mcp/ subdir NOT created — mcp-servers.md archives (OQ-1 resolved 2026-04-25)
└── archive/
    ├── v1-orianna-gate/              # existing; unchanged
    │   ├── plan-lifecycle.md
    │   └── key-scripts-excerpt.md
    ├── pre-network-v1/               # NEW — retired roster + retired protocol docs
    │   ├── agent-network.md          # was architecture/agent-network.md (Phase-1 framing)
    │   ├── agent-system.md           # was architecture/agent-system.md (retired roster + v1 Orianna)
    │   └── pr-rules.md               # was architecture/pr-rules.md (TeamCreate review loop)
    ├── billing-research/
    │   └── 2026-04-05-claude-billing-comparison.md
    └── (per-flag dir created if Duong archives discord/telegram/runlock)
```

**Rationale for the three top-level subdirs:**

- `agent-network-v1/` is the canonical heart. Everything here is authoritative for the v1 agent system.
- `apps/` separates application-domain knowledge (deploy targets, hosting, CORS) from agent-network knowledge. A reader investigating "how does the agent system work" should not collide with myapps Firebase deploy details.
- `mcp/` subdir is NOT created. `mcps/evelynn/` is retired (OQ-1 resolved 2026-04-25); `mcp-servers.md` archives to `archive/`.

Single-folder alternatives were considered and rejected:

- **All-flat under `architecture/agent-network-v1/`** — rejected. Putting `deployment.md` alongside `coordinator-memory.md` muddles concerns; the next reader who adds an app-deploy doc puts it in the canonical folder where it doesn't belong.
- **Per-component subfolders (network/, hooks/, invariants/, lifecycle/)** — rejected. Most files are 50-200 lines; chopping them across four subfolders fragments the reading experience without simplifying authorship. Two-level structure (canonical / apps / mcp) is enough.

## 5. Archival policy

### 5.1 Where archived material goes

Extend the existing `architecture/archive/<retirement-tag>/` precedent. A retirement tag is a short noun phrase identifying the retired regime (e.g. `v1-orianna-gate`, `pre-network-v1`, `billing-research`).

- A whole retired regime = its own subfolder (`archive/<tag>/`) holding all the files that belonged to it.
- A single retired file with no associated regime = top-level under `archive/` with a date prefix: `archive/YYYY-MM-DD-<slug>.md`.

Rule: archived files are read-only historical record. They are NOT cross-linked from any canonical doc except as "see archive/X for the prior regime" pointers in the relevant canonical doc.

### 5.2 Why not move to `plans/archived/`?

`plans/archived/` is for *plans* — execution artifacts with a frontmatter contract. Architecture docs are *living-doc* artifacts. Conflating them would:

- Break `pre-commit-zz-plan-structure.sh` (it lints `plans/**/*.md`; arch docs lack the required frontmatter).
- Make `plans/archived/` harder to scan for plan-history.
- Lose the structural distinction in the canonical-v1 lock manifest.

So keep architecture archival inside `architecture/archive/`. This mirrors how `scripts/_archive/` and `scripts/hooks/_archive/` already handle script-tree retirement (precedent set by `plans/implemented/personal/2026-04-23-plan-lifecycle-physical-guard.md`).

### 5.3 What goes in archive vs. rewrite

- **Archive** when the document describes a regime that no longer exists (v1 Orianna gate, pre-network-v1 roster, agent-manager MCP, retired three-tier commit policy).
- **Rewrite** when the document covers a current concept but its execution claims are stale (`agent-system.md` top half is archive, but `agent-pair-taxonomy.md` is canonical-keep — same concept, different execution accuracy).

### 5.4 Archive markers

The canonical doc that *replaces* an archived one must include a one-line "Supersedes: `archive/<tag>/<file>`" header in its frontmatter or under the title. The archived file gets a one-line "Archived: superseded by `<canonical-path>` on `<YYYY-MM-DD>`" stamp at the top. Both pointers are added in the same commit that does the move.

## 6. Move/merge/archive map

### 6.1 Bulk moves (canonical-keep — preserve content, update internal cross-refs only)

| From | To |
|---|---|
| `architecture/agent-pair-taxonomy.md` | `architecture/agent-network-v1/taxonomy.md` |
| `architecture/agent-routing.md` | `architecture/agent-network-v1/routing.md` |
| `architecture/coordinator-boot.md` | `architecture/agent-network-v1/coordinator-boot.md` |
| `architecture/coordinator-memory.md` | `architecture/agent-network-v1/coordinator-memory.md` |
| `architecture/compact-workflow.md` | `architecture/agent-network-v1/compact-workflow.md` |
| `architecture/plan-lifecycle.md` | `architecture/agent-network-v1/plan-lifecycle.md` |
| `architecture/git-identity-enforcement.md` | `architecture/agent-network-v1/git-identity.md` |
| `architecture/cross-repo-workflow.md` | `architecture/agent-network-v1/cross-repo.md` |
| `architecture/key-scripts.md` | `architecture/agent-network-v1/key-scripts.md` |
| `architecture/platform-parity.md` | `architecture/agent-network-v1/platform-parity.md` |
| `architecture/platform-split.md` | `architecture/agent-network-v1/platform-split.md` |
| `architecture/plugins.md` | `architecture/agent-network-v1/plugins.md` |
| `architecture/testing.md` | `architecture/agent-network-v1/testing.md` |
| `architecture/security-debt.md` | `architecture/agent-network-v1/security-debt.md` |
| `architecture/deployment.md` | `architecture/apps/deployment.md` |
| `architecture/firebase-storage-cors.md` | `architecture/apps/firebase-storage-cors.md` |

These are pure `git mv` (or rename via Edit if hooks don't see `git mv`). Internal `[link](other-file.md)` references get a sed-pass to fix paths.

### 6.2 Rewrites (current concept, stale execution — produce a new file, archive the source)

| Source | New canonical file | Archive destination |
|---|---|---|
| `architecture/README.md` | `architecture/README.md` (overwritten) | none — old version harmless to drop |
| `architecture/system-overview.md` | `architecture/agent-network-v1/overview.md` | `archive/pre-network-v1/system-overview.md` (only if Duong wants the old one preserved; see §10 OQ-2) |
| `architecture/plan-frontmatter.md` | `architecture/agent-network-v1/plan-frontmatter.md` | `archive/v1-orianna-gate/plan-frontmatter.md` (same regime as existing v1-orianna-gate archive — natural fit) |
| `architecture/git-workflow.md` | `architecture/agent-network-v1/git-workflow.md` | `archive/pre-network-v1/git-workflow.md` |
| `architecture/pr-rules.md` | `architecture/agent-network-v1/pr-rules.md` | `archive/pre-network-v1/pr-rules.md` |
| `architecture/infrastructure.md` | `architecture/apps/infrastructure.md` | none — rewrite-in-place; no value in keeping old VPS PM2 processes claim list. |

### 6.3 Whole-file archives (rewrite NOT needed — the whole framing is obsolete)

| From | To |
|---|---|
| `architecture/agent-network.md` | `archive/pre-network-v1/agent-network.md` |
| `architecture/agent-system.md` | `archive/pre-network-v1/agent-system.md` |
| `architecture/claude-billing-comparison.md` | `archive/billing-research/2026-04-05-claude-billing-comparison.md` |

### 6.4 Promotion-into-canon from `plans/implemented/`

Sweep was performed (see §3 survey). Conclusion: nothing in `plans/implemented/` warrants in-line promotion into `agent-network-v1/`. The implemented plans are execution records; their architectural decisions have already propagated into the architecture docs (sometimes incorrectly — that drift is what this plan fixes). Keep `plans/implemented/` as historical record and leave it alone.

### 6.5 `agents/memory/agent-network.md` decision

**Decision: keep where it is, link from canon.**

`agents/memory/agent-network.md` is read by every agent at boot (universal startup chain). Moving it would require updating ~30 agent definitions and CLAUDE.md startup chains. Not worth the churn. Instead:

- `architecture/agent-network-v1/communication.md` (the rewritten canonical communication doc) explicitly states "Live roster source of truth: `agents/memory/agent-network.md`. This file describes the *protocols and contracts* of agent communication; the live participant list is data, not architecture."
- The split is: roster (data) lives in `agents/memory/`; protocols (architecture) live in `architecture/agent-network-v1/`.

## 7. Canonical-source policy

This is the going-forward rule for keeping the canonical folder canonical.

### 7.1 The rule

> **If it's in `architecture/agent-network-v1/`, it's law.** Authoritative description of how the v1 agent system works. Drift from operational reality is a bug to be fixed at next observation.
>
> **If it's elsewhere under `architecture/`, it's research, app-domain, or experimental.** Not authoritative for the agent network. Subject to looser drift tolerance.
>
> **If it's under `architecture/archive/`, it's historical record.** Read-only; never edited except for archive-marker fixes.

### 7.2 Authoring discipline

New architecture docs about the agent network MUST land directly under `architecture/agent-network-v1/`, not at the `architecture/` root. The author of any plan whose `architecture_changes:` frontmatter targets a path outside `agent-network-v1/` must justify the location in their plan body (one sentence — "this is app-domain not agent-network" suffices).

### 7.3 README.md additions

`architecture/README.md` is rewritten to:

1. State the canonical-folder rule (§7.1) up front.
2. Index `agent-network-v1/`, `apps/`, `mcp/`, `archive/`.
3. List the doc-creation guidance (§7.2).

A new `architecture/agent-network-v1/README.md` indexes the canonical files and states the doc-creation guidance specific to this folder.

### 7.4 PR-template addition (deferred)

A future plan can extend `.github/pull_request_template.md` to add a checkbox: "If this PR adds a doc under `architecture/`, the doc lives under the correct sub-tree per `architecture/README.md` §canonical-source policy." Out of scope for this plan — the `apps/strawberry-app` PR template lives in a different repo and adding that check has cross-repo cost.

### 7.5 Drift detection

Already covered by the cornerstone canonical-v1 lock manifest. After lock activates, any change to a file pinned in `architecture/canonical-v1.md` requires a `Lock-Bypass:` trailer with reason. This plan does not duplicate that mechanism; it provides the folder structure that the manifest pins.

## 8. Interaction with the canonical-v1 lock manifest

The cornerstone plan (`plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md`) deliverable `architecture/canonical-v1.md` pins individual files by SHA. After this consolidation lands:

- The manifest pins **folder paths**, not individual file SHAs:
  - `architecture/agent-network-v1/` → recursively pinned (hash of all file SHAs).
  - `.claude/agents/` → recursively pinned (already cornerstone-plan scope).
  - Specific hooks under `scripts/hooks/` → already cornerstone-plan scope.
  - Universal invariants in repo-root `CLAUDE.md` → already cornerstone-plan scope.

- File-level pins inside `agent-network-v1/` are added only for files that have an existential load-bearing role independent of the folder (e.g. `taxonomy.md` if any hook reads it programmatically — which today none do).

- This plan **must land before** the cornerstone plan's lock-activation phase, so the lock baseline includes the consolidated tree.

## 9. Migration discipline

### Decision: incremental moves over one-shot consolidation

**One-shot.** A single consolidation PR with all 30 file moves + rewrites + archives is roughly 40+ file changes including new directories, internal-link sed-passes, and the rewritten files themselves. That is a giant blast-radius commit and `git log` becomes hostile to skim ("everything moved on 2026-04-25"). It also forces all rewrites to ship in one go, increasing the chance any single rewrite is wrong.

**Incremental** is safer in three ways:

1. Each move-or-rewrite is a self-contained commit reviewable on its own.
2. `git log --follow` for any single file produces a clean history.
3. If a rewrite is wrong, only that wave needs to be reverted.

**Wave plan** (executed by a future implementer — Aphelios will break this into T-tasks):

- **Wave 0** — create directories (`agent-network-v1/`, `apps/`, `archive/pre-network-v1/`, `archive/billing-research/`) and write `architecture/README.md` rewrite + `architecture/agent-network-v1/README.md` skeleton. This is the framework that subsequent waves populate.
- **Wave 1** — bulk pure-renames (§6.1, 16 files). One commit per logical group: agent-network group (taxonomy/routing/coordinator-boot/coordinator-memory/compact-workflow/plan-lifecycle/git-identity), repo-discipline group (cross-repo/key-scripts/platform-parity/platform-split/plugins/testing), single-files (security-debt, deployment, firebase-storage-cors).
- **Wave 2** — rewrites (§6.2, 6 files). One commit per rewritten file. Each commit also archives the source if §6.2 calls for it.
- **Wave 3** — whole-file archives (§6.3, 3 files).
- **Wave 4** — internal cross-reference fixes. After all moves, sweep for broken `[link](path)` references and fix in one commit (sed-pass + manual review of result).
- **Wave 5** — flag-resolution archive moves: `mcp-servers.md`, `discord-relay.md`, `telegram-relay.md`, `claude-runlock.md` all archive. OQ-1/3/4/5 resolved 2026-04-25; this wave is now unblocked.

### Conflict-avoidance with three concurrent Viktor branches

Per task brief: dashboard Phase 1 PR #59, feedback-system G1, coordinator-decision-feedback. Verified scopes:

- G1 touches `feedback/` + `scripts/feedback-index.sh` + pre-commit hook — no `architecture/` overlap.
- Plan B (coordinator-decision-feedback) touches `_lib_decision_capture.sh` + `scripts/memory-consolidate.sh` + Evelynn/Sona agent-defs — no `architecture/` overlap.
- Dashboard Phase 1 — no `architecture/` overlap.

So this plan's file scope (entirely under `architecture/`) is disjoint from all three. No coordination needed beyond timing — execute waves while those branches are open without conflict.

The cornerstone plan's `architecture/canonical-v1.md` deliverable IS in `architecture/`, and IS a write-target for the cornerstone implementer. Decision: this plan does NOT touch `canonical-v1.md`. The cornerstone plan creates that file; the consolidation finishes by Wave 4 and the lock manifest pins folder paths thereafter.

## 10. Open questions for Duong

OQ-1. **Is the `evelynn` MCP (`mcps/evelynn/`) still load-bearing?** If retired, archive `mcp-servers.md` whole; if live, rewrite to drop `agent-manager`. (Survey item 19.)

**Resolution (Duong, 2026-04-25):** Retired. Archive `mcp-servers.md` whole. Do NOT create `architecture/mcp/` subdir — the placeholder in §4 is dropped.

OQ-2. **For "rewrite" files, do you want the old version preserved under `archive/`?** My default is yes for `system-overview.md`, `git-workflow.md`, `pr-rules.md` (cleaner audit trail), and no for `infrastructure.md` and `plan-frontmatter.md` (no historical value). Confirm or override.

OQ-3. **Discord-relay status.** Is `apps/discord-relay/` shipped/active, or stalled and abandoned? Determines rewrite-vs-archive for `discord-relay.md`. (Survey item 25.)

**Resolution (Duong, 2026-04-25):** Stalled. Archive `discord-relay.md`.

OQ-4. **Telegram-relay status.** Same question. (Survey item 26.) Note `mcps/evelynn/server.py` already has the tools built but the bridge script doesn't exist; this likely correlates with OQ-1.

**Resolution (Duong, 2026-04-25):** Stalled / abandoned. Archive `telegram-relay.md`.

OQ-5. **Claude runlock contract.** Are Bee or the autonomous-pipeline plans live participants? If both proposed-and-stalled, archive `claude-runlock.md`. (Survey item 28.)

**Resolution (Duong, 2026-04-25):** None live, stalled. Archive `claude-runlock.md`.

OQ-6. **Plans-tree hygiene scope.** This plan scopes to `architecture/`. Want a parallel pass on `plans/in-progress/` to graduate-or-close stale plans? My default: no, separate plan if you want it. The in-progress directory is full of legitimately in-flight work and a sweep risks closing things prematurely.

OQ-7. **Wave commit rhythm.** My default is one commit per file-or-group within each wave (§9 wave plan). Alternative: one commit per wave (5 commits total). One-per-file is reviewable but spammy in `git log`. One-per-wave compresses but makes per-file revert harder. Either works — pick.

## 11. Risks

R1. **Broken external references.** Anything outside `architecture/` that links to `architecture/<old-path>.md` will break. Mitigation: Wave 4 grep sweep for the affected paths across `agents/`, `plans/`, `.claude/`, `scripts/`, root `CLAUDE.md`. Fix references in same commit.

R2. **Archive-marker forgotten in moved file.** Per §5.4, archived file gets a top-of-file stamp. Easy to forget on the last few moves. Mitigation: T-task includes explicit checklist item for stamps; Aphelios's breakdown enumerates per-file.

R3. **`canonical-v1.md` lock manifest race.** If the cornerstone plan ships and pins individual file SHAs before this plan completes, every move under `agent-network-v1/` invalidates a pin. Mitigation: this plan must land BEFORE the cornerstone manifest's lock-activation step. Communicate sequencing to Evelynn.

R4. **Concurrent agent committing under `architecture/`.** If a Viktor instance lands a commit modifying e.g. `architecture/key-scripts.md` while Wave 1 is executing the move to `agent-network-v1/key-scripts.md`, merge resolution is messy. Mitigation: Aphelios announces wave start to Evelynn; Evelynn pauses any concurrent dispatch that touches `architecture/`. Window is short (each wave ≤ 1 hour).

R5. **Rewrites introduce new errors.** A "current concept, stale execution" file rewrite is the highest-risk operation in this plan because the rewriter must accurately distill the current state. Mitigation: Senna review on the rewrite PR; Lucian fidelity review against the rewritten file's claimed sources (e.g. `pr-rules.md` rewrite should match `agent-network.md` agents/memory file + current Senna/Lucian agent defs).

## 12. Architecture impact

Refactor — this plan IS an architecture-layout change. After execution:

- `architecture/` top-level files reduce from 30 to ~2 (the rewritten `README.md` and the cornerstone-plan-owned `canonical-v1.md`). `mcp-servers.md` archives (OQ-1 resolved).
- Canonical heart lives at `architecture/agent-network-v1/` (~21 files).
- `architecture/apps/` (~3 files), `architecture/mcp/` (0–1 files), `architecture/archive/` (5+ files across multiple subdirs).

## Tasks

### Aphelios breakdown notes (2026-04-25)

**Wave-collapse decision (re Orianna's simplicity WARN):** Plan's §9 names six waves (0–5). Aphelios collapses to **five waves** by merging the original Wave 3 (whole-file archives, 3 files) and Wave 5 (flag-resolution archives, 4 files) into a single consolidated archive wave. Rationale: both sub-waves are mechanically identical (whole-file `git mv` + archive-marker stamp at top of moved file), share the same risk class (R2 — forgotten marker), and a 7-file archive batch is still trivially reviewable as one diff. Original Wave 0 (skeleton + README rewrites) and Wave 1 (bulk pure-renames) are **kept separate** — Wave 0 contains the rewritten `architecture/README.md` and the new `architecture/agent-network-v1/README.md` policy text, which is intellectual work needing its own review surface; Wave 1 is mechanical and benefits from a clean "renames only" commit log. Original Wave 4 (cross-ref sweep) stays separate — it must run after all moves are stable, otherwise it re-sweeps. Final wave numbering below: W0, W1, W2, W3 (combined archives), W4 (cross-ref sweep).

**Commit rhythm decision (re OQ-7):** Per-logical-group, not per-file and not per-wave. Specifically: Wave 1 ships as 3 grouped commits (network-internals group, repo-discipline group, single-file moves group); Wave 2 ships one commit per rewrite (6 commits — each rewrite is a distinct intellectual artifact and reverts cleanly file-by-file); Wave 3 ships one batch commit (7 archive moves — mechanical, batches well); Wave 4 ships one sweep commit. Total commits across all waves: ~13. This compromises between OQ-7's two extremes: not 30+ per-file commits (spammy `git log`), not 5 per-wave commits (loses per-file revertability where it matters — the rewrites).

**OQ-2 default applied:** For rewrites, old version preserved under `archive/` for `system-overview.md`, `git-workflow.md`, `pr-rules.md` (cleaner audit trail). NOT preserved for `infrastructure.md`, `plan-frontmatter.md` (no historical value — `plan-frontmatter.md` archives only the v1-orianna fields, which are already captured by `archive/v1-orianna-gate/` precedent), `README.md` (overwrite is fine — it was an index, not a content doc). Aphelios proceeds on this default. If Duong overrides, only Wave 2 task DoDs change.

**Owner_role legend:** All Wave 0–4 build tasks are `sonnet builder` tier unless otherwise marked. Rewrites (Wave 2) are `sonnet builder` because the source-of-truth material to write from is concrete (current agent-defs, current hooks, current memory/agent-network.md); none require novel reasoning. The §7 canonical-source policy text (T.W0.3) is treated as a `sonnet builder` task using the §7.1–7.3 plan body as the verbatim source.

**Concurrency note:** Per §9, no `architecture/` overlap with the three in-flight Viktor branches. Coordinator (T.COORD.4) still announces wave start so Evelynn can pause any future `architecture/`-touching dispatch during each wave's open window.

### Coordination tasks

- [x] **T.COORD.1** — Dispatch breakdown to Aphelios. estimate_minutes: 5. Files: n/a. DoD: Aphelios session opened with this plan path.
- [ ] **T.COORD.2** — Resolve OQ-2/6/7 with Duong (non-blocking refinements). estimate_minutes: 10. Files: this plan §10. DoD: §10 OQ-2/6/7 each get a "Resolution (Duong, YYYY-MM-DD)" line, OR Duong explicitly accepts Aphelios's defaults documented above. blockedBy: none. blocks: none (Aphelios's defaults proceed if Duong silent).
- [ ] **T.COORD.3** — Sequence verification with cornerstone plan owner: confirm Wave 4 completes before `architecture/canonical-v1.md` lock-activation. estimate_minutes: 5. Files: cross-plan check. DoD: Evelynn (or Sona) confirms in inbox.md that the cornerstone plan's lock-activation phase has not started, or has been paused, until T.W4.* tasks merge. blocks: T.W0.1.
- [ ] **T.COORD.4** — Announce wave-start signals to Evelynn so concurrent `architecture/`-touching dispatches pause during each wave's open window. estimate_minutes: 5. Files: `agents/evelynn/inbox.md` (one entry per wave start). DoD: 5 inbox entries (one per W0–W4) posted as each wave begins; each entry names the wave's open file scope. blockedBy: T.COORD.3.

### Phase gate W0 — Skeleton + canonical-source policy

Goal: directory tree exists, READMEs written, policy text live. No content moves yet.

- [x] **T.W0.1** — Create canonical and apps directory skeletons. estimate_minutes: 5. Files: `architecture/agent-network-v1/.gitkeep` (created then removed when README lands), `architecture/apps/.gitkeep`, `architecture/archive/pre-network-v1/.gitkeep`, `architecture/archive/billing-research/.gitkeep`. DoD: `git status` shows the four directories as new; no content moved yet. blockedBy: T.COORD.3.
- [x] **T.W0.2** — Rewrite `architecture/README.md` per §7.3. estimate_minutes: 30. Files: `architecture/README.md`. DoD: file (a) states the canonical-folder rule from §7.1 verbatim or paraphrased ≤10% drift, (b) indexes `agent-network-v1/`, `apps/`, `archive/` (no `mcp/` per OQ-1 resolution), (c) documents the doc-creation guidance from §7.2. Old index of legacy paths removed entirely. blockedBy: T.W0.1.
- [x] **T.W0.3** — Author `architecture/agent-network-v1/README.md` (canonical-folder index + scoped policy). estimate_minutes: 25. Files: `architecture/agent-network-v1/README.md`. DoD: file is ≤80 lines, (a) opens with §7.1 "law-of-the-land" framing, (b) lists the 21 canonical files with one-line summaries (placeholder where files don't yet exist — these get filled in W1/W2), (c) restates §7.2 author-discipline. blockedBy: T.W0.1.
- [x] **T.W0.4** — Author `architecture/apps/README.md` (one-paragraph scope statement). estimate_minutes: 10. Files: `architecture/apps/README.md`. DoD: ≤20 lines, states the apps subtree is app-domain knowledge (deploy targets, hosting, infra) and explicitly distinguishes from agent-network canon. blockedBy: T.W0.1.
- [x] **T.W0.5** — Author `architecture/archive/README.md` (archive subtree explainer per §5). estimate_minutes: 15. Files: `architecture/archive/README.md`. DoD: ≤30 lines, explains retirement-tag convention (§5.1), the archive-marker contract (§5.4), and lists current subdirs (`v1-orianna-gate/`, `pre-network-v1/`, `billing-research/`). blockedBy: T.W0.1.
- [x] **T.W0.6** — Single W0 commit. estimate_minutes: 5. Files: all from T.W0.1–T.W0.5. DoD: one commit titled `chore: architecture wave 0 — canonical skeleton + READMEs`. Commit body cites this plan path. `chore:` prefix per Rule 5 (touches `architecture/**`, not `apps/**`). blockedBy: T.W0.1, T.W0.2, T.W0.3, T.W0.4, T.W0.5.

### Phase gate W1 — Bulk pure-renames (16 files, 3 grouped commits)

Goal: §6.1 table executed via `git mv`. Internal `[link](other-file.md)` paths within each moved file fixed to relative new-tree paths in the same commit. No external cross-refs touched (W4 owns those).

**Group A — agent-network-internals (7 files, one commit):**

- [x] **T.W1.A.1** — `git mv architecture/agent-pair-taxonomy.md architecture/agent-network-v1/taxonomy.md`. estimate_minutes: 5. DoD: file at new path; old path absent.
- [x] **T.W1.A.2** — `git mv architecture/agent-routing.md architecture/agent-network-v1/routing.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.A.3** — `git mv architecture/coordinator-boot.md architecture/agent-network-v1/coordinator-boot.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.A.4** — `git mv architecture/coordinator-memory.md architecture/agent-network-v1/coordinator-memory.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.A.5** — `git mv architecture/compact-workflow.md architecture/agent-network-v1/compact-workflow.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.A.6** — `git mv architecture/plan-lifecycle.md architecture/agent-network-v1/plan-lifecycle.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.A.7** — `git mv architecture/git-identity-enforcement.md architecture/agent-network-v1/git-identity.md`. estimate_minutes: 5. DoD: as above (note: filename short-form change).
- [x] **T.W1.A.8** — Sweep moved files for in-file `[link](sibling.md)` references that now need `agent-network-v1/`-relative or `../`-prefixed paths. estimate_minutes: 15. Files: the 7 files above. DoD: `grep -nE '\]\((agent-pair-taxonomy|agent-routing|coordinator-boot|coordinator-memory|compact-workflow|plan-lifecycle|git-identity-enforcement)\.md\)' architecture/agent-network-v1/` returns zero results, AND no broken in-file relative paths (manual scan).
- [x] **T.W1.A.9** — Group A commit. estimate_minutes: 5. DoD: single commit titled `chore: architecture wave 1A — agent-network-internals renames`. blockedBy: T.W1.A.1..A.8.

**Group B — repo-discipline (6 files, one commit):**

- [x] **T.W1.B.1** — `git mv architecture/cross-repo-workflow.md architecture/agent-network-v1/cross-repo.md`. estimate_minutes: 5. DoD: file at new path.
- [x] **T.W1.B.2** — `git mv architecture/key-scripts.md architecture/agent-network-v1/key-scripts.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.B.3** — `git mv architecture/platform-parity.md architecture/agent-network-v1/platform-parity.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.B.4** — `git mv architecture/platform-split.md architecture/agent-network-v1/platform-split.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.B.5** — `git mv architecture/plugins.md architecture/agent-network-v1/plugins.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.B.6** — `git mv architecture/testing.md architecture/agent-network-v1/testing.md`. estimate_minutes: 5. DoD: as above.
- [x] **T.W1.B.7** — In-file link sweep for Group B (same shape as T.W1.A.8). estimate_minutes: 10. DoD: `grep` of old basenames inside the 6 moved files returns zero results.
- [x] **T.W1.B.8** — Group B commit titled `chore: architecture wave 1B — repo-discipline renames`. estimate_minutes: 5. blockedBy: T.W1.B.1..B.7.

**Group C — single-file moves (3 files, one commit):**

- [x] **T.W1.C.1** — `git mv architecture/security-debt.md architecture/agent-network-v1/security-debt.md`. estimate_minutes: 3. DoD: file at new path.
- [x] **T.W1.C.2** — `git mv architecture/deployment.md architecture/apps/deployment.md`. estimate_minutes: 3. DoD: as above.
- [x] **T.W1.C.3** — `git mv architecture/firebase-storage-cors.md architecture/apps/firebase-storage-cors.md`. estimate_minutes: 3. DoD: as above.
- [x] **T.W1.C.4** — In-file link sweep for Group C (3 files). estimate_minutes: 5. DoD: as W1.A.8 shape.
- [x] **T.W1.C.5** — Group C commit titled `chore: architecture wave 1C — single-file moves into agent-network-v1 and apps`. estimate_minutes: 5. blockedBy: T.W1.C.1..C.4.

### Phase gate W2 — Rewrites (6 files, one commit per rewrite)

Goal: §6.2 rewrites land. Each rewritten file is a fresh authoring against a named source-of-truth, NOT a copy-edit of the old file. Old file (where §6.2 calls for archive) is `git mv`'d to its archive destination in the SAME commit, with the §5.4 archive-marker stamp added.

- [x] **T.W2.1** — Rewrite `architecture/README.md` (already done in W0 as T.W0.2). estimate_minutes: 0 (deduplicated — covered by W0). DoD: confirm T.W0.2 deliverable still satisfies §6.2 row 1; if not, supplement here. Note: this row in §6.2 collapses into W0; no separate W2 task needed.
- [x] **T.W2.2** — Rewrite system-overview into canonical `overview.md`. estimate_minutes: 45. Files: `architecture/agent-network-v1/overview.md` (NEW), `architecture/agent-network.md` → no (different file — leave for W3), `architecture/system-overview.md` → `archive/pre-network-v1/system-overview.md`. DoD: new `overview.md` is one screen (≤80 lines), names current roster as referencing `agents/memory/agent-network.md` rather than enumerating, drops Bard/Zoe/Irelia/agent-manager mentions entirely. Archived original gets §5.4 stamp `Archived: superseded by architecture/agent-network-v1/overview.md on 2026-04-25` at top. New file frontmatter line `Supersedes: archive/pre-network-v1/system-overview.md`. Single commit titled `chore: architecture wave 2.2 — rewrite system-overview into agent-network-v1/overview.md`. blockedBy: T.W0.6.
- [x] **T.W2.3** — Author canonical `agents.md` (replaces retired `agent-system.md` top half). estimate_minutes: 40. Files: `architecture/agent-network-v1/agents.md` (NEW). Source: `agents/memory/agent-network.md` + the W1-A.1 `taxonomy.md` matrix. DoD: file is roster + role table only, ≤120 lines, NO Plan-Lifecycle-Signing-Role section (that was the retired v1 Orianna gate — captured by `archive/v1-orianna-gate/` already), references `taxonomy.md` for the deeper pair-mapping. The source `agent-system.md` is NOT moved here — it whole-file archives in W3. Single commit titled `chore: architecture wave 2.3 — author agent-network-v1/agents.md`. blockedBy: T.W0.6.
- [x] **T.W2.4** — Rewrite `plan-frontmatter.md` (drop v1-Orianna fields). estimate_minutes: 30. Files: `architecture/agent-network-v1/plan-frontmatter.md` (NEW), `architecture/plan-frontmatter.md` → `archive/v1-orianna-gate/plan-frontmatter.md`. DoD: new file documents only current fields (`status`, `concern`, `owner`, `created`, `tests_required`, `architecture_changes`, `architecture_impact`, `complexity`, `tags`, `related`); no `orianna_signature_<phase>` or `orianna_gate_version`. Archived original gets §5.4 stamp. Single commit titled `chore: architecture wave 2.4 — rewrite plan-frontmatter.md, archive v1-Orianna-fields version`. blockedBy: T.W0.6.
- [x] **T.W2.5** — Rewrite `git-workflow.md` (drop retired Tier-3 PR matrix and pre-Rule-5 commit prefixes). estimate_minutes: 40. Files: `architecture/agent-network-v1/git-workflow.md` (NEW), `architecture/git-workflow.md` → `archive/pre-network-v1/git-workflow.md`. DoD: new file's commit-prefix section matches Rule 5 verbatim (chore/ops/feat/fix/perf/refactor scoped by diff), branch-protection and worktree sections preserved, no Lissandra/Rek'Sai/Bard mentions. Archived original gets §5.4 stamp. Single commit titled `chore: architecture wave 2.5 — rewrite git-workflow.md`. blockedBy: T.W0.6.
- [x] **T.W2.6** — Rewrite `pr-rules.md` (drop TeamCreate review loop). estimate_minutes: 40. Files: `architecture/agent-network-v1/pr-rules.md` (NEW), `architecture/pr-rules.md` → `archive/pre-network-v1/pr-rules.md`. DoD: new file's review section names current `strawberry-reviewers` / `strawberry-reviewers-2` identities and the Rule-18 author-cannot-self-approve gate; QA-gate (Rule 16) section, work-scope-anonymity section, account-roles section preserved. No `TeamCreate` / Katarina / Lissandra mentions. Archived original gets §5.4 stamp. Single commit titled `chore: architecture wave 2.6 — rewrite pr-rules.md`. blockedBy: T.W0.6.
- [x] **T.W2.7** — Rewrite `infrastructure.md` (drop agent-manager/evelynn MCP claims, mark Telegram bridge stalled→archived per OQ-4). estimate_minutes: 30. Files: `architecture/apps/infrastructure.md` (NEW or rewrite-in-place via Edit). Source `architecture/infrastructure.md` is NOT preserved (per OQ-2 default: rewrite-in-place, no archive copy). DoD: VPS section accurate (Hetzner CX22 / current PM2 processes), MCP servers section deleted entirely (the canonical surface for MCP listings is now nonexistent — `mcp-servers.md` archives in W3), Telegram-bridge "Planned" paragraph removed (refer reader to `archive/2026-04-25-telegram-relay.md`). Single commit titled `chore: architecture wave 2.7 — rewrite infrastructure.md into apps subtree`. blockedBy: T.W0.6.
- [x] **T.W2.8** — Author canonical `communication.md` (replaces archived `agent-network.md` Phase-1 content). estimate_minutes: 30. Files: `architecture/agent-network-v1/communication.md` (NEW). DoD: per §6.5 decision, file states "Live roster source of truth: `agents/memory/agent-network.md`" up front, then documents the protocol/contract surface (inbox/outbox, dispatch shape, decision-feedback contract pointers) without enumerating the roster. Single commit titled `chore: architecture wave 2.8 — author agent-network-v1/communication.md`. blockedBy: T.W0.6. Note: source `architecture/agent-network.md` archives in W3 (whole-file).

### Phase gate W3 — Whole-file archives (consolidated, 7 files in one commit)

Goal: §6.3 (3 files) + §9 Wave 5 (4 files) executed as one batch. Per Aphelios's wave-collapse, both subwaves merge here.

- [x] **T.W3.1** — `git mv architecture/agent-network.md archive/pre-network-v1/agent-network.md`. estimate_minutes: 3. DoD: archived file gets §5.4 stamp `Archived: superseded by architecture/agent-network-v1/communication.md on 2026-04-25` at top.
- [x] **T.W3.2** — `git mv architecture/agent-system.md archive/pre-network-v1/agent-system.md`. estimate_minutes: 3. DoD: §5.4 stamp pointing to `architecture/agent-network-v1/agents.md` (top half) and `archive/v1-orianna-gate/` (bottom half — Plan-Lifecycle-Signing-Role).
- [x] **T.W3.3** — `git mv architecture/claude-billing-comparison.md archive/billing-research/2026-04-05-claude-billing-comparison.md`. estimate_minutes: 3. DoD: §5.4 stamp `Archived: market-research record from 2026-04-05; decision (team plan via Claude Code OAuth) is in effect`.
- [x] **T.W3.4** — `git mv architecture/mcp-servers.md archive/2026-04-25-mcp-servers.md`. estimate_minutes: 3. DoD: §5.4 stamp `Archived: evelynn MCP retired (OQ-1, 2026-04-25); no canonical replacement` at top. (Top-level `archive/<date>-<slug>.md` per §5.1 — single retired file, no associated regime.)
- [x] **T.W3.5** — `git mv architecture/discord-relay.md archive/2026-04-25-discord-relay.md`. estimate_minutes: 3. DoD: §5.4 stamp `Archived: stalled (OQ-3, 2026-04-25); no canonical replacement`.
- [x] **T.W3.6** — `git mv architecture/telegram-relay.md archive/2026-04-25-telegram-relay.md`. estimate_minutes: 3. DoD: §5.4 stamp `Archived: stalled / abandoned (OQ-4, 2026-04-25); no canonical replacement`.
- [x] **T.W3.7** — `git mv architecture/claude-runlock.md archive/2026-04-25-claude-runlock.md`. estimate_minutes: 3. DoD: §5.4 stamp `Archived: no live participants (OQ-5, 2026-04-25); no canonical replacement`.
- [x] **T.W3.8** — Single W3 commit. estimate_minutes: 5. Files: all W3.1–W3.7. DoD: commit titled `chore: architecture wave 3 — whole-file archives (pre-network-v1 + billing + flag-resolved retirements)`. blockedBy: T.W3.1..W3.7, T.W2.8 (since communication.md must exist before agent-network.md archives — its archive-marker points to it).

### Phase gate W4 — Cross-reference sweep

Goal: every reference to an old `architecture/<old-path>.md` across the entire repo points to its new location. R1 mitigation.

- [ ] **T.W4.1** — Enumerate all old paths into a sweep script. estimate_minutes: 15. Files: scratch list (committed as `assessments/2026-04-25-architecture-consolidation-sweep.md` — a sweep audit log; this is an assessment, not architecture, so it doesn't bloat the canonical tree). DoD: file lists each of the 23 source paths from §6.1+§6.2+§6.3+W3 with its destination. blockedBy: T.W3.8.
- [ ] **T.W4.2** — `grep -rn` sweep across `agents/`, `plans/`, `.claude/`, `scripts/`, root `CLAUDE.md`, `architecture/` (in-tree cross-refs surviving W1–W3) for each old path. estimate_minutes: 20. Files: same audit log appended with hit list. DoD: every hit catalogued with (file, line, surrounding context).
- [ ] **T.W4.3** — Apply fixes per audit log. estimate_minutes: 30. Files: every file in the audit-log hit list. DoD: each old-path reference rewritten to its destination; quoted-prose mentions updated; relative-path references resolved. After-fix `grep -rn` pass returns zero hits for any of the 23 old paths.
- [ ] **T.W4.4** — Verification grep + W4 commit. estimate_minutes: 10. Files: all touched in T.W4.3. DoD: `grep -rn -E '(architecture/(agent-pair-taxonomy|agent-routing|agent-network|agent-system|coordinator-boot|coordinator-memory|compact-workflow|plan-lifecycle|plan-frontmatter|git-identity-enforcement|git-workflow|cross-repo-workflow|key-scripts|platform-parity|platform-split|plugins|testing|security-debt|deployment|firebase-storage-cors|infrastructure|system-overview|pr-rules|mcp-servers|discord-relay|telegram-relay|claude-runlock|claude-billing-comparison|README)\.md)' .` returns zero hits except inside `architecture/archive/` paths (where the old basenames legitimately survive as archive content) and inside this plan body. Single commit titled `chore: architecture wave 4 — cross-reference sweep`. blockedBy: T.W4.1, T.W4.2, T.W4.3.

### Closeout

- [x] **T.CLOSE.1** — Verify §12 architecture-impact summary holds: `architecture/` top-level count is now ≤2 (`README.md`, `canonical-v1.md` once cornerstone ships). estimate_minutes: 5. DoD: `ls architecture/*.md` shows expected files only; everything else lives in `agent-network-v1/`, `apps/`, or `archive/`. blockedBy: T.W4.4.
- [ ] **T.CLOSE.2** — Move plan to `plans/implemented/personal/` via Orianna. estimate_minutes: 10. DoD: Orianna invocation request sent; plan committed in `plans/implemented/personal/2026-04-25-architecture-consolidation-v1.md` with `Promoted-By: Orianna` trailer. blockedBy: T.CLOSE.1.

### Estimate roll-up

- W0: 90 min (5 build tasks + 1 commit task)
- W1: ~110 min (16 mv + 3 sweeps + 3 commits)
- W2: ~255 min (6 rewrites; W2.1 deduplicates into W0)
- W3: ~26 min (7 mv + 1 commit)
- W4: ~75 min (sweep + fix + verify)
- COORD + CLOSE: ~40 min
- **Total: ~9.9 hours of build + ~40 min of coord/close** spread across one operator over 2–3 sessions, OR parallelized across 2 builders with W2 rewrites split (T.W2.2/T.W2.3/T.W2.4 to one builder, T.W2.5/T.W2.6/T.W2.7/T.W2.8 to the other) reducing wall-clock to ~6 hours.
- Total task count: **49 tasks** (4 COORD + 6 W0 + 17 W1 + 7 W2 + 8 W3 + 4 W4 + 2 CLOSE + 1 deduplicated W2.1 placeholder).

`tests_required: false` reflects that this is a doc-tree refactor; there is no behavioral change to test. The cross-reference sweep (T.W4.4) is verifiable by a `grep` against the old paths returning zero results across the repo.

### New OQs surfaced by Aphelios's breakdown

OQ-A1. **`agents.md` vs `taxonomy.md` overlap.** §4 target tree lists both `agents.md` (rewritten roster) and `taxonomy.md` (current `agent-pair-taxonomy.md`). T.W2.3 authors `agents.md` from the same source material the taxonomy doc covers. Risk: two canonical docs documenting overlapping concerns. Suggested resolution: `agents.md` becomes a 30-line roster-only entry and explicitly defers depth to `taxonomy.md`, or `agents.md` is dropped entirely and `taxonomy.md` absorbs its scope. Default: 30-line roster-only `agents.md` with clear "see taxonomy.md for pair-mapping detail" pointer, since the tree benefits from a single-file "who is currently in the network" view. Confirm or override before T.W2.3 fires.

OQ-A2. **Sweep audit log path.** T.W4.1 puts the audit log at `assessments/2026-04-25-architecture-consolidation-sweep.md`. Alternative: discard after sweep (no permanent record). Default: keep — the audit log is a useful record of what cross-refs the consolidation touched, and `assessments/` is the right home for refactor-sweep artifacts. Confirm or override.

OQ-A3. **Wave order: W2 vs W3.** Current order is W0 → W1 (renames) → W2 (rewrites with archives of source) → W3 (whole-file archives of remaining). T.W3.1 (archive `agent-network.md`) is blockedBy T.W2.8 (author `communication.md`) because the archive-marker references it. This blocking is cross-wave but trivial. Alternative: reorder so W3 comes before W2 (archive first, rewrite second). Rejected — current order keeps W3 as a single mechanical batch and W2 builders can author rewrites without first dealing with archive-stamps in their commits. Documented to make the cross-wave dependency explicit.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (swain), concrete decision, full survey of all 30 architecture files with per-file classification, named sequencing constraint (must precede cornerstone canonical-v1 lock activation), and explicit migration discipline. All four blocking OQs (OQ-1/3/4/5) resolved by Duong on 2026-04-25; remaining OQs (OQ-2/6/7) are non-blocking refinements that Aphelios's breakdown can absorb. Risks are enumerated with concrete mitigations. Tasks are actionable with named wave groupings.
- **Simplicity:** WARN: possible overengineering — 6-wave migration for ~30 file moves is at the edge of ceremony; rationale (per-wave revert, clean git log --follow, conflict-avoidance with concurrent Viktor branches) is named and defensible, but Aphelios should consider collapsing Waves 0+1 or Waves 3+5 into single commits if review burden is dominating.
