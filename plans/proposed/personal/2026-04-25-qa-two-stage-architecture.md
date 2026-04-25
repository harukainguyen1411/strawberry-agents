---
status: proposed
concern: personal
owner: swain
created: 2026-04-25
tests_required: true
complexity: standard
orianna_gate_version: 2
tags: [architecture, qa, akali, two-stage, rule-16, agent-pairing, advisory]
related:
  - .claude/agents/akali.md
  - .claude/agents/senna.md
  - .claude/agents/lucian.md
  - CLAUDE.md
  - plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md
architecture_impact: rule-16-amend
---

# QA two-stage architecture — observe-vs-diagnose split + Rule 16 amendment

## Context

Sona escalated PR #32 after observing Akali's `.md` write was blocked by the plan-lifecycle guard, which forced her to deliver QA findings as chat-text. Sona's initial framing was "Akali fabricates source-citations under scope mismatch" — that framing has been **retracted mid-flight**. Sona's verification of PR #32's claims used the wrong worktree HEAD (`feat/p1-t13b-demo-ready-panel`) instead of PR #32's actual head (`feat/demo-studio-v3`, ab51372); on the correct head, Akali's findings F1 (`tool_dispatch.py:127` v1 import vs unwired v2) and F2 (`main.py:5` `load_dotenv(".env.local", override=False)`) **were accurate**. PR #32 is therefore a **demonstrated chat-only-return trust-cycle break** — not a demonstrated confabulation incident.

The "Akali fabricates" pattern across PRs #114 and #75 has not been independently re-verified at the time of this advisory. They may still be confabulation cases — but as Swain I have not validated them against their actual PR HEADs and I do not bake them into this ADR's evidence base. They are mentioned only as candidate prior incidents that warrant re-verification before being cited.

The structural concerns nevertheless stand on their own architectural merit, regardless of whether confabulation has been observed today:

1. **Chat-only return path is a real risk.** When Akali's report write is blocked by any guard (plan-lifecycle, inbox-write, secrets, sandbox, SubagentStop), the fallback today is chat-text — which the coordinator then absorbs as ground truth without verifying file:line claims against actual code. PR #32 demonstrated the trust-cycle break end-to-end: blocked write → chat-text findings → Sona absorbed as ground truth across `/compact` → Sona dispatched fix-planner without spot-checking the citations against the right worktree → erroneous diagnosis (the citations were correct on the real head, but Sona's verification ran on the wrong head). The trust-cycle is brittle whether or not Akali confabulates: if the coordinator does not verify, even accurate Akali findings get mis-applied.

2. **Tool-surface-vs-output-scope mismatch is a real architectural risk.** Akali's tool surface is Playwright MCP (browser DOM, screenshots, video, console, network) — not source-code reading. Today she is invoked under both an OBSERVE responsibility (Figma diff, screen pass/fail) and an implicit DIAGNOSE responsibility (root-cause when she sees a fail). When a Sonnet-medium agent is asked to do two distinct jobs without explicit instrumentation for the second, the failure mode is well-known across the agent fleet — confidence without evidence. This risk has not yet manifested in a verified production incident; it will.

3. **Karma already wrote v1 tactical fixes.** `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` (commit `9511f4e3`, unpromoted) covers (1) PostToolUse reminder hook on `subagent_type=lucian` UI/user-flow dispatches to also dispatch Akali; (2a) Akali agent-def "Reporting discipline" section forbidding chat-only findings; (2b) PostToolUse reminder hook on `subagent_type=akali` reminding the coordinator to verify cited file:line claims before fix-planning. These three fixes address the symptom (chat-only outputs, missed dispatches, ungoverned trust in subagent claims) but not the structural mismatch.

4. **Sona's nuanced fix-3 replaces the original "OBSERVE-only" framing.** Original framing: forbid Akali from citing source unless she Read the file → tool-surface narrowing. Revised framing: **let Akali cite source if and only if she actually Read the file, AND tag every citation as either `verified-by-me` (she Read the file at the cited line and the claim is grounded in observed text) or `inferred-from-symptom` (she did not Read; the claim is a hypothesis from screenshot/video/console)**. This preserves Akali's ability to be useful when she can do the verification herself — without forcing every code-level finding to round-trip through a second agent — while making the trust contract explicit in the report itself.

