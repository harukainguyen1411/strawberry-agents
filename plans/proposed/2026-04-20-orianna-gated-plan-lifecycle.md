---
title: Orianna-gated plan lifecycle — signature required at every phase transition
status: proposed
owner: swain
created: 2026-04-20
tags: [workflow, plan-lifecycle, orianna, governance]
---

# Context

The plan lifecycle today (`proposed/` → `approved/` → `in-progress/` → `implemented/` → `archived/`) is only partially gated. `scripts/plan-promote.sh` runs an Orianna fact-check on the `proposed → approved` transition (see `scripts/plan-promote.sh:63-86` and `scripts/orianna-fact-check.sh`), but subsequent transitions carry no gate at all. The symptoms:

- **Task breakdowns are ad-hoc.** Kayn/Aphelios sometimes emit a `-tasks.md` sibling (e.g. `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md`), sometimes inline the tasks in the parent plan, sometimes skip the step entirely. No hook or script enforces existence.
- **Test plans are decoupled.** Caitlyn writes testing plans on request, but nothing requires one before `approved → in-progress`.
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
- **Low ceremony, high signal.** A dedicated hash ledger (`.orianna-signatures.json` committed to a protected path) is heavier machinery for no additional security — the attacker vector in a solo-dev agent system is not a malicious committer, it is *an agent forgetting to invoke Orianna*. Git authorship is sufficient to distinguish "Orianna wrote this" from "Kayn wrote this" without a separate signing infrastructure.
- **Reviewable in `git log` without tooling.** `git blame <plan>` answers "who signed this" in one command. A sig file or ledger requires an extra step.

The body-hash field *is* load-bearing: if any agent edits the plan body after Orianna signs, the hash recorded in the signature no longer matches the current body, and `plan-promote.sh` refuses on content-drift grounds even if authorship checks out. This catches the "sign, then sneak an edit in before promote" case.

### D1.1. Making Orianna's git identity distinguishable

Today, subagent commits in this repo are authored as `Duongntd <duong.nguyen.thai.duy@gmail.com>` (the agent GitHub account — see `agents/memory/duong.md:14`). Every agent — Jayce, Viktor, Kayn, Orianna — commits as the same identity. That is insufficient for a per-agent signature.

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
- **Caitlyn test plan appended inline.** If `tests_required: true`, the plan must contain a `## Test plan` section inside the plan file. Sibling `<basename>-tests.md` files are **not** accepted — same single-file rule as tasks. Orianna verifies the section exists and is non-empty; she does not validate contents (format is a follow-up Caitlyn ADR, §D11).
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

**Decision:** One plan, one file. Task lists live inside the plan file under a `## Tasks` section. Sibling `<basename>-tasks.md` files are **not** permitted under the new gate. Likewise for Caitlyn's `## Test plan` section (§D2.2) — inline only, no sibling files.

**Rationale:**

- **Single-file lifecycle.** The promote script moves one file; a sibling would force every move to be multi-file. Script complexity grows; drift windows open when only one half moves.
- **Signature coverage.** The signature's body-hash (§D1) covers the task list, test plan, and any other in-file sections automatically. Sibling files would need their own hashes, doubling the machinery with no added value.
- **Orianna grep simplicity.** Every §D2 check is a single-file read — no "is the sibling also clean?" logic.

**Grandfathered sibling files:** Existing sibling files in `plans/in-progress/` and earlier stages (e.g. `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md`) remain on disk for their current phase but carry no signature weight. Plans demoted to `plans/proposed/` under §D8 must inline any existing sibling content before their next promotion — the demotion script performs this merge as part of the one-time backfill.

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
- AI-minutes are calibratable: after the plan completes, Evelynn or Lucian can compare estimate to actual session durations and build a correction factor per agent/task-kind.

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
- The demotion is a one-time bulk operation performed by `scripts/plan-promote.sh --demote-to-proposed` (a new mode, see §D7 follow-up) OR a one-shot migration script. It uses the Drive-mirror-aware flow so Drive docs for demoted plans get (re-)published.
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

## D11. Caitlyn test-plan schema — deferred to a follow-up ADR

This ADR checks only the existence of a `## Test plan` section in the plan file (§D2.2). The schema of that section — test-case list shape, expected/actual columns, coverage expectations — is out of scope here and will be specified in a dedicated Caitlyn ADR. Until that ADR lands, Caitlyn authors an ad-hoc test plan directly inside the plan file (same single-file rule as tasks). Orianna's gate passes as long as the section exists and is non-empty.

---

## D12. Implementation ordering — plan-authoring freeze

Because this ADR introduces new mandatory frontmatter fields (`orianna_gate_version`, potentially `tests_required`, `architecture_changes` / `architecture_impact`) and restructures the lifecycle around a signing gate, **new plan creation is frozen from the moment this ADR promotes to `in-progress/` until the new gate infrastructure is live and validated**. The freeze window is enforced socially (Evelynn does not spawn Swain/Aphelios for new plans during this period) and mechanically via a temporary pre-commit hook that rejects new files under `plans/proposed/`. Once `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`, and the updated `plan-promote.sh` are all green on a smoke test (§D8 demotion + one fresh plan signed through all three phases), the freeze lifts. The freeze is tracked as the final task in this ADR's `## Tasks` section.

