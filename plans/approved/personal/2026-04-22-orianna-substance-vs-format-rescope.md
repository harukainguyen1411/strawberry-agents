---
status: approved
concern: personal
owner: swain
created: 2026-04-22
complexity: complex
orianna_gate_version: 2
tests_required: true
tags: [orianna-gate, plan-lifecycle, scripts, hooks, governance, rescope]
related:
  - plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md
  - plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md
  - plans/approved/personal/2026-04-21-plan-prelint-shift-left.md
  - feedback/2026-04-21-orianna-signing-latency.md
  - feedback/2026-04-21-orianna-signing-followups.md
  - architecture/plan-lifecycle.md
  - agents/orianna/claim-contract.md
  - agents/orianna/allowlist.md
  - agents/orianna/prompts/plan-check.md
  - agents/orianna/prompts/task-gate-check.md
  - agents/orianna/prompts/implementation-gate-check.md
orianna_signature_approved: "sha256:a76395d7e3678a6e5856aebd60e2932cd99aac3452371b494fea1f13d92c2d7f:2026-04-22T06:56:22Z"
orianna_signature_in_progress: "sha256:a76395d7e3678a6e5856aebd60e2932cd99aac3452371b494fea1f13d92c2d7f:2026-04-22T07:06:28Z"
---

# Orianna — substance-vs-format rescope

## 1. Problem & motivation

Orianna's current check set mixes **substance gating** (does the plan actually do what it claims; are required tests/docs present; do cited paths resolve) with **format gating** (is every backtick token on the allowlist or individually suppressed; do prose examples that look path-shaped pass `test -e`; are section headings literal-matched including numbering). The mix is inverting the value of the gate.

Concrete evidence from the current corpus at the time of writing:

- `assessments/plan-fact-checks/2026-04-21-demo-studio-v3-e2e-ship-v2-2026-04-21T09-50-32Z.md` — **10 block findings**, each one a distinct HTTP route path (`/build`, `/verify`, `/logs`, `/approve`) flagged because the route tokens were routed to the work monorepo root and failed `test -e`. None of these pointed at a real defect in the plan.
- `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-15-40Z.md` — **12 block findings**, each a cluster of HTTP routes (`POST /auth/login`, `/auth/session/{sid}`), Python identifiers (`ds_session`, `require_session`, `firebase-admin.auth.verify_id_token`), or ASCII diagram tokens inside fenced code blocks. Recovery required the author to add ~20 per-line `<!-- orianna: ok -->` markers; no substantive claim changed.
- `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-28-28Z.md` (the eventual clean pass) — 0 block, 0 warn, 6 info. The only delta from the red run was cosmetic suppression markers. No design claim shifted.
- `assessments/plan-fact-checks/2026-04-22-explicit-model-on-agent-defs-2026-04-22T02-34-14Z.md` — 1 block at the `implementation-gate-check` phase because the plan declared `architecture_impact: none` in frontmatter but omitted the `## Architecture impact` section body. This is **substance gating working correctly** — a declared-none assertion that carries no body-text rationale should be caught.

Paired with Sona's two feedback docs (`feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-orianna-signing-followups.md`), the dominant cost pattern is ~30 min of wall time per signing session with iteration counts of 2–3 per ADR per phase; the majority of that cost is format-resolvable. Agents spend time placating the gate rather than improving the plan.

The adjacent plan `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md` addresses mechanical latency (body-hash pre-commit guard, signed-fix commit shape, stale-lock recovery, §D3 shape enforcement). It does **not** rescope the check set — every fix there is still inside the current taxonomy. This plan is the missing companion: same goal (reduce signing friction), different lever (prune the check set instead of making the current set faster to satisfy).

### Duong's directive (verbatim intent from the task prompt)

Orianna should gate on **substance**, not **format**.

**Keep rigorous:**
- Required tests exist (xfail-first per CLAUDE.md Rule 12, regression tests per Rule 13).
- Docs updated/created when the change demands them (`architecture/`, CLAUDE.md rules, PR template). <!-- orianna: ok -->
- File paths referenced in claims are correct (not stale, not cross-repo-broken).
- Plan completeness — declared scope is actually covered.

**Relax or drop:**
- Cosmetic formatting (whitespace, markdown style, heading levels).
- Exact-phrase anchor matching when a semantic match exists.
- Claim-wording variations that don't change meaning.
- Forward-ref false positives on outputs the plan itself will produce.

This plan operationalizes that directive as a concrete check-taxonomy rescope.

---

## 2. Decision

Rescope the Orianna check set along a **substance-vs-format axis**. Each check in the current taxonomy is classified as:

- **KEEP** — substance; remains a hard `block` gate.
- **WARN** — useful signal but not load-bearing; demoted to `warn` severity (surfaces in the report, does not halt promotion).
- **DROP** — format-only or redundant with the pre-commit structural linter; removed from the gate entirely.

No change to the signature mechanism (SHA-256 body hash, git author identity, trailers, verification script). No change to the phase sequencing (proposed → approved → in-progress → implemented). No change to the `Orianna-Bypass:` admin-only escape hatch. No change to the grandfathering field `orianna_gate_version: 2`. **Only the check set inside the three phase prompts and the two library functions moves.**

The rescope preserves the tamper-evidence and phase-carry-forward properties. What changes is **what counts as a block finding**.

### Scope — out