This ADR answers Sona's six structural questions and proposes a two-stage QA architecture: **Akali OBSERVES (and may DIAGNOSE with verified-tagged citations) → Senna DIAGNOSES the inferred-tagged claims on FAIL**, with a coordinator-driven seam (not auto-dispatch). It does not supersede Karma's v1 plan; it complements it. Karma's v1 is the tactical patch — ship it. This plan is the structural pivot — ship it next, on a separate PR, after v1 lands.

The QA cornerstone framing from Duong matters here. "Fast and good QA" is the goal. Single-agent QA is fast (one dispatch) but trusts unverified inference. Two-stage QA is slightly slower (Senna dispatch on FAIL with inferred-tagged claims) but accurate where it counts. The win is: **OBSERVE is always one Akali dispatch; verified-tagged code findings ship in her report directly; inferred-tagged code findings trigger a Senna dispatch IFF the FAIL severity warrants it** — so the median UI PR pays only Akali's Playwright cost, and the long-tail FAIL cases with inferred citations pay an extra Senna dispatch instead of the coordinator absorbing inference as ground truth. The structural cost is one Rule 16 amendment + one agent-def rewrite + one coordinator-side prompt rule.

## Decision

### D1 — One agent or two? (Q1)

**Two agents, one role — with citation-tagging at the seam.** Akali stays as the QA observer-and-may-also-cite-when-she-Read; Senna's lane extends to QA-diagnosis on FAIL when Akali's report contains `inferred-from-symptom` claims that the coordinator deems load-bearing. The seam lives at the **coordinator dispatch pattern**, not at the agent-def or at Rule 16 (Rule 16 is amended for shape but not for the dispatch decision — see D3).

Rationale: the OBSERVE skill is browser-centric and inherently fast/parallelizable; the DIAGNOSE skill is code-read-centric and inherently sequential and source-grounded. The two skills want different model dispositions and different cost envelopes. A single agent equipped with both Playwright AND source-read tools is the current de-facto state and produces a known risk class — when the same agent runs both phases without explicit citation-tagging, downstream consumers cannot tell which findings she verified vs which she inferred.

Crucial point informed by Sona's mid-flight correction: **a tool-surface ban (no `Read` for Akali) is the wrong fix — Akali can be useful when she does the verification herself, and forcing every code-level finding through Senna doubles the dispatch cost on PRs where Akali's verification is correct.** PR #32 demonstrated this: F1 and F2 were accurate on the right head; tool-surface narrowing would have rejected them upfront and forced a Senna round-trip for findings that needed none. The right structural change is **citation-tagging in the report itself**: every code-level finding declares `cite_kind: verified | inferred` and `cite_evidence: <how-i-verified | what-symptom-suggested>`. Verified-tagged findings ship to the coordinator as authoritative; inferred-tagged findings are coordinator-decision points (accept on its face, dispatch Senna for grounding, or dismiss as low-severity).

Why Senna rather than a new agent: Senna already has the tool surface (`Read`, `Glob`, `Grep`, `Edit`, `Write`, `Bash`, `Agent`), the model tier (Opus high), and the disposition (PR code-quality reviewer — finds bugs, off-by-ones, races). Asking her to read Akali's screenshots + video + DOM dumps + repo source and ground the inferred-tagged findings is a natural extension of her existing review job. Adding a new "qa-diagnose" agent adds roster surface for a behavior Senna already does well. (Lucian is the wrong pair — his lane is plan/ADR fidelity, not code root-cause; Caitlyn's lane is plan-test design, not bug investigation.)

Tier confirmation: Senna is Opus-high (tier=single_lane, role_slot=pr-code-security, effort=high) — appropriate for the grounding depth. Akali stays Sonnet-medium for OBSERVE + verified-tagged citations — appropriate for procedural Playwright runs and bounded source-grounding (read-then-cite is shallow and Sonnet handles it well). Cost asymmetry is acceptable: Senna only runs on FAIL with inferred-tagged claims that the coordinator wants grounded — empirically a small fraction of UI PRs.

### D2 — Akali citation-tagging (replaces the OBSERVABLE-only structural fix)

