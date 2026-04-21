---
title: Orianna web-research verification — extend plan-check with external-claim freshness via WebFetch, WebSearch, and context7
status: implemented
concern: personal
owner: karma
created: 2026-04-20
complexity: quick
orianna_gate_version: 2
tests_required: true
architecture_impact: none
tags:
  - orianna
  - fact-check
  - tooling
  - quick-lane
orianna_signature_approved: "sha256:702141f0032c5290aca490e80a9122cc8a835871389b588fb9efae0f3e9b95c9:2026-04-21T02:45:44Z"
orianna_signature_in_progress: "sha256:702141f0032c5290aca490e80a9122cc8a835871389b588fb9efae0f3e9b95c9:2026-04-21T02:46:55Z"
orianna_signature_implemented: "sha256:702141f0032c5290aca490e80a9122cc8a835871389b588fb9efae0f3e9b95c9:2026-04-21T02:48:02Z"
---

## Context

Orianna's plan-check gate today (`agents/orianna/prompts/plan-check.md` Step C)
verifies load-bearing claims by grepping anchors against the current repo
checkout. That catches fabricated/stale **internal** references — the
"Firebase GitHub App" motivating bug — but it cannot catch a second class of
failure the gate was originally meant to address: plans relying on stale
training data for **external** facts (library API surfaces, RFC citations,
vendor behavior, documented URLs). An agent can confidently cite
`client.completions.create` when the current SDK surface is
`client.messages.create`, and today's gate will happily pass it.

This plan adds an additive **Step E — External claims verification** to the
existing plan-check prompt. Step E extracts load-bearing external assertions
(named libraries/SDKs/APIs, RFC/spec quotes, version numbers, explicit URLs)
and verifies each via live tools: `context7` for named libraries,
`WebFetch` for URL citations, and `WebSearch` as a fallback for assertions
without a URL anchor. It uses the existing `block`/`warn`/`info` severity
set — no new levels — and runs under a per-plan budget cap to keep the gate
affordable. Step C (grep-anchor) is untouched; Step E is purely additive.

This is scoped tighter than the broader role-redesign ADR at
`plans/proposed/2026-04-19-orianna-role-redesign.md` (two-phase gate,
Firecrawl, monthly sweep, contract v2). That ADR is in `proposed/` and may
ship independently; this plan delivers the narrow slice Duong actually
wants in the next pass — Step E in the existing prompt, nothing more. If
the role-redesign lands first, reconcile by rebasing Step E's text into
Phase 2 of that design.

## Decisions

1. **Additive only.** Keep Steps A–D verbatim. Add Step E after Step D.
   Report body gains a new `## External claims` section alongside the
   existing Block/Warn/Info sections; findings continue to count toward
   the existing `block_findings`/`warn_findings`/`info_findings` totals
   in frontmatter. No new severity level.
2. **Trigger heuristic (conservative).** Step E fires on a token only when
   the plan sentence contains at least one of: (a) a named library/SDK/API
   (proper noun not on the path-prefix routing table, e.g. "Next.js",
   "Anthropic SDK", "firebase-cli"), (b) a version number (e.g. `v15.2`,
   `>=0.30`, `RFC 9110`), (c) an explicit `http(s)://` URL, (d) an
   RFC/spec citation. Purely internal claims continue to use Step C only.
3. **Tool routing per claim.**
   - Has URL → `WebFetch` (read the cited URL; flag 404, deprecation banner,
     or sunset redirect).
   - Names a library/SDK/framework → `context7`: call
     `resolve-library-id`, then query the relevant docs section for the
     cited symbol/flag/version.
   - Bare factual assertion with no URL and no recognized library →
     `WebSearch` (one query, one pass; snippets inform verdict but are
     never the sole block signal — if a search surfaces a canonical URL,
     follow up with `WebFetch`).
4. **Budget cap.** Per-plan cap of **15 external-tool calls** total across
   WebFetch + WebSearch + context7 (honored via env var
   `ORIANNA_EXTERNAL_BUDGET`, default 15). When the cap is hit, remaining
   B3-triggered claims emit a `warn` with "budget exhausted; verify
   manually" — not `block`. Cap is a call-count ceiling, not a dollar one.
5. **Severity mapping.**
   - `block`: cited URL redirects to an explicit deprecation/sunset page;
     context7 reports the cited symbol is `@deprecated` or removed at/below
     the cited version; library is sunset.
   - `warn`: cited URL returns 404/DNS failure; library major-version
     bump with breaking changes and the plan pins no version; WebSearch
     turns up strong contradicting signal without authoritative source;
     budget exhausted.
   - `info`: vendor rebrand (old name redirects cleanly to new); tool-name
     change where tool still exists under another name; context7
     resolved cleanly with no contradiction.