In-flight work at the freeze start — plans already in `in-progress/` or `implemented/` — continues under grandfathered rules (§D8). The freeze applies only to the creation of new `proposed/` entries.

---

# Resolved gating questions (round 1)

All eight original gating questions were answered by Duong on 2026-04-20. Decisions are captured in the relevant `D*` sections; summary below.

1. **Q1. Orianna git identity.** Resolved: `orianna@agents.strawberry.local` as author email (§D1.1). No GitHub bot account.
2. **Q2. Bypass eligibility.** Resolved: option (b) — `Orianna-Bypass` is valid only when the commit/push originates from Duong's admin identity `harukainguyen1411`, introduced only when break-glass is needed. Agents always use other accounts. Enforcement lives in the pre-commit hook (§D1.2 / §D9.1).
3. **Q3. Grandfathering cutoff.** Resolved: all plans in `plans/approved/` are demoted back to `plans/proposed/` and must re-earn a signature (§D8). Plans in `in-progress/`, `implemented/`, and `archived/` stay put under grandfathered rules; retroactive signing of in-flight plans is author's discretion.
4. **Q4. Test-plan format.** Resolved: defer schema to a follow-up Caitlyn ADR (§D11). The `## Test plan` section is appended inline to the plan file — no sibling files.
5. **Q5. Estimate sanity bounds.** Resolved: `1 ≤ estimate_minutes ≤ 60`. Values above 60 are **block**, forcing decomposition (§D4).
6. **Q6. Architecture-impact declaration default.** Resolved: no implicit default. Plans must declare either `architecture_changes:` or `architecture_impact: none`; missing both is **block** at the implemented gate (§D5).
7. **Q7. Signature coverage of sibling files.** Resolved: no sibling files permitted — one plan, one file (§D3). The question dissolves because the artifact it protected no longer exists.
8. **Q8. Implementation ordering.** Resolved: freeze new plan creation from this ADR's `in-progress/` start until the new gate infrastructure is validated end-to-end (§D12).

---

# Open gating questions (round 2 — new, raised by revision)

These arose while incorporating Duong's round-1 answers and need a decision before this ADR moves to `approved/`.

1. **Q9. Demotion script ownership.** §D8's bulk demotion of `plans/approved/` → `plans/proposed/` + status rewrite + Drive-mirror republish is a one-shot migration. Where does it live? Options: (a) a new mode `scripts/plan-promote.sh --demote-to-proposed` (symmetrical with the existing promote flow — heavier script, benefit of reuse); (b) a throwaway `scripts/migrate/2026-04-20-demote-approved.sh` (lighter, but one-off scripts tend to rot in-tree); (c) manual — author a one-line migration note and use existing `plan-promote.sh` in a reverse mode. Leaning: (a) — adding `--demote-to-proposed` as a first-class mode is cheap once and may prove useful beyond this migration (e.g. re-opening an accidentally-promoted plan).
2. **Q10. Sibling-file merge during demotion.** §D3 requires demoted plans to inline any existing sibling `-tasks.md` or `-tests.md` content before the next promotion. Is this a manual author step, or does the demotion script auto-merge (append sibling content under `## Tasks` / `## Test plan`)? Auto-merge is fragile if siblings have non-canonical heading structures; manual is another thing for Duong/Aphelios to remember. Leaning: auto-merge with a conservative rule — append verbatim under a new `## Tasks (migrated from sibling)` heading so the author can clean up, and mark the plan with `migration_cleanup_required: true` frontmatter that Orianna's `approved` gate checks for (block until cleared).
3. **Q11. Freeze-enforcement hook scope.** §D12's temporary pre-commit hook blocks new files under `plans/proposed/` during the freeze. Does this also block *edits* to existing `proposed/` files (e.g. iterating on an in-flight draft)? Strict read is "new-file-only"; a looser read would block all `proposed/` churn to prevent sneaking drafts in under the wire. Leaning: new-file-only — authors should still be able to polish existing drafts (including this ADR) during the freeze; the goal is to stop *new* work, not to freeze the whole tree.

---

# Out of scope (explicit)

- **Task-execution gates during implementation.** This ADR does not gate per-task commits during `in-progress`. A task-level signature protocol could follow, but adds overhead per commit; defer.
- **Cross-repo architecture** (i.e. `strawberry-app` architecture docs). This ADR scopes to strawberry-agents only. Cross-repo extension is a follow-up once the in-repo flow is proven.
- **PR-level signature.** PRs to `apps/`** are a separate lifecycle governed by CLAUDE.md rules 15, 16, 18. Orianna does not sign PRs.
- **Automation of architecture-doc updates.** §D5 requires the human (or implementing agent) to update `architecture/` — Orianna verifies the update happened but does not write architecture docs herself.

