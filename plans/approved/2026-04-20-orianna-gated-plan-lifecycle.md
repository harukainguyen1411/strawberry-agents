---
title: Orianna-gated plan lifecycle — signature required at every phase transition
status: approved
owner: swain
created: 2026-04-20
tags: [workflow, plan-lifecycle, orianna, governance]
---

# Context

> **Role-slot reference.** This ADR refers to agents by **role slot** rather than by name — `the normal-track breakdown agent`, `the complex-track test planner`, etc. The concrete name-to-slot mapping lives in the companion taxonomy ADR `plans/proposed/2026-04-20-agent-pair-taxonomy.md`. When the taxonomy ADR lands, role-slot references here resolve through its pair matrix (§D1 of that ADR). This ADR's signature / gating content is unchanged by the taxonomy; only role labels are decoupled from specific agent identities.

The plan lifecycle today (`proposed/` → `approved/` → `in-progress/` → `implemented/` → `archived/`) is only partially gated. `scripts/plan-promote.sh` runs an Orianna fact-check on the `proposed → approved` transition (see `scripts/plan-promote.sh:63-86` and `scripts/orianna-fact-check.sh`), but subsequent transitions carry no gate at all. The symptoms:

- **Task breakdowns are ad-hoc.** The backend breakdown agents (normal- and complex-track) sometimes emit a `-tasks.md` sibling (e.g. `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md`), sometimes inline the tasks in the parent plan, sometimes skip the step entirely. No hook or script enforces existence.
- **Test plans are decoupled.** The test-plan / audit agent writes testing plans on request, but nothing requires one before `approved → in-progress`.
- **Architecture docs drift.** `architecture/` contains 22 files (`ls architecture/`) but no promote step verifies that an implemented plan left a trail in that tree. Duong explicitly flagged this as the single biggest staleness risk.
- **Orianna doesn't "sign" anything.** The existing fact-check writes a report to `assessments/plan-fact-checks/` and exits 0/1 — the promote consumes the exit code but no durable "Orianna approved promotion at phase X" marker survives in the plan itself. The hook `scripts/hooks/pre-commit-plan-promote-guard.sh` accepts *any* report file for a plan as sufficient evidence, even one written before the plan's current content.

This ADR proposes restructuring the lifecycle so **Orianna signs every phase transition**. Without her signature, `plan-promote.sh` refuses to move the file. Signatures are tamper-evident through git authorship. Each gate runs a different check, appropriate to the phase.

---

# Decisions

## D1. Signature mechanism — frontmatter field, commit-author verified

**Decision:** Orianna's signatures live in the plan's YAML frontmatter as repeatable keys, one per transition:

```yaml
orianna_signature_approved: "sha256:<hash>:<iso-timestamp>"
orianna_signature_in_progress: "sha256:<hash>:<iso-timestamp>"
orianna_signature_implemented: "sha256:<hash>:<iso-timestamp>"
```

The `<hash>` is SHA-256 of the plan file's body (content after the second `---`) computed at signing time. The `<iso-timestamp>` is UTC ISO-8601.

Tamper-evidence comes from **git commit authorship**, not from cryptographic signing. `plan-promote.sh` runs `git log --follow --format='%ae %H' -- <plan>` and walks backward to find the commit that introduced the specific `orianna_signature_<phase>` line. That commit's author email MUST match the Orianna identity (see §D1.1). If the line was introduced by any other author, the signature is invalid and promotion halts.

**Why this over detached sig files or a hash ledger:**

- **Single source of truth.** The plan file *is* the thing being signed; keeping the signature alongside the content avoids a second file that can drift out of sync. A detached `.signed/<plan>.sig` file is two things to keep consistent; if someone `git mv`s the plan, the sig file must move with it. One file is fewer edge cases.
- **Low ceremony, high signal.** A dedicated hash ledger (`.orianna-signatures.json` committed to a protected path) is heavier machinery for no additional security — the attacker vector in a solo-dev agent system is not a malicious committer, it is *an agent forgetting to invoke Orianna*. Git authorship is sufficient to distinguish "Orianna wrote this" from "any other agent wrote this" without a separate signing infrastructure.
- **Reviewable in `git log` without tooling.** `git blame <plan>` answers "who signed this" in one command. A sig file or ledger requires an extra step.

The body-hash field *is* load-bearing: if any agent edits the plan body after Orianna signs, the hash recorded in the signature no longer matches the current body, and `plan-promote.sh` refuses on content-drift grounds even if authorship checks out. This catches the "sign, then sneak an edit in before promote" case.

### D1.1. Making Orianna's git identity distinguishable

Today, subagent commits in this repo are authored as `Duongntd <duong.nguyen.thai.duy@gmail.com>` (the agent GitHub account — see `agents/memory/duong.md:14`). Every agent — builders, task planners, fact-checkers alike — commits as the same identity. That is insufficient for a per-agent signature.

**Proposal:** When Orianna signs, she commits with a `git commit --trailer "Signed-by: Orianna"` trailer *and* a conventional author override:

```bash
git -c user.name="Orianna (agent)" \
    -c user.email="orianna@agents.strawberry.local" \
    commit -m "chore: orianna signature for <plan>-<phase>" \
    --trailer "Signed-by: Orianna" \
    --trailer "Signed-phase: <phase>" \
    --trailer "Signed-hash: sha256:<hash>"
```

The committer remains `Duongntd` (git enforces committer = the authenticated pusher), but the *author* field is Orianna's. `plan-promote.sh` verifies:

1. The commit that introduced `orianna_signature_<phase>` has author email `orianna@agents.strawberry.local`.
2. That same commit carries a `Signed-by: Orianna` trailer.
3. That same commit carries a `Signed-hash:` trailer matching the value now in frontmatter.
4. That same commit's *tree diff* is limited to one file: the plan in question (i.e. Orianna's signing commits touch nothing else — see §D1.2).

Requirement (4) prevents the "Orianna signs in a commit that also sneaks through unrelated changes" attack. If the signing commit's diff extends beyond the plan file, the signature is invalid.

**Alternative considered:** Use GPG-signed commits with an Orianna-specific key stored under `secrets/`. Rejected because (a) key management adds failure modes (expired keys, lost passphrases) for no added security over author-verification in a local-agent system, and (b) GPG setup is already complex on the current Mac/Windows split (CLAUDE.md rule 10).

### D1.2. Enforcement hook

A new pre-commit hook `scripts/hooks/pre-commit-orianna-signature-guard.sh` verifies on every commit: if the diff touches only a plan file AND the commit author is `orianna@agents.strawberry.local`, enforce that:

- The diff is limited to exactly one file under `plans/`.
- The diff adds exactly one `orianna_signature_<phase>` frontmatter line (no other content change is allowed in a signing commit).
- The `Signed-by:`, `Signed-phase:`, `Signed-hash:` trailers are present and consistent.

This is a *positive* check: it defines what a valid Orianna commit looks like. Orianna commits that don't meet the shape are rejected, preventing silent misuse of the agent identity.

---

## D2. Phase-specific Orianna checks

Orianna runs a different check at each gate. The checks escalate in what they cover.

### D2.1. proposed → approved (`orianna_signature_approved`)

**Preserves existing behavior** from `scripts/orianna-fact-check.sh`. Additions:

- **Fact-check:** grep-anchor verification per `agents/orianna/claim-contract.md` v1. Block findings halt promotion.
- **Gating questions answered:** if the plan has an "Open questions" or "Gating questions" section, Orianna scans for unresolved markers (`TBD`, `TODO`, `?`, `Decision pending`) and flags them as block. A plan with open gating questions cannot be approved.
- **No load-bearing unverified claims:** current claim-contract behavior.
- **Frontmatter sanity:** `status: proposed`, `owner:` present, `created:` present, `tags:` present.

### D2.2. approved → in-progress (`orianna_signature_in_progress`)

New checks. Orianna verifies:

- **Task list exists.** A `## Tasks` section in the plan file itself. Sibling `<basename>-tasks.md` files are **not** accepted — one plan, one file (§D3).
- **AI-minute estimates.** Every task in the list has an `estimate_minutes: <integer>` field (see §D4 for format). No human-hour estimates; no unit-less numbers.
- **Test tasks present when tests are needed.** If the plan declares `tests_required: true` in frontmatter (default is `true`; set `false` explicitly to opt out with justification), at least one task must have `kind: test` or a title matching `^(write|add) .* test` (case-insensitive).
- **Test plan appended inline.** If `tests_required: true`, the plan must contain a `## Test plan` section inside the plan file — authored by the test-plan / audit role. Sibling `<basename>-tests.md` files are **not** accepted — same single-file rule as tasks. Orianna verifies the section exists and is non-empty; she does not validate contents (format is a follow-up test-plan schema ADR, §D11).
- **Signature carry-forward.** The `orianna_signature_approved` line must be present and still valid (hash match, authorship match). If the plan body was edited after approval, the approved signature is stale and the in-progress signature cannot be issued until approval is re-signed.

### D2.3. in-progress → implemented (`orianna_signature_implemented`)

This is the new architecture-freshness gate. Orianna verifies:

- **Implementation evidence.** For each grep-anchor claim in the plan (paths, script names, workflow files), the anchor resolves *now*. This re-runs claim-contract checks on the current tree. Plans shouldn't claim `scripts/foo.sh exists` and land with no such script.
- **Architecture updated OR explicit opt-out.** See §D5 for the rule. Either `architecture_changes:` frontmatter lists modified files under `architecture/`, OR `architecture_impact: none` is declared with a one-line reason in a `## Architecture impact` section.
- **Tests ran.** If `tests_required: true`, a `## Test results` section must exist with at minimum a link to a CI run URL OR a local test log path under `assessments/`. Orianna does not parse pass/fail — she verifies the section exists and contains a link.
- **Signature carry-forward.** Both `orianna_signature_approved` and `orianna_signature_in_progress` must be present and valid against the current body hash.

### D2.4. implemented → archived

No Orianna gate. Archiving is bookkeeping, not a governance event. `plan-promote.sh` allows this transition without a signature — but it also refuses to *remove* an existing `orianna_signature_implemented` line, so the archived file retains its trail.

---

## D3. Where task breakdowns live — appended to plan file

**Decision:** One plan, one file. Task lists live inside the plan file under a `## Tasks` section. Sibling `<basename>-tasks.md` files are **not** permitted under the new gate. Likewise for the `## Test plan` section (§D2.2) written by the test-plan / audit role — inline only, no sibling files.

**Rationale:**

- **Single-file lifecycle.** The promote script moves one file; a sibling would force every move to be multi-file. Script complexity grows; drift windows open when only one half moves.
- **Signature coverage.** The signature's body-hash (§D1) covers the task list, test plan, and any other in-file sections automatically. Sibling files would need their own hashes, doubling the machinery with no added value.
- **Orianna grep simplicity.** Every §D2 check is a single-file read — no "is the sibling also clean?" logic.

**Grandfathered sibling files:** Existing sibling files in `plans/in-progress/` and earlier stages (e.g. `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md`) remain on disk for their current phase but carry no signature weight. Plans demoted to `plans/proposed/` under §D8 must inline any existing sibling content **manually** before their next `orianna-sign approved` invocation (Q10 resolution — no auto-merge). Orianna's approved gate greps `plans/` for any `<basename>-tasks.md` or `<basename>-tests.md` still on disk for the plan being signed and blocks until the sibling is removed or its content merged.

**Task entry schema (inline):**

```markdown
## Tasks

- [ ] **T1. Write failing test for X.** `kind: test` | `estimate_minutes: 10`
  - files: `tests/unit/x.test.ts`
  - detail: assert function returns Y for input Z
- [ ] **T2. Implement X.** `kind: impl` | `estimate_minutes: 25`
  - files: `src/x.ts`
  - detail: minimal implementation to pass T1
```

`kind:` is one of `test | impl | docs | infra | chore`. `estimate_minutes:` is an integer.

---

## D4. AI-minute estimate format

**Decision:** `estimate_minutes: <integer>`. Units are AI-minutes — the wall-clock time a Sonnet executor session is expected to take, not human-equivalent effort.

**Orianna's validation at the `approved → in-progress` gate:**

1. Every task entry contains the literal string `estimate_minutes:` followed by whitespace and an integer.
2. Integer is within sanity bounds: `1 ≤ n ≤ 60`. Values above 60 are **block** — a task larger than one AI-hour must be decomposed before promotion, not flagged-through. Values below 1 (zero or negative) are **block**.
3. No alternative units anywhere in the Tasks section: grep for `hours`, `days`, `weeks`, `h)`, `(d)` and flag as block. AI-minute is the only unit.
4. Missing field on any task entry is **block**.

**Why minutes, not points/t-shirts:**

- Planners underestimate systematically when abstract units (points) are used. Concrete time pressures the estimate toward reality.
- Duong is running a solo-operator agent system — throughput is literal wall-clock across agents, not velocity abstraction.
- AI-minutes are calibratable: after the plan completes, Evelynn or the PR fidelity reviewer can compare estimate to actual session durations and build a correction factor per agent/task-kind.

---

## D5. Architecture freshness rule

**Rule:** A plan requires an architecture update when it introduces or changes any of:

1. **System components** — new services, scripts, or top-level scripts under `scripts/` that other agents will invoke.
2. **APIs or interfaces** — new CLI tools, MCP tools, HTTP endpoints, or inter-agent message schemas.
3. **Data flows** — new persistence, new sync boundaries (e.g. Drive mirror), new cross-repo dependencies.
4. **Cross-cutting policy** — new rules in CLAUDE.md, new commit-prefix conventions, new lifecycle phases, new gates.

The set maps approximately to: "does this plan cause other agents to need to relearn something?"

**Orianna's `in-progress → implemented` check:**

The plan MUST contain ONE of:

- `**architecture_changes:` frontmatter field** — a YAML list of paths under `architecture/`, e.g.
  ```yaml
  architecture_changes:
    - architecture/agent-system.md
    - architecture/key-scripts.md
  ```
  Orianna verifies each listed path exists AND has a git-log entry modifying that file within the window `[approved_signature_timestamp, now]`. "You listed `architecture/agent-system.md` but didn't touch it since approval" = block.
- **OR an `architecture_impact: none` frontmatter field with `## Architecture impact` section** — one line reason minimum.
  ```yaml
  architecture_impact: none
  ```
  ```markdown
  ## Architecture impact

  None. This plan migrates one script's error messages; no documented component
  or interface changes.
  ```
  Orianna verifies: frontmatter value present, section heading exactly matches, body non-empty.

Plans MUST declare one of the two forms above — there is no implicit default. A plan arriving at the implemented gate with neither `architecture_changes:` nor `architecture_impact: none` is **blocked**. Orianna's error message points the author at §D5 with a one-line summary of both options. Forcing explicitness means every implemented plan answers "did this affect the system?" on the record.

**Why explicit opt-out over inference:** if Orianna tries to infer "did this plan touch architecture-relevant things" from the diff, she needs a complex heuristic that will be wrong. Making the author commit to one of two options (changed these files, or none) shifts the decision to where the knowledge lives.

---

## D6. `plan-promote.sh` enhancements

New logic:

1. **Signature presence check.** For the target phase, assert `orianna_signature_<target-phase>` exists in frontmatter. No signature = refuse with a clear error message pointing to how to obtain one (invoke Orianna via `scripts/orianna-sign.sh <plan> <phase>` — see §D7).
2. **Signature validity check.** Run `scripts/orianna-verify-signature.sh <plan> <phase>`:
  - Compute SHA-256 of the current body. Compare to the hash in the signature field.
  - Run `git log --follow --format='%ae %H %s' -- <plan>` and find the commit that introduced the signature line.
  - Verify that commit's author email is `orianna@agents.strawberry.local`.
  - Verify that commit carries `Signed-by: Orianna`, `Signed-phase: <phase>`, `Signed-hash: <hash>` trailers and they match.
  - Verify that commit's diff is scoped to only the plan file (§D1.2).
