# Plan Lifecycle — Phases, Gates, and Orianna Signatures

**Source of truth:** `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`

This document is the operator-facing reference. It describes how a plan moves
through the lifecycle, what Orianna checks at each gate, and how signatures
work. Read this document to understand what to do; read the ADR for why those
decisions were made.

---

## Phases

A plan moves through five sequential phases. The directory name reflects the
current phase:

| Phase | Directory | Status value |
|-------|-----------|--------------|
| Authoring | `plans/proposed/` | `proposed` |
| Approved | `plans/approved/` | `approved` |
| In progress | `plans/in-progress/` | `in-progress` |
| Implemented | `plans/implemented/` | `implemented` |
| Archived | `plans/archived/` | `archived` |

Plans are promoted (moved between directories) by `scripts/plan-promote.sh`.

---

## Gate overview

Three transitions require an **Orianna signature** before `plan-promote.sh`
will move the file:

| Transition | Signature field | Gate prompt |
|------------|-----------------|-------------|
| proposed → approved | `orianna_signature_approved` | `agents/orianna/prompts/plan-check.md` |
| approved → in-progress | `orianna_signature_in_progress` | `agents/orianna/prompts/task-gate-check.md` |
| in-progress → implemented | `orianna_signature_implemented` | `agents/orianna/prompts/implementation-gate-check.md` |

The implemented → archived transition has **no gate** (bookkeeping only;
existing signatures are preserved in the archived file).

Plans without `orianna_gate_version: 2` in frontmatter are **grandfathered**:
they promote under the old single-phase fact-check behavior. All new plans
must include `orianna_gate_version: 2`.

---

## How to sign a plan

Use `scripts/orianna-sign.sh`:

```sh
bash scripts/orianna-sign.sh <plan.md> <phase>
```

Valid phases: `approved`, `in_progress`, `implemented`.

**What it does:**

1. Verifies the plan is in the correct source directory for the phase.
2. If signing `in_progress` or `implemented`, verifies all prior signatures
   are still valid (carry-forward check).
3. Invokes the phase-appropriate Orianna prompt via the `claude` CLI.
4. If the check passes (zero block findings): appends the
   `orianna_signature_<phase>` line to frontmatter and commits with Orianna's
   git author identity plus the three required trailers.
5. Does NOT push. `plan-promote.sh` pushes when it moves the file.

**If the check fails:** Orianna writes a report to
`assessments/plan-fact-checks/` describing every block finding. Fix the
issues, then re-run `orianna-sign.sh`.

**No offline fallback:** if the `claude` CLI is unavailable, signing refuses
with a clear error. No signature is issued until connectivity is restored
(ADR §D9.2).

---

## What Orianna checks at each gate

### proposed → approved (`plan-check.md`)

Full scope defined in `agents/orianna/prompts/plan-check.md`. Summary:

- **Frontmatter sanity:** `status: proposed`, `owner:`, `created:`, `tags:` all
  present.
- **Gating questions:** no unresolved `TBD` / `TODO` / `Decision pending`
  markers in gating/open-questions sections.
- **Claim-contract:** every path-shaped backtick token resolves via `test -e`
  in the repo (two-repo routing: strawberry-agents vs strawberry-app).
- **Sibling-file grep:** no `<basename>-tasks.md` or `<basename>-tests.md`
  files under `plans/` (one-plan-one-file rule, ADR §D3).

### approved → in-progress (`task-gate-check.md`)

Full scope in `agents/orianna/prompts/task-gate-check.md`. Summary:

- **`## Tasks` section inline:** required, non-empty.
- **`estimate_minutes:` on every task:** integer in `[1, 60]`; no alternative
  unit literals (`hours`, `days`, `weeks`, `h)`, `(d)`).
- **Test task present** (when `tests_required: true`): at least one task with
  `kind: test` or a title matching `write/add/create/update ... test`.
- **`## Test plan` section inline** (when `tests_required: true`): non-empty.
- **Sibling-file absent** (same as approved gate).
- **Approved-signature carry-forward:** `orianna_signature_approved` present
  and valid against current body hash.

### in-progress → implemented (`implementation-gate-check.md`)

Full scope in `agents/orianna/prompts/implementation-gate-check.md`. Summary:

- **Implementation evidence:** every path-shaped claim resolves on the current
  tree (re-runs claim-contract on the implemented codebase).
- **Architecture declaration** (exactly one of):
  - `architecture_changes:` list — each path exists AND has a git commit
    modifying it after the approved-signature timestamp.
  - `architecture_impact: none` — `## Architecture impact` section present
    and non-empty.
- **`## Test results` section** (when `tests_required: true`): contains a CI
  URL (`https://`) or path under `assessments/`.
- **Both prior signatures carry-forward:** `orianna_signature_approved` and
  `orianna_signature_in_progress` both valid.

---

## Signature format

Signatures are stored in YAML frontmatter:

```yaml
orianna_signature_approved: "sha256:<64-hex-chars>:<ISO-8601-UTC>"
orianna_signature_in_progress: "sha256:<64-hex-chars>:<ISO-8601-UTC>"
orianna_signature_implemented: "sha256:<64-hex-chars>:<ISO-8601-UTC>"
```

The hash is SHA-256 of the plan body (content after the second `---`),
with CRLF normalized to LF and trailing whitespace stripped per line.
Normalization is implemented in `scripts/orianna-hash-body.sh`.

**Tamper evidence:** the commit that introduces each signature line must:
- Be authored by `orianna@agents.strawberry.local`.
- Carry three trailers: `Signed-by: Orianna`, `Signed-phase: <phase>`,
  `Signed-hash: sha256:<hash>`.