**Keep Akali's source-read affordance** (`Read`, `Glob`, `Grep` — whichever tools she effectively has via framework default; current def at `.claude/agents/akali.md:10-15` declares only Playwright MCP and inherits the framework-default tool set). The original advisory drafted by Swain proposed removing source-read tools from Akali to mechanically prevent confabulation. Sona's correction supersedes that — the tool-surface ban is too sharp; it discards Akali's verified-tagged findings as collateral.

Instead, mandate a **citation-tagging contract** in the agent-def. Every code-level finding in the report declares two new fields:

- `cite_kind: verified | inferred`
- `cite_evidence: <one-line: "Read foo.py:123 — line contains <quoted-snippet>" | "Symptom: console error 'X is not a function' on screen Y; inferred X imported but unwired">`

Hard rules added to akali.md:

- (R1) For any code-level finding (anything citing `<path>:<line>` form, function/symbol names from code, or imports/exports), the report MUST include `cite_kind` and `cite_evidence`.
- (R2) `cite_kind: verified` requires Akali to have actually invoked `Read` (or `Grep` with the `--head` flag) on the cited path/line in the current session. The `cite_evidence` field MUST quote a snippet from the read file confirming the claim.
- (R3) `cite_kind: inferred` is the default when verification was skipped. The `cite_evidence` field MUST name the symptom (screenshot path, video timestamp, console message, network response) that grounds the inference. **Never leave `cite_evidence` empty.**
- (R4) The aggregate `verdict:` field gains a sibling `requires_diagnosis: <true|false>` that fires `true` when ANY finding in the report is `cite_kind: inferred` AND verdict is FAIL or PARTIAL. PASS reports never set `requires_diagnosis: true` regardless of cite_kind distribution.

This is the load-bearing structural change. Karma's v1 §Decision Fix 2a says "never chat-only findings; always write the report"; Sona's revised fix-3 says "let her cite source IFF she Read it AND tag the citation as verified-by-me OR inferred-from-symptom". With citation-tagging mandatory, the trust contract becomes machine-verifiable: pr-lint can grep for `cite_kind:` presence on every code-level finding; a future hook can scan the report and dispatch Senna automatically on `requires_diagnosis: true`; the coordinator has an explicit signal of which claims to trust on their face.

Coupled change: `## Output convention` in akali.md now mandates the report frontmatter carries `requires_diagnosis: <true|false>` plus `diagnosis_dispatch: <senna-pr-comment-url-or-none>` (filled by the coordinator after Senna runs). The single-file convention preserves pr-lint's existing `QA-Report:` check unchanged.

What this does NOT prescribe: a tool-surface ban. Akali keeps `Read`/`Grep`/`Glob`. The structural lever is the report contract, not capability removal.

### D3 — Auto-dispatch vs coordinator-driven (Q2)

**Coordinator-driven, not auto-dispatch.** When Akali returns a report containing `cite_kind: inferred` claims with FAIL or PARTIAL verdict (`requires_diagnosis: true`), Evelynn or Sona reads the report and decides whether to dispatch Senna with the report path as the input artifact. There is no automatic chained dispatch.

Rationale: auto-dispatch couples agents (two failure modes — Akali's report-write breaks → Senna never runs; Senna's diagnosis runs on a PASS Akali report due to a status-flip bug → wasted Opus-high cycle) and erodes coordinator situational awareness. Coordinator-driven keeps the chain explicit and gives the coordinator the choice of "Akali says X with `cite_kind: inferred` — does this inference need grounding by Senna, or is the symptom self-explanatory enough to fix without source-grounding, or low-severity enough to dismiss?" Sometimes the screenshot IS the diagnosis (visible Figma drift, missing button, wrong copy) and a Senna dispatch wastes a cycle. Sometimes the screenshot needs root-causing (intermittent layout break, console error of unclear provenance) and Senna is the right next move. **The coordinator's judgement is the seam** — automation removes the judgement.

The objection is "coordinator discipline is exactly what just failed." Reframed against Sona's correction: the actual failure on PR #32 was not a missed dispatch — Sona dispatched the right next step (a fix-planner). The failure was Sona absorbing Akali's chat-text claims as ground truth and then verifying them against the wrong worktree HEAD. Two distinct failures stacked: (i) chat-only return path activated because the report write was blocked, (ii) coordinator-side verification ran on the wrong head. Both need addressing.

