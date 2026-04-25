---
title: No AI attribution — defense in depth (prompt + hook + CI)
slug: no-ai-attribution-defense-in-depth
date: 2026-04-25
status: approved
concern: personal
complexity: quick
owner: karma
orianna_gate_version: 2
tdd_required: true
tests_required: true
estimate_minutes: 95
risk: low
touches:
  - .claude/agents/_shared/
  - .claude/agents/
  - scripts/hooks/commit-msg-no-ai-coauthor.sh
  - scripts/sync-shared-rules.sh
  - .github/workflows/pr-lint.yml
  - tests/
references:
  - CLAUDE.md (global) — "Never include AI authoring references in commits"
  - plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
  - PR #49 (sync-shared-rules.sh + shared include mechanism)
  - Offending commits: b2b8944 (Talon), d8088bd (Jayce)
---

## Context

The rule "Never include AI authoring references in commits" is currently enforced by exactly one mechanism: `scripts/hooks/commit-msg-no-ai-coauthor.sh`. Two failure modes have shown up in practice:

1. **Hook regex gap.** The current pattern `(claude|anthropic|ai|bot|assistant)` in the name slot misses `Co-Authored-By: Claude Sonnet 4.6` style trailers because the word-boundary class `[[:space:](]` requires whitespace-or-paren before the keyword, and the model-name forms ("Sonnet", "Opus", "Haiku") are not in the keyword set at all. Commits `b2b8944` (Talon) and `d8088bd` (Jayce) slipped through this gap.
2. **No prompt-layer rule.** Agents reflexively add AI attribution → hook blocks → revert/retry. Wastes cycles. Hook alone is whack-a-mole because the prompt never told the agent not to try.

Defense in depth: a shared prompt-layer include so agents do not produce attribution in the first place, a tightened commit-msg hook that catches escapes, and a new CI lint over PR body + comments (commit-msg hook does not cover GitHub-side text). All three layers list AI markers as **non-exhaustive** — the canonical phrase is "includes but is not limited to" so future model names or branding do not require a re-plan.

The universal `Co-Authored-By:` block (any name, not just AI) is a deliberate tightening: this system has no legitimate use case for the trailer today, and `Human-Verified: yes` already exists as the override for the rare legitimate human pair-programming case. If a human collaborator contributes, attribution belongs in the PR body prose with the override trailer present, not in a `Co-Authored-By:` line that this system's tooling treats as suspect by default.

## Decision

**Three-layer defense.** Layer 1 (prompt) is authored once in `_shared/no-ai-attribution.md` and inlined into every agent def (coordinators + subagents) via the existing PR #49 mechanism. Layer 2 tightens the existing commit-msg hook. Layer 3 adds CI scanning of PR body + PR comments. All three reference the same canonical marker list, kept in sync by convention (no runtime coupling — duplication is acceptable for three small lists).

**Sync-script extension required.** The current `sync-shared-rules.sh` replaces everything below a single include marker. Most agent defs already include a role-shared file (`_shared/quick-executor.md`, `_shared/breakdown.md`, etc.). To add a second universal include without breaking the first, this plan extends `sync-shared-rules.sh` to support multiple `<!-- include: _shared/<file>.md -->` markers in sequence: each marker line is preserved, and the content immediately following each marker (until the next marker or EOF) is replaced from the corresponding shared file. Idempotency preserved.

**Universal `Co-Authored-By:` block.** The hook currently only flags `Co-Authored-By:` trailers whose name/email matches AI keywords. This plan tightens to block ANY `Co-Authored-By:` trailer. `Human-Verified: yes` override remains. This applies to BOTH concerns (personal and work repos) — Sona ports separately per Layer 3.

## Open questions

- Should the universal `Co-Authored-By:` block be feature-flagged (e.g. an opt-out env var) for the first week in case it fires unexpectedly on imported commits during merges? **Default position: no flag.** Override mechanism (`Human-Verified: yes`) already exists; merges with foreign trailers can re-author or amend. Surfacing for visibility.
- Layer 3 CI lint on `issue_comment` events — should it block, or only post a comment? **Default: block (fail check).** Aligns with "make incorrect attribution a hard stop." Reviewers can edit the comment to remove markers if needed; check re-runs on edit.

## Tasks

### T1 — xfail: structural test for shared include presence

- kind: test
- estimate_minutes: 10
- files: `tests/agents/test_no_ai_attribution_include.sh` (new) <!-- orianna: ok -->
- detail: POSIX-bash test that walks `.claude/agents/*.md` (excluding `_shared/`, `orianna.md` if it lives in `_script-only-agents/`), asserts each file contains the literal line `<!-- include: _shared/no-ai-attribution.md -->`, AND asserts the inlined block immediately following matches the canonical content of `.claude/agents/_shared/no-ai-attribution.md`. Mark xfail by exiting with the documented xfail sentinel (`echo "XFAIL: …" && exit 0`) referencing this plan.
- DoD: test committed in its own commit on the plan branch with subject prefix `chore(test):` and body referencing `plans/proposed/personal/2026-04-25-no-ai-attribution-defense-in-depth.md` task T1; xfail sentinel present; test runs and passes-as-xfail.