- Prompt rewrites unrelated to the substance-vs-format axis (e.g. new external-claim categories).
- Changes to `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, `scripts/orianna-hash-body.sh`, or `scripts/plan-promote.sh` — the signing/verification machinery stays.
- Changes to the pre-commit linter `scripts/hooks/pre-commit-zz-plan-structure.sh` — the shift-left linter is out of scope; its five rules continue to run at commit time. (Indirect effect: some Orianna checks that drop here may coincidentally overlap the linter; that duplication was already the design per the split-of-responsibilities table in `architecture/plan-lifecycle.md` §Split of responsibilities.)
- Changes to the `concern: work` resolution-root flip — the routing remains as-is; this plan only changes how misses are classified.
- Re-signing of already-signed plans — addressed in §7 (grandfathering).

---

## 3. Design

### 3.1 Classification axis

A check is **substance** if its absence or failure would allow a plan to land with a real defect — something a downstream implementer or reviewer would have to discover the hard way (missing test, broken reference to a file that doesn't exist, missing architecture doc update when the change demands one, declared-none assertion with no justification body).

A check is **format** if its absence or failure blocks a plan that is otherwise architecturally sound, solely because the rendering or token distribution doesn't match the extractor's heuristic. HTTP route tokens routed as filesystem paths, Python identifiers flagged as integration names, ASCII diagram tokens inside fenced code blocks, exact-phrase heading variants — all format.

A check is **duplicate** if the pre-commit structural linter (`scripts/hooks/pre-commit-zz-plan-structure.sh`) already enforces the same invariant at commit time. Duplicate checks can be dropped from Orianna without loss of coverage because the linter is strictly upstream: anything it catches never reaches Orianna.

### 3.2 Current check taxonomy — enumerated

Enumerated by source file, with classification and proposed disposition. Every check below is a present-day block-capable finding path.

**Source: `agents/orianna/prompts/plan-check.md` (proposed → approved gate)**

| # | Check | Category | Classification | Disposition |
|---|-------|----------|----------------|-------------|
| PA-1 | Step A — `status: proposed` exact match | Format | Duplicate with linter (`status:` frontmatter check) + trivial | WARN (signal, not block) |
| PA-2 | Step A — `owner:` present, non-blank | Substance | Ownership is load-bearing for accountability | KEEP |
| PA-3 | Step A — `created:` present, non-blank | Format | Date provenance; rarely load-bearing | WARN |
| PA-4 | Step A — `tags:` present, non-blank | Format | Tagging is organizational, not correctness | WARN |
| PA-5 | Step B — gating-question scan (`TBD` / `TODO` / `Decision pending` in `## Open questions` / `## Gating questions` / `## Unresolved`) | Substance | Open gating Qs on an `approved` plan = the decision is not yet taken | KEEP |
| PA-6 | Step C — path-shaped backtick token, routed, `test -e` miss | Mixed | Keep for `agents/`, `plans/`, `scripts/`, `architecture/`, `assessments/`, `.claude/`, `tools/decrypt.sh`, `tools/encrypt.sh` (all are internal references where misses indicate real stale claims). DROP for all other path-shapes — too many false positives on HTTP routes, Python dotted identifiers, template tokens, etc. | SPLIT (see §3.3) | <!-- orianna: ok -->
| PA-7 | Step C — path-shaped token inside a fenced code block | Format | Fenced blocks are almost always illustrative (diagrams, example shell, pseudocode) | DROP |
| PA-8 | Step C — integration-shaped token off allowlist | Substance | The original Firebase-GitHub-App motivator | KEEP (unchanged) |
| PA-9 | Step C — integration-shaped token in Section 2 of allowlist without anchor | Substance | Specific integrations still require anchors | KEEP |
| PA-10 | Step D — sibling `<basename>-tasks.md` / `-tests.md` file under `plans/` | Substance | One-plan-one-file rule; a sibling indicates the plan isn't actually complete inline | KEEP | <!-- orianna: ok -->
| PA-11 | Step E — cited URL HTTP 410 / deprecation redirect | Substance | Library/API has been sunset | KEEP |
| PA-12 | Step E — context7 @deprecated symbol at cited version | Substance | Same | KEEP |
| PA-13 | Step E — cited URL HTTP 404 / DNS failure | Mixed | Already at `warn` severity (not block); no change | KEEP-AS-WARN |
| PA-14 | Step E — library major-version bump with plan pinning no version | Format | Expected state for most plans | KEEP-AS-WARN |
| PA-15 | Step E — WebSearch contradicting without authoritative source | Format | Weak signal | KEEP-AS-WARN |
| PA-16 | Step E — budget exhausted | Format | Budget is a cost ceiling, not a signal | KEEP-AS-WARN |

**Source: `agents/orianna/prompts/task-gate-check.md` (approved → in-progress gate)**

| # | Check | Category | Classification | Disposition |
|---|-------|----------|----------------|-------------|
| TG-1 | Step A — `## Tasks` section exists, non-empty | Substance | A plan being signed for in-progress without tasks is malformed | KEEP |
| TG-2 | Step B — every `- [ ]` task entry has `estimate_minutes:` | Format | Duplicate with pre-commit linter rule 2 | DROP (covered by linter) |
| TG-3 | Step B — `estimate_minutes` integer in [1, 60] | Format | Duplicate with linter rule 2 | DROP (covered by linter) |
| TG-4 | Step B — banned unit literals `hours`/`days`/`weeks`/`h)`/`(d)` | Format | Duplicate with linter rule 2 | DROP (covered by linter) |
| TG-5 | Step C — test task present when `tests_required: true` (kind:test or title matches write/add/create/update .* test) | Substance | Rule 12 TDD invariant | KEEP |
| TG-6 | Step D — `## Test plan` section present and non-empty when `tests_required: true` | Substance | Rule 12 / Rule 13 foundation | KEEP |
| TG-7 | Step E — sibling `-tasks.md` / `-tests.md` under `plans/` | Substance | Same as PA-10 | KEEP | <!-- orianna: ok -->
| TG-8 | Step F — `orianna_signature_approved` present + valid | Substance | Carry-forward invariant | KEEP |