Failure (i) is addressed by Karma's v1 Fix 2a (Akali agent-def "Reporting discipline" — surface the guard message, never paraphrase). Failure (ii) is addressed by Karma's v1 Fix 2b (PostToolUse reminder on `subagent_type=akali` to verify cited file:line — explicitly include the rule "verify against the PR's actual head, not your current worktree"). D2 above adds the third layer: with `cite_kind: verified` declared in the report, the coordinator's verification reduces to a quick `Read <path>:<line>` against the same head Akali used (Akali should record the head SHA in the report frontmatter, see D6(f) below) — making the verification mechanical and head-mismatch detection cheap. Auto-dispatch does not solve any of these; it only mechanizes a chain that the coordinator should still gate.

Hook surface to add: extend Karma v1's PostToolUse reminder hook on `subagent_type=akali` to also emit, when the dispatch description signals FAIL or `requires_diagnosis`, a second reminder line: "If Akali's report has `cite_kind: inferred` claims AND verdict is FAIL/PARTIAL, dispatch Senna with the report path as input — do not dispatch a fix-planner directly off inferred claims. Verified claims may go straight to fix-planner. Verify the head SHA in the report matches the PR's actual head before either dispatch." This is one additional substring check in the existing hook; no new hook file.

### D4 — Rule 16 amendment shape (Q3)

Current Rule 16 reads (CLAUDE.md:92-101):

> Before opening a UI or user-flow PR, Akali (`.claude/agents/akali.md`) must run the full Playwright MCP flow (`mcp__plugin_playwright_playwright__*` tool family) with video + screenshots and diff against the Figma design — report lives under `assessments/qa-reports/` and is linked in the PR body via a `QA-Report: <path-or-url>` line. Enforced by `.github/workflows/pr-lint.yml` (PR body linter). A `QA-Waiver: <reason>` line is accepted in lieu of a report when Akali cannot run (e.g. no running staging environment). Non-UI and non-user-flow PRs exempt. _User-flow_ means: new routes, new forms, state-transition changes, auth flows, session lifecycle changes.

Proposed amendment (verbatim — the diff for the Rule 16 block):

> Before opening a UI or user-flow PR, the QA two-stage flow runs: (a) **Akali OBSERVES (and may verify-cite source)** — runs the full Playwright MCP flow (`mcp__plugin_playwright_playwright__*`) with video + screenshots, diffs against the Figma design, and writes a structured report to `assessments/qa-reports/<slug>.md` containing per-screen pass/fail, video/screenshot artifact paths, console + network anomalies, and (for any code-level finding) a `cite_kind: verified | inferred` tag plus a `cite_evidence:` line. The report frontmatter also carries `head_sha:` (the commit Akali tested against) and `requires_diagnosis: <true|false>` (true iff verdict is FAIL/PARTIAL AND any finding is `cite_kind: inferred`). (b) **If `requires_diagnosis: true`** — the coordinator decides whether to dispatch Senna against the QA artifact set; if dispatched, Senna reads the screenshots, video, console excerpts, and the actual repo source at the recorded `head_sha`, and appends a `## Diagnosis` section to the same report with grounded `<file>:<line>` citations (each tagged `cite_kind: verified`) and a recommended fix shape. (c) The PR body links the QA report via `QA-Report: <path-or-url>`. Enforced by `.github/workflows/pr-lint.yml`. A `QA-Waiver: <reason>` line is accepted in lieu of a report when Akali cannot run (e.g. no running staging environment). Non-UI and non-user-flow PRs exempt. _User-flow_ means: new routes, new forms, state-transition changes, auth flows, session lifecycle changes.

