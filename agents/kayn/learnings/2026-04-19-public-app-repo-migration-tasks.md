# Kayn session learnings — 2026-04-19 public-app-repo migration task breakdown

## Context

Took Azir's approved migration ADR (`plans/approved/2026-04-19-public-app-repo-migration.md`) and produced an executable `P<phase>.<step>`-keyed task breakdown at `plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md`.

## Mid-session scope change

Evelynn dispatched a scope change after the initial breakdown was drafted: Phase 2 shifts from a sed-rewrite of the old slug to **parametrize** every runtime slug reference so future renames are a single env-var change.

- P2.2 (original sed-rewrite) retired.
- Six new parametrization tasks P2.P1-P2.P6 by file-type category (runtime TS, workflows, shell, prompts, discord-relay, docs).
- New P2.Z regression-guard hook (`scripts/hooks/check-no-hardcoded-slugs.sh`) with allowlist file + CI wiring.
- Owner for parametrization shifted to Viktor (refactoring specialty); Ekko retains P2.1 (grep + categorize), P2.3 (secondary sweep), P2.4 (build verify), P2.5 (branch-protection template).
- Dispatch spine updated: P2.1 → fan out Window B → P2.Z → serial P2.3 → P2.4 → P2.5. Two owner handoffs within one phase — explicit handoff note added.
- Clock schedule adjusted; three parallel windows renamed to A/B/C/D (B is new — Phase 2 fan-out; original B becomes C, C becomes D).

## What shaped the breakdown

- **Team override:** Evelynn reassigned Caitlyn (originally Phase 3 + 5 owner in ADR §10) to author an acceptance-gate checklist in parallel; Viktor takes Phases 3 + 5 instead. Ekko keeps Phases 0-2 + 4. Noted explicitly in the "Team composition" section so the ADR-vs-tasks diff is traceable.
- **TDD skipped:** per Duong decision (confirmed via Evelynn). Each task names the actual Caitlyn gate IDs (`P0-G1`, `M-G14`, etc.) from `assessments/2026-04-18-migration-acceptance-gates.md` (57 gates, committed at beb0902). Initially drafted with placeholder gate names + fallback to ADR §9 — swapped in real IDs on a second pass once I found the committed checklist.
- **Squash-only history:** ADR §5.1 default. No path-filter branch present in tasks; simpler P1 flow.
- **bee-worker public:** ADR §8 decision 6 — explicit "except bee-worker" note in P1.3.
- **One-time admin-merge allowed in P0.2:** gated on D10 Duong sign-off if CI minutes still 0. Flagged in task text + dispatch table.
- **harukainguyen1411 ownership:** every reference uses the correct slug; §9 item 4 is de facto satisfied by preflight step D1.

## Structural choices

- 27 numbered tasks across 6 phases + 10 Duong-blockers as a summary table.
- Each task has: ID, title, owner, inputs, outputs, acceptance gate, rollback-point row ref in ADR §6.3, blockers, Duong-in-loop flag.
- Dispatch section uses: (a) ASCII critical-path spine, (b) three named parallel windows (A/B/C) with participants, (c) owner-concurrent clock table, (d) "hard serial points" callouts so Evelynn can see what *can't* fan out.
- Caitlyn-gate cross-reference table at the end so this file can be search-replaced once Caitlyn's checklist lands.

## Gotchas I noticed while breaking down the ADR

- **R15 is a Phase 3 blocker I split into its own task (P2.5).** ADR §4.4 step 4 says "fix `.github/branch-protection.json` in strawberry-app" but the template has to be fixed *before* the push so it's part of the initial state. Moved to late Phase 2 so it ships with the first push.
- **`apps/private-apps/bee-worker` exception.** ADR §4.2 step 4b would delete `apps/private-apps/` wholesale; the §8 decision 6 override means Ekko has to selectively preserve the subdir. Called out explicitly in P1.3 so it's not missed.
- **ADR §6.1 secret-provisioning via `gh secret get` doesn't work** (the note at §4.4 step 2 acknowledges this). P3.2 flags this as a value-pasting step for Duong rather than a pipe-through.
- **PAT re-issue (P3.3) must not read decrypted token into agent context** (Rule 6). Documented as "never logged" + child-process only.
- **Phase 6 is 7 days after P3.9**, not 7 days after P3.8. Staging green isn't enough — the stability window starts from the first green *prod* deploy.

## What I'd revisit

- Once Caitlyn's `assessments/2026-04-18-migration-acceptance-gates.md` lands, the fallback-to-§9 table at the bottom becomes stale — do a follow-up pass to swap placeholder gate names for real IDs.
- If P0.2's admin-merge path is taken, the "only sanctioned admin merge" clause should be re-checked in P3.8 to make sure we're not using it twice.
- P3.9 is written for "any app" prod deploy. If a specific app is chosen as the canary (myapps? landing?), the task becomes more verifiable — Evelynn may tighten this at dispatch time.

## Handoff state

Task file landed at `plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md`. Ekko + Viktor can dispatch from it; Duong's 10 blockers (D1-D10) are enumerated up front.
