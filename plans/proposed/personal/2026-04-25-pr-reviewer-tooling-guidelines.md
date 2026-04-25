---
status: proposed
concern: personal
owner: azir
created: 2026-04-25
tests_required: false
complexity: complex
orianna_gate_version: 2
tags: [architecture, pr-reviewer, senna, lucian, camille, security, scalability, reliability, adr, canonical-v1-lock]
related:
  - .claude/agents/senna.md
  - .claude/agents/lucian.md
  - .claude/agents/camille.md
  - .claude/agents/_shared/no-ai-attribution.md
  - plans/proposed/personal/2026-04-25-qa-two-stage-architecture.md
  - plans/proposed/personal/2026-04-25-akali-qa-discipline-hooks.md
  - CLAUDE.md
architecture_impact: reviewer-discipline-primitive + senna-checklist + lucian-checklist + escalation-paths + camille-on-dispatch + reviewer-audit-loop
---

# PR Reviewer Tooling & Guidelines — Senna + Lucian (+ Camille)

## Context

PR review is the second-of-three gates that ensure shipped code is correct, secure, scalable, and reliable. (The other two are TDD enforcement at commit time — Rules 12/13/14 — and Akali QA at user-flow PRs — Rule 16.) Today the reviewer roster is:

- **Senna** (`.claude/agents/senna.md`) — code-quality + security reviewer, Opus high (the agent-def header reads `model: opus`, `effort: high`), tools include Bash/Read/Edit/Write/Glob/Grep/Agent/WebSearch/WebFetch.
- **Lucian** (`.claude/agents/lucian.md`) — plan/ADR fidelity reviewer, Opus medium, same tool surface.
- **Camille** (`.claude/agents/camille.md`) — git/security advisor, Opus medium, advisory only, not on the standing PR-review dispatch path.

The lane split (Senna = code, Lucian = plan-fidelity) was independently validated on PRs #63/#64/#65: Senna found a real fork-bomb risk and an idempotency bug in the feedback system (`agents/senna/learnings/2026-04-25-pr63-feedback-system-g1-fork-bomb-and-idempotency.md`), Senna found a rollup formula bug on #64, and Lucian caught contract drift across the architecture-wave-2 cross-references on #65 (`agents/lucian/learnings/2026-04-25-pr65-architecture-wave2-lock-bypass-path-drift.md`). Zero overlap, perfect lane discipline. The lane split is **out of scope** for this ADR; it is working as designed.

What is in scope: **everything around the lanes**. Tooling/plugin gap, per-dimension coverage explicitness, escalation paths, agent-def amendments, anti-patterns, reviewer-audit loop, and Camille's role. Duong's directive: PR review (together with QA) is what ensures the final result not just works but works **securely, scalably, and reliably**. The reviewers must have the best tools and clearest guidelines available, and we must be able to know they are doing a good job.

The retired-agents archive (`.claude/_retired-agents/*.md`) shows that prior reviewer roles (Lissandra, Fiora, Ornn, Katarina) were wired with `coderabbit:code-review`, `coderabbit:autofix`, `pr-review-toolkit:review-pr`, and `superpowers:code-reviewer` plugin skills. **Senna and Lucian today have none of those plugin skills declared in their `tools:` lists** — they operate on raw Read/Bash/Grep/WebFetch. This is a genuine surface gap that this ADR addresses.

We are pre-canonical-v1-lock (Saturday ship). The amendments here are intentionally additive (new shared primitive, new checklists, new escalation rules) rather than restructural — so they are absorbable on the canonical-v1 timeline without destabilizing the lane split that is currently working.

## Decision

### D1 — Adopt a `_shared/reviewer-discipline.md` primitive (the canonical reviewer contract)

Create `.claude/agents/_shared/reviewer-discipline.md` and `<!-- include: -->` it from both `senna.md` and `lucian.md` (synced via the existing `scripts/sync-shared-rules.sh`). The primitive codifies the universal reviewer rules that apply to BOTH lanes:

1. **Read the actual file at the cited line before quoting it.** Citing line numbers from `gh pr diff` output without opening the file is forbidden — diff line numbers and file line numbers diverge after rebase or partial-context diffs. Every `path/to/file.ts:NN` citation in a review body must come from a `Read` of that file at the current PR head SHA.
2. **Verify the SHA before re-reviewing.** Run `gh api repos/<owner>/<repo>/pulls/<n> --jq '.head.sha'` before the second pass — cached `gh pr view` output has burned real cycles (see Azir's memory note on stale-view discipline). New tip = re-fetch.
3. **Severity is a contract, not a vibe.** Each finding is one of: `BLOCKER` (merge cannot land), `IMPORTANT` (should-fix, negotiable, reviewer accepts deferral with a tracked follow-up), `NIT` (suggestion only, never blocks). Reviewers must not file nits as blockers (finding-creep) nor file blockers as nits (rubber-stamp adjacent).
4. **Honest verdict, no rubber-stamp.** Approve when the code/plan is fine. Request-changes when it isn't. Comment-only when findings are real but non-blocking. The reviewer never approves to be polite.
5. **Run the code mentally, end-to-end, on at least one representative input.** For non-trivial logic changes, trace the data path through the diff. "I read the diff and it looked fine" is not a review.
6. **Cite the WHY, not just the WHAT.** Every finding states the failure mode it would produce in production (data loss, auth bypass, silent retry storm, etc.) — not just "this is wrong."
7. **Do not file findings outside your lane.** Senna does not opine on plan fidelity; Lucian does not opine on logic bugs. Cross-lane observations are passed to the pair-mate via the review body's `Cross-lane note:` section, which the pair-mate sees on their own dispatch.

The primitive is the durable contract. The per-lane checklists (D2, D3) are the operational expansion.

### D2 — Senna explicit coverage matrix (correctness, security, scalability, reliability, test-quality)

Senna's `## Scope — What You Check` section today is a six-bullet natural-language list. That works for correctness but is too soft for security/scalability/reliability — those dimensions need an explicit walk-through so failure modes are not skipped. Replace the natural-language list with a five-axis checklist Senna explicitly walks per PR:

**Axis A — Correctness** (existing, unchanged): logic bugs, off-by-one, precedence, null/undefined, race conditions, return-value misuse.

**Axis B — Security** (new explicit checklist): authentication path (who can call this?), authorization path (who can call this with what scope?), input validation (where does untrusted input enter? is it validated/escaped before use in SQL, shell, HTML, file paths, URLs?), secrets handling (env vars only, never logged, never in error messages, never in commit), injection surfaces (SQL/shell/template/header), path traversal (`..`, absolute paths, symlinks), CSRF/SSRF (server-side requests with attacker-controlled URLs), deserialization (untrusted JSON/YAML/pickle), dependency CVEs (any new package — surface for Camille if uncertain), TOCTOU races on auth checks. Senna walks ALL of these for any PR touching `apps/**` server-side code, auth, deploy, or IAM.

**Axis C — Scalability** (new explicit checklist): query patterns (N+1? full table scan? missing index?), fanout (does this loop dispatch K subagents/HTTP calls/DB queries linearly in input size?), allocation patterns (quadratic memory? unbounded buffer?), state-coupling (does this hold a lock/connection across an await? does it cache without an eviction policy?), assumed input size (does it work at 10x today's load? 100x?). Senna asks "what breaks at scale?" not "is this fast right now?"

**Axis D — Reliability** (new explicit checklist): error handling (every error path examined — not just `try/catch` swallow), retry/backoff (idempotent? jittered? bounded?), idempotency (can this run twice safely? if it can't, is it gated by a unique constraint or lock?), partial-failure modes (what happens if step 3 of 5 fails — is rollback / compensation / replay handled?), timeouts (every external call has one), circuit-breaking (is there a rate-limit or fail-fast on hot dependencies?), observability (errors logged with enough context to debug post-hoc?). Senna asks "what happens at 3am when this fails halfway?"

**Axis E — Test quality** (existing, sharpened): xfail-first ordering present (Rule 12); regression test for bug fixes (Rule 13); tests actually exercise the claimed behavior (no `expect(true).toBe(true)`); golden files meaningful (no empty fixtures); xfail markers honest (real expected-failure, not a TODO marker); coverage gap surfaced explicitly when a code path is added but not tested.

**Format choice — checklist, not natural-language.** Each axis becomes a concrete bullet list in the agent-def. The checklist is walked but not posted verbatim — Senna posts findings, not a recital of the checklist. The checklist's purpose is the *walk*, not the artifact. (Posting the full checklist on every PR would be noise; the empty-axis case is "no findings on this axis," which Senna implies by silence on it.)

### D3 — Lucian explicit coverage matrix (plan, ADR, contract, deferral, cross-repo)

Same treatment for Lucian's lane. The current six-bullet list becomes a five-axis checklist:

**Axis F — Plan fidelity:** does the PR do exactly what the named task in the plan specifies? Acceptance criteria from the plan re-checked one by one. Scope creep flagged. Silent deferrals flagged.

**Axis G — ADR alignment:** every architectural decision the parent ADR records is honored. Contract invariants checked. Module boundaries respected. Decision Dn that the plan cited as load-bearing is verified actually load-bearing in the diff.

**Axis H — Contract drift:** schemas, APIs, file formats, frontmatter fields, env-var names — anything the ADR promised to downstream consumers is preserved bit-for-bit. Renames, type-widening, default-changes flagged.

**Axis I — Deferral discipline:** if the PR defers something, the deferral is explicit in the PR body, matches the plan's "out-of-scope" list (or extends it with a noted reason), and is tracked as a follow-up (issue, plan-stub, or named task in a successor plan). Silent deferrals are blockers.

**Axis J — Cross-repo / lifecycle coupling:** if work is intentionally split across `strawberry-agents` (plans) vs `strawberry-app` (code) vs `mmp/workspace` (work), the PR respects the boundary; plan promotions go through Orianna (Rule 19); xfail-first ordering on TDD-enabled services (Rule 12); commit-prefix-by-diff-scope (Rule 5).

Same format choice — walked, not recited.

### D4 — Plugin / MCP surface gap analysis & decision

The retired-agents archive declares Lissandra/Fiora/Ornn/Katarina with `coderabbit:code-review`, `coderabbit:autofix`, `pr-review-toolkit:review-pr`, and `superpowers:code-reviewer` plugin skills. Senna and Lucian inherited none of these. The decision:

**D4a — DO add `coderabbit:code-review` and `pr-review-toolkit:review-pr` to Senna only.** Coderabbit is a strong static-analysis pre-pass for the security/scalability axes; pr-review-toolkit gives a structured walk Senna can lean on for the explicit-checklist mode in D2. Add to Senna's frontmatter `tools:` list. Lucian does NOT get these — plan fidelity is not a static-analysis problem and the noise would dilute her lane.

**D4b — DO NOT wire `snyk` or `gitleaks` as Senna MCP servers.** `gitleaks` is already enforced at pre-commit (`scripts/install-hooks.sh`) and at CI (`.github/workflows/`) — adding it to Senna's surface would duplicate the gate without adding signal. `snyk` requires a paid token and runs at the org level — it belongs in CI, not in a per-PR reviewer's tool surface. The reviewer's job is to catch what static tools miss; doubling up the static tools at the reviewer is anti-leverage.

**D4c — DO add `semgrep` as a Senna invocation pattern, not as an MCP server.** Senna may invoke `semgrep --config=auto <changed-paths>` via Bash on PRs that touch security-sensitive surfaces (auth, deploy, IAM, anything under `apps/**/server/`). Semgrep findings are inputs to Senna's review, not a verdict. This is documented in the Senna agent-def as a security-axis tool, not a plugin.

**D4d — DO add `superpowers:code-reviewer` to BOTH Senna and Lucian.** The skill's discipline (read the file, cite the why, separate severities) reinforces D1. It is the closest match to the `_shared/reviewer-discipline.md` primitive and acts as a redundant prompt-level reinforcement.

### D5 — Escalation paths (when a reviewer dispatches a sibling)

Senna and Lucian today operate as terminal lanes — they do not dispatch siblings. That is the wrong default for a few specific cases:

**E1 — Senna sees a security issue she cannot classify or whose blast radius she cannot bound.** Examples: a novel auth pattern she has not reviewed before, a deserialization surface with unclear input provenance, a cryptographic primitive she cannot verify is correctly applied. **Action:** Senna dispatches **Camille** as an `effort: medium` advisory subagent with the PR number, the specific surface, and her uncertainty. Camille returns a security verdict (BLOCK / NEEDS-MITIGATION / OK) which Senna folds into her review. Senna remains the verdict-of-record on the PR; Camille is consulted, not delegated to.

**E2 — Senna sees a scalability concern that depends on architectural assumptions outside the diff.** Examples: a query pattern that's fine at 10x today's load but breaks at 100x given the planned migration; a fanout pattern that was acceptable in v0 but not in the canonical-v1 deploy footprint. **Action:** Senna files the finding as `IMPORTANT` (not BLOCKER), tags `[escalate: azir]` in the review body, and the coordinator picks it up as a separate Azir architecture review on a follow-up cycle. Senna does not block the PR on architectural questions she cannot answer.

**E3 — Lucian sees a plan-fidelity gap that is structural (the plan itself is wrong, not the implementation).** Examples: the plan's Dn says one thing but the parent ADR contradicts it; the plan was written against a stale invariant. **Action:** Lucian files the finding as `IMPORTANT` (not structural-block), tags `[escalate: swain|azir]` in the review body, and the coordinator dispatches Swain or Azir to revise the plan/ADR. The PR may proceed if the implementation honors the plan-as-written (Lucian's lane is fidelity to the plan, not correctness of the plan).

**E4 — Lucian sees an ADR contract drift that requires a new ADR amendment.** **Action:** Lucian files BLOCKER, tags `[escalate: azir]`, the coordinator dispatches Azir to author an ADR amendment, and the PR holds until the amendment lands.

These four patterns are codified in the per-agent definitions under a new `## Escalation` section.

### D6 — Camille on the dispatch path for security-sensitive PRs

Camille's role today is "git/security advisor — advice and assessment only." She is not on the standing PR-review dispatch. The decision:

**D6a — Camille remains advisory, NOT a parallel reviewer.** Adding Camille as a third standing lane would duplicate the security axis Senna already owns (Axis B in D2) and slow every PR. The lane split stays Senna + Lucian.

**D6b — Camille IS dispatched on coordinator-level for security-blast-radius PRs.** The coordinator (Sona/Evelynn) dispatches Camille in parallel with Senna+Lucian when the PR touches: auth code, IAM/permissions config, deploy scripts (`scripts/deploy/**`, `.github/workflows/`), secret-handling code, the `tools/decrypt.sh` family, branch-protection or CODEOWNERS changes, agent-identity boundaries (reviewer-auth, gh-auth-guard, plan-lifecycle-guard). Detection: PR labels (`security`, `auth`, `deploy`) OR diff-scope match (paths in the list above). The coordinator-side detection is added to the standing dispatch heuristic.

**D6c — Camille's verdict is advisory; Senna remains verdict-of-record for the security axis.** When Camille and Senna agree, fast path. When they disagree, the coordinator escalates to Duong; agents do not auto-resolve security disagreements between reviewer and advisor.

### D7 — Anti-patterns explicitly forbidden (in `_shared/reviewer-discipline.md`)

Codified, named, blocked:

- **Rubber-stamp APPROVE** — approving without findings on a non-trivial diff. Reviewer must produce either findings or an explicit "I walked the five axes; no findings" statement.
- **Finding-creep** — filing nits as blockers to look thorough. Severity discipline per D1.3.
- **Phantom citation** — quoting `path/file.ts:NN` without opening the file. Banned by D1.1.
- **Stale-SHA review** — re-reviewing without re-fetching head SHA. Banned by D1.2.
- **Lane bleed** — Senna opining on plan fidelity, Lucian opining on logic bugs. Pass via `Cross-lane note:` instead.
- **Vibe verdict** — "looks good to me" without walking the axes. Reviewer must cite at least one walked axis even on APPROVE.
- **Self-approval bypass** — using `gh pr merge --admin` or skipping required reviewer identity (Rule 18). Already universal-rule; named here for reviewer-context emphasis.
- **AI-attribution leak** — any agent name or AI marker in the review body. Already universal-rule (Rule 21); named here for reviewer-context emphasis.

### D8 — Reviewer-of-reviewer audit loop

The retrospection dashboard (`plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md`, v2) tracks subagent dispatches by `subagent_type` and outcome. Extend it with a **reviewer-quality panel** that surfaces:

- **Reviewer-found-vs-missed-bug ratio** — for each merged PR, was a post-merge bug found by prod smoke (Rule 17), staging E2E (Rule 15), or a follow-up PR within 14 days? If yes, did Senna's review on the original PR mention the failure surface? `mentioned-and-flagged` / `mentioned-but-classified-too-low` / `not-mentioned` are the three buckets. Rolling 90-day average per reviewer.
- **Severity calibration drift** — what fraction of Senna's BLOCKER findings actually blocked? What fraction of her NIT findings were later revealed as load-bearing? Calibration drift over time is the signal.
- **Lane-bleed rate** — how often did Senna file plan-fidelity findings, or Lucian file logic-bug findings? Should trend to zero.
- **Mean-time-to-review** — dispatch-to-verdict latency per reviewer. Slow reviews block ship; fast reviews that miss bugs are worse than slow reviews.

The panel is implemented as part of the dashboard v2 phase, not in this ADR — this ADR only specifies the data we want surfaced. The data is already captured (`subagents/agent-<id>.{jsonl,meta.json}` per Azir's memory note); the work is the panel UI + the post-merge-bug correlation logic.

Manual audit cadence in the meantime: Duong runs a monthly spot-check on five random closed PRs from the prior month — was the reviewer's verdict calibrated against what shipped? Findings logged to `assessments/YYYY-MM-DD-reviewer-audit.md`. This is the human-loop bridge until the panel exists.

### D9 — Agent-def amendments (concrete edits)

**Senna (`.claude/agents/senna.md`):**
1. Replace the existing `## Scope — What You Check` section with the five-axis checklist from D2 (each axis as a sub-section with bulletpoint failure modes).
2. Add `## Escalation` section codifying E1, E2 from D5.
3. Add `<!-- include: _shared/reviewer-discipline.md -->` after the existing no-ai-attribution include.
4. Add to frontmatter `tools:` list: `coderabbit:code-review`, `pr-review-toolkit:review-pr`, `superpowers:code-reviewer`. (`semgrep` is invoked via Bash, not declared as a tool.)
5. Add a paragraph in the new `## Tools` section pointing at semgrep as a security-axis Bash invocation.

**Lucian (`.claude/agents/lucian.md`):**
1. Replace the existing `## Scope — What You Check` section with the five-axis checklist from D3.
2. Add `## Escalation` section codifying E3, E4 from D5.
3. Add `<!-- include: _shared/reviewer-discipline.md -->` after the existing no-ai-attribution include.
4. Add to frontmatter `tools:` list: `superpowers:code-reviewer`. (Not coderabbit/pr-review-toolkit — wrong lane per D4a.)

**Camille (`.claude/agents/camille.md`):**
1. Add `## When you are dispatched on a PR` section codifying D6b (the diff-scope detection list and the verdict shape: BLOCK / NEEDS-MITIGATION / OK).
2. Make explicit that Camille's verdict on a PR is advisory to Senna, not a parallel reviewer — Senna remains verdict-of-record per D6c.

**New file `.claude/agents/_shared/reviewer-discipline.md`:**
- Codifies D1 (seven universal reviewer rules) and D7 (eight anti-patterns) verbatim. Synced into both senna.md and lucian.md by `scripts/sync-shared-rules.sh`.

**Coordinator-side (Evelynn / Sona dispatch logic):**
- Update the standing PR-review dispatch heuristic to detect security-blast-radius PRs (D6b list) and dispatch Camille in parallel with Senna+Lucian. Does NOT require an agent-def change to Evelynn/Sona — the heuristic lives in the coordinator's CLAUDE.md or routing-check shared primitive. Implementation detail for the breakdown phase.

### D10 — What is explicitly NOT changing

- **The Senna+Lucian lane split.** Stays as designed. Today's PR #63/#64/#65 evidence shows the split is producing zero overlap and high signal per lane.
- **The reviewer-auth concern-split.** Senna stays on `strawberry-reviewers-2`, Lucian on `strawberry-reviewers`, both via `scripts/reviewer-auth.sh` on personal concern. Work-concern path unchanged.
- **Rule 18.** No reviewer self-approves. No `--admin` bypass. Universal.
- **The PR template.** Out of scope (parallel QA ADR handles that).
- **QA pipeline (Akali).** Out of scope (parallel ADR `2026-04-25-qa-two-stage-architecture.md`); cross-referenced for reviewer/QA seam coherence but not amended here.

## Tradeoffs

1. **Checklist vs natural-language scope.** Checklists are heavier on prompt tokens and risk becoming a recital ritual that hides actual judgment. Mitigated by D2's "walked but not posted" rule — the checklist is reviewer-private, the review body remains finding-driven.
2. **Plugin additions to Senna.** Adding `coderabbit` + `pr-review-toolkit` adds dispatch surface and possibly latency. Justified because the retired-agents archive shows these were standard equipment for the prior reviewer roster, and Senna/Lucian's lack of them is a regression we did not consciously decide to take.
3. **Camille on the security-blast-radius dispatch path.** Adds a third dispatch on ~10–20% of PRs. Mitigated by keeping Camille advisory (verdict-of-record stays Senna) and by gating on a diff-scope heuristic (not every PR).
4. **Reviewer-of-reviewer audit panel.** Real engineering work to correlate post-merge bugs back to the originating PR review. Justified because without it, "are the reviewers doing a good job?" is a vibe question; this ADR's whole premise is the reviewers are the gate, and we cannot trust a gate we cannot measure.
5. **Manual audit bridge.** Five PRs per month is a small sample, but it is a non-zero feedback loop until the panel exists. Better than waiting for the panel.

## Acceptance Criteria

1. `.claude/agents/_shared/reviewer-discipline.md` exists and is `<!-- include: -->`'d into both senna.md and lucian.md.
2. Senna's agent-def has the five-axis checklist (A–E), the escalation section (E1, E2), and the new tool entries (`coderabbit:code-review`, `pr-review-toolkit:review-pr`, `superpowers:code-reviewer`).
3. Lucian's agent-def has the five-axis checklist (F–J), the escalation section (E3, E4), and the new tool entry (`superpowers:code-reviewer`).
4. Camille's agent-def has the `## When you are dispatched on a PR` section codifying the security-blast-radius dispatch contract.
5. The coordinator dispatch heuristic detects security-blast-radius PRs and dispatches Camille in parallel with Senna+Lucian on those.
6. The reviewer-quality panel is specced for dashboard v2 (not implemented in this ADR; tracked as follow-up).
7. The first manual reviewer audit lands at `assessments/YYYY-MM-DD-reviewer-audit.md` within 30 days of approval.
8. `scripts/sync-shared-rules.sh` propagates the new shared primitive without diverging copies between senna.md and lucian.md.
9. No regression in lane discipline — Senna does not start opining on plan fidelity, Lucian does not start opining on logic bugs. Verified on the next 10 PRs after rollout.

## Out of Scope

- Lane split changes (Senna stays code, Lucian stays plan).
- Implementation breakdown — Kayn handles.
- QA pipeline / Akali — parallel ADR.
- PR template changes — parallel QA ADR.
- Dashboard v2 panel implementation — separate plan once dashboard v1 lands.
- New reviewer agent roles — none added; Camille promoted to dispatch-conditional, not added as a third lane.

## Follow-ups

1. Kayn breakdown into Aphelios-implementable tasks (shared primitive, three agent-def edits, coordinator heuristic, sync-script verification).
2. Dashboard v2 panel for reviewer-quality metrics (separate plan, after dashboard v1).
3. First manual reviewer-audit assessment (Duong, within 30 days post-approval).
4. Cross-coherence review with the QA two-stage ADR — confirm Senna's role-extension to QA-diagnose-on-FAIL (in the QA ADR) does not conflict with Senna's PR-reviewer five-axis load here. (Likely fine; both jobs use the same tool surface and disposition. Worth a Lucian fidelity pass once both ADRs are in `approved/`.)