Four substantive changes vs current text: (1) Rule names "Akali OBSERVES (and may verify-cite)" + "Senna DIAGNOSES inferred-tagged claims on FAIL/PARTIAL" as the canonical two-stage flow; (2) makes the citation-tagging contract (`cite_kind: verified | inferred` + `cite_evidence:`) a Rule-level invariant, not just an agent-def detail; (3) introduces `head_sha:` as a frontmatter field so the coordinator can verify Akali ran against the PR's actual head before trusting any citations; (4) introduces `requires_diagnosis` as the seam and locates the diagnosis output ("appends a `## Diagnosis` section to the same report"). The single-file output convention preserves pr-lint's `QA-Report:` check as-is — no CI workflow changes required.

What does NOT change in Rule 16: enforcement layer (still pr-lint.yml), waiver mechanism, exempt classes, definition of user-flow.

### D5 — Plan-lifecycle for the four fixes (Q5)

**Recommendation: Q5(c) — split the work.** Promote Karma's v1 (`2026-04-25-akali-qa-discipline-hooks.md`) as the tactical patch on its own PR. Ship this plan as a separate architectural plan on a follow-up PR, sequenced AFTER v1 lands. Two reasons:

1. **Different artifact shape and reviewer surface.** v1 ships ~3 small files (two POSIX bash hooks + an akali.md section + settings.json wiring), low blast radius, single Senna+Lucian review pass. This plan ships a Rule 16 text amendment + an akali.md citation-tagging contract + a coordinator prompt rule update + a hook extension to gate "dispatch Senna on FAIL with inferred-tagged claims" — higher blast radius, broader reviewer surface (touches CLAUDE.md, which everyone reads on boot). Mixing them invites a tangled review where critique of D2's citation-tagging contract blocks shipping the cheap hook bundle.

2. **Sequencing buys validation data.** v1 lands first → coordinator gets the verify-claims reminder, Akali stops chat-only findings, the Lucian-UI dispatch reminder catches the missed-dispatch class. Run for a week (3–5 UI PRs). If v1 alone fixes the recurring class (no new chat-only-trust-cycle breaks observed; coordinator verification habit established), this plan can downgrade D2/D3/D4 from "must-ship" to "nice-to-have" and we save an architectural commit. If v1 lands and a new trust-cycle break occurs (e.g. Akali cites unverified source as if verified, or the coordinator skips verification despite the reminder), this plan ships immediately as "v1 wasn't enough — here's the structural contract fix."

Concretely: do NOT extend Karma's v1 in place to add fix-3 + D2/D3/D4. v1 is unpromoted; appending content invalidates its existing structure (the §Tasks T1–T6 set is scoped tightly to three hooks). Adding the structural pivot doubles the plan size and re-opens D-decisions Karma already settled. Extension is also a worse fit for the corrected framing: Sona's nuanced fix-3 (cite_kind tagging) is structurally distinct from v1's three hooks — combining them in v1 would conflate the citation-contract redesign with the discipline-reminder hooks and produce a less reviewable PR.

### D6 — Other system-level concerns (Q6)

**(a) Akali's report should be append-only by Senna.** When the coordinator dispatches Senna against `assessments/qa-reports/<slug>.md`, Senna appends a `## Diagnosis` section to the existing file. She does NOT rewrite Akali's observation section, does NOT update the verdict, does NOT touch frontmatter beyond filling `diagnosis_dispatch:`. This is structurally enforced via Akali's existing report-write authorship; Senna's tool surface allows `Edit` so she can append. Two-author append on a single file is the simplest representation of "OBSERVE then DIAGNOSE on the same artifact" and avoids artifact proliferation that the pr-lint linker would have to track separately.

**(b) Parallel QA-vs-implementation chain — out of scope, but flagged.** A future ADR could explore: dispatch Akali in parallel with Senna+Lucian PR review (rather than gating PR open on Akali). The benefit is faster feedback to the implementer — Senna+Lucian start immediately on diff review while Akali boots Playwright. The cost is a UI bug found by Akali AFTER Senna already approved the PR introduces a re-review cycle. Karma's v1 fix-1 (PostToolUse reminder on Lucian dispatch) implicitly assumes the current sequential model (Akali first, then Lucian). The parallel model would change that hook — but is a separate decision and not load-bearing for the structural confabulation fix. **Defer**, file as OQ-1.