6. **Tool availability.** Orianna is invoked via `scripts/orianna-fact-check.sh`
   with `claude -p --dangerously-skip-permissions`, which grants
   unrestricted tool access at runtime — so `WebFetch`, `WebSearch`, and
   `context7` are already callable. The only change needed is documenting
   the tool expectations in the prompt (Step E explicitly names which tool
   to use per case). No changes to the CLI flags or an agent-definition
   file are required (Orianna has no `.claude/agents/orianna.md` today; <!-- orianna: ok -->
  <!-- prior line notes a known-absent path — do not block -->
  
   she is prompt-driven).
7. **Suppression.** The existing `<!-- orianna: ok -->` suppression syntax
   from Step C carries over to Step E: authors can opt out per line or
   per following line for external claims the same way they do for
   internal ones.

## Tasks

### T1 — Extend plan-check prompt with Step E

- **kind:** docs
- **estimate_minutes:** 40
- **files:**
  - `agents/orianna/prompts/plan-check.md`
- **detail:** Insert a new `### Step E — External-claim verification`
  section after the existing Step D and before `## Report format`. Body
  must specify, in order: [1] the Step E trigger heuristic from Decision 2;
  [2] the per-case tool routing from Decision 3 — URL goes to WebFetch;
  named library goes to context7 resolve-library-id then query; an
  unanchored factual assertion goes to WebSearch. [3] the
  severity table from Decision 5; [4] budget cap semantics from Decision 4
  including the `ORIANNA_EXTERNAL_BUDGET` env var name and default 15;
  [5] explicit reuse of the `<!-- orianna: ok -->` suppression syntax per
  Decision 7. Also extend `## Report format` to add a `## External claims`
  section after the existing Info findings section; entries use the same
  step-prefix shape as Steps A–D (e.g. "**Step E — External:** `firebase
  functions:config:set` | **Tool:** WebFetch → https://… | **Result:**
  page returns HTTP 410 sunset | **Severity:** block"). Update the
  `## Scope guardrails` bullet list at the end of the prompt to include
  Step E ("Does this external claim still hold against live docs?").
  Update the `check_version: 2` frontmatter reference in the report
  template to `check_version: 3` and add a new frontmatter field
  `external_calls_used: <integer>` (count of external tool invocations
  made) beneath `info_findings`.
- **DoD:** prompt file committed; `grep -c "Step E" agents/orianna/prompts/plan-check.md` ≥ 3;
  `check_version: 3` appears exactly once in the report template block;
  new `external_calls_used:` frontmatter field is present in the example
  frontmatter block; no Step A–D wording has been altered (diff shows
  only additions).

### T2 — Document tool expectations and budget env var in the orianna profile

- **kind:** docs
- **estimate_minutes:** 20
- **files:**
  - `agents/orianna/profile.md`
- **detail:** Add a short "External verification tools" subsection listing
  WebFetch, WebSearch, and context7 as Orianna's Phase-Step-E tool set,
  cross-linking to `agents/orianna/prompts/plan-check.md` Step E. Document
  the `ORIANNA_EXTERNAL_BUDGET` env var (default 15) and note that
  `scripts/orianna-fact-check.sh` already grants unrestricted tool access
  via `--dangerously-skip-permissions`, so no CLI flag change is required.
  If the "External verification tools" heading already exists from prior
  work, extend it in place rather than duplicating.
- **DoD:** `grep -n "ORIANNA_EXTERNAL_BUDGET" agents/orianna/profile.md`
  returns at least one hit; `grep -n "Step E" agents/orianna/profile.md`
  returns at least one hit.

### T3 — Wire the budget env var through the invocation script

- **kind:** feat
- **estimate_minutes:** 25
- **files:**
  - `scripts/orianna-fact-check.sh`
- **detail:** Read `ORIANNA_EXTERNAL_BUDGET` from the environment with
  default `15`; export it into the child `claude` process so the prompt
  can reference it as a concrete number. Add a one-line log to stderr
  ("external budget: <N>") so reports are diagnosable. Do NOT change
  exit-code semantics, report path, or the existing fallback to
  `scripts/fact-check-plan.sh` when the `claude` CLI is unavailable. No
  behavior change for plans that trigger zero Step-E claims.
- **DoD:** `bash -n scripts/orianna-fact-check.sh` passes; running the
  script with `ORIANNA_EXTERNAL_BUDGET=0` against a plan with pure
  internal claims exits 0 and the stderr log shows "external budget: 0";
  running without the env var shows "external budget: 15".

### T4 — Add a regression test for prompt structure and env-var passthrough

- **kind:** test
- **estimate_minutes:** 30
- **files:**
  - `scripts/test-orianna-plan-check-step-e.sh` (new) <!-- orianna: ok -->
- **detail:** POSIX-bash test script that asserts: [1] the plan-check
  prompt contains a `Step E` section between Step D and the
  `## Report format` heading; [2] the prompt references
  `ORIANNA_EXTERNAL_BUDGET`, `WebFetch`, `WebSearch`, and `context7`
  literally; [3] `scripts/orianna-fact-check.sh` exports
  `ORIANNA_EXTERNAL_BUDGET` (grep for the export line); [4] the default
  value is `15`. Test is structural only — no live LLM invocation, no
  network. Make it executable (`chmod +x`). Do not wire into CI in this
  plan; leave that to a follow-up if Duong wants it blocking.
- **DoD:** <!-- orianna: ok -->
  `bash scripts/test-orianna-plan-check-step-e.sh` exits 0 on
  the fully-implemented branch and exits non-zero if any of T1/T2/T3
  outputs regress.

## Test plan

The invariants this plan must protect:

1. **Step E is additive.** Steps A–D wording is byte-identical pre/post;
   a `diff` of the prompt file shows only additions after the end of
   Step D. T4 covers this by asserting the `Step E` string lands after
   Step D and before `## Report format`.
2. **No new severity.** Only `block`/`warn`/`info` appear in the prompt.
   T4 asserts no new severity-like tokens (e.g. `critical`, `fatal`)
   were introduced in the Step E section.
3. **Tools named match Decision 3.** `WebFetch`, `WebSearch`, and
   `context7` are each referenced by name at least once in Step E. T4
   asserts all three literals are present.
4. **Budget knob is plumbed end-to-end.** The env var
   `ORIANNA_EXTERNAL_BUDGET` is referenced in the prompt (T1), the
   profile (T2), and exported by the invocation script (T3). T4 greps
   each file and fails if any referent is missing.
5. **Fallback behavior preserved.** `scripts/orianna-fact-check.sh`
   still falls back to `scripts/fact-check-plan.sh` when the `claude`
   CLI is absent — T3's DoD covers this by explicit non-modification of
   the fallback branch. A manual smoke test on a throwaway branch with
   `command -v claude` stubbed to fail confirms the fallback path still
   runs unchanged (not automated — leave to reviewer).
6. **Report schema bump is visible.** `check_version: 3` appears in the
   prompt's report template exactly once; `external_calls_used:` appears
   in the frontmatter example exactly once. T4 asserts both.

Manual verification after merge (not automated, run by Duong or a
reviewer on one real plan in `plans/proposed/`):

- Run `bash scripts/orianna-fact-check.sh plans/proposed/<some-plan>.md`
  against a plan that cites a library (e.g. any plan mentioning Next.js
  or the Anthropic SDK). Confirm the resulting report in
  `assessments/plan-fact-checks/` contains a populated `## External
  claims` section and the new `external_calls_used:` frontmatter field.
- Run the same invocation with `ORIANNA_EXTERNAL_BUDGET=0` and confirm
  the `## External claims` section reports all triggered B3 claims as
  `warn` with "budget exhausted; verify manually" and no block finding
  is emitted from Step E.

## Architecture impact

This plan is additive only — no new components, no schema changes outside
the plan-check prompt. The only behavioral change is that Orianna's
`plan-check` gate may now make live external tool calls (WebFetch,
WebSearch, context7) when Step E triggers. The invocation contract
(`scripts/orianna-fact-check.sh` calling `claude -p
--dangerously-skip-permissions`) is unchanged. Exit-code semantics are
unchanged. The report schema gains `external_calls_used:` in frontmatter
and `## External claims` in the body; downstream consumers that parse
reports must tolerate the new fields (additive, not breaking).

## Test results

Structural regression test passes:
`assessments/plan-fact-checks/2026-04-20-orianna-web-research-verification-2026-04-21T02-37-29Z.md`

Local run: `bash scripts/test-orianna-plan-check-step-e.sh` — 16/16 passed.

## Related work

- `plans/proposed/2026-04-19-orianna-role-redesign.md` — larger two-phase
  redesign. This plan is a narrower, compatible subset: if the redesign
  lands first, Step E folds into its Phase 2 and this plan is closed as
  superseded; if this plan lands first, the redesign absorbs Step E into
  Phase 2 and extends it with Firecrawl + monthly sweep.
- `agents/orianna/claim-contract.md` — v1 contract. This plan does NOT
  bump the contract version; it adds a prompt-level extraction step that
  reuses the v1 extraction heuristic.
- `agents/orianna/prompts/plan-check.md` — the file this plan primarily
  extends.
- `scripts/orianna-fact-check.sh` — the invocation script that grants
  unrestricted tool access via `--dangerously-skip-permissions`.
