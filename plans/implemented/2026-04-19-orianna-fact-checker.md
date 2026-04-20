---
title: Orianna — fact-checker agent and mandatory plan-promote fact-check gate
status: implemented
owner: azir
created: 2026-04-19
tags: [orianna, fact-check, plan-promote, agent]
---

# Problem

During the S47 public-app-repo migration session (2026-04-18), Yuumi's retro
fact-check caught that one of Azir's plans referenced a "Firebase GitHub App"
integration that does not exist in the repo. All four deploy workflows use
`FIREBASE_SERVICE_ACCOUNT`<!-- orianna: ok — example secret name in problem description prose, not a load-bearing path claim --> key auth. Duong spent ~15 minutes hunting for a
nonexistent Firebase Console option before the claim was traced back to the
plan text.

The same class of error shows up in architecture docs: `discord-relay` moved
from Hetzner to GCE, but several `architecture/*.md` files still reference the
old Hetzner box. These stale claims do not fail any existing hook — they pass
every lint, every test, every pre-commit guard — and only surface when a human
acts on the wrong instruction.

The system has no fact-checking layer. Planners write; Duong approves; Sonnets
execute. If the plan says "turn on the Firebase GitHub App," nobody in that
chain is responsible for verifying the GitHub App actually exists. Memory
files and learnings accrete the same kind of drift over months — a claim that
was true on 2026-01-10 is still sitting in `agents/<name>/memory/MEMORY.md` on
2026-04-18, referencing a file that was deleted two weeks ago.

Today's workaround — Yuumi doing an ad-hoc retro fact-check — is reactive and
inconsistent. The bug only got caught because Evelynn happened to ask for a
retro in that particular session. A proactive, mandatory gate is needed.

# Solution

Introduce **Orianna**, a Sonnet-tier agent with two explicit roles:

1. **Fact-checker for plans before promotion.** Every plan leaving
   `plans/proposed/` must pass Orianna's grep-style evidence check. Executed
   as a mandatory step in `scripts/plan-promote.sh`. Fails closed; no
   `--no-verify`-equivalent bypass for agents.

2. **Weekly memory auditor.** A script Orianna invokes to sweep
   `agents/*/memory/**` and `agents/*/learnings/**` for stale claims against
   current repo state across both the agent-infra repo and `strawberry-app`.
   Output is a report to `assessments/memory-audits/`, which a human (Duong)
   or Evelynn reconciles.

The common thread is **grep-style evidence**: every non-trivial claim about
the system (an integration, a tool, a path, a flag, a command, a file
location) must cite an anchor that can be reproduced with a single `grep` or
`ls` against the current working tree. Claims without anchors either get
removed, rewritten as clearly-speculative future-state, or supplied with
real anchors.

## 1. Agent definition (`.claude/_script-only-agents/orianna.md`)

Standard Sonnet executor shape, matching the pattern from
`plans/approved/2026-04-09-wire-remaining-sonnet-specialists.md`<!-- orianna: ok — historical plan ref; plans/approved/ deleted per T9.1 of orianna-gated-plan-lifecycle ADR --> §4.

Frontmatter:

```yaml
---
name: Orianna
model: sonnet
effort: low
permissionMode: bypassPermissions
description: Fact-checker and memory auditor — verifies every load-bearing claim in a plan has a grep-able anchor in the repo. Gates plan promotion and runs weekly memory/learnings audits. Fails closed; does not edit plans, only reports. Invoked by plan-promote.sh and by /agent-ops audit.
tools:
  - Read
  - Glob
  - Grep
  - Bash
---
```

Tool rationale — deliberately **read-only**:

- **Read, Glob, Grep** — primary work surface. She reads the plan, extracts
  claims, greps the repo for anchors.
