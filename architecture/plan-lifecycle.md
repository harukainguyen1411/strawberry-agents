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

- **Frontmatter:** `owner:` present and non-blank. (`status:`, `created:`,
  `tags:` are enforced at commit time by the pre-commit linter — not rechecked
  here. Rescoped 2026-04-22: OQ-4 resolution b.)
- **Gating questions:** no unresolved `TBD` / `TODO` / `Decision pending`
  markers in gating/open-questions sections.
- **Claim-contract (v2):** internal-prefix (C2a) backtick tokens resolved via
  `test -e` (block on miss). Non-internal-prefix (C2b) tokens — HTTP routes,
  dotted identifiers, template expressions — logged as `info` (no filesystem
  check). Fenced code block content not extracted. (Rescoped 2026-04-22: OQ-1,
  OQ-2.)
- **Sibling-file grep:** no `<basename>-tasks.md` or `<basename>-tests.md`
  files under `plans/` (one-plan-one-file rule, ADR §D3).

### approved → in-progress (`task-gate-check.md`)

Full scope in `agents/orianna/prompts/task-gate-check.md`. Summary:

- **`## Tasks` section inline:** required, non-empty.
- **`estimate_minutes:`** NOT checked here — the pre-commit structural linter
  (`scripts/hooks/pre-commit-zz-plan-structure.sh`) is the sole enforcer.
  (Rescoped 2026-04-22: OQ-3 resolution a.)
- **Test task present** (when `tests_required: true`): at least one task with
  `kind: test` or a title matching `write/add/create/update ... test`.
- **`## Test plan` section inline** (when `tests_required: true`): non-empty.
- **Sibling-file absent** (same as approved gate).
- **Approved-signature carry-forward:** `orianna_signature_approved` present
  and valid against current body hash.

### in-progress → implemented (`implementation-gate-check.md`)

Full scope in `agents/orianna/prompts/implementation-gate-check.md`. Summary:

- **Implementation evidence (v2):** internal-prefix (C2a) path claims resolve
  on the current tree. C2b tokens (non-internal-prefix) are info. Fenced blocks
  not extracted. (Rescoped 2026-04-22: OQ-1, OQ-2.)
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

**Tamper evidence:** the commit that introduces each signature line must satisfy
one of two shapes defined in §Shape B commit contract below.

Verification: `bash scripts/orianna-verify-signature.sh <plan.md> <phase>`

---

## Shape B commit contract

`scripts/orianna-sign.sh` emits two commit shapes. The
`scripts/hooks/pre-commit-orianna-signature-guard.sh` hook accepts both.

**Shape A (sig-only commit):** the default when no mechanical pre-fix edits
were applied.

- Diff adds exactly one `orianna_signature_<phase>:` frontmatter line.
- No other lines change.
- Trailers: `Signed-by: Orianna`, `Signed-phase: <phase>`,
  `Signed-hash: sha256:<hash>`.
- The commit must touch exactly one file (the plan file).

**Shape B (atomic body+signature commit):** emitted when `--pre-fix` is active
and the pre-fix script (`scripts/orianna-pre-fix.sh`) produced body edits in the
same invocation.

- Diff includes BOTH the pre-fix rewrites AND the `orianna_signature_<phase>:` insertion.
- Commit message carries an additional `Signed-Fix: <phase>` trailer BEFORE the
  three standard trailers.
- The `pre-commit-orianna-signature-guard.sh` hook verifies that the body hash
  stored in the new signature line equals the post-diff body hash (not the
  pre-diff hash). A hash mismatch rejects the commit.
- One-file scope is still required.

Shape B halves the commit ceremony for work-concern plans with legacy
workspace-prefix patterns: the mechanical rewrite and the signature land in a
single atomic commit instead of two separate commits.

Cross-reference: `architecture/key-scripts.md` §Shape B commit contract.

---

## Body-hash pre-commit guard

`scripts/hooks/pre-commit-orianna-body-hash-guard.sh` prevents the most common
silent failure mode: editing a signed plan's body after signing without
re-signing.

**How it works:** for every staged `plans/**/*.md` file that carries one or
more `orianna_signature_*` fields, the hook recomputes the body hash via
`scripts/orianna-hash-body.sh` and compares it to the hash stored in each
signature field. If any field's stored hash does not match the current body
hash, the commit is rejected.