- Touch exactly one file (the plan file).

Verification: `bash scripts/orianna-verify-signature.sh <plan.md> <phase>`

---

## What happens if you edit the plan after signing

Editing the plan body changes the hash. The stored signature no longer matches
and `orianna-verify-signature.sh` will fail.

**Resolution:** run `orianna-sign.sh <plan> <phase>` again. Orianna re-runs
the gate check (which is fast for the approved gate) and re-signs with the
new hash.

**Trivial edits** (whitespace, trailing newlines) do NOT invalidate the
signature because `orianna-hash-body.sh` strips these during normalization.

---

## Grandfather rules

Plans in `plans/in-progress/`, `plans/implemented/`, and `plans/archived/` at
the time this ADR landed continue under the old single-phase behavior. They
finish their current phase without Orianna signatures.

Plans in `plans/approved/` were demoted back to `plans/proposed/` as a
one-time migration. They must re-earn `orianna_signature_approved` before
they can advance again.

A plan opts into the new gate by including `orianna_gate_version: 2` in
frontmatter. `plan-promote.sh` checks this field: absent = grandfathered
(legacy behavior with warning); `2` = full §D2 gates enforced.

---

## Plan-authoring freeze (§D12)

New plan creation is frozen (pre-commit hook
`scripts/hooks/pre-commit-plan-authoring-freeze.sh`) until the Orianna gate
infrastructure is validated end-to-end. The freeze:

- **Blocks:** newly-added files under `plans/proposed/`.
- **Allows:** edits to existing proposed drafts.

The freeze lifts when T11.1 (end-to-end smoke test) passes. At that point
the freeze hook is deleted from `scripts/hooks/` and removed from
`scripts/install-hooks.sh`.

---

## Bypass (break-glass)

If Orianna's check keeps failing and the block cannot be resolved, Duong's
admin identity (`harukainguyen1411`) may use the `Orianna-Bypass: <reason>`
trailer in the promote commit to skip the signature check. The bypass is
visible in git history. Agent identities cannot use this trailer (enforced
by `scripts/hooks/pre-commit-plan-promote-guard.sh`).

---

## Pre-commit structural lint

**Shift-left rationale:** Orianna's structural plan checks (required frontmatter,
`estimate_minutes:` on every task, `## Test plan` presence when `tests_required: true`)
are deterministic and fast. Running them only at promotion-time means a planner can push
a structurally broken plan and find out late. `scripts/hooks/pre-commit-plan-structure.sh`
runs the same deterministic checks at `git commit`, before any LLM invocation.

**What the hook checks:**

- **Frontmatter:** all six required keys present (`status`, `concern`, `owner`, `created`,
  `orianna_gate_version`, `tests_required`).
- **Task estimates:** every `- [ ]` / `- [x]` task entry has `estimate_minutes:` with an
  integer in `[1, 60]`. Banned alternative literals (`hours`, `days`, `weeks`, `h)`, `(d)`)
  are rejected outside backtick spans.
- **Test plan section:** when `tests_required: true`, a `## Test plan` heading with at least
  one non-blank, non-heading line must be present.

**What the hook does NOT check:**

- Path-shaped claim verification (LLM-only; Orianna's `plan-check.md` at `proposed → approved`).
- Semantic correctness, prose quality, or gating-question resolution.
- Plans under `plans/archived/**` (grandfathered) or `plans/_template.md` (has placeholder values
  by design).

**Split of responsibilities:**

| Layer | Tool | Trigger | Checks |
|-------|------|---------|--------|
| Pre-commit (this) | `scripts/hooks/pre-commit-plan-structure.sh` | `git commit` | Structural (fast, deterministic) |
| Promotion gate | Orianna via `scripts/orianna-sign.sh` | `plan-promote.sh` | Full: structural + semantic + path claims |

**Entry point:** copy `plans/_template.md` for new plans. All required frontmatter keys and
section headings are pre-filled with `<placeholder>` values that fail the linter until filled in.

**Shared library:** `scripts/_lib_plan_structure.sh` exposes `check_plan_frontmatter`,
`check_task_estimates`, `check_test_plan_present`, and `check_plan_structure`. Both the hook
and any other caller source this lib. The estimate validation rules match
`scripts/_lib_orianna_estimates.sh` (§D4).

**Performance:** single awk pass over all staged plan files; < 200ms for 10 staged plans.

---

## Related scripts

| Script | Purpose |
|--------|---------|
| `scripts/orianna-sign.sh` | Entry point: run Orianna check, append signature, commit |
| `scripts/orianna-verify-signature.sh` | Verify a signature (4-check: hash, author, trailers, single-file scope) |
| `scripts/orianna-hash-body.sh` | Compute normalized SHA-256 of plan body |
| `scripts/plan-promote.sh` | Move plan between phase directories (verifies signatures) |
| `scripts/hooks/pre-commit-orianna-signature-guard.sh` | Enforce signing commit shape |
| `scripts/hooks/pre-commit-plan-authoring-freeze.sh` | Block new plan creation during freeze window |
| `scripts/hooks/pre-commit-plan-structure.sh` | Pre-commit structural lint for staged plans/**/*.md |
| `scripts/_lib_plan_structure.sh` | Shared lib: check_plan_frontmatter, check_task_estimates, check_test_plan_present, check_plan_structure |
| `plans/_template.md` | Plan authoring template; correct-by-construction frontmatter + section skeletons |
| `agents/orianna/prompts/plan-check.md` | proposed→approved gate prompt |
| `agents/orianna/prompts/task-gate-check.md` | approved→in-progress gate prompt |
| `agents/orianna/prompts/implementation-gate-check.md` | in-progress→implemented gate prompt |
