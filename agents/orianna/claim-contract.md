---
contract-version: 2
created: 2026-04-19
rescoped: 2026-04-22
source-adr: plans/approved/2026-04-19-orianna-fact-checker.md
rescope-adr: plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md
---

# Orianna Claim-Extraction Contract — v2

## v1 → v2 delta

This file was bumped from v1 to v2 as part of the substance-vs-format rescope
(ADR `plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md`).

**What changed:**

- **§1 C2 split:** the single "Repo path" claim category (C2) is now split into
  two sub-categories: C2a (internal-prefix path, block on miss) and C2b
  (all other path-shaped tokens, info on miss). See §1 below.
- **§2 Non-claim categories expanded:** four new categories added — HTTP route
  tokens, dotted identifiers (Python/TS style), tokens inside fenced code
  blocks, and template/brace expressions. See §2 below.
- **§5 Routing scope narrowed:** routing (`test -e`) applies only to C2a tokens.
  C2b tokens are logged as `info` without any filesystem check. See §5 below.
- **§6 Extraction heuristic changed:** fenced code blocks are no longer
  extracted. Only inline backtick spans (outside fences) are extracted. See §6
  below.

**What did NOT change:**

- The signature mechanism (SHA-256 body hash, git author trailers, verification
  script). No existing signature is invalidated — the contract is not hashed
  into plan signatures.
- Severity definitions for block, warn, and info (§3).
- The strict-default rule for C1 and C2a (§4).
- Routing logic itself (which root applies for which concern) (§5).
- Suppression syntax `<!-- orianna: ok -->` (§8).
- The report structure (§7).

The rescope is a **strict shrink**: fewer checks can only decrease block counts.
Every plan that passed the v1 gate trivially passes the v2 gate.

This file is the authoritative specification for what counts as a verifiable
claim in a plan document, and what severity level to assign when a claim
cannot be verified. Both the LLM path (`scripts/orianna-fact-check.sh`) and
the bash fallback (`scripts/fact-check-plan.sh`) must honor these definitions.
A reviewer reading only this file can classify any suspect token without
consulting the ADR.

**Allowlist file:** `agents/orianna/allowlist.md` — vendor bare names that
pass without anchors are enumerated there. Consult it before flagging any
integration-shaped token.

---

## 1. Claim categories requiring anchors

A load-bearing claim is any concrete reference to system state that a
downstream reader would act on. The following categories always require an
anchor — a reproducible reference a reviewer can verify in under 30 seconds.

| # | Claim category | Example | Required anchor shape |
|---|---|---|---|
| C1 | Integration / service name | "Firebase GitHub App" | File path + line, or `gh api` call confirming the integration exists, or link to official vendor docs if it is a bare vendor name not on the allowlist |
| C2a | **Internal-prefix repo path** — token begins with an internal-prefix (see §5b opt-back list and §5b personal routing). Miss severity: **block**. | `scripts/plan-promote.sh`, `agents/orianna/claim-contract.md` | `test -e` returns success against the correct repo checkout |
| C2b | **Other path-shaped token** — a token that contains `/` or ends in a recognized extension but does NOT begin with an internal-prefix. Miss severity: **info** (no filesystem check performed). | `/auth/login`, `company-os/tools/demo-studio-v3/agent_proxy.py` | Not required; logged as info if unresolvable |
| C3 | Command / CLI flag | `firebase deploy --only functions:api` | Citation of the tool's help output or a docs URL |
| C4 | GitHub Actions workflow or secret name | `.github/workflows/deploy.yml`, `FIREBASE_SERVICE_ACCOUNT` | File path in `.github/workflows/` + `grep` match for the secret name |
| C5 | Script or tool path | `scripts/plan-promote.sh` | `ls` hit against this repo |
| C6 | Architecture claim | "discord-relay runs on GCE" | Reference to the architecture doc or deploy config that asserts the same fact |
| C7 | Existing plan reference | `plans/approved/2026-04-17-deployment-pipeline.md` | `ls plans/**` hit |

**C2a internal-prefix list** (applies under both personal and work concerns):
`agents/`, `plans/`, `scripts/`, `architecture/`, `assessments/`, `.claude/`,
`secrets/`, `tools/decrypt.sh`, `tools/encrypt.sh`. Under `concern: personal`
also: `apps/`, `dashboards/`, `.github/workflows/`.

Note: C5 is a specialization of C2a (script paths always match the internal
prefix). Both are block-severity on miss. C5 remains listed separately for
historical clarity.

---

## 2. Non-claim categories (out of scope — do not flag)

The following are not verifiable claims and must never be flagged:

- **Speculative / future-state statements** — must be clearly marked with
  "Proposed:", "Will:", "In a future phase:", or equivalent. If the marker is
  absent, treat the statement as a present-tense claim and evaluate it.
- **Commentary, rationale, or tradeoff discussion** — prose explaining why a
  decision was made.
- **Design intent** — "we want the system to feel coherent."
- **Named agent roles and personas** — names that appear in
  `agents/memory/agent-network.md` (e.g. "Orianna", "Ekko", "Viktor") are
  roster references, not integration claims.
- **Pure opinion / style** — word choice, tone, formatting preference.
- **HTTP route tokens** — any token whose first segment is an HTTP method
  (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`) or whose first
  character is `/` followed by a path segment that is not an internal-prefix.
  Examples: `/auth/login`, `POST /api/sessions`, `GET /build/{id}`. These are
  API surface descriptors, not filesystem claims. Never extracted for checking.
- **Dotted identifiers** — tokens composed of dotted segments using camelCase
  or snake_case with no `/` separator and no recognized filesystem extension.
  Examples: `firebase_admin.auth.verify_id_token`, `ds_session`,
  `ClassName.method`. These are code symbols, not paths.
- **Tokens inside fenced code blocks** — entire content between ` ``` ` fences
  is illustrative (diagrams, pseudocode, example shell, state machines).
  No tokens are extracted from fenced blocks. Authors who want fenced content
  checked can move the relevant claim outside the fence.
- **Template / brace expressions** — tokens containing `{` or `}` with nested
  variable names. Examples: `{uid, email, iat}`, `{sid}/{token}`,
  `/path/{param}`. These are placeholder patterns, not real paths.

Orianna is a fact-checker, not a style editor. Prose quality is never a
block finding.

---

## 3. Severity definitions

### block

The claim is load-bearing (categories C1–C7) AND cannot be verified against
the current working tree or remote state. Halts promotion. Examples:

- An integration name not on the allowlist and not anchored to a file/line.
- A repo path that does not exist under `test -e` against the applicable
  repo checkout.
- A workflow file reference where the file is absent from `.github/workflows/`.
- A script path that does not resolve under `ls` in this repo.

### warn

The claim exists and was once correct, but appears stale — the file or
service exists but its content has changed in a way that may invalidate the
claim. Not immediately load-bearing enough to halt promotion, but must appear
prominently in the report for human triage. Examples:

- A file that exists but whose content no longer contains the referenced
  function or key.
- An architecture claim that references a service that exists but has been
  moved (e.g. a hostname that resolves but to a different host than the claim
  implies).

### info

A claim that is verifiably true but is missing a formal anchor (i.e. the
claim is correct, just not cited). Also used for style suggestions such as
rewording for clarity. Never halts promotion. Examples:

- A path that resolves cleanly but has no inline reference in the plan text.
- An integration name on the allowlist that could nonetheless benefit from
  an explicit link.
- Unknown path prefixes where the path cannot be classified by routing rules
  (see §5) — flagged as info with "unknown path prefix; add to contract if
  load-bearing."

---

## 4. Strict-default rule (Duong decision 6)

Any claim in category C1 (integration / service name) or **C2a** (internal-prefix
repo path) that **cannot be verified** defaults to **block** severity. There is
no "warn by default for integration names" mode. When in doubt, block.

C2b (other path-shaped token) misses default to **info** severity — these are
not filesystem claims by Orianna's v2 taxonomy. Upgrading a C2b finding to
block requires an explicit author escalation (use `<!-- orianna: ok -->` to
indicate the author wants the token suppressed, or move it outside a fence and
add it to an internal-prefix path if it is actually load-bearing).

Rationale: the problem that motivated Orianna's creation was an unverified
integration name ("Firebase GitHub App") that consumed 15 minutes of Duong's
time. Leniency on integration names defeats the purpose of the gate.
The C2a/C2b split is motivated by the documented false-positive pattern on HTTP
routes, dotted identifiers, and diagram tokens (see rescope ADR §1 evidence).

---

## 5. Repo routing rules

**Routing applies to C2a (internal-prefix path) tokens only.** Non-internal-
prefix path tokens (C2b) do not undergo `test -e` and are logged as `info`
with the note "non-internal-prefix path token; C2b category; no filesystem
check performed." The routing rules below describe how to resolve C2a tokens
across repo checkouts. C2b tokens bypass routing entirely.

Routing is concern-aware. The plan's `concern:` frontmatter field determines
which resolution root applies.

### 5a. Plans with `concern: work` — resolution root flip

When a plan's frontmatter declares `concern: work`, the **default resolution
root** for every path-shaped token is the work monorepo:

> `~/Documents/Work/mmp/workspace/`

**Opt-back list** — these strawberry-agents infra prefixes and exact file
tokens always resolve against this repo (working tree) regardless of concern:

- `agents/`
- `plans/`
- `scripts/`
- `assessments/`
- `architecture/`
- `.claude/`
- `secrets/`
- Exact files: `tools/decrypt.sh`, `tools/encrypt.sh`

Note: bare `tools/` is **NOT** on the opt-back list. Work-concern plans
frequently cite `tools/demo-studio-v3/...` and similar paths that live inside
the workspace monorepo, not in this repo. Only the two specific helper files
above are opted back.

**Routing logic for `concern: work`:**

1. Check if the token matches any opt-back entry above. If yes, verify with
   `test -e` against the strawberry-agents working tree.
2. Otherwise, verify with `test -e` against `~/Documents/Work/mmp/workspace/`.
   A miss is a **block** finding — not an `info` unknown-prefix finding.
   The block finding's anchor text names the workspace root as the expected
   location.

If the workspace checkout is absent, emit a `warn` finding:
"could not verify N cross-repo path(s); work-concern checkout not found at
`~/Documents/Work/mmp/workspace/`." Do not silently skip (ADR §4.5).

### 5b. Plans with `concern: personal`, no `concern:` field, or any other value — original two-repo routing (unchanged)

**This repo (`Duongntd/strawberry`, checkout: working tree):**

- `agents/`
- `plans/`
- `scripts/`
- `architecture/`
- `assessments/`
- `.claude/`
- `tools/`

**strawberry-app repo (`harukainguyen1411/strawberry-app`, checkout: `~/Documents/Personal/strawberry-app/`):**

- `apps/`
- `dashboards/`
- `.github/workflows/`
- `scripts/usage-dashboard/` (local path `~/Documents/Personal/strawberry-app/scripts/usage-dashboard/`)
- `tests/e2e/` (local path `~/Documents/Personal/strawberry-app/tests/e2e/`)

**Unknown prefix:** emit an `info` finding: "unknown path prefix `<prefix>/`;
add to this contract's routing table if the path is load-bearing."

If the strawberry-app checkout is absent, emit a `warn` finding naming it. Do
not silently skip cross-repo checks (ADR §4.5).

### 5c. `grep "resolution root" agents/orianna/claim-contract.md` test

The resolution root for `concern: work` plans is `~/Documents/Work/mmp/workspace/`.
The opt-back list above (§5a) is the single exception. The opt-back list in this
file, in `scripts/fact-check-plan.sh`, and in `agents/orianna/prompts/plan-check.md`
must enumerate identical entries.

---

## 6. v2 extraction heuristic

1. Parse the plan markdown. **For each inline backtick span outside a fenced
   code block**, extract the token. Fenced code blocks (content between ` ``` `
   fences) are illustrative and are not extracted. Authors who want specific
   fenced content checked can move the relevant claim outside the fence.
2. For each extracted token, classify:
   - **C2b / non-claim** — first, apply the non-claim category tests from §2:
     HTTP route? Dotted identifier (camelCase/snake_case with no `/`)? Template/
     brace expression (`{`, `}`)? Whitespace-containing span? If any non-claim
     test matches, log as `info` (non-claim skip) and skip further checks.
   - **Flag** — starts with `-`? Skip entirely.
   - **Path-shaped** — contains `/` or ends in a recognized extension (`.sh`,
     `.md`, `.ts`, `.js`, `.tsx`, `.jsx`, `.json`, `.yml`, `.yaml`, `.env`,
     `.bats`)? Proceed to step 3.
   - **Integration name** — proper noun, not a path, not a flag? Proceed to
     step 4.
   - **Command / other** — skip.
3. For each path-shaped token:
   - Check if the token begins with an internal-prefix (C2a): `agents/`,
     `plans/`, `scripts/`, `architecture/`, `assessments/`, `.claude/`,
     `secrets/`, `tools/decrypt.sh`, `tools/encrypt.sh`; and under
     `concern: personal` also `apps/`, `dashboards/`, `.github/workflows/`.
   - **C2a token:** apply routing rules (§5) and run `test -e` against the
     applicable repo checkout. Miss → `block`. Hit → `info` (clean pass).
   - **C2b token (not internal-prefix):** log as `info` with note
     "non-internal-prefix path token; C2b category; no filesystem check
     performed." No `test -e` is run.
4. For each integration-shaped token:
   check the allowlist (`agents/orianna/allowlist.md`). If on the allowlist
   as a bare vendor name, pass. If not on the allowlist, flag for
   author-supplied anchor (block severity per §4 strict default).
5. Emit a report with one row per suspect token: claim text, anchor
   attempted, result, severity.

Authors may add an inline comment `<!-- orianna: ok -->` immediately after a
suspect backtick span to suppress a finding; this is logged as `info` in the
report (author-suppressed).

---

## 7. Report structure (on disk)

Reports are written to
`assessments/plan-fact-checks/<plan-basename>-<ISO-timestamp>.md`.

Frontmatter:

```yaml
---
plan: <relative path to plan file>
checked_at: <ISO 8601 timestamp>
auditor: orianna
claude_cli: present | absent
block_findings: <count>
warn_findings: <count>
info_findings: <count>
---
```

Body sections (in order):

1. `## Block findings` — one sub-entry per finding with claim text, anchor
   attempted, and failure reason.
2. `## Warn findings` — same shape, lower urgency.
3. `## Info findings` — same shape, informational only.

Empty sections must still appear with "None." so the report is always
machine-parseable without absence handling.

---

## 8. Suppression syntax

Plan authors may suppress Orianna findings on specific lines using an inline
HTML comment marker. This is the intended escape hatch for META-EXAMPLES and
prose that describes the gate's own motivating cases.

### Marker

```
<!-- orianna: ok -->
```

### Placement rules

**Same-line suppression** — place the marker at the end of (or anywhere on)
the line that contains the claim. All tokens extracted from that line are
treated as explicitly authorized and logged as `info` (author-suppressed). No
`block` or `warn` finding is emitted for any token on that line.

```markdown
The Firebase GitHub App reference is an example of the bug we're preventing. <!-- orianna: ok -->
```

**Preceding-line suppression** — place the marker on a standalone line
immediately before the claim line. All tokens extracted from the following
line are suppressed.

```markdown
<!-- orianna: ok -->
`agents/nonexistent/example-path.md`
```

### Example use case

A plan about Orianna's own design may need to cite "Firebase GitHub App" as
the motivating example. Without the marker the gate would block on the
integration name. With the marker on the same line, the gate logs it as `info`
and allows promotion.

### What suppression does NOT bypass

- Suppression is line-scoped. Only the marked line (and at most the one
  following a standalone marker) is suppressed.
- Suppression is author intent, not a blanket skip. Each suppressed finding
  still appears in the `## Info findings` section of the report, so reviewers
  can audit what was explicitly blessed.
- Suppression does not affect preceding lines or any other lines in the file.

---

## 9. Scope boundary — what Orianna does not do

- She does not rewrite plans. She reports only.
- She does not flag prose quality, tone, or opinion.
- She does not validate semantic correctness of commands (e.g. whether
  `npm install --legacy-peer-deps` is the right flag for a given project).
  Only structural verifiability: does the path/integration/workflow exist?
- She does not block on `warn` or `info` findings. Only `block` halts
  promotion.
- She does not run in advisory-only mode for agent invocations. If a plan
  has block findings, the promote fails. No bypass for agents (ADR §3.3).