**Error message:** the hook prints a self-documenting runbook to stderr:

```
[orianna-body-hash-guard] ERROR: body-hash mismatch on <phase> signature in <plan>
  stored:   <old-hash>
  current:  <new-hash>
  Recovery: remove the orianna_signature_<phase> field from frontmatter and
            re-run: bash scripts/orianna-sign.sh <plan> <phase>
  Bypass:   add 'Orianna-Bypass: <reason>' trailer (Duong only; hooks verify identity)
```

**Invariant preserved:** a body edit on a signed plan is blocked at commit
time, not silently deferred to promotion time (§T2 of
`plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md`).

**Re-running install-hooks.sh** is required for existing checkouts to pick
up this hook after the gate-speedups branch merges.

---

## What happens if you edit the plan after signing

Editing the plan body changes the hash. The stored signature no longer matches
and `orianna-verify-signature.sh` will fail. The body-hash pre-commit guard
(§Body-hash pre-commit guard above) catches this at commit time; without the
hook, promotion-time verification catches it instead.

**Resolution:** remove the stale `orianna_signature_<phase>` field from
frontmatter and re-run `orianna-sign.sh <plan> <phase>`. The sign script
re-runs the gate check and re-signs with the new hash.

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

**Pre-Orianna archive:** historical pre-Orianna plans (those lacking
`orianna_gate_version: 2`) have been relocated to `plans/pre-orianna/<phase>/`
to keep the active phase directories focused on current-regime work. The
pre-orianna tree preserves the original phase as a subdir (proposed,
approved, in-progress, implemented, archived). `plan-promote.sh` and
`orianna-sign.sh` do not operate on pre-orianna paths; the structural
pre-commit linter exempts the directory alongside `plans/archived/*`.

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

**Shift-left rationale:** Orianna's structural plan checks are deterministic and fast.
Running them only at promotion-time means a planner can push a structurally broken plan
and find out hours later. `scripts/hooks/pre-commit-zz-plan-structure.sh` runs all
deterministic Orianna-parity checks at `git commit`, before any LLM invocation.

**What the hook checks (all five rules, Orianna-parity):**

- **Rule 1 — Canonical `## Tasks` heading:** a plan body must contain exactly `## Tasks`
  or `## N. Tasks` (where N is an integer). Variant spellings like `## Task breakdown (Foo)`
  are rejected with `no canonical ## Tasks heading found`. Both a canonical heading and a
  variant may coexist; only the canonical heading satisfies the rule.
- **Rule 2 — Per-task estimate_minutes key:value:** every `- [ ]` / `- [x]` task entry
  must carry `estimate_minutes: <int>` as a key:value on the task line (not just a table column).
  Integer must be in `[1, 60]`. Banned alternative literals (`hours`, `days`, `weeks`, `h)`,
  `(d)`) are rejected outside backtick spans.
- **Rule 3 — Test-task title qualifier:** any task whose first word after the em-dash is one
  of `xfail`, `test`, or `regression` (case-insensitive) must either (a) begin with an approved
  action verb (`Write`, `Add`, `Create`, `Update`) OR (b) carry `kind: test` on the task line.
  This rule prevents ambiguous test-task titles that Orianna would reject at sign time.
- **Rule 4 — Cited backtick paths must exist:** every `` `path/like/this.ext` `` token in the
  plan body that looks like a file path (contains `/` or has a file extension, not starting with
  `http`) is resolved relative to the repo root. Missing paths block with `cited path does not
  exist: <path>`. Suppress with `<!-- orianna: ok -->` on the same line for prospective paths
  (files that do not exist yet).
- **Rule 5 — Forward self-reference:** if a plan in `plans/proposed/` cites its own future
  promoted path (e.g. `plans/approved/.../<same-slug>.md`), that line requires
  `<!-- orianna: ok -->`. Forward self-references without suppression are blocked.

**What the hook does NOT check:**

- Body-hash carry-forward freshness (Orianna's sixth check — the signature is appended after
  the commit, so this stays Orianna-only).
- Semantic correctness, prose quality, or gating-question resolution.
- Plans under `plans/archived/**` (grandfathered) or `plans/_template.md`.

**Suppression marker:** `<!-- orianna: ok -->` anywhere on a line suppresses rules 4 and 5
for that line. Use it for prospective paths and intentional forward self-references. The marker
is per-line and must appear on the same line as the backtick-quoted path.

**Grandfathering policy:** the hook only runs on staged diffs. Existing plans that pre-date
this rule set are not retroactively blocked; they stay quiet on disk until their next edit
triggers a staged diff. Authors with plans that have variant headings or cross-repo path
citations should add `<!-- orianna: ok -->` suppressions (rule 4) or rename the heading
(rule 1) when next editing.

**Split of responsibilities:**

| Layer | Tool | Trigger | Checks |
|-------|------|---------|--------|
| Pre-commit | `scripts/hooks/pre-commit-zz-plan-structure.sh` | `git commit` | Structural (all 5 rules, fast, deterministic) |
| Promotion gate | Orianna via `scripts/orianna-sign.sh` | `plan-promote.sh` | Full: structural + semantic + body-hash carry-forward |

**Entry point:** copy `plans/_template.md` for new plans. All required frontmatter keys and
section headings are pre-filled with `<placeholder>` values that fail the linter until filled in.

**Shared library:** `scripts/_lib_plan_structure.sh` exposes `check_plan_frontmatter`,
`check_task_estimates`, `check_test_plan_present`, and `check_plan_structure`. The estimate
validation rules match `scripts/_lib_orianna_estimates.sh` (§D4). The new hook does not
source the lib (single-file awk pass); the lib remains available for standalone callers.

**Performance:** single awk pass over all staged plan files; < 200ms for 10 staged plans.

---

## Related scripts

| Script | Purpose |
|--------|---------|
| `scripts/orianna-sign.sh` | Entry point: run Orianna check, append signature, commit. Emits shape A or shape B commits (see §Shape B commit contract). Supports `--pre-fix` / `--no-pre-fix` flags; invokes `scripts/orianna-pre-fix.sh` when active. Calls `scripts/_lib_stale_lock.sh` at startup to clear stale `.git/index.lock`. |
| `scripts/orianna-verify-signature.sh` | Verify a signature (4-check: hash, author, trailers, single-file scope) |
| `scripts/orianna-hash-body.sh` | Compute normalized SHA-256 of plan body |
| `scripts/orianna-pre-fix.sh` | Apply known-safe mechanical rewrites before the first Orianna invocation (concern-scoped workspace prefix, prose-host suppressors, `?`-marker detection). Idempotent. |
| `scripts/_lib_stale_lock.sh` | Shared library: `maybe_clear_stale_lock <lockfile>` — clears a stale `.git/index.lock` when it is >60s old and has no live holder. Sourced by `orianna-sign.sh` and `plan-promote.sh` at startup. |
| `scripts/plan-promote.sh` | Move plan between phase directories (verifies signatures). Calls `scripts/_lib_stale_lock.sh` at startup. |
| `scripts/hooks/pre-commit-orianna-body-hash-guard.sh` | Block commits that edit a signed plan's body without re-signing (see §Body-hash pre-commit guard). Wire via `scripts/install-hooks.sh`. |
| `scripts/hooks/pre-commit-orianna-signature-guard.sh` | Enforce signing commit shape — accepts shape A (sig-only) and shape B (body+signature, `Signed-Fix:` trailer) |
| `scripts/hooks/pre-commit-plan-authoring-freeze.sh` | Block new plan creation during freeze window |
| `scripts/hooks/pre-commit-zz-plan-structure.sh` | Pre-commit structural lint for staged plans/**/*.md (rules 1–5, Orianna-parity) |
| `scripts/hooks/pre-commit-t-plan-structure.sh` | Legacy pre-commit linter (rules 1–2 only); superseded by `pre-commit-zz-plan-structure.sh` |
| `scripts/_lib_plan_structure.sh` | Shared lib: check_plan_frontmatter, check_task_estimates, check_test_plan_present, check_plan_structure |
| `plans/_template.md` | Plan authoring template; correct-by-construction frontmatter + section skeletons |
| `agents/orianna/prompts/plan-check.md` | proposed→approved gate prompt |
| `agents/orianna/prompts/task-gate-check.md` | approved→in-progress gate prompt |
| `agents/orianna/prompts/implementation-gate-check.md` | in-progress→implemented gate prompt |