**(c) QA-fast lane — out of scope.** Some UI PRs (typo fix, copy change, single-color tweak) don't need a full Playwright pass. Today Rule 16 admits a `QA-Waiver: <reason>` for these but it's Duong-only. A "QA-fast" path that runs a 30-second screenshot diff (no video, no full-flow click-through) instead of the full Playwright suite would let Akali honor Rule 16 on trivial PRs without the cost. **Defer**, file as OQ-2.

**(d) Cross-concern QA scope.** Akali's def has a "Prod QA auth — demo-studio-v3" section (akali.md:45-51), which is work-concern surface (`apps/demo-studio` lives in the work repo). This plan is `[concern: personal]` and amends a personal-concern Rule 16. The Rule 16 in CLAUDE.md is a universal invariant covering both concerns. The structural pivot (citation-tagging Akali + Senna diagnosis on inferred FAIL) applies to both concerns — Senna's existing concern-split reviewer-auth (senna.md:69-83) handles the work-vs-personal review path, so a work-concern UI PR FAIL routes through `post-reviewer-comment.sh` and a personal-concern FAIL routes through `reviewer-auth.sh --lane senna`. No additional concern routing required. **Confirm in OQ-3.**

**(e) Akali's FAIL definition must be tightened.** Current akali.md says "Per-screen pass/fail table" and "Overall verdict: PASS / FAIL / PARTIAL" but does not define what triggers each. Without a clear FAIL definition, `requires_diagnosis: true` is a coin-flip. Add to akali.md: FAIL = (any screen pixel-diff > threshold against Figma frame) OR (any console error not in allowlist) OR (any network request returning 5xx) OR (any required interaction step that did not complete). PARTIAL = (Figma diff present but coordinator-acceptable, e.g. style polish needed). PASS = (all of the above clean). `requires_diagnosis: true` fires iff verdict ∈ {FAIL, PARTIAL} AND any code-level finding has `cite_kind: inferred`. PASS reports never set `requires_diagnosis: true`.

**(f) `head_sha` in report frontmatter — head-mismatch prevention.** The PR #32 incident demonstrated that coordinator-side verification can run on the wrong worktree HEAD if the coordinator does not explicitly check. Mandate that Akali's report frontmatter includes `head_sha: <full-or-short-sha>` recording the commit she tested against — captured via `git rev-parse HEAD` from the worktree she ran in. The coordinator's verification ritual (Karma v1 Fix 2b reminder) extends to: "Before verifying any cited file:line, confirm `head_sha` in the report matches the PR's actual head. If mismatch, the citations may be against a stale tree — re-dispatch Akali on the correct head before proceeding." This is a one-line frontmatter addition with a one-line coordinator rule and a one-line addition to Karma v1's verify-claims reminder; the cost is negligible and the trust-cycle protection is large.

## Tasks

This plan is advisory + architectural. Tasks here are minimal — 3 coordination tasks (no code self-implementation). The actual implementation tasks are downstream of this ADR (Karma authors a v2-structural plan if Duong/Sona accept the recommendations, OR Evelynn dispatches an implementer directly). Plan-structure linter requires `## Tasks` so coordination steps are listed.

### T1 — Synthesize with Lux's parallel return + present to Duong

- kind: ops
- estimate_minutes: 30
- files: (no commits — Evelynn-side synthesis)
- detail: Evelynn reads this advisory + Lux's Akali-agent-def advisory in parallel, identifies overlaps (D2 here on citation-tagging contract may overlap Lux's "output shape" answer; reconcile if so), produces a unified recommendation summary for Duong covering: (a) ship Karma v1 as-is, (b) accept/reject D2 (citation-tagging contract `cite_kind: verified | inferred`), (c) accept/reject D3 (coordinator-driven dispatch on inferred-tagged FAIL/PARTIAL), (d) accept/reject D4 (Rule 16 amendment text), (e) accept/reject D6(f) (`head_sha` frontmatter), (f) commit to the OQ deferrals or escalate any to "must-decide-now". Duong responds; Evelynn either commits the answers as a follow-up `## Decision-Outcome` section appended to this ADR (with `Decided-By: Duong` trailer), or dispatches Karma to author the v2 structural plan with the accepted decisions baked in.
- DoD: Evelynn returns a synthesis to Duong within one working day after both advisories return; Duong's decisions captured either in a follow-up commit appending §Decision-Outcome to this plan, or in a fresh v2 plan authored by Karma.

