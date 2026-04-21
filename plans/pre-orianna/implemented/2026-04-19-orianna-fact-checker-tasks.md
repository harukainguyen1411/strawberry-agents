---
status: implemented
owner: kayn
date: 2026-04-19
title: Orianna fact-checker — Task Breakdown
parent_adr: plans/implemented/2026-04-19-orianna-fact-checker.md
---

# Orianna fact-checker — Task Breakdown

Executable task list for the approved ADR
(`plans/in-progress/2026-04-19-orianna-fact-checker.md`). Five numbered phases
map ADR §1-§5 into atomic tasks. Each task has an ID of the form
`O<phase>.<step>`, a goal, inputs/outputs, acceptance criteria, files
touched, verification step, and prerequisite task IDs. Implementers are
**not** assigned here — per `#rule-plan-writers-no-assignment`, Evelynn
delegates after this breakdown lands.

Repo shorthand used throughout:
- **this repo** = `Duongntd/strawberry` (currently canonical agent-infra
  repo; migrating to `harukainguyen1411/strawberry-agents` per the
  companion migration plan — per Duong's decision, Orianna is wired here
  now, not deferred).
- **strawberry-app** = `harukainguyen1411/strawberry-app` (public code
  repo checkout at `~/Documents/Personal/strawberry-app/`).

## Duong's decisions on Azir's open questions (applied)

| # | Question | Decision | Impact on tasks |
|---|---|---|---|
| 1 | Personality naming | Defer to Lulu/Neeko (not blocking) | `profile.md` stub in O1.2; voice fill-in deferred |
| 2 | Create `agents-table.md`? | **Create now** | New task **O5.3** |
| 3 | CLAUDE.md Rule 7 amendment | Skip (default) | No task; Rule 7 stays as-is |
| 4 | Fallback scope when `claude` CLI absent | **Partial-check** | O3.2 `fact-check-plan.sh` is the fallback path; O3.1 wrapper detects missing CLI and falls through |
| 5 | v2 weekly audit trigger | **GitHub Actions scheduled workflow** | Not in v1 scope; noted in O4 exit notes for future |
| 6 | Block-severity threshold for v1 | **Strict** (unverifiable integration/path fails) | O3.1 / O3.2 severity rules codify strict default |
| 7 | Migration timing | **Wire now** in current repo | All tasks target `Duongntd/strawberry` paths |

## Acceptance criteria model

No formal TDD (parallels the migration plans). Each task names concrete
acceptance criteria verifiable by Jhin/Kayn at review time, plus a
**verification step** a reviewer can run in under 60 seconds against the
working tree. ADR §7 post-implementation checklist is the superset gate;
task-level acceptance criteria are its decomposition.

---

## Phase O1 — Agent scaffolding

Exit criterion: Orianna exists as a fully-defined Sonnet subagent with
standard roster directory layout. No behavior yet — this phase just
materializes the agent identity so `claude --subagent orianna` resolves.

### O1.1 — Create `.claude/agents/orianna.md` agent definition

- **Goal:** Define Orianna as a Sonnet executor with the exact tool
  restrictions from ADR §1.
- **Inputs:** ADR §1 (frontmatter + body guidance);
  `.claude/agents/skarner.md` and `.claude/agents/jhin.md` as Sonnet
  executor templates; CLAUDE.md Rule 9 (model field required).
- **Outputs:** New file `.claude/agents/orianna.md`.
- **Acceptance criteria:**
  - Frontmatter includes `name: Orianna`, `model: sonnet`, `effort: low`,
    `permissionMode: bypassPermissions`, and the `description:` string
    from ADR §1.
  - `tools:` list is **exactly** `[Read, Glob, Grep, Bash]` — no Write,
    no Edit, no Agent, no WebFetch, no WebSearch. Deviation blocks
    acceptance.
  - Body sections: Role, Modes (`plan-check <path>`, `memory-audit`),
    Operating discipline (the four bullets from ADR §1), Commit
    discipline (she never commits — invoking script commits).
  - Personality voice placeholder present with a TODO comment
    referencing Lulu/Neeko (per Duong decision 1, deferred).
  - File passes `grep -l '^model:' .claude/agents/orianna.md` and the
    model value is `sonnet` (CLAUDE.md Rule 9).
- **Files touched:** `.claude/agents/orianna.md` (NEW).
- **Verification:** `grep -c '^- ' .claude/agents/orianna.md` under the
  `tools:` block equals 4; `head -20 .claude/agents/orianna.md` shows
  the correct frontmatter.
- **Blockers:** none.
- **Depends on:** —.

### O1.2 — Create `agents/orianna/` directory scaffold

- **Goal:** Standard agent directory layout matching every other roster
  agent (ADR §2).
- **Inputs:** ADR §2; `agents/skarner/` and `agents/yuumi/` as shape
  references.
- **Outputs:** New files:
  - `agents/orianna/profile.md` — one-page persona + role summary,
    voice placeholder calling out Lulu/Neeko naming pass.
  - `agents/orianna/inbox.md` — empty inbox scaffold matching the
    `agents/<name>/inbox.md` convention.
  - `agents/orianna/memory/MEMORY.md` — header only, "No sessions yet"
    body.
  - `agents/orianna/learnings/index.md` — header only, empty index.