- **Bash** — needed to run the fact-check script itself, to `gh api` against
  GitHub for repo-remote checks (e.g. "does this workflow file exist on main
  in strawberry-app?"), and to `cd` into the `strawberry-app` checkout when a
  plan references cross-repo paths.
- **NO Write/Edit** — Orianna never modifies plans, memory files, or
  learnings. She emits a report. The plan author (or Evelynn, or Duong)
  reconciles. This is deliberate: a fact-checker that also rewrites is an
  editor, and drift-prevention discipline collapses when the same agent both
  finds and fixes.
- **NO Agent** — she does not delegate. She is a terminal check.

Body (abbreviated; full template follows the Sonnet specialist pattern):

- **Role**: You are Orianna, the fact-checker. You do one thing: you verify
  that every load-bearing claim in a document has a grep-able anchor in the
  current repo state. You never edit. You report.
- **Modes**: `plan-check <path>` (invoked by plan-promote.sh),
  `memory-audit` (invoked weekly).
- **Operating discipline**:
  - Never trust the author. Assume every integration name, path, flag, and
    command is suspect until grep-confirmed.
  - If a claim cannot be confirmed AND cannot be clearly-marked as
    speculative future-state, it fails.
  - Cross-repo claims require checking both repos (agent-infra +
    strawberry-app).
  - Report structure: ordered list of (claim, anchor attempted, result,
    severity). Severity levels: **block** (load-bearing false claim),
    **warn** (stale/ambiguous but not load-bearing), **info** (style
    suggestion, e.g. missing anchor on a claim that happens to be true).
- **Commit discipline**: Orianna never commits. If she produces a memory-
  audit report, the script that invokes her handles the commit under
  `chore:` prefix.

**Personality direction** (leave open for Lulu/Neeko or Duong to name the
vibe, but suggestions):

- **"The skeptic's skeptic."** Dry, surgical, faintly annoyed by sloppy
  claims. She is not a critic of ideas — she is a critic of unsupported
  statements. When a claim is wrong, she does not moralize; she cites the
  missing anchor and moves on.
- Tonal anchor candidates: a staff-level SRE who has been burned by a
  runbook too many times; a copy-editor at a science journal; the friend
  who asks "source?" before agreeing to anything.
- Avoid: combative, gotcha, or lecturing. Orianna's value is precision, not
  punishment.

Duong or Lulu/Neeko should pick the final voice when the file is written.

## 2. Directory structure under `agents/orianna/`

Mirror the shape used by every other Opus/Sonnet roster agent:

```
agents/orianna/
  profile.md              # one-page persona + role summary
  inbox.md                # Evelynn messages (standard inbox pattern)
  memory/
    MEMORY.md             # persistent operational memory
  learnings/
    index.md              # running index of session learnings
    YYYY-MM-DD-*.md       # per-session learning files
```

No `journal/` or `transcripts/` directories until a need emerges — keep it
minimal. The audit-report directory is **not** here; it lives in
`assessments/memory-audits/` (see §4) because reports are a product, not an
agent-internal artifact.

## 3. `plan-promote.sh` fact-check gate

### 3.1 What "grep-style evidence" means

A load-bearing claim in a plan is any concrete reference to system state
that a downstream reader would act on. The fact-check gate requires that
each such claim have an anchor — **a reproducible reference a reviewer can
verify in under 30 seconds**.

**Categories of claims that require anchors:**

| Claim category | Anchor shape |
|---|---|
| Integration / service name (e.g. "Firebase GitHub App") | File path + line, or `gh api` call, or a link to official docs if the integration is vendor-named |
| Repo path (e.g. `apps/bee/server.ts`) | `ls` or `test -f` returns success against the correct repo checkout | <!-- orianna: ok -->
| Command / CLI flag (e.g. `firebase deploy --only functions:api`) | Citation of the tool's help output or docs URL |
| GitHub Actions workflow / secret name | File path in `.github/workflows/` + grep match for the secret name |
| Script / tool path (e.g. `scripts/plan-promote.sh`) | `ls` hit |
| Architecture claim (e.g. "discord-relay runs on GCE") | Reference to the architecture doc or the deploy config that proves it |
| Existing plan reference | `ls plans/**` hit |

**Categories that do NOT require anchors:**

- Speculative / future-state statements (must be clearly marked, e.g.
  "Proposed:", "Will:", "In a future phase:").
- Commentary, rationale, tradeoff discussion.
- Design intent ("we want the system to feel coherent").
- Named agent roles and personas defined in the agent roster.

**How Orianna extracts claims:**

v1 heuristic (deliberately simple, grows with experience):

1. Parse the plan markdown; for each fenced code block and each inline
   backtick span, extract the token.
2. For each backtick span, classify: path? flag? integration name? command?
3. For each path-shaped token, run `ls` against the applicable repo
   checkout (agent-infra repo for `agents/`, `plans/`, `scripts/`,
   `architecture/`; strawberry-app checkout for `apps/`, `dashboards/`,
   `.github/workflows/`).
4. For each integration-shaped token that isn't in a known-allowlist of
   vendor names (Firebase, GCP, Cloud Run, etc.), flag for author-supplied
   anchor.
5. Emit a report with one row per suspect token.

v1 accepts false positives. Orianna's v1 report is advisory-with-teeth:
the **author** (or Evelynn) triages. Items marked `block` halt promotion.
Items marked `warn` or `info` appear in the report but do not halt.

Over time, a small allowlist/denylist file under `agents/orianna/` can
capture learned patterns (e.g. "Firebase" is always vendor-legitimate;
"Firebase GitHub App" is a specific integration and must be anchored).

### 3.2 Integration point in `plan-promote.sh`

Current flow (reference: existing script at `scripts/plan-promote.sh`):

1. Validate source is in `plans/proposed/`.
2. Validate target status.
3. Require clean source.
4. Unpublish Drive doc if present.
5. `git mv`, rewrite `status:`, commit, push.

New flow inserts a gate **between step 3 and step 4**:

```
3.5. Run fact-check:
     - Invoke Orianna via Claude Code subagent (non-interactive).
     - Orianna reads the plan, extracts claims, greps anchors.
     - She writes a machine-readable report to a tempfile:
         assessments/plan-fact-checks/<plan-basename>-<timestamp>.md
     - Exit code: 0 if no block-severity findings; non-zero otherwise.
3.6. If exit code non-zero:
     - Print the block-severity findings to stderr with anchors.
     - Print the path to the full report.
     - Exit 1. Do NOT proceed to unpublish or mv.
3.7. If exit code zero:
     - Still write the report to assessments/plan-fact-checks/ (warn/info
       findings are informational, not blocking).
     - Continue to step 4.
```

**Invocation mechanism** — two options; v1 picks (a):

- **(a) Shell out to `claude` CLI with a pinned prompt and `--subagent orianna`.**
  Pros: reuses the existing subagent infrastructure; matches how other
  agents are invoked. Cons: requires the `claude` CLI to be available in
  whatever environment runs `plan-promote.sh`.
- **(b) Pure-bash heuristic script (`scripts/fact-check-plan.sh`) that does
  the grep work directly.** Pros: no Claude dependency, deterministic.
  Cons: LLM-class judgment (e.g. recognizing that "Firebase GitHub App" is
  an integration name worth flagging vs. "Firebase" which is fine) is hard
  to replicate with regex.

v1 choice: **(a) with (b) as a fallback.** `plan-promote.sh` tries Orianna
first; if the `claude` CLI is not available, it falls back to
`scripts/fact-check-plan.sh` which runs the mechanical grep checks only.
The fallback may underreport (miss subtle stale claims) but never
overreports in a way that blocks valid plans.

### 3.3 Fail-closed policy and bypass

**Fails closed.** No `--no-verify`-style bypass flag for agents. This
matches the discipline from CLAUDE.md Rule 14 (pre-commit hooks cannot be
`--no-verify`'d by agents).

**Human-only bypass** — Duong can override by directly `git mv`'ing the
plan and committing, exactly as he can bypass any other script-enforced
rule. Orianna does not try to prevent Duong-the-human from doing what he
wants; she prevents **agents** from silently shipping unverified plans.

**Explicit non-goals:**

- No `--skip-fact-check` flag in `plan-promote.sh`.
- No environment variable opt-out (`ORIANNA_SKIP=1`, etc.). These always
  become normalized over time.
- No "advisory-only mode" for agent invocations. If a plan has block-
  severity findings, the promote fails. Period.

### 3.4 Interaction with CLAUDE.md Rule 7

CLAUDE.md Rule 7 currently reads: *"Use `scripts/plan-promote.sh` to move
plans out of `plans/proposed/`."* No amendment needed — Rule 7 already
mandates the script; adding a gate inside the script automatically falls
under Rule 7.

A one-line addendum to the Rule 7 text is **recommended but optional**:

> *"...`plan-promote.sh` runs a mandatory fact-check (Orianna) before
> moving the file; plans with block-severity findings cannot be promoted
> until the findings are reconciled."*

This is a doc-clarity nice-to-have, not a behavioral change.

### 3.5 Interaction with CLAUDE.md Rule 8 (session close)

Rule 8 mandates `/end-session` / `/end-subagent-session` for closing any
agent session. Orianna follows Rule 8 like every other agent: when
invoked via `plan-promote.sh`, she runs as a one-shot subagent, emits her
report, and `/end-subagent-session`'s herself. No divergence.

One subtlety: Orianna may be invoked **inside an existing session** (e.g.
Azir writes a plan, runs `plan-promote.sh`, which spawns Orianna). That
spawn is a subagent invocation; standard subagent closure rules apply.

## 4. Weekly memory-audit workflow

### 4.1 Scope

Orianna sweeps:

- `agents/*/memory/**` (every agent's persistent memory)
- `agents/*/learnings/**` (every agent's learning files)
- `agents/memory/**` (shared memory — `duong.md`, `agent-network.md`, etc.)

She does **not** sweep:

- `plans/**` (plans are fact-checked at promotion time; no retro sweep)
- `architecture/**` (may be added in v2; architecture docs are smaller in
  number and easier to human-review)
- `assessments/**` (these are themselves reports; auditing them recursively
  is a rabbit hole)

### 4.2 Trigger

**v1: manual only.** A new `/agent-ops audit memory` slash command (or
direct shell invocation of `scripts/orianna-memory-audit.sh`) runs the
sweep. Duong invokes it when he wants it.

Rationale for skipping cron in v1:

- A cron'd audit that nobody reads is worse than no audit. v1 needs a
  human feedback loop to tune the signal-to-noise ratio.
- The agent-infra repo is currently migrating to `harukainguyen1411/
  strawberry-agents`; wiring cron against a repo that's about to move
  invites breakage.
- Weekly is a rough target. "Weekly-ish, whenever Duong remembers"
  is fine for v1.

**v2 (out of scope for this ADR):** GitHub Actions scheduled workflow in
the agent-infra repo that opens a PR with the audit report. Deferred
until v1 has produced 2-3 audits and the format has stabilized.

### 4.3 Output format

Reports go to `assessments/memory-audits/YYYY-MM-DD-memory-audit.md`.
Frontmatter:

```yaml
---
title: Memory audit — YYYY-MM-DD
status: needs-reconciliation | reconciled
auditor: orianna
created: YYYY-MM-DD
repos_checked:
  - Duongntd/strawberry@<sha>
  - harukainguyen1411/strawberry-app@<sha>
---
```

Body structure:

```markdown
# Summary
- Files scanned: <n>
- Claims extracted: <n>
- Block-severity findings: <n>
- Warn-severity findings: <n>
- Info-severity findings: <n>

# Block findings
(ordered list; each entry: file, line, claim, anchor attempted, result,
proposed fix)

# Warn findings
(same shape)

# Info findings
(same shape, often aggregated by pattern)

# Reconciliation checklist
- [ ] <agent>/<file>:<line> — <brief>
- [ ] ...
```

### 4.4 Reconciliation flow

1. Orianna produces the report (status: `needs-reconciliation`).
2. Evelynn reads the report, groups findings by owning agent.
3. For each owning agent: Evelynn delegates a memory-update task
   (Yuumi for simple file edits; the owning agent itself if the finding
   needs contextual judgment) pointing at the specific lines.
4. Each owning agent updates its memory/learnings file, commits, reports
   done.
5. When all reconciliation-checklist items are checked, Evelynn (or Duong)
   updates the report frontmatter `status: reconciled` and commits.

### 4.5 Cross-repo handling

When a claim in an `agents/*/memory/**` file references a path in
`apps/**` or `.github/workflows/**`, Orianna checks the claim against the
`strawberry-app` checkout at `~/Documents/Personal/strawberry-app/` (per
CLAUDE.md's two-repo model).

If the strawberry-app checkout is missing or stale, she emits a **warn**
severity finding on the audit itself ("could not verify N cross-repo
claims; strawberry-app checkout not found at expected path") rather than
silently skipping.

## 5. Roster updates

Three files need updates when Orianna lands:

### 5.1 `agents/memory/agent-network.md`

Add to the **Sonnet — Executors** table:

| **Orianna** | Fact-checker & memory auditor — verifies claims in plans before promotion; runs weekly memory/learnings audits |

Delegation chain addendum (under "Coordination"):

> - Duong/Evelynn → Orianna (fact-check on demand or via `plan-promote.sh`)

### 5.2 `agents/memory/agents-table.md`

This file does not currently exist (verified via Glob). It is referenced
in the task brief. Two paths:

- **(a) Create it** as a single consolidated table of all agents with
  role, model, tier, and current-status columns. Reasonable, but out of
  scope for this plan — should be its own small plan if Duong wants it.
- **(b) Drop the reference** from this plan and note the file doesn't
  exist. Recommended for v1.

v1 choice: **(b).** If `agents-table.md` gets created later (it would be
a net improvement to discoverability), Orianna gets added to it at that
time. No action needed in this plan.

### 5.3 `agents/evelynn/CLAUDE.md` — Delegation Decision Tree

Add a row to the Delegation Decision Tree table (§ "Delegation Decision
Tree"):

| Fact-check a plan before promotion, weekly memory/learnings audit | **Orianna** (Sonnet fact-checker) |

Also add Orianna to the "Full roster" line in the
`#rule-prefer-roster-agents` comment block.

## 6. Files changed

Agent infrastructure (this repo, currently `Duongntd/strawberry`, migrating
to `harukainguyen1411/strawberry-agents`):

- **New:** `.claude/_script-only-agents/orianna.md` — agent definition (landed at `_script-only-agents/` rather than `agents/` per operational classification).
- **New:** `agents/orianna/profile.md` — persona.
- **New:** `agents/orianna/memory/MEMORY.md` — empty scaffold.
- **New:** `agents/orianna/learnings/index.md` — empty scaffold.
- **New:** `agents/orianna/inbox.md` — empty scaffold.
- **New:** `scripts/orianna-fact-check.sh` — the subprocess entrypoint
  that `plan-promote.sh` invokes. Wraps the `claude` CLI call with the
  Orianna subagent, falls back to `fact-check-plan.sh` on missing CLI.
- **New:** `scripts/fact-check-plan.sh` — pure-bash fallback; runs the
  mechanical grep/ls checks only.
- **New:** `scripts/orianna-memory-audit.sh` — invoked manually or via
  `/agent-ops audit memory`; runs the weekly sweep.
- **New:** `assessments/memory-audits/.gitkeep` — directory scaffold.
- **New:** `assessments/plan-fact-checks/.gitkeep` — directory scaffold.
- **Modified:** `scripts/plan-promote.sh` — insert fact-check gate
  between steps 3 and 4.
- **Modified:** `agents/memory/agent-network.md` — roster + delegation
  chain addenda.
- **Modified:** `agents/evelynn/CLAUDE.md` — Delegation Decision Tree row
  + `#rule-prefer-roster-agents` roster list.
- **Modified (optional, recommended):** `CLAUDE.md` Rule 7 — one-line
  addendum about the fact-check gate.

Application repo (`harukainguyen1411/strawberry-app`): **no changes.**

## 7. Risks & open questions

### Risks

- **False positives cause promotion friction.** If Orianna flags too many
  claims as block-severity, authors will learn to route around her
  (directly `git mv`'ing, or — worse — moving blocks to non-backtick
  prose to dodge the extractor). Mitigation: v1 is conservative —
  block-severity is reserved for **unambiguously false** claims; warn is
  the default for "looks suspicious." The author gets to reclassify with
  a follow-up commit + Orianna re-run.
- **Claude CLI dependency in `plan-promote.sh`.** The script must remain
  POSIX-portable per CLAUDE.md Rule 10. Invoking the CLI is fine on
  darwin/Linux/Git-Bash-on-Windows if the CLI is installed; the fallback
  handles absence. Needs testing on Windows.
- **The audit never gets read.** A report in `assessments/memory-audits/`
  that no human reviews is just accrual of more stale text. Mitigation:
  v1 is manual-trigger only; the human invoking it is implicitly
  committing to read it. If v2 cron'd reports get ignored, that's a sign
  the feature isn't needed.
- **Orianna becomes a style police.** If she creeps from "is this claim
  true" into "is this claim written well," the value collapses into
  nitpicking. Guardrail: her definition of claim is narrow (integration,
  path, flag, command, architecture reference). Prose and opinion are
  explicitly out of scope.
- **Two-repo checkout coordination.** Claims about `apps/**` require the
  `strawberry-app` checkout; if the checkout is stale, Orianna may report
  false stale-claim findings on Orianna's side. Mitigation: the fact-check
  script runs `git -C ~/Documents/Personal/strawberry-app fetch` and
  checks against `origin/main` not the local working tree.
- **Overlap with Yuumi's retro fact-check.** Yuumi has been doing this ad-
  hoc. Orianna supersedes that for plans; Yuumi still does the general
  session retro. No conflict; document this in Yuumi's memory update.

### Open questions for Duong

1. **Personality naming.** Should Lulu or Neeko name Orianna's voice, or
   would you prefer to pick it? This plan leaves it open.
2. **`agents-table.md`.** Create it as part of this work, or defer? v1
   defers.
3. **CLAUDE.md Rule 7 amendment.** Add the one-line fact-check addendum,
   or leave Rule 7 as-is? Either is fine — the gate works either way;
   the amendment is doc clarity only.
4. **Fallback scope.** Is the pure-bash fallback (`fact-check-plan.sh`)
   acceptable as a partial check, or should `plan-promote.sh` refuse to
   run at all when the `claude` CLI is unavailable? v1 choice: partial-
   check fallback. Alternative: hard-fail with "install Claude CLI."
5. **Weekly audit trigger in v2.** When we eventually automate the
   audit: GitHub Actions scheduled workflow opening a PR, vs. a cron on
   Duong's Mac. Defer.
6. **Block-severity threshold for v1.** Start strict (any unverifiable
   integration/path fails) and loosen, or start loose (only
   provably-false fails) and tighten? I recommend **start strict** — the
   Firebase GitHub App case would have been caught by strict, not by
   loose. Easier to add exceptions than to catch up on drift.
7. **Migration timing.** The agent-infra repo migrates to
   `harukainguyen1411/strawberry-agents` per the approved companion-
   migration plan. Wire Orianna in the old repo (this one) now, or wait
   for the migration to land? I recommend **wire now**: the files are
   all under `agents/` and `scripts/` which move together in the
   migration — no special work needed.

# Verification

Post-implementation checklist (for whoever Evelynn assigns):

1. `.claude/_script-only-agents/orianna.md` exists; `model: sonnet`; `tools:` restricted
   to Read/Glob/Grep/Bash.
2. `agents/orianna/{profile.md,memory/MEMORY.md,learnings/index.md,inbox.md}`
   all exist.
3. `scripts/orianna-fact-check.sh` exits 0 on a known-clean plan and
   non-zero on a seeded bad plan.
4. `scripts/plan-promote.sh` refuses to promote a seeded bad plan.
5. `scripts/plan-promote.sh` promotes a clean plan exactly as before.
6. `scripts/orianna-memory-audit.sh` runs end-to-end and produces a report
   in `assessments/memory-audits/`.
7. Cross-repo check: a seeded plan referencing a nonexistent
   `apps/foo/bar.ts` in strawberry-app fails promotion with a clear <!-- orianna: ok -->
   message pointing at the strawberry-app checkout.
8. `agents/memory/agent-network.md` shows Orianna in the Sonnet table.
9. `agents/evelynn/CLAUDE.md` Delegation Decision Tree has an Orianna row.
10. Smoke test: invoke Orianna manually on a plan (e.g. `plans/approved/2026-04-19-public-app-repo-migration.md`<!-- orianna: ok — historical plan ref; plans/approved/ deleted per T9.1; plan was demoted to proposed and later re-promoted -->).
    Report should emerge cleanly.

# Handoff note

This plan is scope-complete at the architecture level. **Do not assign an
implementer in this plan.** Per `#rule-plan-writers-no-assignment`,
Evelynn decides delegation after Duong approves and moves the plan to
`plans/approved/`<!-- orianna: ok — historical ref to promotion target; plans/approved/ was deleted per T9.1 after this plan was implemented -->.

Likely breakdown once approved:

- One task: agent definition + directory scaffolds (Yuumi or Ekko).
- One task: `orianna-fact-check.sh` + `fact-check-plan.sh` + the
  `plan-promote.sh` integration (Ekko or Jayce; non-trivial bash).
- One task: `orianna-memory-audit.sh` (Ekko).
- One task: roster/decision-tree updates (Yuumi).
- One task: v1 smoke test run against existing plans + report-format
  validation (Vi or Caitlyn).

Kayn or Aphelios can break this into concrete tasks when Evelynn decides
it's time.
