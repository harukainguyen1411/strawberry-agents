---
title: Orianna prompt audit — false-positive reduction input for T-prompt-1
author: lux
created: 2026-04-21
concern: personal
kind: advisory
related:
  - plans/approved/personal/2026-04-21-orianna-gate-speedups.md
  - .claude/_script-only-agents/orianna.md
  - agents/orianna/prompts/plan-check.md
  - agents/orianna/claim-contract.md
  - scripts/orianna-fact-check.sh
  - scripts/fact-check-plan.sh
---

# Orianna prompt audit — advisory input for `T-prompt-1`

Advisory only. This document is the evidence pack for T-prompt-1 of
`plans/approved/personal/2026-04-21-orianna-gate-speedups.md` §6. A downstream
agent (Talon, per the plan) will apply the prompt changes. No production file
was edited while producing this doc.

## 1. Scope reminder — what the prompt actually does today

Two code paths share the name "Orianna":

1. **LLM path (primary)** — `scripts/orianna-fact-check.sh` spawns a non-interactive
   `claude` subprocess with the system prompt in `.claude/_script-only-agents/orianna.md`
   plus the task prompt sourced from `agents/orianna/prompts/plan-check.md`. Reports
   carry `claude_cli: present`, `check_version: 3`.

2. **Bash fallback** — `scripts/fact-check-plan.sh`, invoked via `exec` when the
   `claude` CLI is missing. Reports carry `claude_cli: absent`, `check_version: 1`.
   The fallback is a pure-bash grep/ls engine with no LLM involvement.

The recent pin to Opus-low (`54ac1bf chore: pin Orianna to Opus-low …`) affects
only the LLM path.

## 2. False-positive distribution — 20-report sample

Sample: the 20 most-recently written reports under
`assessments/plan-fact-checks/` at audit time (21 Apr 2026, 12:20 UTC).
Classifications use the prompt task's category list.

### 2a. Dominant observation — path bifurcation

The sample is not homogeneous. Reports split into two very different
populations:

| Path | Count in sample | Typical findings shape |
|---|---|---|
| LLM v3 (`claude_cli: present`) | 14/20 | 0–2 block, 0–1 warn, 1–16 info |
| LLM v2 (`claude_cli: present`, older `gate: implementation-gate-check`) | 1/20 | 1 block (arch-declaration), 0 info |
| Bash fallback v1 (`claude_cli: absent`) | 5/20 | 0–14 block, **311–340 info** |

The 5 bash-fallback reports alone account for **≈1580 of the ≈1620 info
findings** in the 20-report sample. They are the headline FP producer,
not the LLM path. Every non-bash-fallback `info` in the sample is ≤16.

### 2b. False-positive distribution — bash-fallback path

Sampling the 311 info findings on
`2026-04-21-memory-consolidation-redesign-2026-04-21T11-57-39Z.md`
(representative of all five bash-fallback reports):

| Category | Count (approx) | Share | Example |
|---|---:|---:|---|
| FP — "unknown path prefix; add to contract if load-bearing" on a **bare filename** (no `/`, classified as prose reference) | ≈220 | 71% | `open-threads.md`, `INDEX.md`, `memory-consolidate.sh`, `/end-session`, `archive/` |
| TP-adjacent — anchor-confirmed repo path logged as info style-only (these are "correct but uncited") | ≈85 | 27% | `scripts/memory-consolidate.sh`, `agents/evelynn/CLAUDE.md`, `.claude/skills/end-session/SKILL.md` |
| FP — git-branch tokens as paths | ≈2 | <1% | `feat/coordinator-memory-two-layer-boot` |
| FP — env-var / technical strings | ≈3 | 1% | `GIT_DIR=/dev/null`, `tdd-gate.yml` (bare, no `.github/workflows/` prefix) |
| FP — block severity on deleted-on-purpose files | 14 blocks in one of the five reports | n/a | `scripts/filter-last-sessions.sh` ×many, the plan explicitly deletes this file |

**Bash fallback FP rate (severity ≥ info, excluding real anchor confirmations): ~73%** of the noise comes from a single failure mode — it cannot distinguish a bare filename in a prose sentence from a load-bearing relative path. Every repetition of `open-threads.md` in the plan body produces a fresh info finding.