- **Acceptance criteria:**
  - All four files exist.
  - No `journal/` or `transcripts/` directory (ADR §2 explicitly defers
    these until need emerges).
  - `profile.md` cites ADR §1 as the source of truth for behavior, not
    itself.
- **Files touched:** four new files above.
- **Verification:** `ls agents/orianna/` lists `profile.md inbox.md
  memory learnings`; `ls agents/orianna/memory/` lists `MEMORY.md`;
  `ls agents/orianna/learnings/` lists `index.md`.
- **Blockers:** none.
- **Depends on:** —.

### O1.3 — Create output directory scaffolds

- **Goal:** Empty directories for Orianna's two report products (ADR §6
  file list).
- **Inputs:** ADR §4.3 (memory-audit report path) and §3.2 (plan
  fact-check report path).
- **Outputs:**
  - `assessments/memory-audits/.gitkeep`
  - `assessments/plan-fact-checks/.gitkeep`
- **Acceptance criteria:** both `.gitkeep` files committed so the
  directories exist before any script tries to write into them.
- **Files touched:** two new `.gitkeep` files.
- **Verification:** `ls assessments/memory-audits/ assessments/plan-fact-checks/`
  returns `.gitkeep` in each.
- **Blockers:** none.
- **Depends on:** —.

---

## Phase O2 — Claim-extraction contract (shared spec)

Exit criterion: a single written specification captures the v1 claim
taxonomy, anchor rules, and severity thresholds that both the LLM path
(O3.1) and the bash fallback (O3.2) must honor. This phase produces no
runtime code — only the contract the scripts are written against.

### O2.1 — Author `agents/orianna/claim-contract.md`

- **Goal:** Codify ADR §3.1 (grep-style evidence categories, non-claim
  categories, v1 extraction heuristic) as a versioned spec file Orianna
  and `fact-check-plan.sh` both reference.
- **Inputs:** ADR §3.1, §3.3, Duong decision 6 (strict threshold).
- **Outputs:** `agents/orianna/claim-contract.md` containing:
  - Version header (`contract-version: 1`).
  - Seven claim categories with anchor shape rules (ADR §3.1 table).
  - Non-claim categories (speculative future-state, commentary, etc.).
  - Severity definitions:
    - **block** — unverifiable integration name, unverifiable repo path
      in applicable repo, unverifiable workflow / secret / script
      reference. Halts promotion.
    - **warn** — stale-looking but not load-bearing (e.g. reference to
      a file that exists but content changed).
    - **info** — style suggestion (e.g. missing anchor on a claim that
      happens to be true).
  - Strict-default rule: any unverifiable integration or path claim
    defaults to **block** (Duong decision 6).
  - Allowlist file path reference (O2.2).
- **Acceptance criteria:**
  - File is self-contained — a reviewer reading only this file can
    classify any suspect token without reading the ADR.
  - Explicit enumeration of "two-repo" routing: `agents/`, `plans/`,
    `scripts/`, `architecture/`, `assessments/`, `.claude/` → this
    repo; `apps/`, `dashboards/`, `.github/workflows/` → strawberry-app.
  - Explicitly rules prose and opinion out of scope (ADR §7 style-police
    guardrail).
- **Files touched:** `agents/orianna/claim-contract.md` (NEW).
- **Verification:** `grep '^contract-version:' agents/orianna/claim-contract.md`
  matches 1.
- **Blockers:** none.
- **Depends on:** —.

### O2.2 — Author `agents/orianna/allowlist.md`

- **Goal:** Seed the known-good vendor-name allowlist referenced in ADR
  §3.1 step 4, so v1 doesn't block on "Firebase" or "GCP" as bare names.
- **Inputs:** ADR §3.1 heuristic; the Firebase GitHub App bug as the
  canonical negative example (a specific integration name **not** on the
  allowlist even though "Firebase" is).
- **Outputs:** `agents/orianna/allowlist.md` with two sections:
  - **Vendor bare names** (allowed without anchor): Firebase, GCP,
    Cloud Run, GitHub, GitHub Actions, Dependabot, Cloudflare, PostgreSQL,
    Node.js, TypeScript, etc. (seed list; grows over time).
  - **Specific integrations requiring anchors** (never allowlisted as
    bare names): "Firebase GitHub App", "Firebase CI/CD GitHub App",
    "GitHub App", named Cloud Run services, etc. <!-- orianna: ok -->
- **Acceptance criteria:**
  - Both sections populated with at least the seed entries above.
  - File has a top-note: "Adding entries is a PR-review decision.
    Removing entries requires a plan."
- **Files touched:** `agents/orianna/allowlist.md` (NEW).
- **Verification:** `grep -c '^- ' agents/orianna/allowlist.md` is
  ≥ 10 (rough seed coverage).
- **Blockers:** none.
- **Depends on:** O2.1 (category definitions referenced).

---

## Phase O3 — Plan fact-check gate

Exit criterion: `plan-promote.sh` refuses to promote a seeded bad plan
and promotes a clean plan unchanged. Both the LLM path (primary) and
the bash-only fallback (secondary, when `claude` CLI is absent) work.

### O3.1 — Write `scripts/orianna-fact-check.sh` (LLM entrypoint)

- **Goal:** Wrapper script that spawns Orianna as a non-interactive
  subagent via `claude` CLI to fact-check a plan, and emits a
  machine-readable report. Falls through to O3.2 script when `claude`
  CLI is unavailable (Duong decision 4 — partial-check fallback).