**Source: `agents/orianna/prompts/implementation-gate-check.md` (in-progress → implemented gate)**

| # | Check | Category | Classification | Disposition |
|---|-------|----------|----------------|-------------|
| IG-1 | Step A — every path-shaped claim resolves on the current tree | Mixed | Same split as PA-6: KEEP for internal-prefix tokens (real stale-claim signal), DROP for HTTP routes / fenced tokens / identifiers | SPLIT (see §3.3) |
| IG-2 | Step B — architecture declaration: `architecture_changes:` list with each path existing + git-log after approved timestamp | Substance | Rule: docs updated when change demands it | KEEP |
| IG-3 | Step B — architecture declaration: `architecture_impact: none` + non-empty `## Architecture impact` section | Substance | Declared-none with no rationale is a gap, not a pass | KEEP |
| IG-4 | Step C — `## Test results` section with CI URL or `assessments/` path | Substance | Rule 12: test results must be recorded | KEEP | <!-- orianna: ok -->
| IG-5 | Step D — `orianna_signature_approved` carry-forward | Substance | Carry-forward invariant | KEEP |
| IG-6 | Step E — `orianna_signature_in_progress` carry-forward | Substance | Carry-forward invariant | KEEP |

**Source: `scripts/_lib_orianna_architecture.sh` (delegate of IG-2 / IG-3)**

| # | Check | Category | Classification | Disposition |
|---|-------|----------|----------------|-------------|
| ARC-1 | Listed `architecture_changes:` path exists on disk | Substance | KEEP (unchanged) |
| ARC-2 | Listed path has git commit after approved-signature timestamp | Substance | KEEP (unchanged) |
| ARC-3 | `architecture_impact: none` + non-empty `## Architecture impact` body | Substance | KEEP (unchanged) |

**Source: `scripts/_lib_orianna_estimates.sh` (delegate of TG-2 / TG-3 / TG-4)**

With TG-2/TG-3/TG-4 dropped from Orianna in favor of the pre-commit linter, the lib remains used by the linter itself (`scripts/_lib_plan_structure.sh` sources it). **No deletion; only one caller removed.**

**Source: `scripts/fact-check-plan.sh` (bash fallback when `claude` CLI is unavailable)**

The fallback mirrors the LLM path's claim-contract. Every check it performs is a subset of the PA-6/PA-7 path-shaped-token logic. It must be rescoped in lockstep with the prompt change — see §3.3.

**Source: `agents/orianna/claim-contract.md` §1–§6**

This file is the authoritative spec for what counts as a claim. The rescope requires editing §1 (claim categories), §2 (non-claim categories), §5 (routing rules), and §6 (extraction heuristic) to encode the new split. Specifically:

- §1: Introduce a sub-classifier on path-shaped tokens — "internal-repo-prefix path" (the opt-back list) vs "arbitrary path-shaped token." Only the former is load-bearing.
- §2: Add explicit non-claim categories for HTTP route tokens (`/auth/login`, `GET /foo`, etc.), Python/TypeScript dotted identifiers (`module.function`, `ClassName.method`), ASCII diagram tokens inside fenced code, template placeholders with nested braces (`{uid, email, iat}`). <!-- orianna: ok -->
- §5: Keep routing but change the miss severity from `block` → `info` for non-internal-prefix tokens under `concern: work`.
- §6: Drop extraction from fenced code blocks entirely (replace with: code blocks are illustrative; authors opt in to checking via `<!-- orianna: ok -->` at fence-start, which stays suppression-only, never triggers a check).

**Source: `agents/orianna/allowlist.md`**

No content change; the allowlist's purpose (vendor bare names pass without anchors) is preserved. The churn of adding common identifiers to Section 1 is exactly the workaround pattern that motivated the rescope. Keeping Section 1 small remains the right posture.

### 3.3 The path-shape check — split in detail

PA-6 / IG-1 / the bash fallback all perform the same operation: extract every backtick-quoted path-shaped token, route it, `test -e`. The split:

**New rule set (applies under both personal and work concerns):**

1. **Internal-prefix path tokens** — tokens beginning with `agents/`, `plans/`, `scripts/`, `architecture/`, `assessments/`, `.claude/`, `tools/decrypt.sh`, `tools/encrypt.sh`, or (under `concern: personal`) `apps/`, `dashboards/`, `.github/workflows/`. These are references to this repo's own infrastructure or, for the personal concern, the strawberry-app checkout. A miss on these is a real stale-claim signal. <!-- orianna: ok -->
   - **Miss severity:** `block` (unchanged from today).
   - **Rationale:** the overwhelming majority of stale internal refs caught by today's gate are here, and the cost of a false positive is trivially fixable (rename, suppress, or fix the reference).

2. **All other path-shaped tokens** — HTTP routes (`/auth/login`, `POST /foo`, `GET /bar`), workspace-monorepo paths under `concern: work` that fall outside the opt-back list, dotted identifiers containing `/` (rare), template literals (`{uid}/{sid}`), etc. <!-- orianna: ok -->
   - **Miss severity:** `info` (downgraded from `block`).
   - **Rationale:** today's false-positive pattern is almost exclusively this class. Converting to `info` makes the finding visible in the report but non-blocking. The pre-commit linter (rule 4) continues to catch genuinely-broken **internal** paths at commit time.
   - **Suppression:** authors may still use `<!-- orianna: ok -->` for self-documentation, but it becomes optional rather than mandatory.