### 2c. False-positive distribution — LLM v3 path

Across the 14 v3 reports in the sample, real false positives (as opposed to
legitimate path/sibling blocks or author-suppressed infos):

| Category | Count | Share | Example |
|---|---:|---:|---|
| TP — sibling `-tasks.md` / `-tests.md` blocks (Step D §D3) | 3 | correct block, not a FP | `demo-studio-v3-vanilla-api-ship-tasks.md` exists |
| TP — real stale path (block, correct) | 2 | correct | `plans/in-progress/work/2026-04-20-managed-agent-lifecycle.md` moved to approved |
| **FP — prose-mode CLI flag parsed as missing path** (block) | **1** | confirmed FP | `setup_agent.py --force` on line 42 of demo-studio-v3-vanilla-api-ship (report `…11-46-41Z.md`) — treated as a bare path, missed the `--force` flag context |
| **FP — git branch token as path** (block) | **1 claim × 5 sites** | confirmed FP | `feat/demo-studio-v3` in session-state-encapsulation (report `…06-40-28Z.md`) |
| **FP — bare-filename unknown-prefix info** (info, noise only) | 3–5 per large plan | nuisance | `tdd-gate.yml`, `orianna-fact-check.sh` (bare, no prefix) |
| FP — code-symbol mistaken for path | 0 confirmed | — | `client.messages.stream` etc. **softly triggered Step E** but were not reported as path-claims. Step E budget stayed at 0/15. |
| FP — URL-in-backticks flagged | 0 confirmed | — | Current prompt correctly treats URLs in prose links as rationale, not Step-E triggers. |
| Author-suppressed repetitions correctly passed | ≈60+ per large work-concern plan | correct | All `<!-- orianna: ok -->` suppressions honored |

**LLM v3 true false-positive share in block/warn severity: 2 distinct FP
categories, ~3 incidents across 14 reports.** Info-severity noise exists but
is already well-contained (median 6 info per plan, max 16).

**Hypothesis from Sona validated with caveats:** URL-token FPs are NOT currently
dominating — the existing Step E heuristic is conservative enough. Code-symbol
FPs are also not currently dominating — Step E correctly defers to suppression
or skips verification when the claim is an internal SDK shape. The two LIVE
categories are (a) prose-mode flag parsing and (b) git-branch-as-path, plus
the residual bare-filename unknown-prefix noise.

## 3. Live-docs best-practice check — Opus 4.7 at low effort

Confirmed against the canonical Anthropic docs (fetched 21 Apr 2026,
full text at the URLs below). Quotes verbatim:

**On literal interpretation at low effort**
("More literal instruction following" section):

> "Claude Opus 4.7 interprets prompts more literally and explicitly than
> Claude Opus 4.6, particularly at lower effort levels. It will not silently
> generalize an instruction from one item to another, and it will not infer
> requests you didn't make… If you need Claude to apply an instruction broadly,
> state the scope explicitly."