- **Inputs:** ADR §3.2 (invocation mechanism option a); ADR §3.1
  (report structure — ordered list of claim, anchor attempted, result,
  severity); O2.1 claim contract; O2.2 allowlist.
- **Outputs:** `scripts/orianna-fact-check.sh` — POSIX bash, takes one
  positional arg (plan path), writes report to
  `assessments/plan-fact-checks/<plan-basename>-<ISO-timestamp>.md`,
  exits 0 on "no block findings", 1 on "block findings present", 2 on
  invocation error.
- **Acceptance criteria:**
  - `set -euo pipefail` at top; POSIX-portable per CLAUDE.md Rule 10.
  - Usage banner when called with 0 args.
  - Plan path validated to exist and end in `.md`.
  - Detects absence of `claude` CLI via `command -v claude`; on absence,
    logs "claude CLI not found, falling back to mechanical check"
    to stderr and `exec`'s `scripts/fact-check-plan.sh` with the same
    args. Exit code propagates.
  - When `claude` CLI is present: invokes
    `claude --subagent orianna --non-interactive --prompt '<pinned prompt>'`.
    The pinned prompt (stored inline as a heredoc in the script)
    instructs Orianna to (a) read the plan, (b) extract claims per
    `agents/orianna/claim-contract.md`, (c) resolve each claim against
    the appropriate repo checkout (this repo for agent-infra paths,
    `~/Documents/Personal/strawberry-app/` for app paths, running a
    `git -C ~/.../strawberry-app fetch origin main` first per ADR §7
    risks mitigation), (d) emit the report in the structured shape
    defined in O2.1.
  - Report structure on disk: frontmatter with `plan:`, `checked_at:`,
    `auditor: orianna`, `claude_cli: present|absent`,
    `block_findings:`, `warn_findings:`, `info_findings:`; body with
    the three severity sections.
  - Exit code: 0 if zero block findings; 1 if ≥ 1 block finding;
    2 on invocation error (claude CLI crashed, timed out, etc.).
  - Report file is always written — even on exit 1 — so reviewers can
    open it.
- **Files touched:** `scripts/orianna-fact-check.sh` (NEW).
- **Verification:**
  - `bash -n scripts/orianna-fact-check.sh` passes (syntax).
  - Run against a known-clean plan (e.g.
    `plans/approved/2026-04-19-public-app-repo-migration.md` per ADR §7
    item 10); exit 0; report file lands under
    `assessments/plan-fact-checks/`.
  - Run against a deliberately-seeded bad plan (see O6.1); exit 1;
    report enumerates the block findings.
- **Blockers:** O1.1 (subagent must exist for `--subagent orianna` to
  resolve), O2.1, O2.2.
- **Depends on:** O1.1, O2.1, O2.2.

### O3.2 — Write `scripts/fact-check-plan.sh` (bash fallback)

- **Goal:** Deterministic pure-bash fallback that runs the mechanical
  checks from O2.1 (path existence, workflow-file existence,
  script-path existence) when the LLM path isn't available. Intentionally
  simpler than O3.1 — may under-report but must never over-report in a
  way that blocks a valid plan (ADR §3.2).
- **Inputs:** ADR §3.2 option (b); O2.1 claim contract (for the subset
  the bash script can verify without LLM judgment); O2.2 allowlist (to
  skip bare vendor names).
- **Outputs:** `scripts/fact-check-plan.sh` — same CLI contract as
  O3.1 (positional plan path, writes report, same exit code schema).
- **Acceptance criteria:**
  - POSIX-portable bash per CLAUDE.md Rule 10; `set -euo pipefail`.
  - Extracts all backtick spans and fenced-code tokens from the plan.
  - For each path-shaped token (contains `/` or ends in a recognized
    extension), classifies by prefix per O2.1 routing rules and runs
    `test -e` against the applicable repo root:
    - `agents/`, `plans/`, `scripts/`, `architecture/`, `assessments/`,
      `.claude/`, `tools/` → this repo.
    - `apps/`, `dashboards/`, `.github/workflows/` → strawberry-app
      checkout. If checkout is missing, emits a `warn` finding on the
      check itself ("could not verify N cross-repo paths") rather than
      failing silently (ADR §4.5).
    - Unknown prefixes → `info` finding with "unknown path prefix; add
      to contract if load-bearing."
  - Skips bare tokens matching the allowlist (O2.2).
  - Does NOT attempt integration-name judgment — that's LLM-only. All
    non-path tokens are passthrough `info`-severity.
  - Exit codes and report file path match O3.1 exactly.
  - `claude_cli: absent` in the report frontmatter.
- **Files touched:** `scripts/fact-check-plan.sh` (NEW).
- **Verification:**
  - `bash -n scripts/fact-check-plan.sh` passes.
  - Run against the seeded bad plan (O6.1); exit 1; at least the path
    claim is flagged as `block` (the integration-name drift may slip
    through as `info` — documented and expected).
  - Run against a clean plan; exit 0.
- **Blockers:** O2.1, O2.2.
- **Depends on:** O2.1, O2.2.

### O3.3 — Integrate fact-check gate into `scripts/plan-promote.sh`

- **Goal:** Insert the fact-check step between the current "require
  clean source" (step 3) and "unpublish Drive doc" (step 4), per ADR
  §3.2.