### T2 — Promote Karma v1 (tactical patch) via Orianna

- kind: ops
- estimate_minutes: 15
- files: `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` → `plans/approved/personal/`
- detail: Per Rule 19 / Rule 7, only Orianna can promote plans out of `plans/proposed/`. Evelynn dispatches Orianna with the v1 plan path; Orianna reads, fact-checks, renders APPROVE or REJECT; on APPROVE she git-mvs the file, commits with `Promoted-By: Orianna` trailer, pushes. After promotion, Evelynn dispatches an implementer (likely Karma + Ekko-pair, or Aphelios for breakdown) to ship the three hooks + akali.md edit + settings.json wiring. Senna+Lucian review the resulting PR.
- DoD: Karma v1 lands on main as a single PR; QA-Waiver acceptable per the plan's own §Test plan; PostToolUse hooks fire correctly in production (manual smoke included in v1 T6).

### T3 — Author v2 structural plan (if Duong accepts D2/D3/D4/D6(f))

- kind: ops
- estimate_minutes: 0 (gated on T1 outcome)
- files: `plans/proposed/personal/<YYYY-MM-DD>-qa-two-stage-implementation.md` (new — gated on T1 outcome) <!-- orianna: ok -- prospective path, gated on Duong acceptance -->
- detail: Karma (or Evelynn directly if she absorbs the advisory) authors a v2 implementation plan that ships D2 (akali.md citation-tagging contract — `cite_kind`/`cite_evidence`/`requires_diagnosis` frontmatter and reporting rules), D3 (extend Karma v1 hook to include the "dispatch Senna on FAIL with inferred-tagged claims" reminder line + head_sha mismatch warning), D4 (Rule 16 amendment text), D6(a) (Senna append-only on the existing report), D6(e) (Akali FAIL definition tightening), D6(f) (`head_sha` frontmatter field). Plan tasks include xfail tests per Rule 12 (e.g. an akali.md report-template grep test asserting the four frontmatter fields are documented; a Rule 16 text test asserting the new wording is present in CLAUDE.md; a hook test feeding a sample report with `cite_kind: inferred` + verdict FAIL and asserting the verify-and-Senna reminder fires). Reviewers: Senna + Lucian. QA-Waiver acceptable on the v2 PR (no UI surface touched — only agent-defs, hooks, CLAUDE.md text).
- DoD: v2 plan exists in `plans/proposed/personal/`, signed off by Orianna, ready for implementation dispatch — OR explicitly cancelled if Duong/Sona decide v1 alone is sufficient after a week of validation data.

## Test plan

This plan is advisory — its test surface is the v1 + v2 implementation plans, not this document. The v1 plan's existing §Test plan covers the three hook + agent-def changes. The v2 plan (gated on T3) will require xfail tests for each of: akali.md report contract (regression-grep for `cite_kind:`, `cite_evidence:`, `head_sha:`, `requires_diagnosis:` documentation), Rule 16 amendment text presence (CLAUDE.md grep), citation-contract enforcement (informal — prompt-layer rule, optional pr-lint extension), Senna append-only constraint (informal — prompt-layer rule).

What this advisory protects against without code: (a) the wrong-shape conclusion that Akali's tool surface should be narrowed by removing `Read`/`Grep` (D2 explicitly rejects this after Sona's correction; the right lever is the citation-tagging contract); (b) the wrong-shape conclusion that auto-dispatch on FAIL is the right seam (D3 explicitly rejects this); (c) the wrong-shape conclusion that v1 should be extended in-place (D5 explicitly rejects this); (d) the wrong-shape conclusion that Rule 16 should remain unchanged (D4 amends it); (e) the wrong-shape conclusion that PR #32 demonstrates fabrication (the §Context narrative explicitly retracts this and reframes as a chat-only-trust-cycle break).

Out of scope: the v1 plan's §Test plan (already covers v1 invariants); coordinator-side prompt rule changes for Evelynn/Sona that are NOT v1 scope (those land in v2 if D3 is accepted); cross-concern Akali differences (D6(d) defers to OQ-3); Vi's role (Vi is `role_slot: test-impl` for normal-track integration testing — distinct from Akali's QA-observer role; Vi's tool surface includes Playwright but her dispatch context is "run the standard test suite", not "QA a PR before open"; this plan does not touch Vi); independent re-verification of PR #114 / PR #75 confabulation claims (Sona did not retract those; they may be real but Swain has not verified — out-of-band confirmation needed before either is cited as evidence).