3. **Signature carry-forward.** For transitions past the first, verify all prior-phase signatures are also valid. An invalid earlier signature invalidates later signatures (you cannot sign `in-progress` on top of an `approved` that was tampered with).
4. **No fallback to mechanical-only check.** The current `orianna-fact-check.sh` falls back to `scripts/fact-check-plan.sh` when the `claude` CLI is absent (see `scripts/orianna-fact-check.sh:70-75`). For signing, there is no fallback — if Orianna cannot be invoked, no signature is issued. See §H for the offline failure mode.

The existing fact-check call at `scripts/plan-promote.sh:66-86` is replaced by the signature-verification call. The promote script no longer invokes the fact-check directly — instead, `orianna-sign.sh` (new, see §D7) invokes the fact-check as a precondition to signing.

---

## D7. New helper scripts

Three new scripts, all POSIX-portable bash (CLAUDE.md rule 10):

### D7.1. `scripts/orianna-sign.sh <plan> <phase>`

Entry point for Orianna's signing flow. Steps:

1. Verify the plan is currently in the correct source directory for the requested phase (e.g. phase `approved` requires the plan to be in `plans/proposed/`).
2. Invoke the phase-appropriate Orianna check (`plan-check` for approved, `task-gate-check` for in-progress, `implementation-gate-check` for implemented — new prompts under `agents/orianna/prompts/`).
3. If the check passes cleanly:
  a. Compute body hash.
   b. Append `orianna_signature_<phase>: "sha256:<hash>:<iso-timestamp>"` to frontmatter.
   c. Commit with Orianna's author identity and the required trailers (§D1.1).
   d. Do NOT push. `plan-promote.sh` pushes when it moves the file.
4. If the check fails: exit non-zero, do not modify the plan.

### D7.2. `scripts/orianna-verify-signature.sh <plan> <phase>`

Called by `plan-promote.sh`. Returns 0 if signature is present and valid, non-zero otherwise. Emits a human-readable diagnosis on stderr describing which check failed.

### D7.3. `scripts/hooks/pre-commit-orianna-signature-guard.sh`

Enforces §D1.2 commit shape. Installed via `scripts/install-hooks.sh`.

---

## D8. Migration / backfill

**Demote approved plans; grandfather later-stage plans; enforce going forward.**

- **All plans currently in `plans/approved/` are moved back to `plans/proposed/`** as part of this ADR's implementation. Their `status:` frontmatter is rewritten to `proposed`. These plans re-enter the lifecycle and must earn an `orianna_signature_approved` under the new regime before they can promote again. This guarantees every plan that reaches `in-progress` from here on carries a valid approved-phase signature, which the in-progress gate's signature carry-forward check (§D2.2) requires.
- The demotion is a **manual one-time operation** (Q10 resolution). No new mode on `scripts/plan-promote.sh`, no throwaway migration script. Author performs `git mv plans/approved/<plan>.md plans/proposed/`, rewrites the `status:` frontmatter line to `proposed`, and batches all demotions into one `chore:` commit. Sibling-file merging (where applicable) is also manual per §D3 — author inlines existing `<basename>-tasks.md` / `<basename>-tests.md` content into the parent plan before the next `orianna-sign approved` invocation. Drive mirror re-publishing for demoted plans follows `scripts/plan-publish.sh` invoked per-file post-demotion (proposed-only mirror rule still holds; once in `proposed/`, Drive publishing is valid).
- Plans currently in `plans/in-progress/`, `plans/implemented/`, `plans/archived/` remain where they are with no retroactive signatures. They finish their current phase under grandfathered rules.
- A new frontmatter field `orianna_gate_version:` is introduced. Plans signed under the new regime carry `orianna_gate_version: 2`. Plans without this field are grandfathered.
- `plan-promote.sh` checks `orianna_gate_version` on the source plan. If absent, log a warning ("grandfathered plan; gate-v1 rules applied") and fall back to the existing single-phase fact-check behavior. If present and `= 2`, enforce §D2 gates for the requested transition.
- New plans created after this ADR lands MUST include `orianna_gate_version: 2`. The pre-commit hook for plan creation can enforce this (out of scope for this ADR; note as follow-up).
- For plans currently in `in-progress/`, retroactive signing is author's discretion — no bulk backfill. A plan already mid-implementation can opt in by running `scripts/orianna-sign.sh <plan> approved` followed by `... in-progress` before its next phase transition; otherwise it promotes to `implemented/` under grandfathered rules.

**The `proposed/` directory becomes the single entry point** for the new gate. Every plan — whether newly authored or demoted from `approved/` — gets signed at this boundary before it can move forward.

---

## D9. Failure modes

### D9.1. Orianna's check keeps failing

**Escape hatch:** Duong-only manual override via the existing `Orianna-Bypass: <reason>` commit-message trailer, now extended to cover any gate phase. Pattern (existing hook `pre-commit-plan-promote-guard.sh:86-88`):

```
Orianna-Bypass: <reason, minimum 10 chars>
```

The trailer allows the promote commit without a valid signature. It is logged in git history, so audits show exactly which transitions were force-promoted. Agents MUST NOT use this trailer — the hook is extended to reject `Orianna-Bypass` trailers in commits authored by agent identities (author email `duong.nguyen.thai.duy@gmail.com` = Duongntd = agent account). Only commits authored by Duong's admin identity (`harukainguyen1411` / Duong's personal email) are permitted to carry the bypass. Per Duong: `harukainguyen1411` is the admin account, introduced only when needed for break-glass; agents always use other accounts.

This preserves the break-glass property (Rule 18 precedent: human-only bypass) while making the bypass visible in history.

### D9.2. Orianna subagent unreachable during promote

**Offline-fail.** If `claude` CLI isn't available (the fallback case in `scripts/orianna-fact-check.sh:70-75`), `orianna-sign.sh` exits non-zero with a clear message. No signature is issued. Promote halts with "signature unavailable; Orianna cannot be invoked — retry when connectivity restored."

Rationale: skip-with-warning in a signing context is a silent security failure. If we can't verify we're signing, we don't sign. The `fact-check-plan.sh` mechanical fallback is insufficient for a signing gate — it doesn't do the phase-specific checks (§D2.2, §D2.3), so a signature based on it would be a false claim of review.

### D9.3. Race — two agents promote the same plan simultaneously

**Mitigation:** `plan-promote.sh` acquires an advisory file lock on `<repo-root>/.plan-promote.lock` (using `flock` on Linux/Mac, `lockfile`-style fallback via `mkdir` for portability) before beginning any file move. Lock held for the duration of the promote. Second concurrent invocation fails fast with "plan-promote is already running (pid N); retry."

This is a best-effort mitigation — the actual protection is git's atomicity on commit/push, which will reject the second mover with a non-fast-forward error. The file lock makes the failure mode cleaner than a mid-promote git conflict. File-lock scope is the repo, not per-plan, because the cost of serializing all promotes is negligible (promotes are seconds-long, not minutes).

### D9.4. Signature invalidation on legitimate edits

Expected workflow: author edits plan after approval (typo fix, clarification). The hash in `orianna_signature_approved` no longer matches the body. `orianna-verify-signature.sh` fails at the next transition.

**Resolution:** The author runs `scripts/orianna-sign.sh <plan> approved` again to re-sign after the edit. Orianna re-runs the proposed→approved check, which is cheap (§D2.1 is the lightest gate). A legitimate edit costs one re-sign; a tampering attempt is caught.

