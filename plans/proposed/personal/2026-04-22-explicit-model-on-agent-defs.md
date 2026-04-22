---
title: Explicit `model:` on every agent definition — retire inheritance
status: approved
owner: karma
date: 2026-04-22
created: 2026-04-22
concern: personal
complexity: quick
orianna_gate_version: 2
tests_required: true
tags: [agents, frontmatter, governance, claude-md-rule-9]
---

# Context

Agent definitions under `.claude/agents/*.md` that are intended to run on Opus currently OMIT the `model:` frontmatter field on the assumption that spawns will inherit the session's default model (Opus 4.7 1M). That assumption is the convention codified in the pair-taxonomy ADR at `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:85` ("Opus agents: omit `model:` from frontmatter") and permitted by `CLAUDE.md:63` ("Omitting `model:` is permitted and means the agent inherits the session's default model at spawn time"). <!-- orianna: ok -->

Field experience contradicts that assumption. Observed: Opus-intended subagents spawned from a coordinator running on the 1M Sonnet variant have inherited Sonnet and produced degraded planning output (e.g. Aphelios shallow-preambled and was killed mid-"let me start by reading files in parallel" in this session). Inheritance is not reliable enough to be a default — it is a footgun.

The fix is mechanical and single-domain: every agent definition declares `model:` explicitly. Opus-tier agents get `model: opus`. Sonnet-tier agents already do this; a small number still need it. `CLAUDE.md` Rule 9 wording tightens from SHOULD to MUST. Taxonomy ADR §D1.1a is superseded on this single point and gets a revision-log entry acknowledging the reversal. No schema changes, no new external integrations, single top-level domain (`.claude/agents/` + one CLAUDE.md line) — quick lane. <!-- orianna: ok -->

---

## Authoritative classification (derived 2026-04-22)

Source: `ls .claude/agents/*.md .claude/_script-only-agents/*.md` + pair-taxonomy ADR §D1 matrix (`plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:42-61`). <!-- orianna: ok -->

### Opus tier — MUST declare `model: opus`

| Agent | File | Current | Matrix anchor |
|-------|------|---------|---------------|
| Aphelios | `.claude/agents/aphelios.md` | missing | §D1 row 2 (complex breakdown, Opus-high) |
| Azir | `.claude/agents/azir.md` | missing | §D1 row 1 (normal architect, Opus-high) |
| Caitlyn | `.claude/agents/caitlyn.md` | missing | §D1 row 3 (normal test-plan, Opus-medium) |
| Camille | `.claude/agents/camille.md` | missing | §D1 row 17 (single-lane git/security, Opus-medium) |
| Evelynn | `.claude/agents/evelynn.md` | missing | §D1 row 0 (coordinator personal, Opus-medium) |
| Heimerdinger | `.claude/agents/heimerdinger.md` | missing | §D1 row 9 (DevOps advice, Opus-medium) |
| Karma | `.claude/agents/karma.md` | missing | §D13.1 (quick-planner, Opus-medium) |
| Kayn | `.claude/agents/kayn.md` | missing | §D1 row 2 (normal breakdown, Opus-medium) |
| Lucian | `.claude/agents/lucian.md` | missing | §D1 row 12 (PR plan fidelity, Opus-medium) |
| Lulu | `.claude/agents/lulu.md` | missing | §D1 row 6 (normal frontend-design, Opus-medium) |
| Lux | `.claude/agents/lux.md` | missing | §D1 row 8 (complex AI-specialist, Opus-high) |
| Neeko | `.claude/agents/neeko.md` | missing | §D1 row 6 (complex frontend-design, Opus-high) |
| Senna | `.claude/agents/senna.md` | missing | §D1 row 11 (PR code/security, Opus-high) |
| Sona | `.claude/agents/sona.md` | missing | §D1 row 0 (coordinator work, Opus-medium) |
| Swain | `.claude/agents/swain.md` | missing | §D1 row 1 (complex architect, Opus-xhigh) |
| Xayah | `.claude/agents/xayah.md` | missing | §D1 row 3 (complex test-plan, Opus-high) |
| Orianna | `.claude/_script-only-agents/orianna.md` | already `model: opus` | §D1 row 13 (single-lane, pinned) |

### Sonnet tier — already declare `model: sonnet` (no edits needed)

Akali, Ekko, Jayce, Lissandra, Rakan, Seraphine, Skarner, Soraka, Syndra, Talon, Vi, Viktor, Yuumi. Verified via `grep -H "^model:" .claude/agents/*.md` on 2026-04-22.

### Edge-case resolutions

- **Lissandra** — `model: sonnet` already set (`.claude/agents/lissandra.md:2`). Role is pre-compact memory consolidator; Sonnet-medium is correct per existing definition. No change. <!-- orianna: ok -->
- **Orianna** — `model: opus` already set (`.claude/_script-only-agents/orianna.md:4`) with an explicit "model pinned so she stays on Opus regardless of caller context" justification in her description. Script-only, not spawned via Agent tool; CLAUDE.md warns against new Haiku agents but Orianna is Opus (compliant). No change. <!-- orianna: ok -->
- **Skarner, Yuumi** — `model: sonnet` already set. Sonnet-low minions per §D1 rows 15–16. No change.
- **Camille** — missing `model:`; single-lane git/security advisor at Opus-medium per §D1 row 17. Needs `model: opus`.

---

## `CLAUDE.md` Rule 9 — wording change

Current text at `CLAUDE.md:63`:

> every `.claude/agents/<name>.md` SHOULD declare a `model:` frontmatter field … Omitting `model:` is permitted and means the agent inherits the session's default model at spawn time. <!-- orianna: ok -->

New text (tighten SHOULD → MUST; remove inheritance permission):

> every `.claude/agents/<name>.md` MUST declare a `model:` frontmatter field (`opus` for planners/coordinators/deep-reasoning specialists, `sonnet` for executors — short aliases, never pinned version IDs). Inheritance is prohibited: observed silent Sonnet-on-Opus-agent spawns produced degraded planning output (see `plans/proposed/personal/2026-04-22-explicit-model-on-agent-defs.md`). Haiku is retired; do not introduce new Haiku agents. <!-- orianna: ok -->

This reverses the taxonomy ADR's §D1.1a recommendation for Opus agents specifically. §D1.1a should get a revision-log entry (not a rewrite — the ADR is implemented and frozen; future enforcement uses Rule 9 as the authoritative text).

---

## Tasks

All tasks are single-domain edits to `.claude/agents/*.md` plus the Rule 9 line. Each task is a small, reviewable batch. <!-- orianna: ok -->

- **T1. Add `model: opus` to planner/coordinator batch (8 files).** kind: edit. estimate_minutes: 10. Files: `.claude/agents/aphelios.md`, `.claude/agents/azir.md`, `.claude/agents/swain.md`, `.claude/agents/kayn.md`, `.claude/agents/lux.md`, `.claude/agents/karma.md`, `.claude/agents/evelynn.md`, `.claude/agents/sona.md`. Detail: insert `model: opus` as the first or second frontmatter field (convention: above `effort:`), preserving existing field order otherwise. Do not touch `effort:`, `tier:`, `role_slot:`, `concern:`, or any other field. DoD: `grep -L "^model:" <files>` returns empty; all eight files still parse as valid YAML frontmatter; pre-commit hook passes.

- **T2. Add `model: opus` to review/QA-plan batch (4 files).** kind: edit. estimate_minutes: 6. Files: `.claude/agents/senna.md`, `.claude/agents/lucian.md`, `.claude/agents/caitlyn.md`, `.claude/agents/xayah.md`. Detail: same insertion convention as T1. DoD: `grep -L "^model:" <files>` returns empty; pair-mate symmetry still holds (Caitlyn ↔ Xayah tier fields unchanged).

- **T3. Add `model: opus` to single-lane remaining batch (4 files).** kind: edit. estimate_minutes: 6. Files: `.claude/agents/heimerdinger.md`, `.claude/agents/camille.md`, `.claude/agents/lulu.md`, `.claude/agents/neeko.md`. Detail: same convention. DoD: `grep -L "^model:" <files>` returns empty; pair-mate symmetry check for Lulu ↔ Neeko unaffected.

- **T4. Tighten `CLAUDE.md` Rule 9 wording.** kind: edit. estimate_minutes: 5. Files: `CLAUDE.md` (line 63 region). Detail: replace the Rule 9 paragraph with the MUST-wording drafted in the "CLAUDE.md Rule 9" section above. Add a one-line revision-log entry at the bottom of `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md` noting the reversal ("2026-04-22 — §D1.1a Opus-omit convention superseded by CLAUDE.md Rule 9 MUST-declare; see `plans/proposed/personal/2026-04-22-explicit-model-on-agent-defs.md`"). DoD: `grep -n "MUST declare" CLAUDE.md` returns line 63 region; taxonomy ADR has the revision-log entry appended. <!-- orianna: ok -->

- **T5. Verification sweep.** kind: verify. estimate_minutes: 5. Files: `.claude/agents/*.md`, `.claude/_script-only-agents/*.md`. Detail: run `for f in .claude/agents/*.md .claude/_script-only-agents/*.md; do grep -q "^model:" "$f" || echo "MISSING: $f"; done` and confirm empty output. Verify no file declares `model: haiku` or a pinned ID like `model: opus-4-7` / `model: sonnet-4-6`. DoD: no MISSING lines; no pinned IDs; short report posted to the PR body. <!-- orianna: ok -->

No shared-includes under `.claude/agents/_shared/` are edited — they do not carry `model:` and the convention lives in per-agent frontmatter by design (§D4.2). <!-- orianna: ok -->

---

## Test plan

Invariants protected:

1. **Every agent definition declares `model:`.** Grep-verifiable (T5).
2. **Opus-intended agents actually spawn on Opus.** Spawn-test.
3. **Sonnet-intended agents still spawn on Sonnet (no accidental promotions).** Spawn-test.

Test steps (post-merge, before promoting plan to `implemented/`): <!-- orianna: ok -->

- **TP1. Static sweep.** Run the T5 grep; confirm zero missing-`model:` output across both agent dirs. Confirm no pinned version IDs (`grep -nE "^model: (opus|sonnet)-[0-9]" .claude/agents/*.md .claude/_script-only-agents/*.md` returns empty).
- **TP2. Opus spawn check.** Duong invokes one opus-tier subagent (e.g. Azir with a trivial "what model are you running on?" task). Agent reports its model in the closeout message. Expected: Opus 4.7 (or current session opus tier). Recorded in `assessments/` spawn-test note or in the PR body. <!-- orianna: ok -->
- **TP3. Sonnet spawn check.** Same flow for one sonnet-tier subagent (e.g. Talon or Jayce). Expected: Sonnet 4.6. Recorded alongside TP2.
- **TP4. Rule 9 hook alignment (optional, non-blocking).** If a future pre-commit hook enforces §D4.3a check #3, confirm it does not regress on this change. No hook update is in scope for this plan — flag for follow-up.

Failure modes and rollback: if TP2 or TP3 shows a wrong model, the explicit declaration did not take effect — first suspect is agent-definition cache. Clear cache / restart harness and re-test. If the declaration is genuinely ignored by the loader, revert the batch and open an upstream Claude Code issue; inheritance reliability becomes the new problem but is out of scope here.

---

## Orianna anchors

Every load-bearing claim in this plan has a grep-able anchor. Listed with file + line:

- Rule 9 current wording (SHOULD, inheritance permitted): `CLAUDE.md:63`.
- Taxonomy ADR §D1.1a Opus-omit rule (being reversed): `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:81`, `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:85`. <!-- orianna: ok -->
- Taxonomy ADR §D1 matrix (tier assignments for every agent listed in the classification table): `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:42-61`. <!-- orianna: ok -->
- Taxonomy ADR §D13.1 (quick-lane roster for Karma + Talon): `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:440-444`. <!-- orianna: ok -->
- Orianna already declares `model: opus` with explicit pinning rationale: `.claude/_script-only-agents/orianna.md:4` and description text at `.claude/_script-only-agents/orianna.md:8`. <!-- orianna: ok -->
- Lissandra, Skarner, Yuumi already declare `model: sonnet`: `.claude/agents/lissandra.md:2`, `.claude/agents/skarner.md:2`, `.claude/agents/yuumi.md:2`. <!-- orianna: ok -->
- Sona missing `model:` (first-class coordinator per §D1 row 0 / Q8 resolution): `.claude/agents/sona.md:1-6` (frontmatter block with `name:`, `effort:`, `description:` but no `model:`). <!-- orianna: ok -->
- Evelynn missing `model:` (coordinator personal per §D1 row 0): `.claude/agents/evelynn.md:1-6`. <!-- orianna: ok -->
- Camille missing `model:` (single-lane Opus-medium per §D1 row 17): `.claude/agents/camille.md:1-6`. <!-- orianna: ok -->
- Pair-mate symmetry hook (Caitlyn ↔ Xayah, Lulu ↔ Neeko) specified in: `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md:285`. <!-- orianna: ok -->
- Full missing-`model:` file list verified via: `grep -L "^model:" .claude/agents/*.md .claude/_script-only-agents/*.md` run at plan-authoring time (2026-04-22) — returned the 16 files enumerated in the classification table.

---

## Open questions

- None blocking. One deferral: whether to update the pre-commit hook in §D4.3a check #3 (which currently treats `model: opus` as a "redundant, warning" violation) to invert its semantics — now `model: opus` is required, not redundant. That hook is not yet implemented per scan of `scripts/hooks/`; flagging for whoever implements it. Not in scope for this plan. <!-- orianna: ok -->

## References

- `CLAUDE.md` — Rule 9.
- `plans/pre-orianna/implemented/2026-04-20-agent-pair-taxonomy.md` — §D1 matrix, §D1.1a model convention, §D4.3a hook checks, §D13 quick-lane roster.
- `.claude/agents/_shared/` — 10 shared-includes files (unchanged by this plan). <!-- orianna: ok -->
