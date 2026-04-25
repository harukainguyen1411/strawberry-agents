---
status: proposed
concern: personal
owner: azir
created: 2026-04-25
tests_required: true
complexity: complex
orianna_gate_version: 2
tags: [architecture, frontend, ui-ux, design, lulu, neeko, seraphine, soraka, akali, plan-artifact, accessibility, rule-amendment]
related:
  - .claude/agents/lulu.md
  - .claude/agents/neeko.md
  - .claude/agents/soraka.md
  - .claude/agents/seraphine.md
  - .claude/agents/akali.md
  - CLAUDE.md
  - architecture/agent-network-v1/agents.md
  - plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md
  - plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md
architecture_impact: rule-add (UI plan-artifact gate); rule-amend (Rule 16 cross-ref); plan-template-amend
---

# Frontend / UI / UX as a first-class plan citizen

## Context

Duong's directive (verbatim): _"Frontend and UI/UX design is currently heavily overlooked and it's also not documented in the process. I don't want this. We also need to prioritize this. The final product should not just be a working one but also a usable one."_

Today the process treats UI/UX as a downstream side effect of implementation. Plans flow idea → Aphelios breakdown → Seraphine impl, with Lulu/Neeko consulted only when the implementer or coordinator happens to remember they exist. There is **no required design-spec artifact** on the plan, **no gate** preventing impl dispatch on UI work without design, and **no codified accessibility floor**. Akali's Rule 16 visual-diff lands at the END (PR open), where a structural design problem is most expensive to fix.

The just-shipped W2 roster (`architecture/agent-network-v1/agents.md`) already has the right people: Lulu (normal-track design advisor, Opus), Neeko (complex-track designer, Opus-high), Soraka (trivial frontend, Sonnet), Seraphine (complex frontend, Sonnet), Akali (QA, Sonnet, Playwright + Figma diff). The fix is structural — make design a required plan artifact and gate implementer dispatch on its presence — not roster expansion.

This ADR is sequenced for the pre-canonical-v1-lock Saturday ship: it modifies the plan template, adds one universal invariant (Rule 22), amends Rule 16's cross-reference, and tunes four agent defs. It does not stand up a design system (out of scope; deferred to a Lulu-owned ADR).