### T2 — Author shared include + extend sync script + inline into all agent defs

- kind: code
- estimate_minutes: 25
- files: `.claude/agents/_shared/no-ai-attribution.md` (new), `scripts/sync-shared-rules.sh`, `.claude/agents/*.md` (all agent defs, both `.claude/agents/` and `.claude/_script-only-agents/`) <!-- orianna: ok -->
- detail:
  - (a) Write `_shared/no-ai-attribution.md` with the rule text. Canonical body: a "Never write AI attribution" header, then "Never write any `Co-Authored-By:` trailer regardless of name (legitimate human pair-programming uses `Human-Verified: yes` override)." Then "Never write AI markers in commit messages, PR body, or PR comments — including but not limited to: `Claude`, `Anthropic`, `🤖`, `Generated with [Claude Code]`, `AI-generated`, any Anthropic model name (`Sonnet`, `Opus`, `Haiku`), the URL `claude.com/code` or similar." Then "These markers are non-exhaustive — when in doubt, omit attribution."
  - (b) Extend `sync-shared-rules.sh` to support multiple include markers per file. Each `<!-- include: _shared/<file>.md -->` line marks the start of a managed block; the block ends at the next include marker or EOF. The script preserves marker lines and replaces only the content between them. Idempotent.
  - (c) Append `<!-- include: _shared/no-ai-attribution.md -->` to every agent def under `.claude/agents/*.md` and `.claude/_script-only-agents/*.md` (currently: orianna). Run the extended sync script to inline the block.
  - Remove xfail sentinel from T1's test in the same commit only if all assertions now pass; otherwise leave xfail and follow up. (Convention: T1 test commit is xfail; T2 implementation flips it green.)
- DoD: `bash scripts/sync-shared-rules.sh` exits 0 and is idempotent (running twice produces no diff); T1 test passes (no xfail sentinel); every file matched by `ls .claude/agents/*.md .claude/_script-only-agents/*.md` contains both the include marker and the inlined block.

### T3 — xfail: regex tests for tightened commit-msg hook

- kind: test
- estimate_minutes: 10
- files: `tests/hooks/test_commit_msg_no_ai_coauthor.sh` (new or extended) <!-- orianna: ok -->
- detail: Add cases asserting the hook rejects:
  - `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` (current gap — would have caught b2b8944).
  - `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`.
  - `Co-Authored-By: Random Human <human@example.com>` (universal block — no name keyword).
  - Body containing `🤖 Generated with [Claude Code](https://claude.com/code)`.
  - Body containing `AI-generated commit message`.
  - Body containing the bare URL `claude.com/code`.
  - Body mentioning `Sonnet 4.6` outside a trailer (assert blocked — model names are markers).
- And asserts it accepts:
  - Clean message with no trailer.
  - `Co-Authored-By: Random Human <human@example.com>` plus `Human-Verified: yes` (override path).
  - Message containing the word "ai" in normal English prose (e.g. "fix typo in word 'maintain'") — guard against false positives. Document chosen anchoring: AI-marker scan applies only to (i) `Co-Authored-By:` lines, (ii) lines containing the marker as a standalone token or quoted phrase, NOT substring-matches inside unrelated words. Test "maintain" as a negative case.
- xfail sentinel until T4 lands.
- DoD: test committed solo with `chore(test):` prefix; xfail sentinel present.

### T4 — Tighten commit-msg hook

- kind: code
- estimate_minutes: 15
- files: `scripts/hooks/commit-msg-no-ai-coauthor.sh`
- detail:
  - Replace PATTERN_A so ANY `Co-Authored-By:` trailer is flagged (universal block); keep PATTERN_B (email domain) as belt-and-suspenders.
  - Add a third scan over the entire message body for AI markers: `Sonnet`, `Opus`, `Haiku`, `Generated with [Claude Code]`, `🤖`, `AI-generated`, `claude\.com`. Anchor as standalone token or inside backtick/bracket markup to avoid "maintain"-style false positives — concretely, require the marker to be preceded by start-of-line, whitespace, `(`, `[`, backtick, or `:`, AND followed by end-of-line, whitespace, `)`, `]`, backtick, comma, or period.
  - Update the rejection message to enumerate the broader rule and point to `_shared/no-ai-attribution.md`.
  - `Human-Verified: yes` override continues to short-circuit at the top.
- DoD: T3 test passes (no xfail); manual smoke per case in T3 confirms behavior; rejection message updated.

### T5 — xfail: PR body + comment lint test (CI shape)

- kind: test
- estimate_minutes: 10
- files: `tests/ci/test_pr_lint_no_ai_attribution.sh` (new) <!-- orianna: ok -->
- detail: Shell-level test that invokes the inlined PR-lint snippet (extracted to a callable function or a shared `scripts/ci/pr-lint-no-ai-attribution.sh` helper) against fixture PR bodies and comment payloads. Cases: clean body passes; body containing `🤖 Generated with [Claude Code]` fails; body containing `Co-Authored-By: Anyone <a@b>` fails; body with `Human-Verified: yes` line plus an offending marker passes; comment payload containing `Sonnet 4.6` fails. Same anchoring discipline as T3/T4. xfail sentinel until T6 lands.
- DoD: test committed solo with xfail sentinel.