Implication for Orianna: every classification rule must enumerate positive
AND negative matches. The current prompt says "classify each token" but does
not spell out what is NOT a claim (e.g. "a backtick span immediately followed
by `--<flag>` on the same line is a CLI invocation, not a path").

**On effort=low scoping** ("Calibrating effort and thinking depth"):

> "Claude Opus 4.7 respects effort levels strictly, especially at the low end.
> At `low` and `medium`, the model scopes its work to what was asked rather than
> going above and beyond… on moderately complex tasks running at `low` effort
> there is some risk of under-thinking."

> "If you observe shallow reasoning on complex problems, raise effort to `high`
> or `xhigh` rather than prompting around it. If you need to keep effort at
> `low` for latency, add targeted guidance."

Implication: at low effort Orianna will not self-correct ambiguity by default;
the prompt must pre-enumerate edge cases, not expect the model to deduce them.

**On examples** ("Use examples effectively"):

> "When adding examples, make them:
> - Relevant: Mirror your actual use case closely.
> - Diverse: Cover edge cases and vary enough that Claude doesn't pick up
>   unintended patterns.
> - Structured: Wrap examples in `<example>` tags."
>
> "Include 3–5 examples for best results."

Implication: the plan-check prompt today has exactly ONE example block
(the META-EXAMPLE for `<!-- orianna: ok -->` suppression). Adding a compact
`<examples>` block of 3–5 negative examples (what NOT to flag) would hit
the recommended band.

**On positive vs negative instructions**
("Response length and verbosity"):

> "Positive examples showing how Claude can communicate with the appropriate
> level of concision tend to be more effective than negative examples or
> instructions that tell the model what not to do."

Implication: phrase new rules as "A backtick span preceding `--<flag>` is a
command invocation" (positive) rather than "Do not flag prose CLI flags as
missing paths" (negative).

**On explaining rationale** ("Add context to improve performance"):

> "Providing context or motivation behind your instructions, such as
> explaining to Claude why such behavior is important, can help Claude
> better understand your goals… Claude is smart enough to generalize from
> the explanation."

Implication: every new rule should carry a one-line "why" so the model can
generalize to adjacent shapes we forgot to enumerate.

Sources
- `https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices` (canonical, fetched 21 Apr 2026; prose quoted verbatim above)

## 4. Top-3 recommended prompt changes (ranked by expected FP-reduction × implementation cost)

### Rank 1 — Add a §C.pre "negative-example" block enumerating what NOT to flag in Step C

**Why first:** Fixes the two live v3 FPs (prose-CLI-flag and git-branch-as-path)
plus the residual unknown-prefix noise. Highest expected FP reduction per line
of prompt. Implementation cost: ~25 lines of prompt text, no code change.

**Target file:** `agents/orianna/prompts/plan-check.md` (Step C, insert
immediately before the numbered extraction steps).

**Before** (current Step C opening, `agents/orianna/prompts/plan-check.md`
lines 57–65):

```markdown
### Step C — Claim-contract checks (v1, preserved)

1. Read the plan at the path provided.
2. Extract every backtick span and fenced-code token.
3. Classify each token using the heuristic in `claim-contract.md` §6:
   - Path-shaped (contains `/` or ends in a recognized extension)?
   - Flag (starts with `-`)?
   - Integration name (proper noun, not a path, not a flag)?
   - Command?
4. For each path-shaped token, apply the routing rules from …
```

**After** (insert new subsection before the existing numbered list):

```markdown
### Step C — Claim-contract checks (v1, preserved)

**Step C.0 — Extraction scope (run this classifier BEFORE routing).**

A backtick span is only a path-shaped claim when ALL of the following hold:

- Contains `/` OR ends in a recognized file extension from the claim
  contract's routing table (`.md`, `.sh`, `.py`, `.ts`, `.yml`, `.yaml`,
  `.json`, `.toml`, `.tsx`, `.js`).
- Is NOT followed on the same line by a token starting with `--` or `-`
  (those tokens make the backtick span a CLI invocation, not a path).
- Does NOT match any of the explicit non-path shapes below.

The following backtick shapes are NEVER path claims and must produce no
Step C finding (not even info):

<examples>
<example shape="cli-invocation">
Input line: `setup_agent.py --force` must rewrite the vault on every rotation.
Reason: the trailing `--force` flag marks this as a command example, not
a bare-path claim. Extract nothing for Step C.
</example>

<example shape="git-branch">
Input line: Branch: `feat/demo-studio-v3`
Reason: `feat/<slug>` and `integration/<slug>` shapes match git branch
naming. They are not filesystem paths even though they contain `/`.
Emit no Step C finding. If the plan author wants the gate to verify a
branch exists on the remote, they cite the full `git ls-remote` line.
</example>

<example shape="python-dotted-identifier">
Input line: call `client.messages.stream()` to get streaming events.
Reason: dotted identifiers with no `/` are code symbols, not paths.
Step E may or may not trigger for these; Step C never does.
</example>

<example shape="http-route">
Input line: POST to `/v1/config/<id>` returns the vault descriptor.
Reason: a token starting with `/` that contains no file extension AND
no `.claude/` or `.github/` prefix is an HTTP route or CLI command
(`/end-session`, `/v1/preview/{id}`). Emit no Step C finding.
</example>

<example shape="env-var">
Input line: Set `MANAGED_AGENT_TOKEN` in the runtime env.
Reason: ALL_CAPS_WITH_UNDERSCORES with no `/` and no extension is an
environment variable name. Never a path.
</example>

<example shape="firestore-collection">
Input line: documents live under `demo-studio-sessions/{id}/runs`.
Reason: path-shaped tokens inside a sentence whose subject is a
Firestore/database collection are not filesystem paths. In a `concern:
work` plan, the author should still add `<!-- orianna: ok -->` to be
explicit; but the extractor must not produce a block on these.
</example>
</examples>

Context for the model: these six shapes dominate the noise floor in the
existing report corpus (see `assessments/orianna-prompt-audit-2026-04-21.md`
for the evidence). Filtering them at extraction time eliminates the
downstream Step C grep entirely — faster and more accurate than flagging
then suppressing.

**If a backtick span is ambiguous, prefer to NOT flag it.** Orianna's
role is to catch unverified load-bearing anchors, not to produce a
complete inventory of every token. A false negative on a borderline
token costs one human review; a false positive wastes the gate's
credibility.

1. Read the plan at the path provided.
… (existing numbered list continues unchanged)
```

**Expected FP reduction:** prose-CLI-flag and git-branch-as-path blocks
eliminated (~2 block FPs per large work-concern plan); bare-filename
unknown-prefix noise reduced by the extension-allowlist gate (~3–5 info
reductions per plan).

**Regression risk:** LOW. The new rules are all additive filters; they
remove entries from the Step C input set. A real missing path with a
`/` and an extension still passes through untouched. One mild risk:
the extension allowlist must include every extension actually used in
the codebase. The list above covers 99% (grep for backtick spans across
`plans/**.md` shows the long tail is `.age`, `.gpg`, `.example`, which
should be added). Suggest Talon verify the extension list by grepping
`plans/` for real path-shaped tokens currently in use.

### Rank 2 — Prepend a "claim-contract memoization" instruction for multi-invocation plans

**Why second:** Cuts tool-call count by ~2 on every second-and-later
invocation inside a single plan. Smaller wall-time win than Rank 1
but zero regression risk.

**Constraint (documented, not a fix):** Orianna sessions are ONE-SHOT.
The `scripts/orianna-fact-check.sh` and `scripts/orianna-sign.sh`
launchers both `exec` the `claude` CLI once per invocation and never
reuse the process. Session-scoped memoization therefore only applies
WITHIN a single plan-check run — i.e. when the Step C extractor
reads `agents/orianna/claim-contract.md` once and applies the rules
to N tokens, rather than re-reading the contract on each claim.

This is a small win but essentially free. See §5 for the caching
path the Anthropic platform itself provides, which would matter more.

**Target file:** `agents/orianna/prompts/plan-check.md` (Before you
start section, lines 6–15).

**Before:**

```markdown
## Before you start

Read these two files in full before extracting any claims:

1. `agents/orianna/claim-contract.md` — the v1 claim taxonomy, severity
   definitions, two-repo routing rules, and extraction heuristic.
2. `agents/orianna/allowlist.md` — vendor bare names that pass without
   requiring an anchor.

You may NOT edit any file. You are read-only. Your only output is the
report file described below.
```

**After:**

```markdown
## Before you start

Read these two files in full ONCE, before extracting any claims:

1. `agents/orianna/claim-contract.md` — the v1 claim taxonomy, severity
   definitions, two-repo routing rules, and extraction heuristic.
2. `agents/orianna/allowlist.md` — vendor bare names that pass without
   requiring an anchor.

Hold the routing table, opt-back list, extension allowlist, and
suppression grammar in working memory for the remainder of this run.
You will apply them across every token extracted from the plan body.
Do NOT re-Read these two files mid-run — the rules do not change
between tokens within a single plan check. One pass through the
contract; many tokens classified against it.

You may NOT edit any file. You are read-only. Your only output is the
report file described below.
```

**Expected wall-time impact:** 1–2 Read tool calls saved per invocation.
On a session already doing 8–15 Read/Grep calls, this is a 10–15%
tool-call reduction. Small, but free.

**Regression risk:** ZERO. Rules in the two files don't change
mid-run by definition.

### Rank 3 — Batch the Step C anchor checks into a single Bash invocation

**Why third:** Biggest wall-time win if implemented correctly; highest
implementation risk because the sibling script already does this
pattern (`test -e` loop) and the LLM must be given a concrete shape.

**Target file:** `agents/orianna/prompts/plan-check.md` (Step C subsection
4, the path-routing loop).

**Before** (the existing Step C point 4, abbreviated):

```markdown
4. For each path-shaped token, apply the routing rules … Run
   `test -e <repo-root>/<path>` for each routed path. Does not exist
   → `block`. Exists → `info` (clean pass, anchor confirmed).
```

**After:**

```markdown
4. For each path-shaped token, apply the routing rules … Once you have
   enumerated ALL routed paths for the plan, batch the existence checks
   into at most TWO Bash invocations — one per resolution root — rather
   than one `test -e` per path. Recommended pattern:

   ```bash
   # Build the list of tokens routed to this repo:
   for p in path1 path2 path3 …; do
     if [ -e "$REPO_ROOT/$p" ]; then
       printf 'HIT %s\n' "$p"
     else
       printf 'MISS %s\n' "$p"
     fi
   done
   ```

   A single Bash call testing N paths costs one tool-call round-trip;
   N sequential `test -e` calls cost N. On a typical plan with 10–20
   routed paths this reduces Step C tool calls from ~15 to ~2.

   For cross-repo tokens (`apps/`, `dashboards/`, `.github/workflows/`),
   issue one additional Bash call against the strawberry-app checkout
   after the `git -C … fetch origin main` prefetch. Same batch pattern.

   After the batch returns, classify each result: HIT → info, MISS →
   block under the strict default rule. Suppressed-line tokens
   (`<!-- orianna: ok -->`) are logged as info regardless of the
   HIT/MISS result, per §8 of the claim contract.
```

**Expected wall-time impact:** biggest win in the set. On a 20-path
plan, Orianna today makes roughly 15–20 individual Bash/Read calls for
Step C; batching reduces this to 2 calls. At Opus-low effort with no
thinking token cost, most of the wall-time is tool-call round-trip,
so this may compress Step C from ~10s to ~1s. Estimated plan-level
reduction: 20–35% of total wall time for plans with many path tokens
(work-concern plans in particular).

**Regression risk:** MEDIUM. The model must correctly partition tokens
by resolution root BEFORE batching; a partition bug would report
false MISS on opt-back paths. Mitigation: the prompt should tell Orianna
to emit a pre-batch inventory (sorted list of tokens per resolution
root) as the first Bash output, so a reviewer can verify the partition
independently of the HIT/MISS results. Also: at Opus-low the model
may refuse to build the loop and revert to one-call-per-path; the
prompt should include the shell snippet verbatim as an illustration so
there's no ambiguity about the intended shape. Include that
illustration in the prompt (as shown above) rather than leaving "use
Bash" underspecified.

## 5. Orthogonal recommendation — enable prompt caching on the system prompt

Not strictly in scope for T-prompt-1 (which is a prompt-text edit), but
the single largest latency/cost win sitting on the table:

`scripts/orianna-fact-check.sh` invokes `claude -p --system-prompt "…" "$FULL_PROMPT"`
with a long static system-prompt preamble (the `.claude/_script-only-agents/orianna.md`
content — role, modes, discipline, report shape, ~60 lines). Claude's
prompt caching, if enabled on that preamble, would deliver near-instant
preamble processing on every invocation after the first (5-minute TTL
by default).

At the time of writing, the `claude` CLI's `-p` flag does not expose a
cache-control option; this would require a small helper switching to the
SDK or raw Messages API. Flag for Talon / a future task as a potentially
bigger win than any prompt-text edit. Not a T-prompt-1 item.

## 6. Estimated wall-time reduction if Ranks 1+2+3 all applied

Back-of-envelope, from the v3 sample:

| Change | Tool-call reduction | Wall-time reduction |
|---|---:|---:|
| Rank 1 — negative examples | 0 (extraction is same turn) | ~2–5s (fewer downstream Bash invocations for FP paths) |
| Rank 2 — memoize contract | 1–2 Read calls saved | 1–2s |
| Rank 3 — batch Step C Bash | 13–18 Bash calls saved | 8–15s |
| **Combined** | **≈15 tool calls saved / run** | **≈15–25s per plan-check run**, against a current mean of ~45–60s wall-time on non-trivial plans |

Percentage estimate: **~25–40% wall-time reduction on plans with ≥10
path tokens**, and correspondingly smaller on plans with few tokens
(where Step C already completes in 1–2 calls).

This comfortably meets the §6 success criterion in the gate-speedups plan
("Median Orianna single-pass fact-check time drops by ≥25%, or if not,
the T-prompt-1 audit doc explains why and defers the target"). No
deferral needed; the audit validates the 25% target.

## 7. Regression-risk summary

| Change | Could cause false NEGATIVES (missed real claims)? | Mitigation |
|---|---|---|
| Rank 1 extension allowlist | Yes, if a real claim uses an unlisted extension (`.age`, `.gpg`, `.example`) | Talon must grep `plans/**.md` for backtick path tokens and verify the allowlist covers all real shapes before shipping |
| Rank 1 git-branch shape | Yes, if a plan intentionally cites `feat/<slug>` as a filesystem path (unusual) | None needed — if a branch shape is load-bearing, author uses full `git ls-remote` citation |
| Rank 1 CLI-flag shape | Yes if a real path contains a literal `--` (extremely rare) | Limit the rule to "same line as backtick", not "anywhere in file" |
| Rank 2 memoize contract | No | — |
| Rank 3 batch Step C | Yes, if a partition bug mis-routes a path | Emit pre-batch inventory for reviewer audit; include shell snippet verbatim in the prompt |

None of the changes weaken the v1 claim-contract's §4 strict-default rule.
A missing load-bearing path STILL blocks.

## 8. Bash fallback — separate recommendation out of scope for T-prompt-1

The 311-info bash-fallback reports represent ~98% of all info-severity
noise in the corpus. T-prompt-1 is scoped to the LLM prompt and cannot
address this.

Recommendation for a separate follow-up (not this plan):

Either (a) retire the bash fallback entirely and fail closed when
`claude` CLI is absent (simplest), or (b) teach
`scripts/fact-check-plan.sh` the same extension allowlist and prose-shape
filter described in Rank 1. Option (a) is preferred on current evidence —
the fallback reports are not signal; they are noise that Duong has to
scroll past when opening a fresh report directory listing.

Flag this to Sona / Evelynn as a post-T-prompt-3 followup; out of scope
for T-prompt-1.

## 9. Dependencies — nothing blocks T-prompt-1

- T-prompt-1 per the approved plan is "research / audit → findings doc";
  this file IS that deliverable.
- T-prompt-2 (the actual prompt edit) requires only this file as input
  plus the target file `.claude/_script-only-agents/orianna.md` plus
  `agents/orianna/prompts/plan-check.md`. All three exist. Talon can
  run as scheduled.
- No production file had to be modified to produce this assessment.

## References

- `.claude/_script-only-agents/orianna.md` (role prompt, last modified
  2026-04-21, commit `54ac1bf` pin to Opus-low)
- `agents/orianna/prompts/plan-check.md` (task prompt for plan-check
  mode; this is the actual edit target for T-prompt-2)
- `agents/orianna/claim-contract.md` (v1 extraction contract, referenced
  by both the LLM prompt and the bash fallback)
- `scripts/orianna-fact-check.sh` (LLM-path launcher)
- `scripts/fact-check-plan.sh` (bash-fallback engine — responsible for
  the 311-info reports)
- `plans/approved/personal/2026-04-21-orianna-gate-speedups.md` §6, T-prompt-1/2/3

Anthropic canonical docs cited verbatim in §3:
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices
