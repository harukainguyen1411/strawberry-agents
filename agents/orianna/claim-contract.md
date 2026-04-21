---
contract-version: 1
created: 2026-04-19
source-adr: plans/approved/2026-04-19-orianna-fact-checker.md
---

# Orianna Claim-Extraction Contract — v1

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
| C2 | Repo path | `apps/bee/server.ts` | `ls` or `test -f` returns success against the correct repo checkout |
| C3 | Command / CLI flag | `firebase deploy --only functions:api` | Citation of the tool's help output or a docs URL |
| C4 | GitHub Actions workflow or secret name | `.github/workflows/deploy.yml`, `FIREBASE_SERVICE_ACCOUNT` | File path in `.github/workflows/` + `grep` match for the secret name |
| C5 | Script or tool path | `scripts/plan-promote.sh` | `ls` hit against this repo |
| C6 | Architecture claim | "discord-relay runs on GCE" | Reference to the architecture doc or deploy config that asserts the same fact |
| C7 | Existing plan reference | `plans/approved/2026-04-17-deployment-pipeline.md` | `ls plans/**` hit |

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

Any claim in category C1 (integration / service name) or C2 (repo path) that
**cannot be verified** defaults to **block** severity. There is no "warn by
default for integration names" mode. When in doubt, block.

Rationale: the problem that motivated Orianna's creation was an unverified
integration name ("Firebase GitHub App") that consumed 15 minutes of Duong's
time. Leniency on integration names defeats the purpose of the gate.

---

## 5. Repo routing rules

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

## 6. v1 extraction heuristic

1. Parse the plan markdown. For each fenced code block and each inline
   backtick span, extract the token.
2. For each token, classify: path-shaped (contains `/` or ends in a
   recognized extension)? flag (starts with `-`)? integration name?
   command?
3. For each path-shaped token, apply routing rules (§5) and run `test -e`
   against the applicable repo checkout.
4. For each integration-shaped token (proper noun, not path, not flag):
   check the allowlist (`agents/orianna/allowlist.md`). If on the allowlist
   as a bare vendor name, pass. If not on the allowlist, flag for
   author-supplied anchor (block severity per §4 strict default).
5. Emit a report with one row per suspect token: claim text, anchor
   attempted, result, severity.

v1 accepts false positives from backtick spans that are code samples or
examples. Authors may add an inline comment `<!-- orianna: ok -->` immediately
after a suspect backtick span to suppress a finding; this is logged as `info`
in the report.

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
