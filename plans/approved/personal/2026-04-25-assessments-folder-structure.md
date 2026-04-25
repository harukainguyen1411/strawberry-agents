---
status: approved
concern: personal
owner: lux
created: 2026-04-25
tests_required: false
complexity: complex
orianna_gate_version: 2
tags: [architecture, assessments, taxonomy, doc-tree, canonical-v1, lifecycle]
related:
  - plans/approved/personal/2026-04-25-architecture-consolidation-v1.md
  - plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md
  - plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md
  - CLAUDE.md
  - architecture/plan-lifecycle.md
  - feedback/
architecture_impact: refactor
---

# Assessments folder structure — taxonomy, naming, lifecycle, ownership

## 1. Problem & motivation

The `assessments/` tree is the system's analysis surface — research dumps, QA reports, fact-checks, audits, retrospectives, advisories, recovery artifacts. As of 2026-04-25 it contains **52 entries at the root level** (28 loose `.md` files, 1 patch + README, plus 14 subdirectories of inconsistent shape and depth). Three structural problems compound:

1. **No taxonomy.** Some material is grouped (`research/`, `qa-reports/`, `plan-fact-checks/`, `memory-audits/`, `migration-audits/`, `mcp-ecosystem/`, `branch-protection/`, `advisory/`, `residuals-and-risks/`, `rescued-patches/`, `qa-artifacts/`, `plan-triage/`); some is loose at root (28 files including `agent-folder-audit-2026-04-20.md`, `claude-md-signal-noise-audit.md`, `gemini-pro-ecosystem-assessment.md`, `prompt-caching-audit-2026-04-21.md`, `orianna-prompt-audit-2026-04-21.md`, `ship-day-*-2026-04-21.md` checklists, `agent-system-assessment.md`, `personal-ai-stack.md`); some lives under a concern split (`personal/` 2 files, `work/` 16 files) that mirrors `plans/` but is partial. The mental model for "where does X go" is undefined — every author re-derives it badly.
2. **No naming convention.** The dominant pattern is `YYYY-MM-DD-<slug>.md` (28 of 28 root files use it), but four loose files at root use a `<topic>-<YYYY-MM-DD>.md` suffix-date variant (`agent-folder-audit-2026-04-20.md`, `ai-provider-capacity-expansion-2026-04-21.md`, `orianna-prompt-audit-2026-04-21.md`, `prompt-caching-audit-2026-04-21.md`, `ship-day-*-2026-04-21.md`), and a handful are date-less entirely (`agent-system-assessment.md`, `claude-md-signal-noise-audit.md`, `gemini-pro-ecosystem-assessment.md`, `personal-ai-stack.md`, `reviewer-auth-smoke-2026-04-19.md`). Inside subdirs the prefix-date pattern dominates (`research/2026-04-23-claude-code-routines-spike.md`, `personal/2026-04-20-lissandra-verification.md`) but is not enforced. Skarner cannot reliably sort or filter by date without parsing both shapes.
3. **No frontmatter contract, no lifecycle, no ownership signal.** Most files have no YAML frontmatter at all. A few do — `assessments/research/2026-04-25-agent-observability-tooling.md` carries `author: lux (extracted by skarner) / date / source-session / purpose` but that schema is bespoke. Nothing signals when an assessment goes stale, when it's superseded, who owns updates, or what it assessed. `plan-fact-checks/` has accumulated **376 files** with no archival policy — a write-once log, never groomed. `qa-reports/` has 61 entries (some `.png`/`.webm` artifacts mixed in with `.md` reports). The tree grows monotonically; nothing leaves.

The cornerstone canonical-v1 lock (Phase 2 dashboard ship, see `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` §6.4) needs to know what counts as "current" assessment material vs historical record. Today it cannot: there is no `state` field, no `archived/` subtree, no superseded-by chain. The architecture-consolidation plan explicitly out-of-scopes assessments ("nothing under agents/, nothing under assessments/" §2 scope-out), deferring it here. This plan is the assessments-side companion.