- **Inputs:** current `scripts/plan-promote.sh` (100 lines);
  `scripts/orianna-fact-check.sh` (O3.1).
- **Outputs:** modified `scripts/plan-promote.sh` with new step block.
- **Acceptance criteria:**
  - New step 3.5 invokes `"$SCRIPT_DIR/orianna-fact-check.sh" "$SOURCE"`.
  - On non-zero exit:
    - Prints block-severity summary to stderr (pulled from the latest
      file in `assessments/plan-fact-checks/` matching the plan
      basename).
    - Prints the full report path.
    - `exit 1`; promotion halted before Drive unpublish and before
      `git mv`.
  - On zero exit: proceeds to step 4 unchanged.
  - Warn/info findings do **not** halt.
  - No `--skip-fact-check` flag, no `ORIANNA_SKIP` env var (ADR §3.3
    explicit non-goals).
  - Drive unpublish has NOT fired if fact-check fails — ordering matters
    (an aborted promotion must leave the Drive doc intact).
  - Existing behavior preserved: frontmatter rewrite, commit, push all
    unchanged when fact-check passes.
- **Files touched:** `scripts/plan-promote.sh` (MODIFY).
- **Verification:**
  - Happy path: `./scripts/plan-promote.sh <clean-proposed-plan> approved`
    runs end-to-end as before, plus leaves a report in
    `assessments/plan-fact-checks/`.
  - Block path: with the seeded bad plan in `plans/proposed/`, running
    `./scripts/plan-promote.sh ... approved` exits non-zero, plan stays
    in `plans/proposed/`, Drive doc (if any) is NOT unpublished, report
    enumerates the block findings.
  - `git diff scripts/plan-promote.sh` shows only the new step inserted
    between existing steps 3 and 4 — no refactoring of untouched code.
- **Blockers:** O3.1 (the script being invoked must exist).
- **Depends on:** O3.1, O3.2.

### O3.4 — Author pinned prompt file for Orianna `plan-check` mode

- **Goal:** Extract the pinned prompt from O3.1's heredoc into a
  versioned file so it can be reviewed and updated separately from the
  shell wrapper.
- **Inputs:** ADR §1 operating discipline; O2.1 claim contract; the
  report structure defined in O3.1.
- **Outputs:** `agents/orianna/prompts/plan-check.md` — the pinned
  prompt.
- **Acceptance criteria:**
  - Prompt tells Orianna to load `agents/orianna/claim-contract.md` and
    `agents/orianna/allowlist.md` before extracting claims.
  - Prompt specifies the exact report output path and format (matches
    O3.1 schema).
  - Prompt explicitly forbids editing any file — read-only work only
    (ADR §1 tool rationale).
  - O3.1 wrapper sources this file (e.g. `PROMPT=$(cat "$SCRIPT_DIR/../agents/orianna/prompts/plan-check.md")`)
    rather than inlining the prompt.
- **Files touched:**
  - `agents/orianna/prompts/plan-check.md` (NEW).
  - `scripts/orianna-fact-check.sh` (MODIFY — replace inline heredoc
    with file-sourced prompt; allowed because O3.1 explicitly permits
    this refactor at handoff).
- **Verification:** `grep -l 'plan-check.md' scripts/orianna-fact-check.sh`
  matches; `cat agents/orianna/prompts/plan-check.md` is non-empty.
- **Blockers:** O3.1.
- **Depends on:** O3.1.

---

## Phase O4 — Weekly memory-audit workflow (v1 manual)

Exit criterion: `scripts/orianna-memory-audit.sh` runs end-to-end and
produces a conforming report in `assessments/memory-audits/`. No cron,
no scheduled workflow in v1 (Duong decision 5 defers cron; when we
automate, it will be GitHub Actions scheduled workflow in the agent-infra
repo — NOT Mac cron).

### O4.1 — Author pinned prompt for Orianna `memory-audit` mode

- **Goal:** Companion prompt to O3.4 for the audit sweep.
- **Inputs:** ADR §4.1 (scope), §4.3 (output format), §4.5 (cross-repo).
- **Outputs:** `agents/orianna/prompts/memory-audit.md`.
- **Acceptance criteria:**
  - Prompt enumerates the sweep scope: `agents/*/memory/**`,
    `agents/*/learnings/**`, `agents/memory/**` — and explicit
    NOT-scope: `plans/**`, `architecture/**`, `assessments/**`.
  - Prompt specifies the report shape from ADR §4.3 (summary counts,
    block/warn/info sections, reconciliation checklist).
  - Prompt names the cross-repo check: before touching any claim about
    `apps/**` or `.github/workflows/**`, run `git -C
    ~/Documents/Personal/strawberry-app fetch origin main` and verify
    against `origin/main` not the working tree (ADR §4.5 + §7 risks).
  - Prompt instructs: if strawberry-app checkout is absent, emit a
    top-level `warn` finding and continue (ADR §4.5).
- **Files touched:** `agents/orianna/prompts/memory-audit.md` (NEW).
- **Verification:** file exists, non-empty,
  `grep -c '^##' agents/orianna/prompts/memory-audit.md` ≥ 3.
- **Blockers:** O2.1.
- **Depends on:** O2.1.

### O4.2 — Write `scripts/orianna-memory-audit.sh`

