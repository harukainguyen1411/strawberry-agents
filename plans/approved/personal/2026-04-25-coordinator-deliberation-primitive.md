---
status: approved
concern: personal
owner: karma
created: 2026-04-25
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [coordinator, prompt-architecture, deliberation, evelynn, sona, briefing-altitude, gate-bypass]
related:
  - .claude/agents/evelynn.md
  - .claude/agents/sona.md
  - .claude/agents/_shared/quick-planner.md
  - agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md
  - agents/memory/duong.md
---

# Coordinator deliberation primitive — intent block + altitude selection (shared include)

## 1. Context

Diagnosis (from Lux this session): both coordinators (Evelynn, Sona) execute Duong's instructions literally and reach for tools before reasoning about underlying intent. The current agent defs (`.claude/agents/evelynn.md`, `.claude/agents/sona.md`) are 32 lines each — a frontmatter, an `initialPrompt` startup chain, and one sentence pointing to `agents/<name>/CLAUDE.md`. Nothing in the def, and nothing in the protocol files, installs a *structural pause* between instruction and first tool call. This is a prompt-architecture hole, not a content problem. Three failure modes from this session evidence it: (a) gate-bypass on env-hygiene commit `240bd394` (reverted at `bcbe4a3b`) — surgical-feeling diff was self-licensed past Karma → Talon → Senna+Lucian and silently broke the inbox watcher; (b) briefing-altitude swings — lazy one-liners ("revert landed") on one turn, verbose SHA dumps on the next; (c) filing-question reflex — when Duong asked to install critical thinking, the coordinator's first instinct was to ask Lux *where to put the words*, not to ask what would shift behavior.

The fix is a single shared include — `.claude/agents/_shared/coordinator-intent-check.md` — sourced by both coordinator defs via the existing `<!-- include: _shared/<file>.md -->` mechanism (used today by Karma, Talon, Azir, Aphelios, etc.). The include defines three primitives: (1) an **intent block** (2-4 lines: literal instruction, underlying goal, failure modes if taken literally, shape Duong actually wants) emitted before any state-mutating tool call (Edit, Write, Bash with side effects, Agent dispatch); (2) the **"surgical" anti-self-licensing rule** — diff size is not a justification for bypassing the Karma → Talon → Senna+Lucian chain when the change touches cross-process semantics (env vars, hook scripts, identity resolution, secret handling, agent-def routing); (3) an **altitude-selection step** — classify the response as status-ping vs narrative-brief (default, PM-altitude, 3-7 bullets) vs technical-detail (only when Duong asks why/how/show-me), referencing the existing briefing-verbosity rule in `agents/memory/duong.md` rather than restating it.

Per Lux's recommendation, v1 is prompt-only — no PreToolUse hook. We observe whether the include alone shifts behavior over ~2 weeks before considering runtime enforcement. The "test" for an xfail-first prompt-architecture change is structural: a script that greps both coordinator defs for the include reference and the include file's existence, fails red until wiring lands.

## 2. Decision

**Files.**

- `.claude/agents/_shared/coordinator-intent-check.md` (new) — the shared include. Three sections: `## Intent block`, `## "Surgical" is not a license`, `## Altitude selection`. Concrete failure-mode references inline (gate-bypass on `240bd394`, briefing-altitude swings, filing-question reflex). <!-- orianna: ok -->
- `.claude/agents/evelynn.md` — append `<!-- include: _shared/coordinator-intent-check.md -->` after the existing body content (after line 32).
- `.claude/agents/sona.md` — append `<!-- include: _shared/coordinator-intent-check.md -->` after the existing body content (after line 32).
- `scripts/tests/test-coordinator-intent-include.sh` (new) — structural assertion: fails until both coordinator defs reference the include AND the include file exists with the three required section headings. <!-- orianna: ok -->

**Out of scope (v1).** PreToolUse hook enforcement. State-mutation classifier. Any change to subagent defs. Any change to the briefing-verbosity rule itself.

**Rule mapping.** Rule 12 (xfail-first) — structural-assertion script lands red before the include + wiring lands green. Rule 14 (pre-commit unit tests) — the structural script becomes a unit test wired into the pre-commit pass for changed files under `.claude/agents/`. Rule 18 (no admin merge) — Talon → Senna+Lucian dual review on PR.

## 3. Tasks

### T1. Author structural-assertion script (xfail-first)

- kind: test
- estimate_minutes: 20
- files: `scripts/tests/test-coordinator-intent-include.sh` (new). <!-- orianna: ok -->
- detail: POSIX-portable bash. Three checks. Check A: `.claude/agents/_shared/coordinator-intent-check.md` exists. Check B: file contains the three required H2 headings (`## Intent block`, `## "Surgical" is not a license`, `## Altitude selection`) — exact-string match per heading. Check C: both `.claude/agents/evelynn.md` and `.claude/agents/sona.md` contain the line `<!-- include: _shared/coordinator-intent-check.md -->`. Exit 0 on all-pass, 1 with named failing check on any fail. Land this commit FIRST on the branch, red, referencing this plan path in the commit body. Per Rule 12 the implementation commit cannot precede it.
- DoD: script committed, runs red, commit body references `plans/proposed/personal/2026-04-25-coordinator-deliberation-primitive.md`.