**Trivial edits** (whitespace, trailing-newline normalization): Orianna's body hash normalizes line endings to `\n` and strips trailing whitespace before hashing. This prevents editor-save noise from invalidating signatures. Normalization rules are encoded in `scripts/orianna-hash-body.sh` (new helper, sourced by both sign and verify scripts so they agree).

---

## D10. Architecture doc updates triggered by this ADR

This ADR itself is subject to §D5. Expected `architecture_changes:` on implementation:

- `architecture/agent-system.md` — add Orianna's signing role to the agent-role table.
- `architecture/key-scripts.md` — document `orianna-sign.sh`, `orianna-verify-signature.sh`, `orianna-hash-body.sh`.
- `architecture/pr-rules.md` (or a new `architecture/plan-lifecycle.md`) — document the signed-lifecycle protocol.
- Possibly `CLAUDE.md` — a new Universal Invariant for "plan promotions require Orianna signatures," slot #19 or later.

---

## D11. Test-plan schema — deferred to a follow-up ADR

This ADR checks only the existence of a `## Test plan` section in the plan file (§D2.2). The schema of that section — test-case list shape, expected/actual columns, coverage expectations — is out of scope here and will be specified in a dedicated ADR owned by the test-plan / audit role. Until that ADR lands, the test-plan author writes an ad-hoc test plan directly inside the plan file (same single-file rule as tasks). Orianna's gate passes as long as the section exists and is non-empty.

---

## D12. Implementation ordering — plan-authoring freeze

Because this ADR introduces new mandatory frontmatter fields (`orianna_gate_version`, potentially `tests_required`, `architecture_changes` / `architecture_impact`) and restructures the lifecycle around a signing gate, **new plan creation is frozen from the moment this ADR promotes to `in-progress/` until the new gate infrastructure is live and validated**. The freeze window is enforced socially (Evelynn does not spawn architect or breakdown agents for new plans during this period) and mechanically via a temporary pre-commit hook.

**Freeze scope — new files only (Q11 resolution):** The hook rejects only *newly-added* files under `plans/proposed/`; *edits* to existing proposed drafts continue to pass. Authors must still polish in-flight drafts (including this ADR) during the freeze window. The hook's check is: `git diff --cached --name-status | awk '$1=="A" && $2 ~ /^plans\/proposed\//'` — any match fails the commit with a message pointing at §D12. Modified (`M`), renamed (`R`), and deleted (`D`) entries under `plans/proposed/` pass through.

Once `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, and the updated `plan-promote.sh` are all green on a smoke test (§D8 demotion + one fresh plan signed through all three phases), the freeze lifts. The freeze is tracked as the final task in this ADR's `## Tasks` section.

In-flight work at the freeze start — plans already in `in-progress/` or `implemented/` — continues under grandfathered rules (§D8). The freeze applies only to the creation of new `proposed/` entries.

---

# Resolved gating questions (round 1)

All eight original gating questions were answered by Duong on 2026-04-20. Decisions are captured in the relevant `D*` sections; summary below.

1. **Q1. Orianna git identity.** Resolved: `orianna@agents.strawberry.local` as author email (§D1.1). No GitHub bot account.
2. **Q2. Bypass eligibility.** Resolved: option (b) — `Orianna-Bypass` is valid only when the commit/push originates from Duong's admin identity `harukainguyen1411`, introduced only when break-glass is needed. Agents always use other accounts. Enforcement lives in the pre-commit hook (§D1.2 / §D9.1).
3. **Q3. Grandfathering cutoff.** Resolved: all plans in `plans/approved/` are demoted back to `plans/proposed/` and must re-earn a signature (§D8). Plans in `in-progress/`, `implemented/`, and `archived/` stay put under grandfathered rules; retroactive signing of in-flight plans is author's discretion.
4. **Q4. Test-plan format.** Resolved: defer schema to a follow-up ADR owned by the test-plan / audit role (§D11). The `## Test plan` section is appended inline to the plan file — no sibling files.
5. **Q5. Estimate sanity bounds.** Resolved: `1 ≤ estimate_minutes ≤ 60`. Values above 60 are **block**, forcing decomposition (§D4).
6. **Q6. Architecture-impact declaration default.** Resolved: no implicit default. Plans must declare either `architecture_changes:` or `architecture_impact: none`; missing both is **block** at the implemented gate (§D5).
7. **Q7. Signature coverage of sibling files.** Resolved: no sibling files permitted — one plan, one file (§D3). The question dissolves because the artifact it protected no longer exists.
8. **Q8. Implementation ordering.** Resolved: freeze new plan creation from this ADR's `in-progress/` start until the new gate infrastructure is validated end-to-end (§D12).

---

# Resolved gating questions (round 2)

Round-2 questions raised by the earlier revision were answered by Duong on 2026-04-20. Decisions are captured in the relevant `D*` sections; summary below.

9. **Q9. Demotion script ownership.** Resolved: **manual**. The bulk `plans/approved/` → `plans/proposed/` demotion is a one-time operation performed by hand — no new `--demote-to-proposed` mode added to `scripts/plan-promote.sh`, no throwaway migration script. Rationale: adding a dedicated script for a one-shot backfill invites the script to rot in-tree; a manual pass is cheaper and leaves `plan-promote.sh` focused on forward motion. §D8 is revised accordingly — author runs `git mv` manually for each demoted plan, rewrites `status:`, and commits in one `chore:` batch.
10. **Q10. Sibling-file merge during demotion.** Resolved: **manual**. Authors merge any existing `<basename>-tasks.md` / `<basename>-tests.md` sibling content into the single-file layout by hand before re-promoting. No auto-merge flag on the demotion path. Rationale: siblings don't follow a canonical heading structure and auto-merge would require a per-file review anyway; manual ensures the content is inspected on the way in. §D3's grandfathering note is revised: migrated plans MUST inline sibling content before their next `orianna-sign approved` invocation; Orianna's approved gate performs a grep for sibling filenames under `plans/` to catch unmerged leftovers.
11. **Q11. Freeze scope.** Resolved: **new files only**. §D12's freeze applies only to *new* files under `plans/proposed/`; edits to existing proposed drafts remain allowed. Rationale: authors must still polish in-flight drafts (including this ADR) during the freeze; the goal is to stop *new* plan authoring, not to freeze the whole tree. The temporary pre-commit hook introduced by §D12 checks `git diff --name-status` for `A` (added) entries under `plans/proposed/` — `M` (modified) entries pass through.

---

# Out of scope (explicit)

- **Task-execution gates during implementation.** This ADR does not gate per-task commits during `in-progress`. A task-level signature protocol could follow, but adds overhead per commit; defer.
- **Cross-repo architecture** (i.e. `strawberry-app` architecture docs). This ADR scopes to strawberry-agents only. Cross-repo extension is a follow-up once the in-repo flow is proven.
- **PR-level signature.** PRs to `apps/`** are a separate lifecycle governed by CLAUDE.md rules 15, 16, 18. Orianna does not sign PRs.
- **Automation of architecture-doc updates.** §D5 requires the human (or implementing agent) to update `architecture/` — Orianna verifies the update happened but does not write architecture docs herself.

---

## OQ Resolutions

Evelynn's answers to the three open questions Kayn surfaced in the breakdown (2026-04-20). These resolutions are authoritative; inline task definitions below reflect them.

- **OQ-K1 — T4.3 lib placement:** Separate file. T4.3 ships as `scripts/_lib_orianna_estimates.sh`, not bundled into `_lib_orianna_gate_inprogress.sh`. Rationale: modular and independently testable — new signing infrastructure defaults to separate units. T4.1 sources it via `. _lib_orianna_estimates.sh`.

- **OQ-K2 — CLAUDE.md rule slot for T10.4:** Rule #19. CLAUDE.md currently ends at rule #18; sequential numbering with no gaps means the Orianna signature invariant lands as rule #19. No renumbering of existing rules.