Cross-referenced parallel ADRs at `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` (the §UX Spec feeds Akali's diff target — this plan's D1/D2 must hand off cleanly to that plan's `cite_kind`/`head_sha` contract) and the QA-discipline-hooks tactical patch.

## Decision

### D1 — §UX Spec is a required section on every UI-touching plan

Every plan whose §Tasks include changes under `apps/**/src/**/*.{vue,tsx,jsx,ts,js,css,scss}`, `apps/**/components/**`, `apps/**/pages/**`, `apps/**/routes/**`, or any file Akali's Figma-diff target tracks, MUST include a `## UX Spec` section. The §UX Spec is **authored by Lulu (normal-track) or Neeko (complex-track)** before §Tasks is finalized.

Required §UX Spec subsections (load-bearing — plan-structure linter checks header presence):

- **User flow** — bullet sequence of user actions and resulting screens. Cite the entry route(s).
- **Component states** — for every interactive component touched: `default`, `hover`, `focus`, `active`, `disabled`, `loading`, `error`, `empty`. Optional but recommended: `success`, `partial-data`. Each state names its visual delta and any copy change.
- **Responsive behavior** — breakpoint table (mobile / tablet / desktop minimum) describing layout changes. If the design is desktop-only or mobile-only, declare that explicitly.
- **Accessibility** — keyboard navigation order, screen-reader semantics (ARIA roles, landmarks, labels), color-contrast pairs against tokens, focus-visible behavior, motion-reduce behavior. See D5 for the non-negotiable a11y floor.
- **Figma link** — direct frame URL if a design exists. If no Figma frame, declare `Figma: none — text-spec only` and the plan must include a screenshot or wireframe under `assessments/design/<slug>/` linked from this section.
- **Out of scope** — explicit list of states/screens/flows NOT covered by this plan, to prevent scope drift during impl.

Why a plan section and not a sibling file: same authorship pattern as §Test plan — co-located with §Tasks so Aphelios's breakdown reads design and tasks together; reviewers (Senna/Lucian) see design context inline; Seraphine cannot dispatch on a plan and miss the design. Sibling files invite divergence.

What does NOT need a §UX Spec: plans that touch zero UI surface (backend-only, infra, hooks, agent-defs, scripts, plans about plans). The path-glob check above is the gate. Edge case: a plan that adds a new backend endpoint **consumed by** a UI change in the same plan still needs a §UX Spec for the UI portion — granularity is per-plan, not per-task.

### D2 — Design-spec lifecycle: gate impl dispatch, not breakdown

The §UX Spec lands **before Aphelios breakdown finalizes §Tasks** but **after the §Context and §Decision sections** are drafted. Sequencing rationale: breakdown needs design to know which components, states, and routes to enumerate as tasks; reviewers need design before they can sanity-check the plan. The opposite ordering (breakdown first, design second) produces tasks that don't align to design states and breakdown rework.

**Hard gate (Rule 22, new universal invariant):** No Seraphine or Soraka dispatch may proceed against a plan whose path-glob requires §UX Spec but whose plan body does not contain the section header `## UX Spec`. Enforced by a PreToolUse `Agent` hook (`scripts/hooks/pretooluse-uxspec-gate.sh`) that fires when `subagent_type ∈ {seraphine, soraka}` AND the dispatch description references a plan path under `plans/{proposed,approved,in-progress}/`. The hook reads the plan, runs a header grep + path-glob check on the plan's task files, and blocks dispatch if §UX Spec is missing on a UI-touching plan. Block message names Lulu (normal) or Neeko (complex) as the next dispatch.

This is the analog of Rule 12 (no impl without xfail test) lifted to the design layer: code without a test does not land; UI without a design does not land. The hook scope is intentionally narrow — only Seraphine and Soraka — because they are the two impl agents who can render a UI surface. A backend-impl agent (Aphelios, Karma, Ekko) dispatched against a UI-touching plan does not trip the gate; the plan-structure linter still catches missing §UX Spec at promote-time so the plan cannot reach `approved/` without one.

Bypass path: a `UX-Waiver: <reason>` line in the plan frontmatter is accepted in lieu of §UX Spec when (a) the change is a pure refactor with no visible delta, (b) the change is implementing an already-approved spec from a parent plan and the cross-ref is recorded, or (c) Duong explicitly waives in a `## Decision-Outcome` block. The waiver mirrors Rule 16's `QA-Waiver:` pattern.

### D3 — Design system: scaffold a stub now, defer the build-out

A `architecture/agent-network-v1/design-system.md` doc is **created as a stub in this plan's task set** and **owned by Lulu**. Initial content: design-token taxonomy headings (color, type, spacing, radius, motion, elevation), component-library headings (no entries — referenced as components emerge), accessibility floor (cross-link to D5), and a "How to amend" subsection naming Lulu as owner with Neeko amendment authority for novel patterns.

The build-out (actual token values, component catalogue, type scale numbers) is **out of scope** for this plan and deferred to a Lulu-owned ADR. The stub is load-bearing because §UX Spec authors need a place to point at (`See design-system.md §Tokens`) — without the stub, every §UX Spec reinvents tokens inline and the system never coalesces. With the stub plus Lulu's amendment authority, the doc accumulates real entries every time a §UX Spec introduces or names a token; after 3-5 UI plans it has enough mass for Lulu's follow-up ADR to formalize.

Rationale for stub-now-defer-build: the directive prioritizes shipping the **process**, not the artifact. A premature design system written without real components attached is decorative; a stub that grows organically alongside §UX Spec authorship is structural.

### D4 — Usability gate at QA stage 2 (mid-build), not stage 3 (PR merge)

A "usability check" runs as a **QA stage-2 ritual during implementation**, before PR open. The check is single-question: _can someone other than the implementer use the feature without a tutorial?_ Concretely: Lulu (or Neeko on complex tracks) is dispatched once the impl reaches an interactive surface (route or component renders) and walks the flow as a fresh user, recording (a) friction points, (b) missing affordances, (c) copy ambiguity, (d) state-transition surprises. Output: an inline comment on the impl PR draft (or chat-text return on the impl agent's session) within ~10 minutes; not a full report.

Why stage 2 not stage 3: at PR open Akali's visual-diff is checking pixels against Figma — a different lens. A usability problem (e.g. a button is technically present and pixel-correct but its label is unclear) passes Akali and ships. By stage 2, the impl is malleable and Lulu's friction notes can be addressed in the same PR cycle without a re-review loop. Stage 3 is too late — by then the implementer has psychologically shipped.

Coordinator-driven dispatch, not auto-dispatch: Evelynn fires Lulu for the usability pass when the impl agent reports "interactive surface ready" or when the coordinator reads the impl-agent return text and judges the surface is testable. No hook required; this is a coordinator habit codified in the §Process section of `lulu.md` and a one-line addition to `evelynn/CLAUDE.md`'s impl-dispatch checklist.

Out of scope: a binary gate (PASS/FAIL block on PR merge). Lulu's stage-2 friction notes are advisory; Akali's stage-3 visual-diff remains the binding QA per Rule 16. Conflating the two would either (a) over-empower the advisor (block PRs on subjective copy critiques) or (b) under-empower the QA (treat pixel deltas as advisory). Keep them separate-and-sequential.

### D5 — Accessibility floor (non-negotiable, Lulu-enforced + Akali-detected)

The floor — every UI plan's §UX Spec accessibility subsection MUST attest to:

1. **WCAG 2.2 AA color contrast** — body text 4.5:1, large text 3:1, UI components and graphical objects 3:1. Cite the token pairs.
2. **Keyboard navigation** — every interactive control reachable by Tab; logical tab order; no keyboard traps; visible focus ring on `:focus-visible`.
3. **Semantic HTML first** — `<button>` for actions, `<a href>` for navigation, `<form>` for forms, headings in document order. ARIA only where semantics are insufficient.
4. **ARIA where needed** — labels for icon-only buttons, `aria-live` for async status, `aria-expanded` on disclosure, role attributes only when no native equivalent exists.
5. **Motion-reduce respect** — `prefers-reduced-motion: reduce` disables non-essential animation.
6. **Screen-reader name + role** — every actionable element has both.

Lulu authors and reviews the §UX Spec accessibility subsection. Akali catches regressions at QA stage 3 via Playwright assertions: `getByRole`, focus-order traversal, contrast probe (axe-core via Playwright). This pairs with the parallel QA two-stage ADR — Akali's `cite_kind: verified` tag applies to a11y findings she can ground in DOM (e.g. "missing `aria-label` on button at `<selector>`").

Hard rules added to `lulu.md` and `neeko.md` (§Frontend design role — shared rules already lists "Accessibility is not a feature, it is the floor"; this ADR makes the floor concrete by listing the six items above as a checklist Lulu/Neeko grep against every §UX Spec they author).

Hard rules added to `seraphine.md` and `soraka.md`: refuse to ship a component PR whose interactive controls violate items 2-3-4-6 of the floor regardless of whether §UX Spec covers them. Items 1 and 5 (contrast, motion-reduce) are §UX Spec concerns; impl agents are not expected to derive them.

What does NOT scope into the floor: WCAG AAA, internationalization beyond reading order, prefers-color-scheme support, full keyboard shortcut overlays. Those are escalations for individual plans, not universal floor.

### D6 — Lulu vs Neeko routing (codified split)

Use **Neeko (complex-track, Opus-high)** when ANY of:

- The plan introduces a **new component pattern** not in the design system stub.
- The plan touches **three or more component states** beyond `default`+`hover`+`focus` (e.g. multi-step form with success / error / partial-data / loading-with-skeleton).
- The plan introduces a **novel interaction** (drag-and-drop, multi-select, virtualized list, modal stacking, animation choreography).
- The plan spans **two or more screens** with state continuity between them (e.g. wizard, dashboard with drill-in).
- The plan requires **wireframes or mockups** because no Figma frame exists yet.

Use **Lulu (normal-track, Opus-medium)** when ALL of:

- The change is a **single component variant** (a button gains a destructive style; a card gains a compact density).
- The change is **copy-only** or **token-swap-only** within an existing component.
- The change reuses an **existing component pattern** without new states.
- A Figma frame already exists and the §UX Spec is largely a translation pass.

Tiebreak: when uncertain, dispatch Lulu first; Lulu may escalate to Neeko explicitly via her return text (`recommend_neeko: true` line). Coordinator re-dispatches Neeko on the escalation. This is cheaper than dispatching Neeko upfront for a plan that turns out to be normal-track work.

Codify the split in `lulu.md` (§Process — "When to escalate to Neeko") and `neeko.md` (§Process — "When you're the wrong choice, redirect to Lulu"). This mirrors the Senna ↔ Lucian role-split codification pattern from prior W2 ADRs.

### D7 — PR-body markers for UI/user-flow PRs (mirrors Rule 16's QA-Report)

Every PR opened from a plan whose path-glob required §UX Spec MUST include three new lines in the PR body:

- `Design-Spec: <plan-path-or-figma-link>` — points to the §UX Spec authored by Lulu/Neeko (or to the parent Figma frame if the §UX Spec lives there).
- `Accessibility-Check: pass | deferred-<reason>` — implementer attests the six-floor items are satisfied, or names the deferral reason (e.g. `deferred-akali-stage-3` if the implementer wants Akali to confirm via Playwright).
- `Visual-Diff: <Akali-report-path-or-link> | n/a-no-visual-change | waived-<reason>` — distinct from but compatible with Rule 16's `QA-Report:` line. (`Visual-Diff:` is a subset of `QA-Report:` content and may simply repoint to the same Akali report URL.)

Enforced by `.github/workflows/pr-lint.yml` extension — same harness as the existing `QA-Report:` check; one new job (`pr-frontend-markers`) that scopes to PRs whose changed-file set matches the §UX Spec path-glob from D1. Non-UI PRs exempt by the same path-glob check. A `UX-Waiver:` PR-body line is accepted in lieu of `Design-Spec:` for the bypass cases enumerated in D2.

Rationale: PR reviewers (Senna code-quality, Lucian plan-fidelity) need fast access to design context and a11y attestation. Without these markers, reviewers either (a) skip design context and approve on code-quality alone, or (b) waste cycles spelunking the linked plan to find the §UX Spec. Cheap structural fix; high reviewer-ergonomics gain.

### D8 — Rule 16 cross-reference, NOT replacement

Rule 16 (Akali's Playwright + Figma-diff QA at PR open) is **unchanged**. This ADR adds a sibling rule (Rule 22, see below) and a sibling Akali-input artifact (the §UX Spec, which Akali reads for `head_sha` parity per the parallel QA two-stage ADR). The two together form: design upfront → impl gated on design → usability check mid-build (Lulu) → visual-diff at PR open (Akali, Rule 16) → diagnose-on-FAIL (Senna, parallel ADR).

The Rule 16 amendment text (D4 in the parallel QA two-stage ADR) gains one cross-ref clause: _"Akali's Figma-diff target is the Figma link in the linked plan's §UX Spec; if the plan declares `Figma: none — text-spec only`, the diff target is the wireframe/screenshot under `assessments/design/<slug>/`."_ This is a one-line cross-reference addition handled in the v2 implementation plan downstream of the QA two-stage ADR; this ADR does not duplicate it.

### D9 — New universal invariant: Rule 22

Add to `CLAUDE.md` after Rule 21:

> **22. UI plans require a §UX Spec authored by Lulu or Neeko BEFORE impl dispatch.** Plans whose §Tasks touch UI surface (per the path-glob in `plans/proposed/personal/2026-04-25-frontend-uiux-in-process.md` D1) MUST contain a `## UX Spec` section covering user-flow, component states, responsive behavior, accessibility (per the floor in D5), and a Figma link or local wireframe. Authored by Lulu (normal-track) or Neeko (complex-track) per the routing in D6. Enforced at impl dispatch by the PreToolUse `Agent` hook `scripts/hooks/pretooluse-uxspec-gate.sh` (blocks Seraphine/Soraka dispatch on UI-touching plans missing §UX Spec) and at plan promotion by the plan-structure linter. Bypass: `UX-Waiver: <reason>` in plan frontmatter for refactors with no visible delta, child plans of an already-approved parent spec, or explicit Duong waiver. PR-body markers `Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:` are required on UI/user-flow PRs (per D7); enforced by `.github/workflows/pr-lint.yml`.

This is symmetric to Rule 12 (xfail test before impl) and Rule 16 (Akali QA before UI PR open) — three universal invariants forming the design / test / QA triangle around any UI delivery.

## Tasks

This plan ships as a single PR after Orianna promotion. Reviewers: Senna (code/hook), Lucian (plan-fidelity), and Lulu+Neeko (design-process fidelity — they review their own role definitions). QA-Waiver acceptable: the plan touches no production UI; only agent-defs, hooks, CLAUDE.md, plan template, and a stub doc.

### T1 — Add Rule 22 to CLAUDE.md

- kind: docs
- estimate_minutes: 15
- files: `CLAUDE.md`
- detail: Append Rule 22 verbatim from D9 to the universal-invariants list. Keep numbering consecutive. Do not renumber existing rules. Cross-reference D1's path-glob spec by citing this plan path. Do not edit Rule 16 — that amendment lands via the parallel QA two-stage v2 plan.
- DoD: `grep -c '^22\. \*\*UI plans' CLAUDE.md` returns 1; existing 1-21 numbering intact.

### T2 — Plan template amendment: add §UX Spec to the canonical template

- kind: docs
- estimate_minutes: 30
- files: `architecture/agent-network-v1/taxonomy.md` (plan-template section), `scripts/plan-structure-lint.sh` (if it exists; otherwise note as follow-up)
- detail: Add `## UX Spec` to the plan template after `## Decision` and before `## Tasks`. Include the six required subsection headers from D1 as a comment-block stub: `<!-- UX Spec required iff plan touches: apps/**/src/**/*.{vue,tsx,jsx,ts,js,css,scss}, apps/**/components/**, apps/**/pages/**, apps/**/routes/**. Bypass: UX-Waiver: <reason> in frontmatter. -->`. Plan-structure linter (if present) gains a check: when the plan's task `files:` glob matches the UI path-glob, the §UX Spec header must exist OR `UX-Waiver:` must be present in frontmatter.
- DoD: a fresh plan generated from the template includes the §UX Spec scaffolding; the linter (or a manual grep) flags a UI-path-glob plan without §UX Spec.

### T3 — Implement the impl-dispatch gate hook (Rule 22 enforcement)

- kind: hooks
- estimate_minutes: 90
- files: `scripts/hooks/pretooluse-uxspec-gate.sh` (new), `.claude/settings.json` (wire as PreToolUse on `Agent`)
- detail: POSIX-portable bash. Triggered on PreToolUse when `tool_name == "Agent"` AND `subagent_type ∈ {seraphine, soraka}`. Reads the dispatch description, extracts referenced plan paths matching `plans/(proposed|approved|in-progress)/(work|personal)/.+\.md`. For each plan, reads it, checks: (a) any `files:` glob in §Tasks matches the UI path-glob from D1; (b) if so, the body contains the literal header `## UX Spec` OR the frontmatter contains `UX-Waiver:`. Block (exit 2 with stderr message naming Lulu or Neeko) if (a) is true and (b) is false. Block message includes the plan path, the offending task glob, and the routing hint per D6. xfail test under `tests/hooks/uxspec-gate-xfail.bats` (or equivalent harness) referencing this plan path.
- DoD: hook fires on a synthetic Seraphine dispatch against a UI-touching plan with no §UX Spec; passes on the same plan after a §UX Spec is added; passes on a non-UI plan; passes with a `UX-Waiver:` frontmatter line.

### T4 — Tune `lulu.md`, `neeko.md`, `seraphine.md`, `soraka.md`

- kind: docs
- estimate_minutes: 60
- files: `.claude/agents/lulu.md`, `.claude/agents/neeko.md`, `.claude/agents/seraphine.md`, `.claude/agents/soraka.md`
- detail: (a) Lulu — add §Routing-to-Neeko (D6) and §Accessibility-floor-checklist (D5 six items) and §Stage-2-usability-pass (D4 single-question prompt). (b) Neeko — add §Routing-to-Lulu (D6 inverse) and §Accessibility-floor-checklist (D5). (c) Seraphine + Soraka — add §A11y-floor-refuse (D5 items 2-3-4-6 — refuse to ship violations) and a §Process step "before impl, confirm §UX Spec exists on the linked plan; if missing, fail-loud return to coordinator naming Lulu or Neeko per D6 routing".
- DoD: a manual grep against each agent-def confirms the new sections; `_shared/frontend-design.md` and `_shared/frontend-impl.md` may absorb shared deltas if appropriate (sync via `scripts/sync-shared-rules.sh`).

### T5 — PR-body marker enforcement (`Design-Spec:`, `Accessibility-Check:`, `Visual-Diff:`)

- kind: ci
- estimate_minutes: 60
- files: `.github/workflows/pr-lint.yml`, `scripts/ci/pr-lint-frontend-markers.sh` (new)
- detail: New CI job `pr-frontend-markers`. Scopes via `dorny/paths-filter` or equivalent to PRs whose changed-file set matches the §UX Spec UI path-glob from D1. Greps PR body for the three required markers. Fails on missing marker. Accepts `UX-Waiver:` in lieu of `Design-Spec:`. Updates the PR template (`.github/PULL_REQUEST_TEMPLATE.md`) to include the three lines as scaffolding.
- DoD: a synthetic UI PR opened without the three markers fails the new CI job; the same PR passes after markers added; a non-UI PR is exempt.

### T6 — Design-system stub doc

- kind: docs
- estimate_minutes: 30
- files: `architecture/agent-network-v1/design-system.md` (new)
- detail: Stub structure per D3. Headings: `## Tokens` (subsections: color, type, spacing, radius, motion, elevation — empty lists), `## Components` (empty placeholder), `## Accessibility floor` (cross-link to CLAUDE.md Rule 22 + this plan's D5), `## Amendment authority` (Lulu owns; Neeko amends for novel patterns; cite W2 roster reference). Initial body deliberately minimal.
- DoD: file exists; cross-references resolve; Lulu's agent-def points at it from her §Process.

### T7 — Coordinator-side prompt updates (Evelynn / Sona)

- kind: docs
- estimate_minutes: 20
- files: `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`
- detail: Add to Evelynn's impl-dispatch checklist: "Before dispatching Seraphine or Soraka against a UI-touching plan, confirm §UX Spec exists or `UX-Waiver:` present. If missing, dispatch Lulu (normal) or Neeko (complex) per D6." Sona inherits the same — work-concern UI work flows through Sona dispatch and the Rule 22 gate fires identically. Add to both: "After impl agent reports interactive surface ready, dispatch Lulu for the stage-2 usability pass (D4) before requesting Akali for stage-3 visual-diff." This is prompt-layer; no hook.
- DoD: both coordinator CLAUDE.md files contain the new bullets; they survive `/end-session` memory refresh without drift.

## Test plan

Per Rule 12 every implementation commit lands behind an xfail-first commit on the same branch. Tests this plan needs:

1. **CLAUDE.md Rule 22 grep test** — `tests/invariants/rule-22-uxspec.sh` asserts `grep -c '^22\. \*\*UI plans' CLAUDE.md` returns 1. xfail commit before T1.
2. **Plan-template grep test** — `tests/invariants/plan-template-uxspec.sh` asserts the canonical plan template scaffolding includes the §UX Spec header and the path-glob comment. xfail commit before T2.
3. **Hook integration test** — `tests/hooks/uxspec-gate-xfail.bats` (or equivalent). Three cases: (a) synthetic Seraphine dispatch on a UI-touching plan missing §UX Spec → block exit 2; (b) same plan with §UX Spec → pass; (c) `UX-Waiver:` frontmatter → pass; (d) non-UI plan → pass. xfail commit before T3.
4. **Agent-def grep tests** — `tests/invariants/lulu-routing.sh`, `neeko-routing.sh`, `seraphine-a11y-refuse.sh`, `soraka-a11y-refuse.sh` assert the new sections exist. xfail commit before T4.
5. **PR-lint integration** — synthetic PR fixture under `tests/ci/pr-frontend-markers/` with three sub-fixtures: missing markers (fail), present markers (pass), `UX-Waiver:` substituting `Design-Spec:` (pass). xfail commit before T5.
6. **Design-system stub presence** — `tests/invariants/design-system-stub.sh` asserts file exists with the four required headings. xfail commit before T6.
7. **Coordinator prompt grep tests** — assert the two new bullets exist in Evelynn's and Sona's CLAUDE.md. xfail commit before T7.

QA-Waiver: yes — this plan touches no production UI surface (it touches agent-defs, hooks, CLAUDE.md, plan template, stub doc, CI workflow). Akali Playwright run is unnecessary; Lucian plan-fidelity review is binding instead.

Out of scope for the test plan: validating that `lulu.md`'s Stage-2 usability pass actually catches usability bugs (that's an empirical validation over 3-5 UI PRs post-merge); validating the design-system stub's amendment authority survives Lulu's first proper ADR (downstream); validating that Seraphine and Soraka actually refuse a11y-floor violations in practice (PR-review observation over time, not pre-commit testable).

## Open Questions

- **OQ-1.** Should §UX Spec be required at plan **promotion** time (Orianna gate) in addition to **dispatch** time (Rule 22 hook)? D2 prescribes dispatch-time enforcement only. Adding promotion-time enforcement is a one-line addition to the plan-structure linter — cheap. **Recommend:** YES, add to T2's linter scope. This catches plans that authors mark `complexity: standard` and promote without design, before any impl agent is even dispatched.

- **OQ-2.** Is a `UX-Waiver:` allowed for `complexity: complex` plans, or restricted to `standard`/`trivial`? Complex plans by definition span multi-state flows or novel interactions per D6 — they should always have design. **Recommend:** restrict `UX-Waiver:` to `complexity: standard | trivial`; complex plans MUST have §UX Spec or be downgraded.

- **OQ-3.** Does the stage-2 usability pass apply uniformly across personal + work concerns? Akali's Rule 16 amendment (parallel ADR) handles Senna concern-routing for diagnosis. Lulu and Neeko don't currently have concern-split — they advise both. **Recommend:** YES uniform; Lulu/Neeko are concern-agnostic at the design layer; the impl agent's concern routes the eventual PR review path, which is unaffected by this ADR.

- **OQ-4.** Should the design-system stub include initial token values cribbed from existing `apps/**` styles, or stay genuinely empty until the first §UX Spec adds entries? **Recommend:** stay empty initially; the Lulu follow-up ADR cribs values from existing styles when she scopes the build-out. Pre-cribbing risks codifying drift before audit.

- **OQ-5.** Path-glob accuracy: is the D1 glob (`apps/**/src/**/*.{vue,tsx,jsx,ts,js,css,scss}` etc.) wide enough to catch all UI surface? Edge cases: `.html` templates, `.svg` icons, Tailwind config, theme files. **Recommend:** v1 ships D1's glob; the hook logs every dispatch decision (block / pass / why) and we widen the glob in v2 if a UI PR slips past. False-negatives cost a missed §UX Spec; false-positives cost an unnecessary `UX-Waiver:`.

- **OQ-6.** Does `Visual-Diff:` PR-body marker duplicate Rule 16's `QA-Report:`? D7 names them distinct but compatible. **Recommend:** keep distinct headers (D7 cleanly orthogonal to QA), but allow them to point at the same URL — the redundancy is cheap and the marker disambiguation aids reviewers scanning for design vs QA evidence.

- **OQ-7.** Should the §UX Spec accessibility subsection require an automated axe-core run from Akali (stage 3) before PR merge, or stay attestation-only? **Recommend:** attestation-only for v1; promote to enforced axe-core probe in a follow-up after Akali's stage-3 Playwright is stable. Accessibility automation is fragile and gating on it now risks PR-merge friction before the discipline is established.

## References

- `.claude/agents/lulu.md` (normal-track design advisor; gains Neeko-routing + a11y-floor + stage-2 usability sections)
- `.claude/agents/neeko.md` (complex-track designer; gains Lulu-routing-back + a11y-floor sections)
- `.claude/agents/seraphine.md` (complex frontend impl; gains a11y-floor-refuse + §UX-Spec-required pre-impl check)
- `.claude/agents/soraka.md` (trivial frontend impl; same additions as Seraphine)
- `.claude/agents/akali.md` (QA observer; unchanged here, but consumes §UX Spec's Figma link as her diff target via parallel ADR)
- `CLAUDE.md` Rule 16 (Akali QA at PR open — unchanged here; cross-ref amendment lands in parallel QA two-stage v2)
- `CLAUDE.md` Rule 12 (xfail-first — structural analog for design layer)
- `architecture/agent-network-v1/agents.md` (W2 roster — Lulu/Neeko/Seraphine/Soraka/Akali pairings)
- `architecture/agent-network-v1/taxonomy.md` (plan template — gains §UX Spec scaffolding in T2)
- `plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md` (parallel — §UX Spec feeds Akali's `head_sha` and Figma-diff target; D5 a11y floor pairs with Akali's `cite_kind: verified` a11y findings)
- `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` (parallel — tactical Akali patch; cross-ref to ensure §UX Spec consumption is captured in Akali's report contract)