### T6 — Extend pr-lint workflow to scan body + comments

- kind: code
- estimate_minutes: 20
- files: `.github/workflows/pr-lint.yml`, `scripts/ci/pr-lint-no-ai-attribution.sh` (new helper) <!-- orianna: ok -->
- detail:
  - Add `issue_comment` to the workflow's `on:` triggers (filter to `created`/`edited` on PR comments only — `if: github.event.issue.pull_request`).
  - Extract AI-marker scanning into `scripts/ci/pr-lint-no-ai-attribution.sh` (POSIX bash) so the same logic is callable from both the existing pr-lint job (for PR body) and a new `pr-comment-lint` job (for comments).
  - Add a new job `pr-no-ai-attribution` that fetches PR body (on `pull_request` events) or comment body (on `issue_comment` events), invokes the helper, and fails on match. `Human-Verified: yes` line in the scanned text is the override.
  - Update existing Rule 16 job: leave it untouched — Layer 3 is a sibling job, not a modification of Rule 16 logic.
- DoD: T5 test passes; `actionlint` (or `yq` syntax check) on the workflow yaml passes; both jobs declared with minimal `permissions:` (read for body, none for comments beyond default).

### T7 — Documentation: Rule entry in CLAUDE.md

- kind: docs
- estimate_minutes: 5
- files: `CLAUDE.md` (repo root)
- detail: Add a short bullet under "Critical Rules — Universal Invariants" referencing the three layers and pointing to `_shared/no-ai-attribution.md` as the source of truth for the marker list. Do not duplicate the marker list inline — keep CLAUDE.md compact. Number assignment is the next available rule number (currently 20 → new rule is 21).
- DoD: bullet lands; cross-references to hook script + workflow + shared include are correct paths.

## Test plan

Tests required: yes (Rule 12 — TDD-enabled). xfail-first per Rule 12: each xfail commit lands before its paired implementation commit on the same branch.

**Invariants protected:**

- **I1 (prompt completeness):** Every agent def under `.claude/agents/*.md` and `.claude/_script-only-agents/*.md` contains the no-ai-attribution include marker AND the inlined block matches the canonical shared file. → T1 / T2.
- **I2 (commit-msg hook coverage):** `Co-Authored-By:` trailer is universally blocked regardless of name; `Human-Verified: yes` overrides; AI markers (incl. Sonnet/Opus/Haiku/🤖/"Generated with"/claude.com/AI-generated) in commit-message body are blocked with no false positives on common English substrings. → T3 / T4.
- **I3 (PR-side coverage):** PR body and PR comments are scanned for the same marker set; `Human-Verified: yes` overrides; CI fails on match. → T5 / T6.
- **I4 (sync mechanism):** `sync-shared-rules.sh` supports multiple include markers per file, is idempotent, and exits non-zero if any included shared file is missing. → exercised transitively by T1/T2 (running the sync as part of T2 must produce a clean diff on second run).

**Out of scope for this plan's tests:** End-to-end GitHub Actions integration test of T6 — verified manually by opening a test PR with offending content during T6 review.

## Cross-concern follow-ups (Sona's lane)

These are recorded here as the contract; Sona dispatches her own implementer. Not blocking for this plan to ship.

- **F1 — Port hook + CI lint to `missmp/company-os`.** Same hook script, same workflow shape, same shared rule wording. Track as a separate work-concern plan referencing this one.
- **F2 — Port hook + CI lint to `missmp/workspace`.** Same as F1.
- **F3 — Scrub-PR for existing offending commits.** Non-blocking. Identify offending commits (start with `b2b8944`, `d8088bd`) and decide per-commit whether to amend (history rewrite) or accept-and-document. History rewrite of merged commits requires Duong sign-off — surface as an open question in F3, not auto-execute.

## References

- `CLAUDE.md` — Critical Rules (Universal Invariants)
- `plans/in-progress/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md` — original hook plan
- PR #49 — `sync-shared-rules.sh` and the include mechanism
- `scripts/hooks/commit-msg-no-ai-coauthor.sh` — current hook
- `.github/workflows/pr-lint.yml` — current PR lint workflow (Rule 16)

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (karma), concrete tasks with explicit DoD, and follows xfail-first TDD discipline (Rule 12) with paired test/implementation commits. The two open questions (universal Co-Authored-By block, fail-the-check Layer 3) carry explicit defaults that Duong has confirmed match his "block it, don't ceremony" preference, so they are deemed-resolved. Three-layer defense-in-depth design is well-justified: prompt prevention, hook backstop, CI catch-all, with shared marker list kept in sync by convention. False-positive anchoring discipline (T3 "maintain" negative case) is a thoughtful guard against overly broad regex.