- **Goal:** Shell entrypoint that invokes Orianna in `memory-audit` mode
  and persists the report. Manual-trigger only in v1.
- **Inputs:** ADR §4; O4.1 prompt; claim contract.
- **Outputs:** `scripts/orianna-memory-audit.sh`.
- **Acceptance criteria:**
  - POSIX bash per CLAUDE.md Rule 10; `set -euo pipefail`.
  - Requires `claude` CLI (memory audit is LLM-only — no mechanical
    fallback in v1). On absence, prints clear error and exits 2.
    Rationale: memory audits need semantic judgment; the mechanical
    fallback from O3.2 is not meaningful across 20+ memory files.
  - Invokes
    `claude --subagent orianna --non-interactive --prompt "$(cat agents/orianna/prompts/memory-audit.md)"`.
  - Report written to
    `assessments/memory-audits/<ISO-date>-memory-audit.md` with
    frontmatter conforming to ADR §4.3
    (`title`, `status: needs-reconciliation`, `auditor: orianna`,
    `created`, `repos_checked` including short-SHA of both repos'
    `origin/main`).
  - Script fetches `origin/main` in both repos before invocation so
    `repos_checked:` SHAs are fresh.
  - Exit 0 on successful report write, 1 on invocation error, 2 on
    missing prerequisite (claude CLI, strawberry-app checkout).
  - Commits the report under `chore:` prefix (per ADR §1 "Commit
    discipline — the script that invokes her handles the commit").
  - Does NOT push — leaves push to the invoker (consistent with other
    scripts; agents commit but rely on invoker review before push).
  - **Correction:** actually the script SHOULD push — parallel to
    `plan-promote.sh` step 8. Push enabled.
- **Files touched:** `scripts/orianna-memory-audit.sh` (NEW).
- **Verification:**
  - `bash -n scripts/orianna-memory-audit.sh` passes.
  - Invoke manually against live repo state; report lands under
    `assessments/memory-audits/` with conforming frontmatter; commit
    exists with `chore:` prefix.
- **Blockers:** O1.1, O2.1, O4.1.
- **Depends on:** O1.1, O2.1, O4.1.

### O4.3 — Document the audit reconciliation flow

- **Goal:** A short runbook capturing ADR §4.4 steps so the first
  reconciliation doesn't require re-reading the ADR.
- **Inputs:** ADR §4.4 (five-step flow).
- **Outputs:** `agents/orianna/runbook-reconciliation.md`.
- **Acceptance criteria:**
  - Five-step flow from ADR §4.4 rendered as a numbered list.
  - Names Evelynn as the delegator, Yuumi as the default fixer for
    simple edits, owning agents for contextual judgment.
  - Explains the `needs-reconciliation` → `reconciled` frontmatter
    transition and who performs it (Evelynn or Duong).
- **Files touched:** `agents/orianna/runbook-reconciliation.md` (NEW).
- **Verification:** file exists, renders readably,
  `grep -c '^[0-9]\. ' agents/orianna/runbook-reconciliation.md` ≥ 5.
- **Blockers:** —.
- **Depends on:** —.

---

## Phase O5 — Roster updates + agents-table creation

Exit criterion: every roster document references Orianna; the new
`agents-table.md` exists and is linked from the relevant places.

### O5.1 — Update `agents/memory/agent-network.md`

- **Goal:** Add Orianna to the Sonnet Executors table and the delegation
  chain (ADR §5.1).
- **Inputs:** ADR §5.1; current `agents/memory/agent-network.md`
  (sections: Opus Advisors, Sonnet Executors, Haiku Utilities,
  Coordination).
- **Outputs:** modified `agents/memory/agent-network.md`.
- **Acceptance criteria:**
  - New row in Sonnet Executors table:
    `| **Orianna** | Fact-checker & memory auditor — verifies claims in
    plans before promotion; runs weekly memory/learnings audits |`
  - Coordination section gains a bullet:
    `- Duong/Evelynn → Orianna (fact-check on demand or via plan-promote.sh)`
  - No other table rows are reordered or altered (minimize diff).
- **Files touched:** `agents/memory/agent-network.md` (MODIFY).
- **Verification:** `grep -c 'Orianna' agents/memory/agent-network.md`
  is ≥ 2 (table row + delegation bullet).
- **Blockers:** O1.1 (Orianna must actually exist before being
  advertised).
- **Depends on:** O1.1.

### O5.2 — Update `agents/evelynn/CLAUDE.md` Delegation Decision Tree

- **Goal:** Route fact-check / memory-audit work to Orianna (ADR §5.3).
- **Inputs:** ADR §5.3; current `agents/evelynn/CLAUDE.md` (Delegation
  Decision Tree table + `#rule-prefer-roster-agents` roster list).
- **Outputs:** modified `agents/evelynn/CLAUDE.md`.
- **Acceptance criteria:**
  - New row in Delegation Decision Tree:
    `| Fact-check a plan before promotion, weekly memory/learnings audit | **Orianna** (Sonnet fact-checker) |`
  - `#rule-prefer-roster-agents` "Full roster" line: add `orianna` to
    the Sonnet list, in alphabetical order.
- **Files touched:** `agents/evelynn/CLAUDE.md` (MODIFY).
- **Verification:** `grep -c -i 'orianna' agents/evelynn/CLAUDE.md` is
  ≥ 2.
- **Blockers:** O1.1.
- **Depends on:** O1.1.

### O5.3 — Create `agents/memory/agents-table.md`

- **Goal:** Consolidated single-table view of the full roster per Duong
  decision 2. ADR §5.2 suggested deferring; Duong overrode to create
  now.
- **Inputs:** current roster in `agents/memory/agent-network.md`; the
  `.claude/agents/*.md` files as source of truth for `model:`,
  `tools:`, and status.
- **Outputs:** new file `agents/memory/agents-table.md`.
- **Acceptance criteria:**
  - Single markdown table with columns:
    `Agent | Tier | Model | Role | Definition file | Directory | Current status`.
  - Every agent in `agents/memory/agent-network.md` has a row.
  - Orianna's row present with tier=Sonnet, model=sonnet,
    role=Fact-checker & memory auditor, definition=`.claude/agents/orianna.md`,
    directory=`agents/orianna/`, status=new-2026-04-19.
  - Short note at top: "Authoritative list of agents. When adding or
    removing an agent, update this table in the same commit that
    adds/removes the agent definition file."
  - Link added from `agents/memory/agent-network.md` pointing to this
    file ("See `agents-table.md` for the consolidated table with model,
    tier, and status columns.") — minimize diff; single-line
    addendum.
- **Files touched:**
  - `agents/memory/agents-table.md` (NEW).
  - `agents/memory/agent-network.md` (MODIFY — one-line link).
- **Verification:**
  - Row count in agents-table.md matches roster in agent-network.md.
  - Spot check: Orianna, Skarner (promoted from Haiku), and Evelynn
    rows present and accurate.
- **Blockers:** O1.1 (Orianna's definition file must exist to cite).
- **Depends on:** O1.1, O5.1 (so the table + link go together without
  conflict).

---

## Phase O6 — Smoke tests + verification

Exit criterion: ADR §7 post-implementation checklist items 1-10 all
pass. No remaining open acceptance questions.

### O6.1 — Seed a deliberately-bad plan for negative testing

- **Goal:** Produce a throwaway plan with a known-false claim so O3.1
  and O3.2 can be exercised on a guaranteed-block input.
- **Inputs:** the Firebase GitHub App bug (ADR problem statement) as
  canonical example.
- **Outputs:** `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` <!-- orianna: ok -->
  containing:
  - A claim referencing a nonexistent `apps/bogus/nonexistent.ts` <!-- orianna: ok -->
    (cross-repo; forces strawberry-app checkout path).
  - A claim referencing "Firebase GitHub App" as if it were real.
  - A claim referencing a nonexistent workflow
    `.github/workflows/does-not-exist.yml`. <!-- orianna: ok -->
  - One correct claim (e.g. real reference to
    `scripts/plan-promote.sh`) so the test confirms selective blocking,
    not blanket blocking.
  - Frontmatter `status: proposed`; `throwaway: true` tag so it's
    obvious this plan is test scaffolding.
- **Acceptance criteria:** file exists in `plans/proposed/`; the
  three bad claims and one good claim are clearly delineated.
- **Files touched:** `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` <!-- orianna: ok -->
  (NEW — temporary).
- **Verification:** `ls plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` <!-- orianna: ok -->
  returns a match.
- **Blockers:** —.
- **Depends on:** —.

### O6.2 — Smoke test: clean plan passes

- **Goal:** Confirm ADR §7 item 5 — `plan-promote.sh` promotes a clean
  plan exactly as before the gate was added.
- **Inputs:** an existing proposed plan known to be clean, or
  `plans/approved/2026-04-19-public-app-repo-migration.md` invoked
  through `scripts/orianna-fact-check.sh` directly (since it's already
  approved, use the direct invocation path rather than plan-promote).
- **Outputs:** pass record logged in the verification worklog
  (O6.5).
- **Acceptance criteria:**
  - Direct invocation of `scripts/orianna-fact-check.sh <plan>` on the
    public-app-repo-migration plan exits 0.
  - Report generated in `assessments/plan-fact-checks/` with zero
    block findings.
  - (Optional but preferred) Create a trivial throwaway clean plan in
    `plans/proposed/`, run `plan-promote.sh <plan> approved`, confirm
    file moves to `plans/approved/`, commit created, push occurs —
    identical behavior to pre-gate version modulo the added report
    file.
- **Files touched:** none outside reports.
- **Verification:** O3.1 exit 0; report file exists; report frontmatter
  shows `block_findings: 0`.
- **Blockers:** O3.1, O3.3.
- **Depends on:** O3.1, O3.3.

### O6.3 — Smoke test: bad plan is blocked

- **Goal:** Confirm ADR §7 item 4 — `plan-promote.sh` refuses to
  promote a bad plan and leaves it in `plans/proposed/`.
- **Inputs:** the seeded bad plan from O6.1.
- **Outputs:** pass record.
- **Acceptance criteria:**
  - `./scripts/plan-promote.sh plans/proposed/2026-04-19-orianna-smoke-bad-plan.md approved` <!-- orianna: ok -->
    exits non-zero.
  - Stderr contains the three block findings from O6.1 (with file +
    line anchors).
  - `ls plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` still <!-- orianna: ok -->
    succeeds (file not moved).
  - Report file present in `assessments/plan-fact-checks/` enumerating
    the block findings.
  - No Drive unpublish was performed (verify by checking the plan's
    `gdoc_id:` frontmatter, if any, is unchanged).
- **Files touched:** none (the bad plan is consumed as input).
- **Verification:** exit code ≠ 0; plan remains in proposed/; report
  file present.
- **Blockers:** O3.1, O3.2, O3.3, O6.1.
- **Depends on:** O3.1, O3.2, O3.3, O6.1.

### O6.4 — Smoke test: fallback path works when `claude` CLI absent

- **Goal:** Confirm Duong decision 4 — partial-check fallback fires
  when `claude` CLI is unavailable.
- **Inputs:** seeded bad plan from O6.1.
- **Outputs:** pass record.
- **Acceptance criteria:**
  - Simulate missing CLI by prepending a `PATH` without `claude` (e.g.
    `env PATH=/usr/bin:/bin bash scripts/orianna-fact-check.sh <plan>`).
  - Script logs "claude CLI not found, falling back to mechanical
    check" to stderr.
  - `exec`'s `scripts/fact-check-plan.sh`; exit code propagates.
  - Report file written; `claude_cli: absent` in frontmatter.
  - At least the path claim from O6.1 (nonexistent `apps/bogus/...`) <!-- orianna: ok -->
    is flagged as `block` by the mechanical checker.
  - The Firebase-GitHub-App claim may slip through as `info` — this is
    expected and documented behavior for the fallback (ADR §3.2).
- **Files touched:** none.
- **Verification:** stderr log string present; exit 1; report frontmatter
  `claude_cli: absent`.
- **Blockers:** O3.1, O3.2, O6.1.
- **Depends on:** O3.1, O3.2, O6.1.

### O6.5 — Smoke test: manual memory audit

- **Goal:** Confirm ADR §7 item 6 — `scripts/orianna-memory-audit.sh`
  runs end-to-end and writes a conforming report.
- **Inputs:** current agent memory/learnings state.
- **Outputs:** one memory-audit report committed to
  `assessments/memory-audits/2026-04-19-memory-audit.md` (date floats to
  actual run date).
- **Acceptance criteria:**
  - Script exits 0.
  - Report frontmatter conforms to ADR §4.3 shape.
  - `repos_checked:` contains both repo short-SHAs.
  - Report body has all four sections (summary, block, warn, info,
    reconciliation checklist).
  - At least one stale-claim finding surfaces OR the report explicitly
    states "no findings" with the count breakdown — either is a pass.
    Rationale: we don't know in advance whether drift exists;
    either result is valid evidence the script worked.
  - Commit exists with `chore:` prefix.
- **Files touched:**
  `assessments/memory-audits/2026-04-19-memory-audit.md` (NEW from
  script).
- **Verification:** `ls assessments/memory-audits/` shows the new file;
  `git log -1 --format=%s assessments/memory-audits/2026-04-19-memory-audit.md`
  starts with `chore:`.
- **Blockers:** O4.2.
- **Depends on:** O4.2.

### O6.6 — Smoke test: cross-repo path claim

- **Goal:** Confirm ADR §7 item 7 — a plan referencing a nonexistent
  `apps/foo/bar.ts` in strawberry-app fails promotion with a clear <!-- orianna: ok -->
  message pointing at the strawberry-app checkout.
- **Inputs:** the seeded bad plan (O6.1) already contains an
  `apps/bogus/nonexistent.ts` claim — this test isolates that specific <!-- orianna: ok -->
  claim's handling.
- **Outputs:** pass record.
- **Acceptance criteria:**
  - Block finding for `apps/bogus/nonexistent.ts` names the checkout <!-- orianna: ok -->
    path (`~/Documents/Personal/strawberry-app/`).
  - If strawberry-app checkout is absent, finding is demoted to
    `warn` with message "could not verify cross-repo claim;
    strawberry-app checkout not found at expected path" (ADR §4.5).
  - When checkout is present, finding is `block` and points at the
    actual `origin/main` SHA checked.
- **Files touched:** none.
- **Verification:** inspect the O6.3/O6.4 report files — the
  `apps/bogus/...` finding's message text matches the spec above. <!-- orianna: ok -->
- **Blockers:** O6.3, O6.4.
- **Depends on:** O6.3, O6.4.

### O6.7 — Cleanup: remove seeded bad plan

- **Goal:** The smoke-test artifact from O6.1 must not linger in
  `plans/proposed/`.
- **Inputs:** `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md`. <!-- orianna: ok -->
- **Outputs:** file deleted; commit with `chore: remove orianna smoke
  test scaffolding`.
- **Acceptance criteria:**
  - File no longer in `plans/proposed/`.
  - Commit message has `chore:` prefix.
  - `ls plans/proposed/ | grep orianna-smoke` returns nothing.
- **Files touched:**
  `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` (DELETE). <!-- orianna: ok -->
- **Verification:** `ls plans/proposed/` does not list the file;
  `git log -1 --format=%s` shows the removal commit.
- **Blockers:** O6.3, O6.4, O6.6.
- **Depends on:** O6.3, O6.4, O6.6.

### O6.8 — Promote parent ADR from approved to in-progress → implemented

- **Goal:** Move the parent plan (`plans/approved/2026-04-19-orianna-fact-checker.md`) <!-- orianna: ok -->
  into `plans/in-progress/` when Phase O3 lands and into
  `plans/implemented/` after O6.1-O6.7 all pass, using — fittingly —
  the freshly-installed fact-check gate.
- **Inputs:** parent ADR path.
- **Outputs:** parent ADR moved through the lifecycle via
  `scripts/plan-promote.sh`.
- **Acceptance criteria:**
  - Move to `in-progress` happens at the moment the gate is
    functionally installed (after O3.3), NOT before — otherwise the
    promotion would run without the gate present.
  - Move from `in-progress` → `implemented` happens only after every
    O6 verification passes.
  - **Dogfood test:** the parent ADR itself must pass Orianna's
    fact-check. If Orianna blocks her own ADR, the blockers must be
    reconciled before implementation is declared complete — any
    block-severity finding here is a real signal worth fixing.
  - Both promotion commits use the `chore:` prefix (plan-promote.sh
    already enforces this).
- **Files touched:** `plans/approved/2026-04-19-orianna-fact-checker.md` <!-- orianna: ok -->
  → `plans/in-progress/...` → `plans/implemented/...`.
- **Verification:** `ls plans/implemented/` contains the parent ADR;
  each promotion left a `chore:` commit; the associated fact-check
  reports are in `assessments/plan-fact-checks/`.
- **Blockers:** O3.3 (for first move), O6.1-O6.7 (for second move).
- **Depends on:** O3.3, O6.1-O6.7.

---

## Task summary

Total: **23 tasks** across 6 phases.

| Phase | Tasks | Count |
|---|---|---|
| O1 — Agent scaffolding | O1.1, O1.2, O1.3 | 3 |
| O2 — Claim-extraction contract | O2.1, O2.2 | 2 |
| O3 — Plan fact-check gate | O3.1, O3.2, O3.3, O3.4 | 4 |
| O4 — Weekly memory audit | O4.1, O4.2, O4.3 | 3 |
| O5 — Roster + agents-table | O5.1, O5.2, O5.3 | 3 |
| O6 — Smoke tests + verification | O6.1, O6.2, O6.3, O6.4, O6.5, O6.6, O6.7, O6.8 | 8 |

---

## Dispatch — critical-path spine

Serial spine (minimum latency path from cold start to implemented):

```
O1.1 → O2.1 → O2.2 → O3.1 → O3.3 → O6.1 → O6.3 → O6.7 → O6.8
```

That spine is the shortest route to "gate functional + dogfooded."
Every other task is parallelizable against it given the right windows.

## Dispatch — parallel windows

**Window A (agent scaffolding, no dependencies):** O1.2, O1.3 run
concurrent with O1.1. All three finishable in one slot.

**Window B (prompt + runbook authoring, depends on O2.1):** O3.4, O4.1,
O4.3 all author documentation files and can run concurrent with each
other once O2.1 lands.

**Window C (fallback + memory-audit script, depends on O2.*):** O3.2 and
O4.2 are independent script authoring; run concurrent.

**Window D (roster updates, depends on O1.1):** O5.1, O5.2, O5.3 all
edit roster documents. O5.1 and O5.3 touch the same file
(`agent-network.md` — O5.3 adds a one-line link) so they are soft-
serialized: O5.1 first, then O5.3 rebases onto the result. O5.2 is
independent.

**Window E (smoke tests, depends on O3.* and O4.*):** O6.2, O6.3, O6.4
can run concurrent once O3.3 and O3.2 land. O6.5 needs O4.2. O6.6
depends on O6.3 and O6.4. O6.7 is cleanup serialized after all smoke
tests. O6.8 is the final gate.

## Dispatch — hard serial points

1. **O1.1 before anything invoking the subagent.** `claude --subagent
   orianna` won't resolve until the definition file exists.
2. **O2.1 before O2.2, O3.1, O3.2, O3.4, O4.1, O4.2.** Contract defines
   the shape every downstream consumer expects.
3. **O3.1 before O3.3.** `plan-promote.sh` needs the script it invokes.
4. **O6.8's first move (approved → in-progress) must happen AFTER O3.3
   but BEFORE the second move (in-progress → implemented), which must
   happen AFTER all of O6.1-O6.7.** Two separate commits.
5. **O6.7 before O6.8's second move.** Don't ship with smoke-test
   scaffolding still in `plans/proposed/`.

## Dispatch — Duong-in-loop points

None mandatory. All tasks are agent-executable. Two soft touchpoints:

- **Voice fill-in** in O1.1/O1.2 personality sections — Lulu or Neeko
  picks the voice (Duong decision 1 defers).
- **Allowlist seed review** in O2.2 — Duong may want to review the
  initial allowlist entries before O2.2 commits.

Neither blocks execution; both are low-friction follow-ups.

## Exit notes for v2 (not in this breakdown)

Per Duong decision 5: when v2 automation lands, the weekly memory audit
will be a **GitHub Actions scheduled workflow** in the agent-infra repo
(which by then will be `harukainguyen1411/strawberry-agents` per the
companion-migration plan). NOT a Mac cron job. This v1 breakdown leaves
`scripts/orianna-memory-audit.sh` invocation-shape compatible with a
future scheduled workflow: the script takes no args, reads only
committed state, writes only to `assessments/memory-audits/`, and
commits under `chore:`. A v2 workflow wrapper can call the script
verbatim.
