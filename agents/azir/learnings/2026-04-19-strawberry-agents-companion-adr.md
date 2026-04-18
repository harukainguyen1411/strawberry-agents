# Azir session — strawberry-agents companion ADR

## Task
Draft a companion ADR to `plans/approved/2026-04-19-public-app-repo-migration.md` covering the second split: the agent-infra half of `Duongntd/strawberry` moves to a new private repo `harukainguyen1411/strawberry-agents`. Three-repo end state (strawberry-agents private, strawberry-app public, Duongntd/strawberry archive).

## Output
- `plans/proposed/2026-04-19-strawberry-agents-companion-migration.md`
- Commit: `chore: azir — companion ADR for strawberry-agents migration`

## Mid-flight name change
Initial brief said `harukainguyen1411/dark-strawberry`. Coordinator amended mid-session to `harukainguyen1411/strawberry-agents` — rationale: dark-strawberry is the product brand, strawberry-agents fits the `strawberry-*` repo naming convention alongside strawberry-app. Global substitutions applied; no residual references to dark-strawberry in the ADR.

## Structure delivered
- §1 context + three-repo end-state table
- §2 scope — written as the **complement** of app plan §2.3 (private side) plus symmetric §2.3 dual-tracked
- §3 risk register with `R-agents-1` through `R-agents-8` numbering to avoid collision with app-plan R1-R15
- §4 execution — Phases A1-A6. Piggyback question answered: **separate scratch clone**, not shared. Both derive from same base SHA.
- §5 cross-repo convention amendments (three-repo not two)
- §6 D1-D10 open decisions for Duong in a single-pass confirm table
- §7 acceptance criteria (12 bullets) + T+90 archive milestone
- §7.3 minimal private-infra branch protection profile (no force-push, no deletion, no PR requirement)

## Key design decisions
1. **History strategy: preserve via `git filter-repo --invert-paths`**, not squash (asymmetric with app-plan which squashes). Agent memory files cite SHAs; `--invert-paths` preserves most of them. Ones that do rewrite (commits touching both public and private paths) resolve against the `Duongntd/strawberry` archive.
2. **90-day archive window** (not 7) for `Duongntd/strawberry`. App-plan's 7-day window is for code-deploy stability; agent-memory SHA lookups need a longer tail.
3. **Separate scratch clones per migration** — `/tmp/strawberry-app-filter.git` and `/tmp/strawberry-agents-filter.git`. Concurrent filter-repo on one bare clone is unsafe.
4. **Minimal private-infra branch protection** (§7.3) — no force-push, no deletion, zero review requirement, optional `plan-frontmatter-lint` status check. Plans commit direct to main per CLAUDE.md rule 4.
5. **No new hooks or workflows required at cutover.** `plan-frontmatter-lint` is deferred as D10.
6. **Working-tree swap (Phase A4):** rename local `~/Documents/Personal/strawberry/` to `-archive-local/`, fresh-clone into `strawberry-agents/`. Copy age-key across since it's gitignored.

## Open-decision approach
Listed all 8 brief assumptions as D1-D8, added D9 (branch protection flavor) and D10 (`plan-frontmatter-lint` scope). Table format with Azir's default + confirm checkbox so Duong can resolve in one pass. Flagged D5 (7 vs. 90 days) as the only place Azir disagreed with the brief.

## Disagreements with the brief
- D5 archive window: brief said 7 days matching the app plan; Azir pushed to 90 days because the two archives serve different purposes (code stability vs. SHA-reference tail).
- Everything else in the brief's assumptions accepted.

## Symmetry check
§2 written as the **complement** of app plan §2.3 so the two plans are collectively exhaustive. Acceptance criterion #11 enforces this: "No orphan paths." Dual-tracked items enumerated in §2.3 of this plan to match app plan §2.2/§2.4 dual-tracked rows (secrets-guard, install-hooks, .gitignore, decrypt.sh, commit-prefix linter).

## Handoff
- Plan in `plans/proposed/` — not promoted. Duong reviews + promotes.
- Once D1-D10 captured, Kayn breaks this into tasks (cross-referenced with existing strawberry-app breakdown).
- Ekko/Caitlyn execute: Ekko owns A1/A2/A4, Caitlyn owns A3/A5. Cannot start until strawberry-app Phase 0 completes (shared base SHA).