Adjacent lanes:
- **Azir's parallel ADR `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md`** redesigns Akali's QA-report shape (citation-tagging, `requires_diagnosis` field, frontmatter contract). That ADR owns the shape inside `qa-reports/`. This ADR owns the location, naming, and lifecycle of the `qa-reports/` category — not the content shape.
- **`feedback/` directory** uses a flat `YYYY-MM-DD-<slug>.md` shape with no INDEX.md today (PR #63 shipped INDEX.md infrastructure for an adjacent surface; we model on that goal, not its current state). The `feedback/` flat-shape is the closest existing precedent for what `assessments/` should converge toward — but `feedback/` is small (7 files) and `assessments/` is 100x that, so a flat shape is wrong here. Categorical subdirs are the right primitive.
- **`plans/`** uses `proposed/ → approved/ → in-progress/ → implemented/ → archived/` lifecycle stages plus a `personal/`/`work/` concern split. That five-state lifecycle is overkill for assessments (no proposal review, no approval gate, no in-progress execution). A two-state `active|archived` lifecycle is sufficient.

## 2. Decision

Restructure `assessments/` into a **category-first, concern-aware, lifecycle-aware** tree with a mandatory frontmatter contract, a single naming convention, and a per-category INDEX.md. Adopt these four primitives:

1. **Top-level categories** (canonical list — see §3) replace the current ad-hoc mix. Each top-level entry is a category subdir; no loose files at the assessments root except `README.md` and `INDEX.md`.
2. **Concern split lives inside each category** (`<category>/personal/`, `<category>/work/`) when the category is concern-scoped; categories that are universally cross-concern (e.g. `mcp-ecosystem/`, `research/` on global tooling) skip the split.
3. **Naming: `YYYY-MM-DD-<slug>.md`** universally; date-suffix variants are deprecated. Slugs are kebab-case, ≤6 words, content-descriptive (no agent name as prefix unless it IS the topic).
4. **Lifecycle: two-state `active|archived`.** Active assessments live in their category subtree. Archived assessments move to `<category>/archived/<YYYY>/`. Time-based archival is the default trigger (≥120 days untouched + state not `living`); supersede-driven archival uses the `superseded_by:` frontmatter field.

### Scope — out (deferred):

- **Migration of existing files.** This ADR defines the target tree and the rules. The bulk move is a Kayn breakdown task (touches ~150 files across 14 subdirs + 28 loose root files) tracked separately as `plans/proposed/personal/<date>-assessments-migration-execution.md` once this ADR is approved. No rename is performed by this plan.
- **Dashboard "assessments-by-author" surface.** Defer to retrospection dashboard v1.5 (cornerstone plan §future).
- **QA-report content shape.** Owned by Azir's parallel ADR `2026-04-25-qa-two-stage-architecture.md`. This ADR pins `qa-reports/` as the location and the frontmatter wrapper (date/owner/state/target) but defers the body shape to Azir.
- **`plan-fact-checks/` archival sweep.** 376 files is a content-grooming task, not a structural one. This ADR pins the per-year archive convention; the actual sweep is its own follow-up plan.
- **`agents/<name>/learnings/` reorganization.** That tree is agent-owned and out of `assessments/` scope.
- **Hook enforcement of naming/frontmatter.** Soft-launch first (advisory in agent defs); hardening hooks come in a follow-up plan after the migration lands and we observe author drift.

### Scope — in:

- The 14 existing subdirs + 28 loose root files of `assessments/` as of 2026-04-25.
- The canonical category list and what belongs in each.
- The frontmatter contract (mandatory + optional fields).
- The naming convention.
- The lifecycle (`active|archived`, archival triggers, archive location convention).
- The per-category INDEX.md contract (what it lists, who maintains it, auto-generation eligibility).
- The README.md at `assessments/` root (top-level navigation).
- Cross-references from `CLAUDE.md` File Structure table and `architecture/plan-lifecycle.md` (assessments-lifecycle is sibling content, not derivative).

## 3. Canonical category taxonomy

The taxonomy reflects observed assessment kinds, not theoretical ones. Eight categories cover the existing 52 root-level entries + 14 subdirs without leftovers:

| # | Category | Purpose | Owner-default | Concern-scoped? | Existing material to fold in |
|---|----------|---------|---------------|-----------------|-------------------------------|
| 1 | `research/` | Build-vs-buy spikes, ecosystem surveys, prior-art analysis, tooling evaluations, model/provider research | Lux (AI/MCP), Skarner (memory/observability), Karma (process) | No (cross-concern by default; opt-in `personal/`/`work/` if scope is concern-specific) | `research/*`, `gemini-pro-ecosystem-assessment.md`, `personal-ai-stack.md`, `mcp-ecosystem/*`, `2026-04-12-darkstrawberry-platform-strategy.md` |
| 2 | `qa-reports/` | Akali Playwright runs, manual QA reports, smoke-test reports — anything user-flow validation per Rule 16 | Akali (Playwright), Lulu (manual) | Yes (`qa-reports/personal/`, `qa-reports/work/`) | `qa-reports/*` (61 files; shape owned by Azir's parallel ADR) |
| 3 | `audits/` | Targeted single-surface audits — agent-folder, prompt, secrets, deploy-script, signal-noise, capacity expansion | Author-specific (audit subject's owner) | Yes | `agent-folder-audit-2026-04-20.md`, `claude-md-signal-noise-audit.md`, `prompt-caching-audit-2026-04-21.md`, `orianna-prompt-audit-2026-04-21.md`, `agent-system-assessment.md`, `2026-04-17-deploy-script-audit.md`, `ship-day-azir-secrets-audit-2026-04-21.md`, `ai-provider-capacity-expansion-2026-04-21.md`, `2026-04-08-protocol-leftover-audit.md`, `2026-04-08-myapps-snapshot.md`, `memory-audits/*`, `migration-audits/*` |
| 4 | `reviews/` | Architectural reviews of PRs, retroactive reviews, plan-fact-checks, fidelity reviews | Lucian (fidelity), Senna (PR code), reviewer-of-record | Yes | `2026-04-17-pr-120-121-architectural-review.md`, `2026-04-17-pr-120-121-retroactive-review.md`, `2026-04-18-migration-plan-factcheck.md`, `plan-fact-checks/*` (376 files — moves into `reviews/plan-fact-checks/` subtree) |
| 5 | `retrospectives/` | Post-incident, post-ship, residuals-and-risks, ship-day reviews; coordinator-misroute and process-failure post-mortems | Coordinator-of-record (Evelynn/Sona) | Yes | `2026-04-09-delivery-pipeline-security.md` (partial), `residuals-and-risks/*`, `ship-day-deploy-checklist-2026-04-21.md`, `ship-day-azir-option-a-checklist-2026-04-21.md`, post-mortem material from `work/` and `personal/` |
| 6 | `runbooks/` | Operational runbooks, manual test plans, recovery procedures, dry-run reports | Operator-of-record | Yes | `2026-04-13-dark-strawberry-manual-test-plan.md`, `2026-04-18-migration-dryrun.md`, `2026-04-18-p*-report.md` (P0/P1/P2/P3 phase reports), `2026-04-19-a1-filter-report.md`, `2026-04-19-a7-orphan-path-sentinel.md` (currently in `migration-audits/`), `2026-04-25-superadmin-self-invite-runbook.md` (currently in `work/`), `branch-protection/*`, `2026-04-21-orianna-gate-smoke.md` |
| 7 | `advisories/` | Cross-cutting concerns, fact-found-but-not-yet-actioned, allowlist proposals, capacity warnings | Author-specific | Yes | `advisory/*`, `plan-triage/*`, `2026-04-13-firebase-storage-cors-investigation.md`, `2026-04-19-portfolio-v0-dv0-asks.md`, `2026-04-19-test-topology.md` |
| 8 | `artifacts/` | Binary or semi-binary artifacts that pair with reports — screenshots, videos, console logs, patches, JSON dumps | Producing-agent | Yes | `qa-artifacts/*`, `rescued-patches/*`, `*.png`/`*.webm` currently mixed into `qa-reports/` |

**Out of taxonomy entirely** (move out of `assessments/` in the migration phase):
- `2026-04-21-system-audit-post-foundational-ADRs.md` — this is large enough and structural enough to be promoted to `architecture/` canonical or to a `plans/implemented/` retrospective. Migration plan decides.
- `reviewer-auth-smoke-2026-04-19.md` — 901 bytes, candidate for direct deletion or fold-into a retrospective.

### Why these eight (and not more, not fewer)

- **Eight covers the empirical surface.** Every existing file fits one cleanly; no "miscellaneous" bucket. Nine would be over-fitting (e.g. splitting `audits/` from `reviews/` further); seven would force `audits/` and `runbooks/` to share a confused bucket.
- **Boundaries are testable.** A reader given a filename can route it in <10 seconds: "Is it user-flow validation? → qa-reports. Is it a single-surface deep-dive? → audits. Is it post-incident? → retrospectives. Is it a procedure? → runbooks. Is it forward-looking research? → research. Is it a PR/plan review? → reviews. Is it a not-yet-actioned finding? → advisories. Is it a binary? → artifacts."
- **Owner-default is realistic.** Each category maps to 1–3 agents who actually produce that kind of content today.
- **Concern split is opt-in per-category.** Universally-cross-concern categories (`research/` for tooling, `mcp-ecosystem/` material) don't pay the `personal/`/`work/` overhead.

## 4. Naming convention

**Canonical: `YYYY-MM-DD-<slug>.md`**

- **`YYYY-MM-DD`** — ISO date prefix, the day the assessment was authored (not the day the subject occurred — that goes in frontmatter `target_date:` if relevant).
- **`<slug>`** — kebab-case, ≤6 words, content-descriptive. Avoid agent names as prefixes unless the agent IS the topic (e.g. `orianna-prompt-audit` is fine because Orianna's prompt is the assessed surface; `lux-research-on-mcp` is bad — drop the `lux-` prefix, the owner is in frontmatter).
- **No suffix-date.** `agent-folder-audit-2026-04-20.md` becomes `2026-04-20-agent-folder-audit.md`.
- **No underscores, no spaces, no caps.** `Agent_Folder_Audit.md` and `AgentFolderAudit.md` both invalid.
- **Sub-grouped material** (e.g. PR-specific QA artifacts) lives in a session-named subdir: `qa-reports/personal/2026-04-22-pr69-firebase-2b/{report.md, screenshot-01.png, video.webm}` — the subdir carries the date+slug, the inner files carry semantic names. This prevents 30-file flat dumps when a single PR has many artifacts.

**Why ISO-prefix and not suffix:** prefix-date sorts naturally in `ls` and `find`, makes Skarner's date-range filtering trivial, and matches `plans/`, `agents/<name>/learnings/`, `feedback/` conventions across the repo. Suffix-date is a minority dialect today; converging is cheap.

## 5. Frontmatter contract

Every assessment `.md` file MUST carry a YAML frontmatter block. Eight mandatory fields, four optional.

### Mandatory

```yaml
---
date: 2026-04-25                # ISO date, must match filename prefix
author: lux                     # agent slug or human handle (e.g. duong)
category: research              # one of the 8 canonical categories
concern: personal               # personal | work | cross
target: <subject>               # what was assessed (free text, ≤80 chars)
state: active                   # active | archived | superseded | living
owner: lux                      # agent responsible for keeping this current (often == author)
session: <session-id-or-none>   # CC session id when authored mid-session, or "none"
---
```

### Optional

```yaml
superseded_by: assessments/research/2026-05-12-newer-thing.md   # set when state: superseded
archived_at: 2026-08-25                                         # set when state: archived
related:                                                         # cross-refs to plans, ADRs, other assessments
  - plans/approved/personal/...
  - assessments/research/...
tags: [mcp, prompt-caching, ...]                                 # discovery tags
```

### Field semantics

- **`state: living`** — opt-in for assessments that are intentionally evergreen (e.g. a tooling roster, a `personal-ai-stack.md`-style reference doc). `living` exempts the assessment from the 120-day archival trigger; the owner commits to keeping it current.
- **`state: active`** — default. Subject to the 120-day archival policy unless `living`.
- **`state: archived`** — moved into `<category>/archived/<YYYY>/` subtree; `archived_at:` set.
- **`state: superseded`** — `superseded_by:` points at the replacing assessment; the file stays in place (does not move) but is treated as historical.
- **`category` and folder location MUST agree** — file at `assessments/research/...` MUST have `category: research`. Enforced by a future lint hook (out of scope this plan).
- **`session`** — when authored as a deliverable from a CC session, record the session id so Skarner can join assessments to transcripts. `none` is acceptable for human-authored or batch-extracted content.

### Why mandatory frontmatter

- **Discoverability.** Skarner can `grep -l "owner: lux" assessments/` for routing, `grep -l "state: active" assessments/` for current-truth queries, `grep -l "concern: work" assessments/` for sona surfaces.
- **Lifecycle automation.** `state` + `archived_at` enables a future cron that proposes archival candidates without parsing prose.
- **Authorship attribution.** `author` and `owner` distinguish "who wrote this once" from "who maintains it now"; both matter for the dashboard and for re-routing stale-doc fixes.
- **Supersedes provenance.** `superseded_by:` lets readers chase the chain without git-archaeology.

## 6. Lifecycle

Two-state model: `active` ↔ `archived` (with `superseded` as a special active-shaped state).

### Triggers

1. **Time-based archival.** An assessment with `state: active` (not `living`), untouched (no commit) for ≥120 days, is a candidate for `state: archived`. The owner is the decider; a future Skarner routine surfaces candidates monthly.
2. **Supersede-driven.** Any new assessment that replaces an older one MUST set the older one's `state: superseded` and `superseded_by:` in the same commit. The superseded file does NOT move; it stays for history.
3. **Explicit retire.** Owner may set `state: archived` at any time when the subject regime is retired (e.g. an assessment of a removed feature).

### Archival mechanics

- Archived files MOVE to `<category>/archived/<YYYY>/<original-filename>`. The `<YYYY>` subdivision is the year of `archived_at:` (not the year of the original `date:`).
- Move is a `git mv` in a `chore:` commit; no review gate. (Assessments are not as load-bearing as plans; an Orianna-style promote agent is overkill.)
- The archived file's frontmatter `state: archived` and `archived_at:` are set in the same commit.
- Archived files remain searchable; they are not deleted.

### Why two states (not five)

- Plans need five states because they trace execution from idea → done. Assessments do not execute; they assert truth at a point in time. The only meaningful binary is "is this asserted truth current?"
- A `proposed` state for assessments would invent a review process that doesn't exist (assessments are usually authored as deliverables of work already authorized). A `draft` state is what a CC session is, before commit — git already handles draft-vs-committed.
- `superseded` covers the "newer thing replaces this" case without forcing a move (history is preserved in place).

## 7. INDEX.md contract

Every category subdir carries an `INDEX.md`. Top-level `assessments/INDEX.md` aggregates.

### Per-category INDEX.md shape

```markdown
# <Category> assessments

<one-paragraph purpose statement>

## Active (last 30 days)
- 2026-04-25-foo-thing.md — `<target>` — owner: lux
- ...

## Active (older)
- 2026-03-12-bar.md — `<target>` — owner: skarner
- ...

## Living
- personal-ai-stack.md — `<target>` — owner: lux

## Archived (link to subtree)
See [archived/](./archived/).
```

### Maintenance

- **Auto-generated, not hand-curated.** A future `scripts/assessments/index-gen.sh` (POSIX-portable per Rule 10) walks each category, parses frontmatter, emits the INDEX.md. Hand-edits are overwritten on next generation.
- **Frequency.** Pre-commit hook regenerates the INDEX.md for any category whose contents changed (add/move/remove of `.md` files in that category). This keeps drift to zero without requiring authors to remember.
- **Out of scope this plan.** The script is implementation; this plan only fixes the contract. Generator script is part of the migration-execution plan.

### Top-level `assessments/INDEX.md` and `assessments/README.md`

- `README.md` — one-screen overview: the eight categories, the naming rule, the frontmatter contract, link to this ADR. Hand-curated, rare updates.
- `INDEX.md` — auto-generated category roll-up: link to each category, count of active/archived/living, link to each per-category INDEX.

## 8. Comparison with adjacent surfaces

| Surface | Lifecycle | Naming | Concern split | Frontmatter | Index |
|---------|-----------|--------|---------------|-------------|-------|
| `plans/` | 5 states (proposed/approved/in-progress/implemented/archived) | `YYYY-MM-DD-<slug>.md` | Yes (`personal/`, `work/`) | Mandatory rich schema | None today |
| `architecture/` | 1 state (`archive/<tag>/` for retirement) | Free-form (no date prefix) | No | Optional | `README.md` hand-curated |
| `agents/<name>/learnings/` | 1 state (rolling) | `YYYY-MM-DD-<slug>.md` | No (per-agent) | None | None |
| `feedback/` | 1 state | `YYYY-MM-DD-<slug>.md` | No | None today | None today (model goal) |
| **`assessments/` (this plan)** | **2 states (active/archived) + supersede** | **`YYYY-MM-DD-<slug>.md`** | **Per-category opt-in** | **Mandatory 8-field** | **Auto-generated per-category + top-level** |

The shape converges with `plans/` on the load-bearing primitives (date prefix, frontmatter, archival) without inheriting the heavyweight gate (assessments don't need an Orianna-equivalent). It diverges from `architecture/` deliberately: architecture docs are reference material with low write-rate; assessments are append-mostly with high write-rate, so naming/lifecycle discipline matters more.

## 9. Migration approach (sketch — owned by follow-up plan)

The follow-up plan `<date>-assessments-migration-execution.md` (Kayn breakdown, isolated worktree) will:

1. Classify every existing file into the 8 categories (mechanical, by content + filename heuristics).
2. Generate target paths (apply naming convention, prepend missing date prefixes, kebab-case).
3. Generate frontmatter blocks (back-fill mandatory fields; `author` from git blame, `date` from filename or git-log first-commit, `category` from classification, `concern` from current location or content scan, `target` from H1 heading, `state: active`).
4. Build the migration as a single PR: 1 commit per category with `git mv` + frontmatter back-fill + per-category INDEX.md.
5. Update cross-references (the architecture-consolidation plan, CLAUDE.md File Structure table, any `architecture/*.md` that links into assessments).
6. Soft-launch — no enforcement hook in the migration PR. Hardening hook (frontmatter required, naming required, category-folder agreement) lands in a separate follow-up after a 2-week observation window.

Migration is NOT in this ADR's commit. This ADR ships only the rules.

## 10. Open questions

- **OQ-1: `plan-fact-checks/` handling.** 376 files is a lot. Do we (a) wholesale move under `reviews/plan-fact-checks/`, (b) archive in bulk under `reviews/plan-fact-checks/archived/2026/`, (c) prune anything older than 30 days? Recommend (a) for the structural move, then a separate grooming plan for retention policy. Defer.
- **OQ-2: Does `qa-artifacts/akali/` get folded into `qa-reports/personal/<session-subdir>/` or stay separate as `artifacts/qa/akali/`?** The artifacts category exists for binaries that pair with reports; tighter coupling argues for the report-subdir model. Azir's parallel QA ADR may pin this — defer until both ADRs are reviewed jointly.
- **OQ-3: `living` cap.** Should we cap the number of `living` assessments per category to prevent scope creep (where everything becomes "living" to dodge archival)? Recommend: no cap, but the per-category INDEX.md surfaces the count, and the dashboard surfaces it for review.
- **OQ-4: Cross-concern (`concern: cross`) — is this a real third value, or do we just always pick one?** Recommend keeping `cross` as a third value for genuinely cross-concern material (e.g. global tooling research that informs both work and personal); empirically rare.
- **OQ-5: Hard-fail vs warn on missing frontmatter.** Future enforcement hook — start as warn, escalate to fail after observation. Out of scope here.
- **OQ-6: Per-category README vs INDEX.md collapse.** Could we have one file per category that does both (purpose + listing)? Decision: keep separate. README is hand-curated purpose; INDEX is generated listing. Mixing them defeats auto-generation.

## 11. Risks

- **Migration churn.** Renaming ~150 files breaks every existing inbound link (commit messages, agent learnings, plan cross-refs). Mitigation: the migration PR includes a `mv-map.json` artifact and a `scripts/assessments/migration-link-fix.sh` that scans `plans/`, `architecture/`, `agents/`, `feedback/` for old paths and rewrites them. Out of this ADR; covered in migration plan.
- **Author drift before enforcement hook lands.** During the soft-launch window, new files will land that don't follow the convention. Mitigation: the agent defs of the highest-write owners (Lux, Skarner, Akali, Lucian, Senna) get a one-line addition in their next routine update pointing to this ADR. The enforcement hook closes the gap permanently after the observation window.
- **`category` boundary disputes.** Authors will occasionally disagree on whether something is `audits/` vs `reviews/` vs `retrospectives/`. Mitigation: per-category README defines the boundary in concrete terms; ambiguous files get tagged `tags: [<other-category>]` in frontmatter to surface in cross-category searches.
- **Auto-generated INDEX.md churn in commits.** Every assessment commit also touches its category INDEX.md (and possibly the top-level INDEX.md). Mitigation: the index-gen script is fast and deterministic; pre-commit hook regenerates only the affected category. Acceptable churn cost.

## 12. Acceptance criteria

This ADR is approved when:

1. Duong reviews the eight-category taxonomy and signs off (or pushes back with named alternatives).
2. The frontmatter contract (8 mandatory + 4 optional fields) is approved or amended.
3. The two-state lifecycle (`active` ↔ `archived` + `superseded`) is approved.
4. The naming convention (`YYYY-MM-DD-<slug>.md` prefix-date) is approved.
5. OQ-1 through OQ-6 either resolved here or explicitly deferred to the migration plan.

Migration execution and enforcement-hook plans are separate and follow this ADR.

## 13. References

- `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` — sibling consolidation effort, deliberately scopes out assessments and defers here.
- `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` — Azir's parallel ADR; owns the content shape inside `qa-reports/`.
- `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` — Karma's tactical Akali fixes; pairs with Azir's structural pivot.
- `architecture/plan-lifecycle.md` — sibling lifecycle doc for plans; this ADR's lifecycle section is the assessments-side counterpart.
- `feedback/` — flat-shape precedent (small enough to stay flat); not a model for assessments scale.
- `CLAUDE.md` File Structure table — must be updated by the migration plan to point at the new shape.

## Tasks

> Authored by Aphelios (D1A inline). User directive at breakdown time pulled migration of existing files into scope (the ADR §2 originally deferred migration to a sibling plan). All tasks below are estimated ≤60 min and carry a `parallel_slice_candidate` field per the slicing doctrine (`yes` = independent + >30m; `no` = serial / short / merge-friction; `wait-bound` = long but waiting-dominated). Branch: `chore/aphelios-assessments-breakdown`. Empirical surface confirmed against the live tree on 2026-04-25: **37 loose root `.md` files** (ADR text says 28; the live count is higher — the migration tasks are sized to the live count) **+ 13 category subdirs** (`advisory/`, `branch-protection/`, `mcp-ecosystem/`, `memory-audits/`, `migration-audits/`, `personal/`, `plan-fact-checks/`, `plan-triage/`, `qa-artifacts/`, `qa-reports/`, `rescued-patches/`, `research/`, `residuals-and-risks/`, `work/`).
>
> Phase gates: A → B → C → D → E. Within each phase, tasks marked `parallel_slice_candidate: yes` may run concurrently. The migration phase (B) is the parallelisation jackpot — 8 disjoint category targets, low merge friction.

### Phase A — Foundation scaffolding (target tree exists, nothing moved yet)

- [ ] **T1** — Create the eight category subdirs (`assessments/research/`, `qa-reports/`, `audits/`, `reviews/`, `retrospectives/`, `runbooks/`, `advisories/`, `artifacts/`) plus their `archived/` and (where applicable) `personal/`/`work/` skeleton subdirs. Use `.gitkeep` files since git does not track empty dirs. estimate_minutes: 15. parallel_slice_candidate: no. Files: `assessments/{research,qa-reports,audits,reviews,retrospectives,runbooks,advisories,artifacts}/.gitkeep`, `assessments/{qa-reports,audits,reviews,retrospectives,runbooks,advisories,artifacts}/{personal,work}/.gitkeep`, `assessments/*/archived/.gitkeep`. DoD: `find assessments -type d -newer <baseline>` shows the 8 categories + their personal/work + archived subdirs; no existing files moved yet.
- [ ] **T2** — Author `assessments/README.md` (one-screen overview: 8 categories with one-line purpose each, naming rule cite, frontmatter contract cite, link to this ADR). Hand-curated per §7. estimate_minutes: 30. parallel_slice_candidate: no. Files: `assessments/README.md`. DoD: file exists, ≤120 lines, links to `plans/approved/personal/2026-04-25-assessments-folder-structure.md`, lists all 8 categories with a one-paragraph purpose taken from §3 of this ADR.
- [ ] **T3** — Author placeholder `assessments/INDEX.md` with the auto-generation contract documented (will be overwritten by `index-gen.sh` in Phase C; this task ships the contract + a hand-written initial roll-up linking each per-category INDEX). estimate_minutes: 25. parallel_slice_candidate: no. Files: `assessments/INDEX.md`. DoD: file exists; lists 8 categories with link to each `<category>/INDEX.md`; carries an `<!-- auto-generated by scripts/assessments/index-gen.sh -->` HTML comment marker so the generator can recognise its own output.
- [ ] **T4** — Author one `<category>/README.md` per category (8 files), each ≤60 lines: purpose statement (verbatim from §3 table), category-boundary tests in concrete terms (per §11 risk-mitigation: "ambiguous file? prefer X if Y, prefer Z if W"), owner-default list, concern-split applicability. estimate_minutes: 60. parallel_slice_candidate: yes. Files: `assessments/{research,qa-reports,audits,reviews,retrospectives,runbooks,advisories,artifacts}/README.md` (8 files). DoD: each README ≤60 lines, purpose statement matches §3, boundary-test section present, owner-default section present, links back to this ADR.

### Phase A gate: target tree exists with READMEs and INDEX scaffolding; no migration started.

### Phase B — Migration of existing material (8 category-targeted moves, parallel-friendly)

Per §9 sketch and the live-tree audit. Each B-task: classify → `git mv` with naming-convention fix → backfill mandatory 8-field frontmatter → update per-category INDEX.md (hand-written roll-up; auto-generator lands in Phase C). Each task touches a disjoint category target — low merge friction. The classification heuristic per file: filename keyword + content scan of H1; ambiguous cases get tagged `tags: [<other-category>]` per §11 mitigation.

- [ ] **T5** — **research/**: Move into `assessments/research/` — `gemini-pro-ecosystem-assessment.md` (rename `2026-04-21-gemini-pro-ecosystem-assessment.md` if dateless; check git-log first-commit for date), `personal-ai-stack.md` (mark `state: living`), `2026-04-12-darkstrawberry-platform-strategy.md`, plus the contents of `research/` and `mcp-ecosystem/` (fold `mcp-ecosystem/*` under `research/` with `tags: [mcp-ecosystem]`). Backfill 8-field frontmatter on each. Author `assessments/research/INDEX.md` hand-roll-up. estimate_minutes: 55. parallel_slice_candidate: yes. Files: `assessments/research/**`, deletions under `assessments/{mcp-ecosystem,research}/` (existing pre-migration locations). DoD: every file under `assessments/research/` has 8-field frontmatter; filename matches `YYYY-MM-DD-<slug>.md` (or is the lone `personal-ai-stack.md` living exception); INDEX.md lists all moved files; `git mv` used (history preserved); old `mcp-ecosystem/` dir empty (or removed).
- [ ] **T6** — **qa-reports/**: `git mv assessments/qa-reports/* assessments/qa-reports/personal/` (assume personal-concern by default; any work-concern reports identified by content scan move to `qa-reports/work/`). Backfill frontmatter on each. **Defer body-shape changes to Azir's parallel ADR** — this task only moves location and adds frontmatter wrapper (date/owner/state/target/concern/category/author/session). Author `assessments/qa-reports/INDEX.md` hand-roll-up. estimate_minutes: 60. parallel_slice_candidate: yes. Files: `assessments/qa-reports/{personal,work}/**`. DoD: zero `.md` files at `assessments/qa-reports/*` direct level (all under `personal/` or `work/`); each file has 8-field frontmatter; binaries (`.png`/`.webm`) move to `assessments/artifacts/qa/<session-subdir>/` per §3 row 8 (handled in T12); INDEX.md present.
- [ ] **T7** — **audits/**: Move loose root files matching audit semantics. Suffix-date renames: `agent-folder-audit-2026-04-20.md` → `2026-04-20-agent-folder-audit.md`; `ai-provider-capacity-expansion-2026-04-21.md` → `2026-04-21-ai-provider-capacity-expansion.md`; `orianna-prompt-audit-2026-04-21.md` → `2026-04-21-orianna-prompt-audit.md`; `orianna-url-host-frequency-2026-04-21.md` → `2026-04-21-orianna-url-host-frequency.md`; `prompt-caching-audit-2026-04-21.md` → `2026-04-21-prompt-caching-audit.md`; `ship-day-azir-secrets-audit-2026-04-21.md` → `2026-04-21-ship-day-azir-secrets-audit.md`. Dateless renames (use git-log first-commit date): `claude-md-signal-noise-audit.md`, `agent-system-assessment.md`. Already-prefixed: `2026-04-17-deploy-script-audit.md`, `2026-04-08-protocol-leftover-audit.md`, `2026-04-08-myapps-snapshot.md`. Fold `memory-audits/*` and `migration-audits/*` (note: audit material — runbook-shaped P-reports route to T9). Concern-classify each. Backfill frontmatter. Author `assessments/audits/INDEX.md`. estimate_minutes: 60. parallel_slice_candidate: yes. Files: `assessments/audits/{personal,work}/**`. DoD: every file has 8-field frontmatter; every filename starts `YYYY-MM-DD-`; old `memory-audits/`, `migration-audits/` dirs empty post-move (except runbook-shaped reports diverted to T9); INDEX.md present.
- [ ] **T8** — **reviews/**: Move root review files (`2026-04-17-pr-120-121-architectural-review.md`, `2026-04-17-pr-120-121-retroactive-review.md`, `2026-04-18-migration-plan-factcheck.md`) into `assessments/reviews/` with concern split. **Wholesale move `plan-fact-checks/*` (377 files) to `reviews/plan-fact-checks/`** per OQ-1 recommendation (a). Do NOT backfill frontmatter on the 377 fact-check files — flag with `tags: [bulk-migrated, frontmatter-pending]` in a single top-level `reviews/plan-fact-checks/README.md` note; deep frontmatter sweep is a separate grooming plan per OQ-1. Backfill frontmatter only on the named root review files. Author `assessments/reviews/INDEX.md`. estimate_minutes: 50. parallel_slice_candidate: yes. Files: `assessments/reviews/**`. DoD: 3 root review files + 377 fact-check files at new locations; root review files have 8-field frontmatter; fact-check bulk has README explanation note; INDEX.md present and lists root review files (does not enumerate the 377 individually).
- [ ] **T9** — **retrospectives/**: Move `2026-04-09-delivery-pipeline-security.md`, `ship-day-deploy-checklist-2026-04-21.md` → `2026-04-21-ship-day-deploy-checklist.md`, `ship-day-azir-option-a-checklist-2026-04-21.md` → `2026-04-21-ship-day-azir-option-a-checklist.md`, contents of `residuals-and-risks/`, plus retrospective-shaped material from `personal/` and `work/` subdirs (content-scan; coordinator-misroute / process-failure post-mortems). Backfill frontmatter. Author `assessments/retrospectives/INDEX.md`. estimate_minutes: 50. parallel_slice_candidate: yes. Files: `assessments/retrospectives/{personal,work}/**`. DoD: each file has 8-field frontmatter; suffix-dates renamed to prefix-dates; INDEX.md present; old `residuals-and-risks/` dir empty.
- [ ] **T10** — **runbooks/**: Move `2026-04-13-dark-strawberry-manual-test-plan.md`, `2026-04-18-migration-dryrun.md`, `2026-04-18-p0-0-preflight.md`, `2026-04-18-p1-filter-report.md`, `2026-04-18-p2-parametrize-report.md`, `2026-04-18-p3-1-push-report.md`, `2026-04-18-p3-2-3-4-5-6-7-report.md`, `2026-04-18-p3-9-smoke-report.md`, `2026-04-18-phase-0-merge-queue.md`, `2026-04-18-migration-acceptance-gates.md`, `2026-04-19-a1-filter-report.md`, `2026-04-21-orianna-gate-smoke.md`, `reviewer-auth-smoke-2026-04-19.md` → `2026-04-19-reviewer-auth-smoke.md` (or per OQ-2 sketch, delete if 901-byte stub is fold-into candidate; default: move + frontmatter). Fold `branch-protection/*`. Search `migration-audits/` for runbook-shaped P-reports per T7 referral. Concern-classify; runbook material is mostly work-concern (mmp migration). Backfill frontmatter. Author `assessments/runbooks/INDEX.md`. estimate_minutes: 60. parallel_slice_candidate: yes. Files: `assessments/runbooks/{personal,work}/**`. DoD: each file has 8-field frontmatter; suffix-dates fixed; INDEX.md present; old `branch-protection/` dir empty.
- [ ] **T11** — **advisories/**: Move `2026-04-13-firebase-storage-cors-investigation.md`, `2026-04-19-portfolio-v0-dv0-asks.md`, `2026-04-19-test-topology.md`, contents of `advisory/` and `plan-triage/`. Concern-classify. Backfill frontmatter. Author `assessments/advisories/INDEX.md`. estimate_minutes: 35. parallel_slice_candidate: yes. Files: `assessments/advisories/{personal,work}/**`. DoD: each file has 8-field frontmatter; INDEX.md present; old `advisory/`, `plan-triage/` dirs empty.
- [ ] **T12** — **artifacts/**: Move binaries — `qa-artifacts/*` becomes `artifacts/qa/<original-subdir>/...`; `rescued-patches/*` becomes `artifacts/patches/...`; any `.png`/`.webm` files mixed into `qa-reports/` (T6 referral) move to `artifacts/qa/<session-subdir>/` and a backreference is added in the originating qa-report's frontmatter `related:` field. Frontmatter is **not** required on binaries (`.png`/`.webm`/etc.); pair each artifact group with a `<group>/README.md` carrying minimal frontmatter (8-field) describing the artifact set. Author `assessments/artifacts/INDEX.md`. estimate_minutes: 45. parallel_slice_candidate: yes. Files: `assessments/artifacts/{qa,patches}/**`. DoD: zero binaries left in `qa-reports/`; old `qa-artifacts/`, `rescued-patches/` dirs empty; each artifact group has a README.md with 8-field frontmatter; INDEX.md present.
- [ ] **T13** — **out-of-taxonomy disposition**: Per §3 footnote — `2026-04-21-system-audit-post-foundational-ADRs.md` is structural enough to candidate for `architecture/` or `plans/implemented/` retrospective. Decide: if H1 + content reads like an architecture reference, move to `architecture/`; if it reads like a post-ship retrospective, move to `assessments/retrospectives/`. Default: route to `assessments/retrospectives/` and tag `tags: [system-audit, candidate-architecture-promotion]` for follow-up. Also handle the lingering `personal/` and `work/` subdirs at `assessments/` root: their per-file content moved in T5–T11 (content-scanned each); confirm dirs are empty and remove. estimate_minutes: 25. parallel_slice_candidate: no. Files: `assessments/retrospectives/.../2026-04-21-system-audit-post-foundational-ADRs.md` (or `architecture/...`); `assessments/personal/`, `assessments/work/` removed. DoD: the system-audit file lives at exactly one new location with frontmatter; the legacy `personal/`, `work/` direct subdirs removed; root-level loose `.md` count is zero (only `README.md` and `INDEX.md` remain).

### Phase B gate: zero loose `.md` files at `assessments/` root (other than `README.md` and `INDEX.md`); zero pre-migration subdirs; every migrated file has 8-field frontmatter (except the 377 plan-fact-checks bulk and binaries); every category has INDEX.md.

### Phase C — Tooling (auto-generation + cross-ref maintenance)

- [ ] **T14** — Author `scripts/assessments/index-gen.sh` (POSIX-portable per Rule 10). Walks each category; for each `.md` parses YAML frontmatter (awk, no python dependency); emits per-category INDEX.md per the §7 contract (Active last-30-days, Active older, Living, Archived link). Idempotent — running it twice produces the same output. Writes a top-level `assessments/INDEX.md` aggregating per-category counts. estimate_minutes: 60. parallel_slice_candidate: no. Files: `scripts/assessments/index-gen.sh`. DoD: script is `set -e` clean; runs from repo root; on a tree with 8 categories produces 9 INDEX.md files (8 per-category + 1 top); diff against hand-written INDEX.md from Phase A/B is empty modulo formatting whitespace; runs in <5s on the post-migration tree.
- [ ] **T15** — Author `scripts/assessments/migration-link-fix.sh` (POSIX). Reads a `mv-map.json` artifact (path: `<old-path>` → `<new-path>` mapping; produced by Phase B as a side artifact and committed alongside). Scans `plans/`, `architecture/`, `agents/`, `feedback/`, `CLAUDE.md`, `assessments/README.md` for old paths and rewrites them. Dry-run mode default; `--apply` flag to write. estimate_minutes: 50. parallel_slice_candidate: no. Files: `scripts/assessments/migration-link-fix.sh`, `assessments/mv-map.json` (the artifact itself is updated incrementally during T5–T13; this task formalises its schema). DoD: script supports `--dry-run` (default) and `--apply`; `--apply` rewrites all old-path references; idempotent on second run.
- [ ] **T16** — Wire `index-gen.sh` into pre-commit hook scope. Add a hook entry that detects `.md` add/move/remove inside any `assessments/<category>/**` and runs `bash scripts/assessments/index-gen.sh --category <affected>` to regenerate just the affected category's INDEX.md. Stage the regenerated INDEX.md into the commit. estimate_minutes: 35. parallel_slice_candidate: no. Files: `scripts/hooks/pre-commit-assessments-index-gen.sh` (new), `.git/hooks` wiring via `scripts/install-hooks.sh` update. DoD: editing/adding a file under `assessments/research/` and committing causes `assessments/research/INDEX.md` to appear in the same commit automatically; hook is idempotent (no-op on commits that don't touch assessments).

### Phase C gate: `bash scripts/assessments/index-gen.sh` runs clean and is wired into pre-commit; `migration-link-fix.sh` exists and dry-run is correct.

### Phase D — Cross-references (CLAUDE.md, architecture/, related plans)

- [ ] **T17** — Update `CLAUDE.md` File Structure table row for `assessments/` to describe the new shape (categories, naming, frontmatter, lifecycle); link this ADR. Per §6 acceptance criterion. estimate_minutes: 20. parallel_slice_candidate: yes. Files: `CLAUDE.md`. DoD: the `assessments/` row in the File Structure table mentions the 8 categories, the `YYYY-MM-DD-<slug>.md` rule, the 8-field frontmatter, and the active/archived lifecycle; links to `plans/approved/personal/2026-04-25-assessments-folder-structure.md`.
- [ ] **T18** — Update `architecture/plan-lifecycle.md` to add an explicit cross-reference: "for the assessments-side counterpart see `plans/approved/personal/2026-04-25-assessments-folder-structure.md` §6 lifecycle." Per §13 References. estimate_minutes: 10. parallel_slice_candidate: yes. Files: `architecture/plan-lifecycle.md`. DoD: a clearly-labelled section or bottom-of-file reference points readers to this ADR's §6 lifecycle.
- [ ] **T19** — Update the architecture-consolidation plan `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` to remove its "assessments deferred — see follow-up plan" placeholder and replace with a closed reference to this ADR. Edit-only (do not move the file out of `approved/`). estimate_minutes: 10. parallel_slice_candidate: yes. Files: `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md`. DoD: the placeholder language is replaced with a concrete reference to this ADR; no semantic change to the consolidation plan's own scope.
- [ ] **T20** — Sweep `agents/<name>/profile.md` and `.claude/agents/<name>.md` for the highest-write owners (Lux, Skarner, Akali, Lucian, Senna) per §11 risk mitigation, adding a single one-line pointer to this ADR in their "where to write assessments" guidance. estimate_minutes: 30. parallel_slice_candidate: yes. Files: `.claude/agents/{lux,skarner,akali,lucian,senna}.md` (and corresponding `agents/<name>/profile.md` if the routine-update marker exists there). DoD: each of the 5 agent defs has a one-line addition pointing to `plans/approved/personal/2026-04-25-assessments-folder-structure.md`; commit message lists each touched agent.

### Phase D gate: every cross-reference identified in the ADR is updated; readers landing on `CLAUDE.md`, `architecture/plan-lifecycle.md`, or the consolidation plan can find this ADR within one hop.

### Phase E — Verification (post-migration sanity, not enforcement)

- [ ] **T21** — Author a verification report at `assessments/audits/personal/2026-04-25-assessments-migration-verification.md` with 8-field frontmatter (eat your own dogfood). Report contains: count-of-files-per-category before/after; orphan check (any file under `assessments/` not matching `<category>/(personal|work|archived)?/**`); frontmatter-validation pass (every non-binary, non-fact-check `.md` has the 8 mandatory fields); naming-validation pass (every non-`README.md`, non-`INDEX.md` file matches `YYYY-MM-DD-<slug>.md`). estimate_minutes: 45. parallel_slice_candidate: no. Files: `assessments/audits/personal/2026-04-25-assessments-migration-verification.md`. DoD: the report itself satisfies the very rules it audits (frontmatter present, prefix-date naming); all 4 validation passes recorded with concrete numbers; any failures listed with file paths so a follow-up task can fix them.
- [ ] **T22** — Open PR for the breakdown branch. PR body summarises the 22-task execution, links to this ADR, and explicitly notes that **enforcement hooks are NOT included** (per §2 scope-out — soft-launch first, observation window, then hardening hook in a separate follow-up). PR body carries `Human-Verified: yes` if Duong reviews live; otherwise PR sits with the structural reviewer for non-AI-attribution-clean comments. estimate_minutes: 25. parallel_slice_candidate: no. Files: PR body only (no repo files). DoD: PR exists, links the ADR, status checks green, includes the verification report from T21 inline or as a quoted excerpt; PR description mentions T17 CLAUDE.md update so reviewer notices the policy change.

### Phase E gate: verification report passes 4-pass validation; PR open and green.

### Slicing summary

| Phase | Tasks | `yes` (parallel) | `no` (serial) | `wait-bound` | Notes |
|-------|-------|------------------|---------------|--------------|-------|
| A     | T1–T4 | T4 only          | T1, T2, T3    | —            | T1 must precede T2/T3/T4; T4 (8 READMEs) is the slice candidate. |
| B     | T5–T13| T5–T12 (8 categories) | T13       | —            | Highest parallelisation payoff — 8 disjoint targets. |
| C     | T14–T16 | —              | T14, T15, T16 | —          | Tooling — small, sequential. |
| D     | T17–T20 | T17, T18, T19, T20 | —        | —            | All four touch disjoint files — fully parallel. |
| E     | T21–T22 | —              | T21, T22      | —            | Verification then PR; serial. |

**Honest estimate (serial)**: ≈ 12 hours wall-clock. **With parallel-slicing applied**: ≈ 4–5 hours (Phase B 8 streams ≈ 60 min concurrent + Phase D 4 streams ≈ 30 min concurrent + serial phases ≈ 3 h).

### Open questions surfaced during breakdown

- **OQ-K1** — The ADR §1 quotes "28 loose `.md` files" at root; the live tree on 2026-04-25 has **37**. Tasks T5–T13 are sized to the live count. Confirm this is acceptable (the ADR's own §9 sketch is per-target-tree, not per-old-count, so the discrepancy is benign — surfacing for transparency).
- **OQ-K2** — `plan-fact-checks/` bulk move (T8): 377 files transit `git mv` in a single commit. Is the pre-commit hook (Rule 14) going to run unit tests on this? T8 may need a `chore: ` prefix (no apps/** touched, so yes per Rule 5 it lands as `chore:`). Confirm the hook tolerates a 377-file rename with no test invocation needed.
- **OQ-K3** — T20 touches 5 agent defs. Per Rule 21 commit-msg-no-ai-coauthor hook, these edits are agent-attribution-free, but reviewers should sanity-check no AI marker leaked. Recommend adding a smoke pass in T21 verification.
- **OQ-K4** — Akali QA report shape (T6) is owned by Azir's parallel ADR. If that ADR ships first, T6 should be re-scoped to also adopt the new content shape; if this ADR ships first, T6 ships only the location move and Azir's ADR's tasks back-fill content shape later. Confirm sequencing with Evelynn.
- **OQ-K5** — `state: living` files (`personal-ai-stack.md` and possibly `gemini-pro-ecosystem-assessment.md`) — should `gemini-pro-ecosystem-assessment.md` also be `living` (it's an evergreen ecosystem reference) or is one-off `active` (it's pinned to the 2026-04-21 ecosystem snapshot)? Default to `active` unless owner (Lux) says otherwise.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (Lux), concrete decision with eight-category taxonomy backed by empirical mapping of all 52 root entries + 14 subdirs, mandatory frontmatter contract, and a deliberately-restrained two-state lifecycle. Open questions are explicitly deferred to migration-execution follow-up per acceptance criterion #5; gating sections (Decision, Scope, Acceptance Criteria) carry no TBDs. Migration churn and enforcement hooks are correctly out-of-scope, keeping this ADR a rules-only ship. Authority for promotion: synthesis ADR §7.5 stamp (commit c4be153b) covering Group B + Duong's hands-off Default-track directive.