### T2. Author the shared include

- kind: code
- estimate_minutes: 30
- files: `.claude/agents/_shared/coordinator-intent-check.md` (new). <!-- orianna: ok -->
- detail: Three H2 sections matching T1's grep targets exactly.
  - `## Intent block` — describes the 2-4 line block emitted before any state-mutating tool call. Lists the four bullets (literal / goal / failure-if-literal / shape-of-answer). Names the trigger boundary: Edit, Write, Bash-with-side-effects, Agent dispatch. Notes that read-only tools (Read, Grep, Glob, Bash for status/log/diff) do not require a block.
  - `## "Surgical" is not a license` — diff size is not a gate-bypass justification. Cross-process-semantics edits (env vars, hook scripts, identity resolution, secret handling, agent-def routing) require the full Karma → Talon → Senna+Lucian chain regardless of line count. Cite `240bd394` / `bcbe4a3b` and `agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md` as the canonical failure mode. Name the trap: "if the diff feels too small to need a gate, that is the signal you are about to bypass one."
  - `## Altitude selection` — classify the response before sending: status-ping (one line, e.g. acknowledgement), narrative-brief (default, PM-altitude, 3-7 bullets covering outcome / risk / decision), technical-detail (only when Duong explicitly asks why/how/show-me). Reference the briefing-verbosity rule in `agents/memory/duong.md`; do not restate it. Cite the filing-question reflex from this session as a failure mode of skipping altitude classification entirely.
- DoD: file written, three headings present, content under 80 lines total, no restating of duong.md rules.

### T3. Wire the include into both coordinator defs

- kind: code
- estimate_minutes: 10
- files: `.claude/agents/evelynn.md`, `.claude/agents/sona.md`.
- detail: Append a single line `<!-- include: _shared/coordinator-intent-check.md -->` after the existing final body line in each file. Match the existing include style used by Karma, Azir, Aphelios. Do not modify frontmatter, `initialPrompt`, or existing body sentences.
- DoD: both files contain the include line; T1 script runs green.

### T4. Verify and commit

- kind: chore
- estimate_minutes: 10
- files: none new.
- detail: Run the T1 script — must exit 0. Run `scripts/install-hooks.sh`-installed pre-commit pass on the staged set. Commit T2 + T3 together with prefix `chore:` (touches `.claude/agents/**`, not `apps/**`, per Rule 5). Commit body references this plan path. Push and open PR for Senna + Lucian dual review.
- DoD: PR open, T1 script green in CI, ready for review.

## 4. Test plan

- **Invariant under test.** Both coordinator defs reference the new shared include, AND the include file exists with the three structural sections that encode the deliberation primitive. Without all three, the prompt-architecture hole remains open.
- **Test shape.** `scripts/tests/test-coordinator-intent-include.sh` — structural grep + file-existence assertions. Three named checks (A/B/C in T1). Lands red before the implementation per Rule 12; turns green when T2 + T3 land.
- **Behavioral observation (out of band, not a test).** Per Lux, Duong + coordinators observe over ~2 weeks whether the include shifts behavior — fewer self-licensed surgical commits, more visible intent blocks, fewer altitude swings. If observation shows the include is insufficient, a follow-up plan adds a PreToolUse hook. The 2-week observation is not gated by this plan and does not block merge.
- **Out of scope for the test.** Semantic correctness of intent blocks at runtime. Whether coordinators actually reason vs. parrot. Those are emergent and unscriptable; observation handles them.

## 5. Open questions

None. Lux's diagnosis is taken as the spec; the include shape, the surgical-bypass rule, and altitude selection are all derived directly from the brief. Hook deferral is explicit per Lux's recommendation.

## 6. References

- `agents/evelynn/learnings/2026-04-25-gate-bypass-on-surgical-infra-commits.md`
- `agents/memory/duong.md` (briefing-verbosity rule — referenced, not restated)
- `.claude/agents/_shared/quick-planner.md` (existing include pattern)
- `.claude/agents/karma.md` line 42, `.claude/agents/azir.md` line 34 (existing include call sites)
- Repo-root `CLAUDE.md` Rules 5, 12, 14, 18

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a named owner (karma), concrete tasks with DoDs, and a clean xfail-first test plan (T1 structural script lands red before T2/T3 implementation). Scope is tight: one shared include, two def edits, one structural test. Out-of-scope items are explicitly listed. Open questions section is closed. Rule mapping (12/14/18) is correct. Prompt-only v1 with explicit deferral of hook enforcement keeps the change minimal and observable.