## Open Questions

- **OQ-1.** Should we explore parallel-vs-sequential QA dispatch in a follow-up ADR (D6(b))? Today Akali blocks PR open per Rule 16; a parallel model dispatches Akali alongside Senna+Lucian and accepts a re-review cycle on late FAIL. **Recommend:** defer — current sequential model is correct for now; revisit only if PR throughput becomes a bottleneck.

- **OQ-2.** QA-fast lane for trivial PRs (D6(c))? Add a third PR-body marker `QA-Fast: <reason>` admitting a screenshot-only diff (no Playwright run-through) for typo/copy/color PRs. **Recommend:** Pick — the current `QA-Waiver:` Duong-only path is too sharp for these; a QA-Fast path covered by an Akali `--mode=fast` flag is a natural fit. Defer to a separate ADR.

- **OQ-3.** Does the two-stage architecture apply uniformly across personal + work concerns (D6(d))? **Recommend:** YES, with no concern-routing change — Senna's existing concern-split (senna.md:69-83) handles the review-auth path; the dispatch decision (Senna vs no Senna) is concern-agnostic.

- **OQ-4.** Should the citation-tagging contract be enforced by pr-lint or only by prompt rule? Current D2 is prompt-only. A pr-lint extension could grep the linked `QA-Report:` for `cite_kind:` on every code-level finding bullet — feasible but couples pr-lint to akali.md report-template syntax. **Recommend:** prompt-only for v2; promote to pr-lint enforcement in a future hardening pass if Akali drifts from the contract.

- **OQ-5.** When Akali returns PARTIAL, should the coordinator have a third dispatch option (e.g. dispatch Caitlyn for test-design polish) or just accept-and-proceed? **Recommend:** accept-and-proceed for now — PARTIAL means the screenshot is acceptable to ship with style polish noted; Caitlyn dispatch is overkill. Revisit in v2 if PARTIAL frequency justifies it.

- **OQ-6.** Senna append-only on the existing report file (D6(a)) vs Senna writes a sibling diagnosis file (`assessments/qa-reports/<slug>-diagnosis.md`)? **Recommend:** Pick append-only — single-file convention preserves pr-lint's `QA-Report:` check unchanged. Sibling-file would require a second pr-lint check `QA-Diagnosis:` and increase artifact surface.

- **OQ-7.** Does this advisory invalidate any existing assessment under `assessments/qa-reports/`? Akali has run on multiple PRs already; her past reports may contain source-citations that, post-D2, would be forbidden by the new agent-def. **Recommend:** no — past reports are historical record; new reports comply with new rules; do not retroactively edit. Confirm.

## References

- `.claude/agents/akali.md` lines 10-15 (Playwright MCP-only declaration; framework-default tools currently inherited)
- `.claude/agents/akali.md` lines 22-44 (current Responsibilities + Output convention)
- `.claude/agents/senna.md` lines 32-44 (Senna's current scope — code quality, security; the diagnosis extension fits naturally)
- `.claude/agents/senna.md` lines 69-83 (concern-split reviewer-auth — applies unchanged to QA-diagnosis dispatch)
- `.claude/agents/lucian.md` lines 33-40 (Lucian's plan-fidelity scope — explicitly out of QA-diagnosis lane)
- `CLAUDE.md` lines 92-101 (Rule 16 current text — amended in D4)
- `plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md` (Karma's v1 tactical plan; this ADR explicitly does not supersede it)
- `agents/sona/memory/open-threads.md` lines 303-307 (Sona's prior 2026-04-23 escalation — historical context)
- `agents/sona/memory/open-threads.md` line 40 (PR #32 ghost-citation incident — proximate trigger)
- `assessments/qa-reports/2026-04-22-akali-*.md` (prior Akali QA reports — likely contain source-citations that the post-D2 rule would forbid; OQ-7 confirms no retroactive edits)