- **OQ-K3 — Does this ADR self-demote in T9.1?:** No. Self-referential exception — this ADR stays in `approved/`. Demoting the rule that governs plan demotion is circular; the gating mechanism cannot gate itself retroactively. T9.1's mass demotion of `plans/approved/` EXCLUDES this file (`plans/approved/2026-04-20-orianna-gated-plan-lifecycle.md`). Kayn's breakdown already assumed this; it is now confirmed so the Phase 9 executor has a clear, unambiguous call.

---

# Tasks

> Execution breakdown authored by Kayn on 2026-04-20 per §D3 (one plan, one
> file — task list lives inline, not as a sibling). Executor tiers follow the
> Sonnet roster: **BUILDER (Jayce)** = new scripts/files; **REFACTOR (Viktor)**
> = edits to existing files; **TEST (Vi)** = test authoring (xfail-first per
> CLAUDE.md rule 12); **ERRAND** = Senna / Lucian / Duong-driven bookkeeping
> and manual one-shots.
>
> Definition of done (universal): commits landed on `main` for plan artifacts
> or a named branch for code; all acceptance checks in the task body pass;
> xfail test commit precedes the paired impl commit on TDD-enabled paths;
> `chore:` prefix for non-code commits; conventional prefixes for code.

## Inventory of already-shipped work (NOT re-tasked)

| ADR ref | Deliverable | Status | Evidence |
|---------|-------------|--------|----------|
| D2.1 (v1) | `scripts/orianna-fact-check.sh` | SHIPPED | file exists; invoked from `scripts/plan-promote.sh:66-86` |
| D2.1 | `scripts/plan-promote.sh` wires fact-check between "require clean" and "Drive unpublish" | SHIPPED | `plan-promote.sh:63-86`; grep of `orianna-fact-check.sh` hits line 68 |
| Invocation lockdown | Orianna def relocated to `.claude/_script-only-agents/orianna.md` with script-only header | SHIPPED | commits `36199ef` + `8373bef` |
| Invocation lockdown | `agents/memory/agent-network.md` annotates Orianna as script-only | SHIPPED | commit `8373bef` |
| ADR self-gate | This plan promoted to `approved/` through its own Orianna gate (0/0/22 clean) | SHIPPED | commit `618904b`; reports at `assessments/plan-fact-checks/2026-04-20-orianna-gated-plan-lifecycle-*.md` |
| D2.1 | Pinned prompt `agents/orianna/prompts/plan-check.md` | SHIPPED | file exists; sourced by `orianna-fact-check.sh:79` |
| D2.1 | Claim contract v1 at `agents/orianna/claim-contract.md` | SHIPPED | file exists |
| D2.1 bypass guard | `scripts/hooks/pre-commit-plan-promote-guard.sh` blocks silent bypass | SHIPPED | file exists; accepts fact-check report OR `Orianna-Bypass:` trailer |

**Anti-duplicate rule:** No task below re-creates `orianna-fact-check.sh` or
re-wires it into `plan-promote.sh`. Tasks T6.x **replace** the fact-check call
site with the signature-verification call site; the existing script is retired
in-place (callers migrate, the script remains for `orianna-sign.sh` to reuse
under §D2.1).

**`plan-check.md` is extend-not-replace.** The shipped prompt covers the v1
fact-check + gating-question scan. T3.1 extends it to full §D2.1 scope
(frontmatter sanity + sibling-file grep). Existing v1 checks preserved.

## Dependency graph (phase order)

```
Phase 1 — foundation (parallel)
  T1.1 hash-body helper
  T1.2 orianna git-identity policy doc
  T1.3 frontmatter-fields doc

Phase 2 — signing infrastructure
  T2.1 orianna-sign.sh      (needs T1.1, T3.2, T3.3, T4.1, T4.2, T4.3, T4.4)
  T2.2 orianna-verify-signature.sh (needs T1.1)
  T2.3 signature-shape pre-commit hook
  T2.4 install-hooks wiring

Phase 3 — phase-specific Orianna prompts
  T3.1 extend plan-check for §D2.1 full scope
  T3.2 new task-gate-check prompt (§D2.2)
  T3.3 new implementation-gate-check prompt (§D2.3)

Phase 4 — gate logic libs (feed T2.1)
  T4.1 §D2.2 in-progress checks lib
  T4.2 §D2.3 implemented checks lib
  T4.3 estimate_minutes parser (§D4)
  T4.4 architecture-freshness verifier (§D5)

Phase 5 — tests (xfail-first)
  T5.1 hash-body
  T5.2 verify-signature
  T5.3 signature-shape hook
  T5.4 estimate_minutes parser
  T5.5 architecture verifier
  T5.6 sibling-file grep
  T5.7 end-to-end smoke harness

Phase 6 — plan-promote.sh integration
  T6.1 signature presence + validity (needs T2.2)
  T6.2 carry-forward check (needs T6.1)
  T6.3 advisory file lock (§D9.3)
  T6.4 orianna_gate_version branching (§D8)
  T6.5 retire fact-check call site (needs T6.4, T2.1)

Phase 7 — bypass hardening
  T7.1 extend plan-promote-guard for §D9.1 author-identity rule
  T7.2 confirm offline-fail (§D9.2) via test

Phase 8 — freeze (§D12)
  T8.1 new-file freeze hook
  T8.2 install + announce
  T8.Z removal (executed via T11.2)

Phase 9 — migration (§D8, MANUAL one-shot)
  T9.1 bulk demote plans/approved/*.md → plans/proposed/
  T9.2 sibling-file inline merges (per-plan, opportunistic)

Phase 10 — architecture docs + CLAUDE.md (§D10)
  T10.1 architecture/agent-system.md
  T10.2 architecture/key-scripts.md
  T10.3 new architecture/plan-lifecycle.md
  T10.4 CLAUDE.md universal invariant

Phase 11 — smoke + freeze lift
  T11.1 end-to-end smoke on one fresh plan
  T11.2 execute T8.Z
```

**Hard serial points**
- T2.1 requires T3.2, T3.3, T4.1, T4.2, T4.3, T4.4 (sign.sh orchestrates phase checks)
- T6.1 requires T2.2 (promote calls verify)
- T6.4 requires T9.1 (grandfather logic needs demoted plans on disk to exercise)
- T11.1 requires all of T1–T8 green (§D12 smoke criterion)
- T11.2 (freeze lift) is terminal — final task in the ADR

---

### Phase 1 — Foundation (parallel)

- [ ] **T1.1. Body-hash normalization helper** — `kind: impl` | `estimate_minutes: 35`
  - executor: BUILDER (Jayce) | ADR: §D1, §D9.4
  - files: `scripts/orianna-hash-body.sh` (new)
  - detail: POSIX-bash; strips frontmatter (between first two `---`), normalizes line endings to `\n`, strips trailing whitespace per line, emits SHA-256 hex on stdout.
  - DoD: identical hash for CRLF↔LF and trailing-ws variants; different hash on body change; shellcheck-clean; T5.1 xfail lands first.

- [ ] **T1.2. Document Orianna git-identity policy** — `kind: docs` | `estimate_minutes: 15`
  - executor: ERRAND | ADR: §D1.1
  - files: `agents/orianna/profile.md` (edit)
  - detail: section spells out `orianna@agents.strawberry.local` author email, required trailers (`Signed-by: Orianna`, `Signed-phase:`, `Signed-hash:`), one-plan-one-commit rule.
  - DoD: section present; links back to §D1.1.

- [ ] **T1.3. Document new frontmatter fields** — `kind: docs` | `estimate_minutes: 25`
  - executor: BUILDER (Jayce — new file) | ADR: §D8
  - files: `architecture/plan-frontmatter.md` (new)
  - detail: enumerate `orianna_gate_version`, `orianna_signature_<phase>`, `tests_required`, `architecture_changes`, `architecture_impact` — type, values, default, enforcing gate.
  - DoD: all five fields documented with provenance link to this ADR.

### Phase 2 — Signing infrastructure

- [ ] **T2.1. `scripts/orianna-sign.sh <plan> <phase>`** — `kind: impl` | `estimate_minutes: 55`
  - executor: BUILDER (Jayce) | ADR: §D7.1
  - files: `scripts/orianna-sign.sh` (new)
  - detail: validate source dir for requested phase; invoke phase-appropriate prompt via `claude` CLI (no mechanical fallback — §D9.2); on clean, compute body hash (T1.1), append `orianna_signature_<phase>: "sha256:<h>:<iso>"` to frontmatter, commit with Orianna author identity + trailers (§D1.1); no push.
  - deps: T1.1, T3.2, T3.3, T4.1, T4.2, T4.3, T4.4
  - DoD: rejects wrong-dir phase; on check-fail plan unchanged; on check-pass exactly one frontmatter line added; shellcheck-clean.

- [ ] **T2.2. `scripts/orianna-verify-signature.sh <plan> <phase>`** — `kind: impl` | `estimate_minutes: 45`
  - executor: BUILDER (Jayce) | ADR: §D7.2, §D6.2
  - files: `scripts/orianna-verify-signature.sh` (new)
  - detail: four checks — body-hash match, commit-author email match, trailer presence/consistency, single-file diff scope. 0 on valid, non-zero with stderr diagnosis otherwise.
  - deps: T1.1; T5.2 xfail first
  - DoD: exits 0 on valid; non-zero with distinct message for each of 4 failure modes.

- [ ] **T2.3. Signature-shape pre-commit hook** — `kind: impl` | `estimate_minutes: 40`
  - executor: BUILDER (Jayce) | ADR: §D1.2, §D7.3
  - files: `scripts/hooks/pre-commit-orianna-signature-guard.sh` (new)
  - detail: when commit author = Orianna identity, enforce: diff touches exactly one file under `plans/`; exactly one `orianna_signature_<phase>` line added; all three trailers present and consistent.
  - deps: T5.3 xfail first
  - DoD: accepts valid signing commit; rejects multi-file diff; rejects missing trailer.

- [ ] **T2.4. Install new hook in `scripts/install-hooks.sh`** — `kind: infra` | `estimate_minutes: 10`
  - executor: REFACTOR (Viktor) | ADR: §D7.3
  - files: `scripts/install-hooks.sh` (edit)
  - deps: T2.3
  - DoD: fresh-clone install picks up `pre-commit-orianna-signature-guard.sh`; idempotent.

### Phase 3 — Phase-specific Orianna prompts

- [ ] **T3.1. Extend `plan-check.md` to full §D2.1 scope** — `kind: docs` | `estimate_minutes: 25`
  - executor: REFACTOR (Viktor) | ADR: §D2.1
  - files: `agents/orianna/prompts/plan-check.md` (edit)
  - detail: preserve v1 claim-contract + gating-question checks; add frontmatter sanity (`status: proposed`, `owner:`, `created:`, `tags:`) and sibling-file grep (`<basename>-tasks.md`, `<basename>-tests.md` absent under `plans/` per §D3 grandfather rule).
  - DoD: all §D2.1 bullets covered; v1 checks still pass on plan 1.

- [ ] **T3.2. New `task-gate-check.md` prompt (approved → in-progress)** — `kind: docs` | `estimate_minutes: 35`
  - executor: BUILDER (Jayce) | ADR: §D2.2
  - files: `agents/orianna/prompts/task-gate-check.md` (new)
  - detail: inline `## Tasks` exists; every task has `estimate_minutes:` integer in `[1,60]` (via T4.3); `kind: test` task present when `tests_required: true`; inline `## Test plan` section present and non-empty; approved-signature carry-forward valid (via T2.2); sibling-file grep.
  - deps: T3.1 (format parity), T4.3 reference
  - DoD: each §D2.2 bullet represented as a concrete check with block-severity criteria.

- [ ] **T3.3. New `implementation-gate-check.md` prompt (in-progress → implemented)** — `kind: docs` | `estimate_minutes: 35`
  - executor: BUILDER (Jayce) | ADR: §D2.3
  - files: `agents/orianna/prompts/implementation-gate-check.md` (new)
  - detail: re-run claim-contract on current tree; enforce `architecture_changes:` OR `architecture_impact: none` (via T4.4); `## Test results` section with CI/log link if `tests_required`; carry-forward both prior signatures.
  - deps: T3.2 parity, T4.4 reference
  - DoD: each §D2.3 bullet represented; block-severity criteria explicit.

### Phase 4 — Gate logic libs

- [ ] **T4.1. In-progress gate lib** — `kind: impl` | `estimate_minutes: 50`
  - executor: BUILDER (Jayce) | ADR: §D2.2
  - files: `scripts/_lib_orianna_gate_inprogress.sh` (new)
  - detail: sourceable bash functions — `check_tasks_section`, `check_estimate_minutes` (delegates to T4.3), `check_test_tasks_present`, `check_test_plan_section`, `check_sibling_absent`, `check_approved_carry_forward` (calls T2.2).
  - deps: T2.2, T4.3
  - DoD: each function returns 0/non-zero with stderr; sourced by `orianna-sign.sh`.

- [ ] **T4.2. Implemented gate lib** — `kind: impl` | `estimate_minutes: 50`
  - executor: BUILDER (Jayce) | ADR: §D2.3
  - files: `scripts/_lib_orianna_gate_implemented.sh` (new)
  - detail: `check_claim_anchors_current`, `check_architecture_declaration` (T4.4), `check_test_results_section`, `check_carry_forward_approved`, `check_carry_forward_inprogress`.
  - deps: T2.2, T4.4
  - DoD: all §D2.3 bullets covered; distinct stderr per failure.

- [ ] **T4.3. `estimate_minutes` parser + bounds lib** — `kind: impl` | `estimate_minutes: 30`
  - executor: BUILDER (Jayce) | ADR: §D4
  - files: `scripts/_lib_orianna_estimates.sh` (new, separate — OQ-K1 resolved: separate file, not bundled; T4.1 sources it)
  - detail: parse every task entry under `## Tasks`; verify `estimate_minutes:` present, integer, `1 ≤ n ≤ 60`; reject alt-unit literals (`hours`, `days`, `weeks`, `h)`, `(d)`) anywhere in section.
  - deps: T5.4 xfail first
  - DoD: rejects missing, zero, negative, 61, alt-units; clean pass on conforming fixture.

- [ ] **T4.4. Architecture-freshness verifier lib** — `kind: impl` | `estimate_minutes: 45`
  - executor: BUILDER (Jayce) | ADR: §D5
  - files: `scripts/_lib_orianna_architecture.sh` (new) — or folded into T4.2
  - detail: reads `architecture_changes:` list OR `architecture_impact: none`; enforces exactly one present; for list case verifies each path exists AND has git-log entry modifying it within `[approved_signature_timestamp, now]`; for none case verifies `## Architecture impact` heading exact match with non-empty body.
  - deps: T5.5 xfail first
  - DoD: all four §D5 failure modes rejected with distinct stderr.

### Phase 5 — Tests (xfail-first per CLAUDE.md rule 12)

- [ ] **T5.1. Tests for hash-body helper** — `kind: test` | `estimate_minutes: 25`
  - executor: TEST (Vi) | files: `scripts/test-orianna-hash-body.sh` (new)
  - detail: CRLF↔LF parity, trailing-ws parity, frontmatter-only change same hash, body change different hash.
  - DoD: four cases; xfail commit precedes T1.1 impl.

- [ ] **T5.2. Tests for `orianna-verify-signature.sh`** — `kind: test` | `estimate_minutes: 40`
  - executor: TEST (Vi) | files: `scripts/test-orianna-verify-signature.sh` (new)
  - detail: good sig; tampered body (hash mismatch); wrong author email; missing trailer; multi-file diff scope; stale sig after edit.
  - DoD: six cases; xfail precedes T2.2.

- [ ] **T5.3. Tests for signature-shape hook** — `kind: test` | `estimate_minutes: 30`
  - executor: TEST (Vi) | files: `scripts/hooks/test-pre-commit-orianna-signature.sh` (new)
  - detail: parity with `scripts/hooks/test-plan-promote-guard.sh` structure; valid-accept + 3 reject cases.
  - DoD: xfail precedes T2.3.

- [ ] **T5.4. Tests for estimate_minutes parser** — `kind: test` | `estimate_minutes: 25`
  - executor: TEST (Vi) | files: `scripts/test-orianna-estimates.sh` (new)
  - detail: seven cases — missing, zero, negative, 61, `hours` literal, `(d)` literal, clean pass.
  - DoD: xfail precedes T4.3.

- [ ] **T5.5. Tests for architecture verifier** — `kind: test` | `estimate_minutes: 35`
  - executor: TEST (Vi) | files: `scripts/test-orianna-architecture.sh` (new)
  - detail: both-fields-missing block; list with unmodified path block; list with valid mods pass; none with empty section block; none with one-line reason pass.
  - DoD: five cases; xfail precedes T4.4.

- [ ] **T5.6. Tests for sibling-file grep** — `kind: test` | `estimate_minutes: 20`
  - executor: TEST (Vi) | files: `scripts/test-orianna-sibling-grep.sh` (new)
  - detail: fixture with `<basename>-tasks.md` sibling → approved gate blocks; sibling deleted → pass.
  - DoD: two cases; xfail precedes T3.1 + T4.1 completion.

- [ ] **T5.7. End-to-end smoke harness** — `kind: test` | `estimate_minutes: 55`
  - executor: TEST (Vi) | files: `scripts/test-orianna-lifecycle-smoke.sh` (new)
  - detail: create toy plan in `plans/proposed/`; sign approved; verify; edit body; re-sign; sign in-progress; promote; sign implemented; promote; confirm all three signatures valid post-hoc.
  - deps: T1–T6 complete
  - DoD: scenario green end-to-end; serves as §D12 smoke-test.

### Phase 6 — `plan-promote.sh` integration

- [ ] **T6.1. Signature presence + validity check** — `kind: refactor` | `estimate_minutes: 30`
  - executor: REFACTOR (Viktor) | ADR: §D6.1, §D6.2
  - files: `scripts/plan-promote.sh` (edit)
  - detail: for target phase, assert `orianna_signature_<target>` in frontmatter; invoke `orianna-verify-signature.sh`; halt with error pointing to `orianna-sign.sh`.
  - deps: T2.2
  - DoD: missing/invalid signature halts promote with targeted error.

- [ ] **T6.2. Carry-forward check** — `kind: refactor` | `estimate_minutes: 25`
  - executor: REFACTOR (Viktor) | ADR: §D6.3
  - files: `scripts/plan-promote.sh` (edit)
  - detail: for transitions past approved, verify all prior-phase signatures still valid against current body hash.
  - deps: T6.1
  - DoD: tampered approved-body blocks in-progress promote.

- [ ] **T6.3. Advisory file-lock** — `kind: refactor` | `estimate_minutes: 30`
  - executor: REFACTOR (Viktor) | ADR: §D9.3
  - files: `scripts/plan-promote.sh` (edit)
  - detail: wrap promote body in `flock` on `<repo-root>/.plan-promote.lock` with `mkdir`-fallback for portability (CLAUDE.md rule 10).
  - DoD: concurrent invocation: second fails fast with PID-of-holder error.

- [ ] **T6.4. `orianna_gate_version` grandfather branching** — `kind: refactor` | `estimate_minutes: 35`
  - executor: REFACTOR (Viktor) | ADR: §D8
  - files: `scripts/plan-promote.sh` (edit)
  - detail: read `orianna_gate_version` from source; absent → log warning + retain legacy fact-check behavior; `= 2` → enforce T6.1/T6.2 gates.
  - deps: T6.1, T6.2
  - DoD: grandfathered plan promotes under v1; v2 plan only on valid signature.

- [ ] **T6.5. Retire fact-check call site (v2 path only)** — `kind: refactor` | `estimate_minutes: 20`
  - executor: REFACTOR (Viktor) | ADR: §D6
  - files: `scripts/plan-promote.sh` (edit)
  - detail: on v2 branch, remove direct `orianna-fact-check.sh` invocation — fact-check now runs inside `orianna-sign.sh` as precondition. Keep legacy call on the grandfather branch (T6.4). **Do NOT delete `orianna-fact-check.sh`** — it remains the mechanism `orianna-sign.sh` reuses under §D2.1.
  - deps: T6.4, T2.1
  - DoD: v2 plans: no redundant fact-check; v1 grandfathered: legacy path preserved.

### Phase 7 — Bypass hardening

- [ ] **T7.1. Restrict `Orianna-Bypass` to admin identity** — `kind: refactor` | `estimate_minutes: 25`
  - executor: REFACTOR (Viktor) | ADR: §D9.1
  - files: `scripts/hooks/pre-commit-plan-promote-guard.sh` (edit), plus test update
  - detail: reject any commit carrying `Orianna-Bypass:` trailer when author email = `duong.nguyen.thai.duy@gmail.com` (agent account). Only Duong's admin identity (`harukainguyen1411` / personal email) may use the trailer. Update `scripts/hooks/test-plan-promote-guard.sh` to cover both cases.
  - DoD: agent-identity bypass blocked; admin-identity bypass allowed; existing tests still green.

- [ ] **T7.2. Confirm offline-fail via test** — `kind: test` | `estimate_minutes: 15`
  - executor: TEST (Vi) | ADR: §D9.2
  - files: extend T5.7 smoke harness
  - detail: in a hermetic env with `claude` CLI absent, `orianna-sign.sh` exits non-zero emitting "signature unavailable"; no mechanical fallback written.
  - deps: T2.1
  - DoD: test case confirms: missing CLI → no signature → promote halts.

### Phase 8 — Freeze infrastructure (§D12)

- [ ] **T8.1. Temporary new-file freeze hook** — `kind: impl` | `estimate_minutes: 25`
  - executor: BUILDER (Jayce) | ADR: §D12
  - files: `scripts/hooks/pre-commit-plan-authoring-freeze.sh` (new)
  - detail: `git diff --cached --name-status | awk '$1=="A" && $2 ~ /^plans\/proposed\//'` — any match fails commit with message pointing at §D12. `M`/`R`/`D` entries passthrough.
  - DoD: new file under `plans/proposed/` blocked; edits passthrough.

- [ ] **T8.2. Install + announce freeze** — `kind: infra` | `estimate_minutes: 15`
  - executor: ERRAND | ADR: §D12
  - files: `scripts/install-hooks.sh` (edit), `agents/memory/last-session.md` (edit)
  - deps: T8.1
  - DoD: fresh-clone installs freeze hook; Evelynn sees notice at startup.

- [ ] **T8.Z. Removal task — lift freeze** — `kind: chore` | `estimate_minutes: 10`
  - executor: ERRAND (execute only after T11.1 passes) | ADR: §D12
  - files: `scripts/hooks/pre-commit-plan-authoring-freeze.sh` (delete), `scripts/install-hooks.sh` (edit)
  - deps: T11.1
  - DoD: freeze hook deleted; install-hooks wiring removed; commit `chore: lift §D12 freeze`.

### Phase 9 — Migration (§D8, MANUAL one-shot)

- [ ] **T9.1. Bulk demote `plans/approved/*.md` → `plans/proposed/`** — `kind: chore` | `estimate_minutes: 60`
  - executor: ERRAND (human-driven — Duong; §D8 Q9 = manual, no new script) | ADR: §D8
  - files: every `plans/approved/*.md` EXCEPT `plans/approved/2026-04-20-orianna-gated-plan-lifecycle.md` (OQ-K3 resolved: self-referential exception — this ADR stays in `approved/`; see OQ Resolutions section)
  - detail: enumerate files first (drift-catch); `git mv` each into `plans/proposed/`; rewrite `status: approved` → `status: proposed`; batch into ONE `chore:` commit direct to main; re-publish to Drive per-file via `scripts/plan-publish.sh` (proposed-only mirror).
  - deps: T8.1 installed (freeze active first)
  - DoD: `plans/approved/` contains only this ADR (self-referential exception confirmed by OQ-K3); each demoted plan's `status:` matches new dir; Drive mirror re-published; batch commit lists all demoted plans for audit.

- [ ] **T9.2. Sibling-file inline merges (per-plan, opportunistic)** — `kind: chore` | `estimate_minutes: 20` (per affected plan)
  - executor: ERRAND (author-driven per plan — NOT a single task; one per affected plan) | ADR: §D3, §D8 Q10
  - files: per-plan (parent + sibling)
  - detail: for any plan returning to `proposed/` with a grandfathered `<basename>-tasks.md` or `<basename>-tests.md` sibling still on disk — manually inline sibling content into parent's `## Tasks` / `## Test plan` sections; delete sibling. Approved-gate blocks re-promotion until sibling gone (T3.1 grep).
  - deps: T9.1, T3.1
  - DoD per plan: sibling deleted; parent contains inlined content; Orianna approved-gate passes.
  - **Tracking:** Evelynn maintains the list of plans needing this merge in her inbox; not enumerated here because §D8 explicitly says "author's discretion" and the full 56-plan audit would pre-decide author judgment.

### Phase 10 — Architecture docs + CLAUDE.md (§D10)

- [ ] **T10.1. Add Orianna signing role to `architecture/agent-system.md`** — `kind: docs` | `estimate_minutes: 25`
  - executor: REFACTOR (Viktor) | ADR: §D10
  - deps: T2.1, T2.2 exist (for accurate script refs)
  - DoD: section present describing signing role, three signatures, distinct git identity.

- [ ] **T10.2. Document 4 new scripts in `architecture/key-scripts.md`** — `kind: docs` | `estimate_minutes: 25`
  - executor: REFACTOR (Viktor) | ADR: §D10
  - files: `architecture/key-scripts.md` (edit)
  - deps: T1.1, T2.1, T2.2, T2.3
  - detail: entries for `orianna-sign.sh`, `orianna-verify-signature.sh`, `orianna-hash-body.sh`, `pre-commit-orianna-signature-guard.sh`.
  - DoD: four entries with one-line purpose + usage + exit codes.

- [ ] **T10.3. New `architecture/plan-lifecycle.md`** — `kind: docs` | `estimate_minutes: 45`
  - executor: BUILDER (Jayce) | ADR: §D10
  - files: `architecture/plan-lifecycle.md` (new)
  - detail: operator-facing doc — phases, gates, what Orianna checks at each, signature format, grandfather rules.
  - deps: T1–T8 complete (content stable)
  - DoD: readable without the ADR; references ADR as source of truth.

- [ ] **T10.4. CLAUDE.md universal invariant** — `kind: docs` | `estimate_minutes: 20`
  - executor: ERRAND (Duong approval required — rule addition) | ADR: §D10
  - files: `CLAUDE.md` (edit)
  - detail: add rule #19 (OQ-K2 resolved: sequential numbering, no gaps) stating "Plan promotions past `proposed → approved` require valid Orianna signatures on every transition; no bypass except human-admin-identity."
  - deps: T10.3 (so rule can cite arch doc)
  - DoD: rule present; cross-links to `architecture/plan-lifecycle.md` + §D9.1.

### Phase 11 — Smoke + freeze lift

- [ ] **T11.1. End-to-end smoke: fresh plan through all three gates** — `kind: test` | `estimate_minutes: 40`
  - executor: TEST (Vi) | ADR: §D12
  - files: `assessments/2026-04-XX-orianna-gate-smoke.md` (new report)
  - deps: all of T1–T10 + T9.1
  - detail: create synthetic plan in `plans/proposed/`; sign approved → promote; sign in-progress → promote; sign implemented → promote; re-verify all three signatures post-hoc.
  - DoD: smoke green; report written; signatures verifiable via `orianna-verify-signature.sh` on each phase.

- [ ] **T11.2. Lift freeze (execute T8.Z)** — `kind: chore` | `estimate_minutes: 10`
  - executor: ERRAND | ADR: §D12
  - deps: T11.1 green
  - DoD: freeze gone; new-plan authoring works again; ADR implementation complete.

---

## Executor-tier assignment summary

| Tier | Count | Tasks |
|------|-------|-------|
| BUILDER (Jayce) | 12 | T1.1, T1.3, T2.1, T2.2, T2.3, T3.2, T3.3, T4.1, T4.2, T4.3, T4.4, T8.1, T10.3 |
| REFACTOR (Viktor) | 8 | T2.4, T3.1, T6.1, T6.2, T6.3, T6.4, T6.5, T7.1, T10.1, T10.2 |
| TEST (Vi) | 9 | T5.1–T5.7, T7.2, T11.1 |
| ERRAND | 7 | T1.2, T8.2, T8.Z, T9.1, T9.2 (per-plan pattern), T10.4, T11.2 |

**Total atomic tasks: 33** (T9.2 counted once as a pattern; per-plan instances
tracked opportunistically by Evelynn).

## Cross-cutting call-outs for Evelynn (dispatch hints)

1. **Phase 9 is HUMAN work.** T9.1 is a manual 56-file batch per §D8 Q9 — do not spawn an agent. T9.2 is per-plan and opportunistic.
2. **Phase 5 is xfail-first (CLAUDE.md rule 12).** Every test task commits its xfail before the paired impl lands on the same branch.
3. **T3.1 is extend-not-replace.** Shipped `plan-check.md` is load-bearing (plan 1 passed through it); preserve v1 checks while adding §D2.1 scope.
4. **T6.5 retires the call site — does NOT delete the script.** `orianna-fact-check.sh` remains the machinery `orianna-sign.sh` reuses under §D2.1.
5. **Freeze window is LONG.** T8.1 activates; T11.2 lifts. No new-plan authoring agents spawn in between. Edits to existing drafts are fine (§D12 Q11).
6. **Duong-blockers.** T9.1 (manual demotion), T10.4 (rule addition), any §D9.1 bypass decisions. Everything else is agent-dispatchable.
7. **`orianna_gate_version: 2` is the switch.** Plans authored after this ADR carry it; demoted plans (T9.1) don't yet — they acquire it on first re-sign. T6.4 is the branching point.

## Deliverables explicitly deferred / out of scope

- **D11 test-plan schema ADR** — follow-up ADR owned by test-plan role.
- **Architecture-doc authoring automation** (§"Out of scope") — Orianna verifies, humans/agents write.
- **Cross-repo extension** to strawberry-app lifecycle — deferred.
- **Task-execution gates during in-progress** — deferred.
- **PR-level Orianna signatures** — explicitly out of scope.

## Open questions raised by the breakdown

All three resolved by Evelynn on 2026-04-20. See `## OQ Resolutions` section above for full rationale; inline task definitions updated to reflect each answer.

- **OQ-K1.** T4.3 lib placement — **RESOLVED: separate file** (`scripts/_lib_orianna_estimates.sh`). Not bundled into `_lib_orianna_gate_inprogress.sh`.
- **OQ-K2.** T10.4 rule slot number — **RESOLVED: rule #19.** Sequential, no gaps.
- **OQ-K3.** T9.1 demotion scope — **RESOLVED: this ADR stays in `approved/`.** Self-referential exception; T9.1 excludes this file explicitly.

## Revision log

- 2026-04-20 — Kayn — initial inline breakdown (replaces earlier sibling-file draft per §D3 one-plan-one-file rule). 33 atomic tasks across 11 phases; 8 shipped items inventoried and excluded from re-tasking; anti-duplicate rule on `orianna-fact-check.sh` (retire call site, preserve script).