3. **Fenced code block tokens** — no extraction. Fenced blocks (```` ``` ````) are illustrative (diagrams, pseudocode, example shell, state-machine literals). Extraction-from-fences was the single largest source of reported noise in the firebase-auth and demo-studio-v3 ADRs. Authors who want fenced content checked can move it outside the fence.
   - **Change:** `extract_tokens()` in `scripts/fact-check-plan.sh` and the Step C instructions in `agents/orianna/prompts/plan-check.md` stop iterating fenced-block lines.
   - **Rationale:** the cost-benefit flipped. Zero documented cases of a real stale internal claim being caught *only* inside a fenced block; many documented cases of false positives from fenced content.

4. **Suppression-marker semantics** — unchanged. The `<!-- orianna: ok -->` marker still suppresses per-line per claim-contract §8. Its frequency of use falls substantially because fewer lines are even checked.

### 3.4 Operational surface — warn still shows up

Per the task brief's operational concern: a check demoted from `block` to `warn` still shows up in the CI output. The gate report already has three sections (`## Block findings`, `## Warn findings`, `## Info findings`) and is always written to disk under `assessments/plan-fact-checks/`. `scripts/orianna-fact-check.sh` exit codes are driven by `block_findings` only, so a `warn` or `info` does not halt promotion. Agents triage by reading the report; Duong's visibility is preserved. <!-- orianna: ok -->

No CI-visible change is needed — the report structure already supports it. The promotion script's stderr emits block/warn/info counts (see `scripts/fact-check-plan.sh:442`), which surfaces the warn count without failing. <!-- orianna: ok -->

### 3.5 Rescope in summary — check-set delta

| Kept as block | Demoted to warn | Dropped (covered elsewhere or illustrative) |
|---|---|---|
| PA-2, PA-5, PA-6 (internal prefixes), PA-8, PA-9, PA-10, PA-11, PA-12 | PA-1, PA-3, PA-4, PA-13, PA-14, PA-15, PA-16 (all already warn), PA-6 (non-internal prefixes) | PA-7 (fenced extraction), TG-2, TG-3, TG-4 |
| TG-1, TG-5, TG-6, TG-7, TG-8 | — | — |
| IG-1 (internal prefixes), IG-2, IG-3, IG-4, IG-5, IG-6, ARC-1, ARC-2, ARC-3 | IG-1 (non-internal prefixes) | — |

**Net block-capable check count:** 28 → 21. **Net demoted-to-warn:** 7. **Net dropped:** 4 (1 extractor change + 3 estimate-unit duplicates).

---

## 4. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Demoting non-internal path-shape misses from `block` → `info` silently accepts genuinely-broken external references that someone later has to chase down. | Evidence from the four weeks of gate history: zero cases where such a finding corresponded to a real bug that wouldn't have been caught by either (a) implementation tests, (b) the pre-commit linter for internal paths, or (c) Step E external-claim verification. The class being demoted is precisely the class that produces false positives — HTTP routes, diagram tokens, dotted identifiers. Internal paths stay at `block`. |
| Dropping extraction from fenced code blocks means a diagram that cites a real missing path won't be caught. | Architecture diagrams and state machines name paths that the plan itself *creates*. The in-progress → implemented gate's IG-1 re-check on the current tree catches any path claim that didn't materialize. Pre-commit linter rule 4 also re-checks cited paths. Two layers cover the gap. |
| Dropping `estimate_minutes` validation from Orianna (TG-2/TG-3/TG-4) means the pre-commit linter is the sole enforcer. | The pre-commit linter is strictly upstream of Orianna (it runs at `git commit`, Orianna runs at promote time). If the linter passes, Orianna re-validating the same invariant is tautological. If the linter is ever disabled or regressed, TG-2/TG-3/TG-4 in the prompts are fast to re-enable (one paragraph restoration). Low reversibility cost. |
| The `claim-contract.md` change could be read as "Orianna is softer now" and erode the gate's value. | The `block`-capable checks after rescope are all load-bearing: missing owner, unresolved gating questions, stale internal paths, missing tests, missing architecture declaration, missing test results, invalid signatures, un-allowlisted integrations. The softening is exclusively on format-only classes that were not catching real defects. Duong decision log in §10 OQ-1 records the scope. | <!-- orianna: ok -->
| Authors may treat `warn` findings as "ignore me" and let genuine stale refs accumulate. | Keep `warn` findings visible in the promote-script stderr summary (already implemented). Quarterly memory-audit (separate, existing runbook `scripts/orianna-memory-audit.sh`) can optionally sample `warn` findings for escalation; add this as a follow-up if warn-drift is observed. |
| Changing `claim-contract.md` invalidates existing signatures via body-hash (the contract is referenced in plan bodies). | The claim-contract itself is not part of any plan's body hash — it's a separate file under `agents/orianna/`. Signatures hash only the plan file's body. No signature invalidation. | <!-- orianna: ok -->

---

## 5. Deltas — concrete change manifest

The implementer(s) of this plan must produce the following edits. Each is bite-sized; each is independent.

### 5.1 Prompt: `agents/orianna/prompts/plan-check.md`

1. **Step A** — demote PA-1 (`status: proposed`), PA-3 (`created:`), PA-4 (`tags:`) from block to warn. Keep PA-2 (`owner:`) at block. Edit §Step A wording to distinguish block-level (owner only) from warn-level (status/created/tags).
2. **Step C** — add a new sub-heading "Path-shape classification": split internal-prefix paths (block on miss) from all others (info on miss). Enumerate the internal-prefix list explicitly (same list as `claim-contract.md` §5b inverted). <!-- orianna: ok -->
3. **Step C** — remove the fenced-code-block iteration instruction. Replace with a one-paragraph note that fenced blocks are illustrative and not extracted; authors can move content out of the fence if they want it checked.
4. **Step E** — no change. Severity mapping already has the right shape (most external checks are `info` or `warn`; only sunset/deprecation is `block`).
5. **Report format** — no schema change; `block_findings` / `warn_findings` / `info_findings` counts adjust naturally.

### 5.2 Prompt: `agents/orianna/prompts/task-gate-check.md`

1. **Step B** — delete entirely. Note in its place that `estimate_minutes` validation is handled by the pre-commit linter (`scripts/hooks/pre-commit-zz-plan-structure.sh`) and is not re-checked at sign time.
2. Renumber subsequent Steps C → B, D → C, etc.
3. **Scope guardrails** — update the "You are checking" list to remove the `estimate_minutes` bullet.

### 5.3 Prompt: `agents/orianna/prompts/implementation-gate-check.md`

1. **Step A** — apply the same path-shape classification split as §5.1 item 2. Internal prefixes: block on miss. Non-internal: info.
2. **Step A** — apply the same fenced-block exclusion as §5.1 item 3.
3. Everything else unchanged.

### 5.4 Claim contract: `agents/orianna/claim-contract.md`

1. **§1 Claim categories** — sub-classify C2 (repo path) into C2a (internal-prefix path) and C2b (other path-shaped token). Severity default: C2a → block, C2b → info.
2. **§2 Non-claim categories** — add four new entries:
   - HTTP route tokens (e.g. `/auth/login`, `POST /foo/{bar}`, `GET /baz`).
   - Dotted identifiers with camelCase or snake_case segments (e.g. `module.function`, `Class.method`) that are not also path-shaped. <!-- orianna: ok -->
   - Tokens inside fenced code blocks (```` ``` ````) — entire category.
   - Template/brace expressions (e.g. `{uid, email, iat}`, `{sid}/{token}`). <!-- orianna: ok -->
3. **§5 Routing rules** — add a prefatory paragraph: "Routing applies to internal-prefix path tokens only (C2a). Non-internal-prefix path tokens (C2b) do not undergo `test -e` and are logged as `info`."
4. **§6 v1 extraction heuristic** — replace step 1 ("For each fenced code block and each inline backtick span, extract the token") with: "For each inline backtick span outside a fenced code block, extract the token. Fenced code blocks are illustrative and not extracted."
5. Bump `contract-version: 1` → `contract-version: 2` in frontmatter.

### 5.5 Bash fallback: `scripts/fact-check-plan.sh`

1. **`extract_tokens()`** — remove the fenced-block branch (lines 219–252 in the current file — the `in_fence` iteration and the `/^` ``` `/` toggle). Keep only inline-backtick extraction.
2. **`route_path()`** — no change to routing logic itself.
3. **Main check loop** — after `route_path()`, introduce an `is_internal_prefix()` check. If the path is not internal-prefix under either concern-aware routing branch, classify a miss as `info` instead of `block`.
4. **Severity accounting** — `block_count` no longer increments for non-internal-prefix misses; `info_count` increments instead.
5. Update frontmatter comment at top of file (contract version reference).

### 5.6 Tests — new + updated

**New tests** (in `scripts/test-fact-check-substance-format-split.sh`): <!-- orianna: ok -->

- A plan citing `/auth/login` inside backticks → `info` finding, not `block`.
- A plan citing `scripts/nonexistent.sh` inside backticks → `block` finding. <!-- orianna: ok -->
- A plan with fenced code block containing `` `/foo/bar` `` → no finding extracted.
- A plan with frontmatter missing `status:` → `warn` (was block).
- A plan with frontmatter missing `owner:` → `block` (unchanged).
- A plan with `architecture_impact: none` but no `## Architecture impact` body → `block` (unchanged).
- A plan with `- [ ] **T1** — do X` missing `estimate_minutes:` → Orianna exits 0 with no finding (dropped); pre-commit linter catches at commit.

**Updated tests:**

- `scripts/test-fact-check-concern-root-flip.sh` — assertions against non-internal-prefix misses under `concern: work` must switch from "expect block" to "expect info."
- `scripts/test-fact-check-false-positives.sh` — add positive-case assertions for the new non-claim categories (HTTP routes, fenced tokens).

### 5.7 Lifecycle doc: `architecture/plan-lifecycle.md`

Update the three "What Orianna checks" sub-sections (approved, in-progress, implemented) to reflect the rescoped check set. One sentence of delta per sub-section.

---

## 6. Tasks

- [ ] **T1** — Write the new `scripts/test-fact-check-substance-format-split.sh` as xfail. estimate_minutes: 35. Files: `scripts/test-fact-check-substance-format-split.sh` (new). DoD: 7 test cases from §5.6, all current xfail against unchanged tree; committed on a branch referencing this plan. kind: test <!-- orianna: ok -->
- [ ] **T2** — Run T1 test script against unchanged tree, confirm each of the 7 cases xfails for the expected reason. estimate_minutes: 10. DoD: verified xfail output captured in PR description.
- [ ] **T3** — Update `scripts/test-fact-check-concern-root-flip.sh` and `scripts/test-fact-check-false-positives.sh` per §5.6 updated-tests list; commit as xfail. estimate_minutes: 30. Files: both test scripts (updated). DoD: previously-green tests now xfail on the classification change; kind: test
- [ ] **T4** — Bump claim-contract.md per §5.4 items 1–5 (version 1 → 2). estimate_minutes: 40. Files: `agents/orianna/claim-contract.md` (updated). DoD: contract edits land; no hook failures; T1/T2/T3 still xfail (prompts and script not yet changed).
- [ ] **T5** — Update `scripts/fact-check-plan.sh` per §5.5 items 1–5. estimate_minutes: 50. Files: `scripts/fact-check-plan.sh` (updated). DoD: T1 passes for the two bash-fallback-exercising cases; T3 turns green.
- [ ] **T6** — Update `agents/orianna/prompts/plan-check.md` per §5.1 items 1–5. estimate_minutes: 45. Files: `agents/orianna/prompts/plan-check.md` (updated). DoD: T1 green for LLM-path cases; PA-1/3/4 demotions visible in test output.
- [ ] **T7** — Update `agents/orianna/prompts/task-gate-check.md` per §5.2 items 1–3. estimate_minutes: 30. Files: `agents/orianna/prompts/task-gate-check.md` (updated). DoD: plan with missing estimate_minutes signs cleanly at in-progress (TG-2/3/4 dropped); pre-commit linter still catches it.
- [ ] **T8** — Update `agents/orianna/prompts/implementation-gate-check.md` per §5.3 items 1–3. estimate_minutes: 25. Files: `agents/orianna/prompts/implementation-gate-check.md` (updated). DoD: plan citing HTTP routes inside backticks signs cleanly at implemented.
- [ ] **T9** — Update `architecture/plan-lifecycle.md` per §5.7. estimate_minutes: 20. Files: `architecture/plan-lifecycle.md` (updated). DoD: gate summaries match new check set.
- [ ] **T10** — Full test-suite run: T1 + T3 + `scripts/test-fact-check-concern-root-flip.sh` + `scripts/test-fact-check-false-positives.sh` + `scripts/test-fact-check-work-concern-routing.sh` + `scripts/test-orianna-lifecycle-smoke.sh`. estimate_minutes: 25. DoD: all green.
- [ ] **T11** — Author a single canary plan (complexity: quick, `tests_required: false`, trivial scope like a one-line README edit) citing HTTP routes and fenced-block diagrams inline; confirm it signs at approved on the new check set on the first pass without suppression markers. estimate_minutes: 30. Files: `plans/proposed/personal/2026-04-XX-orianna-rescope-canary.md` (new). DoD: zero block findings; warn/info as expected; plan moves to approved via normal `scripts/orianna-sign.sh` + `scripts/plan-promote.sh` flow. <!-- orianna: ok -->
- [ ] **T12** — Update `agents/orianna/learnings/index.md` with one entry summarizing the rescope and the new claim-contract version. estimate_minutes: 15. Files: `agents/orianna/learnings/index.md` (updated). DoD: entry added with `last_used: <date>`.

Total estimate: 355 minutes.

---

## 7. Grandfathering

The task brief asks whether existing v2-signed plans need re-signing after the rule change.

**Answer: no re-signing required.** Reasoning:

- The `Orianna` signature hashes the plan body (`scripts/orianna-hash-body.sh`), not `agents/orianna/claim-contract.md`, not the prompt files, not `_lib_orianna_*.sh`. The rescope only touches files outside the hash scope.
- The rescope only **removes** or **demotes** checks. It does not add new block-capable checks. A plan that passed the old gate trivially passes the new gate: fewer blocks can only decrease the finding count.
- `scripts/orianna-verify-signature.sh` verifies the signature is still valid against the current plan body; that is unaffected by prompt rescope.
- Carry-forward checks (`check_approved_carry_forward`, `check_carry_forward_inprogress`) invoke `orianna-verify-signature.sh`, which is also unaffected. <!-- orianna: ok -->

Confirmed by construction: the rescope is strictly a check-set **shrink**, and shrink preserves all prior signing-relationships. The `contract-version: 1 → 2` bump is metadata for readers; it does not imply any re-verification by the signature path.

**Exception — reports referenced from plan bodies.** If a plan happens to cite a fact-check report under `assessments/plan-fact-checks/...` in a backtick span, that citation continues to be a C2a (internal-prefix) path token and must resolve under `test -e`. No change. Reports are not deleted by this plan. <!-- orianna: ok -->

**Canary pass (T11)** is the empirical validation: one new plan signed end-to-end on the rescoped gate confirms the grandfathering reasoning in practice. If the canary fails unexpectedly, the rescope is reverted task-by-task (T4–T9 are each single-file reverts).

---

## 8. Rollback

Each task T4–T9 is a single-file edit. Rollback is a per-file `git revert` on the branch that lands the rescope. No data migration, no signature invalidation, no stale state to clean up. The pre-commit linter and the Orianna scripts remain backward-compatible with the v1 claim-contract.

For a full rollback post-merge: revert the merge commit. Re-sign is not required for any plan that was signed on either the v1 or v2 contract, per §7.

---

## Test plan

### Unit level

- `scripts/test-fact-check-substance-format-split.sh` (new, T1) — covers the seven classification boundaries in §5.6 under the bash-fallback path. Runs in CI; must be green. <!-- orianna: ok -->
- `scripts/test-fact-check-concern-root-flip.sh` and `scripts/test-fact-check-false-positives.sh` (updated, T3) — existing suite updated for the new non-internal-prefix demotion. Assertion deltas are documented inline.

### Integration level

- `scripts/test-orianna-lifecycle-smoke.sh` — existing end-to-end smoke test that drives a plan through `proposed → approved → in-progress → implemented`. Must remain green with the rescoped check set. If it fails, the rescope regressed a substance gate.

### Canary level

- T11 — one live plan under `plans/proposed/personal/` signed on the rescoped gate. Qualitative success criterion: the author writes the plan with HTTP routes / ASCII diagrams / dotted identifiers in backticks, and the first `scripts/orianna-sign.sh` call returns exit 0 without any `<!-- orianna: ok -->` markers on those specific tokens.

### Regression level (per Rule 13)

The specific regressions to cover:

- **R1** — A plan citing `/auth/login` in inline backticks signs at approved gate without block. (Was block pre-rescope.)
- **R2** — A plan citing `scripts/does-not-exist.sh` in inline backticks blocks at approved gate. (Unchanged — internal-prefix miss.) <!-- orianna: ok -->
- **R3** — A plan with `- [ ]` task missing `estimate_minutes:` passes Orianna's approved-gate but fails the pre-commit linter. (TG-2 dropped; linter still catches.)
- **R4** — A plan with fenced code block containing `` `/foo/bar` `` passes Orianna without any finding extracted from the fence. (PA-7 dropped.)

All four regressions land as xfail commits under T1 / T3 before the prompt+script changes land. Per Rule 12, that pre-commits the TDD discipline.

---

## 9. Architecture impact

Declared via `architecture_changes:` at implementation time — `architecture/plan-lifecycle.md` gets the §5.7 update (one per-sub-section sentence). The change is small but required, because the operator-facing lifecycle summary must reflect the rescoped check set or it goes stale immediately.

No new architecture doc is created; no existing one beyond `plan-lifecycle.md` is modified. <!-- orianna: ok -->

---

## 10. Gating questions

- **OQ-1 — Severity floor for non-internal-prefix path tokens.** The proposal demotes these to `info`. Alternative: demote to `warn` (still visible in CI stderr summary, still non-blocking, but louder than `info`). Recommendation: `info`. Rationale: today's false-positive signal is high-volume; a loud warn-per-token would still dominate the report view. `info` keeps the accounting (count surfaces in frontmatter) without visual noise. Duong's pick?
  - a: demote to `info` (cleanest — noise minimized, substance still block-gated)
  - b: demote to `warn` (balanced — keeps the finding loud for triage culture)
  - c: keep at `block` but expand the opt-back list case-by-case (quick, but compounds the existing workaround-churn)
  - Pick: a — the author's-intent suppression marker remains the escape hatch if a specific token deserves attention, and nothing prevents adding a single token to the allowlist or opt-back if a pattern emerges.
  - **Resolved:** (a) info. Duong concurs with Swain.

- **OQ-2 — Fenced code block extraction — hard drop vs opt-in re-enable.** The proposal drops fence iteration entirely. Alternative: keep fence iteration but require a preceding `<!-- orianna: check -->` marker to opt a fence back into extraction. Recommendation: hard drop. Rationale: opt-in would add a second marker syntax, doubling the cognitive load; the documented failure mode is "too much extracted from fences," not "too little." Duong's pick?
  - a: hard drop fence extraction (cleanest)
  - b: hard drop + add a per-line "I want this fenced token checked" marker option as a future affordance
  - c: keep fence extraction but expand allowlist coverage (quickest)
  - Pick: a — the category of fenced tokens that's load-bearing (a fenced `agents/.../file.md` that genuinely exists) is already covered by the author citing the same path outside a fence elsewhere in the plan, which is the common practice today. <!-- orianna: ok -->
  - **Resolved:** (a) hard drop. Duong concurs with Swain.

- **OQ-3 — Drop TG-2/TG-3/TG-4 (estimate_minutes at Orianna sign-time) vs keep as redundancy.** The proposal drops in favor of the pre-commit linter. Alternative: keep Orianna's copies as redundancy in case the linter ever regresses. Recommendation: drop. Rationale: the linter is in `scripts/hooks/pre-commit-zz-plan-structure.sh` with tests; its split-of-responsibilities ownership is explicit in `architecture/plan-lifecycle.md`. Redundant enforcement wastes LLM budget. Duong's pick?
  - a: drop from Orianna; rely on linter (cleanest; single owner for the check)
  - b: keep in Orianna but mark deprecated in a comment; delete in a follow-up
  - c: keep in both places (safest but wastes sign-time LLM tokens on every plan)
  - Pick: a — the linter runs at commit time (fast feedback); Orianna runs later. Double-enforcement doesn't add safety; it just adds sign-time latency.
  - **Resolved:** (a) drop from Orianna. Duong concurs with Swain.

- **OQ-4 — Should the warn-to-info demotions in Step A (status/created/tags) drop further to not-checked-at-all?** Demoting to warn still prints them in the report. If the value is truly low (these fields are also caught by the pre-commit linter's frontmatter check), we could stop checking them altogether. Recommendation: warn. Rationale: the linter enforces presence at commit; Orianna warning on mismatch at sign time is a cheap second-look. Zero blocking cost. Duong's pick?
  - a: warn (cleanest — Orianna still notices drift in case the linter is ever regressed)
  - b: drop the checks entirely from Orianna (the pre-commit linter is the source of truth; Orianna shouldn't re-check)
  - c: keep as block (status quo — but contradicts substance-vs-format directive)
  - Pick: a — free signal, non-blocking.
  - **Resolved:** (b) drop entirely. Duong diverges from Swain (Swain recommended warn). Step-A frontmatter checks (status/created/tags) removed from Orianna completely; the pre-commit linter is the sole authority.

- **OQ-5 — Timing: when should the rescope land relative to the adjacent `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md`?** Both ADRs rescope the same gate, differently. Speedups fixes mechanical latency (body-hash pre-commit guard, signed-fix commit shape). This plan fixes check-set scope. Recommendation: this plan lands first. Rationale: speedups assumes the current check set and optimizes the ceremony around it; if the check set shrinks, some of the speedups may be over-engineered (e.g. the signed-fix commit shape is most valuable when iteration count is high, which the check-set shrink reduces). Landing this first lets speedups' implementer measure real iteration counts on the rescoped gate before over-optimizing. Duong's pick?
  - a: this plan first, then re-scope the speedups plan based on post-rescope measurements
  - b: both in parallel (they touch different files — feasible, just riskier)
  - c: speedups first (addresses the cheaper fix first, this plan waits)
  - Pick: a — sequencing maximizes clarity on whether the speedups are still needed at the originally-proposed scope.
  - **Resolved:** (b) parallel. Duong diverges from Swain (Swain recommended serial). Rescope and speedups run in parallel; do not serialize.

- **OQ-6 — Claim-contract version bump: v2 only, or also rename/archive v1?** The proposal bumps `contract-version: 1 → 2` in place. Alternative: keep v1 in an archival copy at `agents/orianna/claim-contract-v1.md` so historical signature verification context is preserved. Recommendation: bump in place. Rationale: the contract isn't hashed into signatures, so there's no retroactive-lookup need. Any future reader can `git log agents/orianna/claim-contract.md` for version history. Duong's pick? <!-- orianna: ok -->
  - a: bump in place, no archive (cleanest)
  - b: bump in place + add a one-paragraph "v1→v2 delta" section at the top of the file
  - c: archive v1 alongside v2 (thorough but clutter)
  - Pick: b — the one-paragraph delta is a cheap note that helps agents reading the contract understand why the extraction heuristic shrank. Promotes durability of the rationale.
  - **Resolved:** (b) bump in place + v1->v2 delta note. Duong concurs with Swain.

---

## 11. Coordination

- **Plan lives in:** `plans/proposed/personal/2026-04-22-orianna-substance-vs-format-rescope.md` <!-- orianna: ok -->
- **Delegation:** Evelynn picks an implementer pair (Viktor or Ekko for bash/prompts; pair with Xayah or Caitlyn for test planning in T1/T3). Swain does not assign — `owner: swain` is authorship only.
- **Serial-after:** recommended to land after any in-flight plan that touches `agents/orianna/prompts/**` to avoid merge conflict. At the time of authoring there are none, but the adjacent `2026-04-21-orianna-gate-speedups.md` does touch `scripts/hooks/` (not prompts); they are file-independent but decision-coupled per OQ-5. <!-- orianna: ok -->
- **Serial-before:** blocks any future plan that wants to tighten the check set again. A revert is one `git revert` away.
- **PR boundary:** one PR for T1+T2 (xfail tests); one PR for T3 (updated test assertions as xfail); one PR for T4 (claim-contract); one PR for T5 (bash fallback); one PR for T6+T7+T8 (prompts, same concern, same reviewer); one PR for T9+T10+T11+T12 (docs + canary + learnings). Six PRs total. Alternative: collapse to three PRs (tests; contract+script; prompts+docs+canary) if reviewer bandwidth is tight.

---

## 12. Orianna anchors

Every path-shaped token cited in this plan body resolves at the time of authoring. The plan itself is a META-EXAMPLE of the rescope (it cites HTTP routes, Python identifiers, fenced tokens in its evidence section §1) and is therefore expected to generate warn/info findings on the pre-rescope gate. Those are documented, not defects.

Prospective output paths (files created by this plan) carry inline `<!-- orianna: ok -->` markers where they appear in backticks:

- `scripts/test-fact-check-substance-format-split.sh` <!-- orianna: ok -->
- `plans/proposed/personal/2026-04-XX-orianna-rescope-canary.md` <!-- orianna: ok -->

---

## 13. Out of scope

- Changes to the signing/verification machinery (`orianna-sign.sh`, `orianna-verify-signature.sh`, `orianna-hash-body.sh`) — those are correct; their contract is preserved. <!-- orianna: ok -->
- Changes to `plan-promote.sh` — continues to call `orianna-fact-check.sh` unchanged. <!-- orianna: ok -->
- Changes to the `Orianna-Bypass:` break-glass path — unaffected.
- Changes to `scripts/hooks/pre-commit-zz-plan-structure.sh` — the linter's five rules remain as-is. Indirect effect: after this plan lands, the linter becomes the single owner of `estimate_minutes` validation.
- New suppression-marker syntaxes (category-level, document-level, fence-opt-in). The line-scoped marker remains the only escape hatch; frequency of use drops because fewer tokens are checked.
- Re-signing of pre-existing v2-signed plans — unnecessary per §7.
- Memory-audit behavior changes (`scripts/orianna-memory-audit.sh`) — separate runbook; not touched here.

---

## 14. References

- `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` — the origin ADR that defined the gate taxonomy this plan rescopes.
- `plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md` — adjacent speedups plan (§10 OQ-5 sequencing).
- `plans/approved/personal/2026-04-21-plan-prelint-shift-left.md` — the shift-left linter ADR; creates the split-of-responsibilities table this plan relies on.
- `feedback/2026-04-21-orianna-signing-latency.md` — session-1 latency report.
- `feedback/2026-04-21-orianna-signing-followups.md` — session-2 report; documents the root-cause cascade.
- `architecture/plan-lifecycle.md` — operator reference; updated in T9.
- `agents/orianna/claim-contract.md` — authoritative spec; bumped to v2 in T4.
- `agents/orianna/allowlist.md` — no change; referenced for completeness.
- `assessments/plan-fact-checks/2026-04-22-firebase-auth-for-demo-studio-2026-04-22T02-15-40Z.md` — 12-block example of the false-positive pattern this rescope eliminates.
- `assessments/plan-fact-checks/2026-04-21-demo-studio-v3-e2e-ship-v2-2026-04-21T09-50-32Z.md` — 10-block HTTP-route example.
