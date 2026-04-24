---
title: Reviewer-auth concern split — harden Senna/Lucian for personal vs work
date: 2026-04-24
owner: Karma
concern: personal
complexity: quick
orianna_gate_version: 2
tests_required: true
status: approved
tags: [reviewer-auth, senna, lucian, concern-split, rule-18]
---

## Context

Senna and Lucian are cross-concern PR reviewers dispatched by both Evelynn (personal) and Sona (work). The reviewer-auth path is not the same on both sides and the current agent defs assume the personal-concern path unconditionally.

- **Personal (Evelynn).** Executors author PRs as `Duongntd`; reviewers post APPROVE via `scripts/reviewer-auth.sh` as `strawberry-reviewers` (Lucian default lane) or `strawberry-reviewers-2` (Senna `--lane senna`). GitHub accepts because author ≠ reviewer. Working end-to-end (PR #40, #41).
- **Work (Sona).** Executors AND reviewers all run under `duongntd99`. GitHub blocks self-approval on same-account reviews, so reviewers post verdicts as **PR comments** via `gh pr comment` (wrapped by `scripts/post-reviewer-comment.sh` for anonymity + signature stripping); Duong manually satisfies Rule 18 (b) from `harukainguyen1411`. Proven today on work PR #114.

Sona's CLAUDE.md already encodes the work-side protocol (§Identity Model, §Reviewer flow — work scope) and Evelynn's CLAUDE.md encodes a similar pattern in the reviewer-failure fallback. The gap is in `.claude/agents/senna.md` and `.claude/agents/lucian.md` themselves: their **Identity** and **Review Process** sections unconditionally prescribe `scripts/reviewer-auth.sh gh pr review`, which is wrong for `[concern: work]` dispatches. Likewise, `scripts/reviewer-auth.sh` has no scope guard — a work-concern reviewer who follows the current agent def would invoke it and either (a) silently authenticate as the wrong identity for a `missmp/*` repo or (b) fail opaquely.

Goal: make both concerns Just Work from the agent definition, with a structural scope guard in `reviewer-auth.sh` as the backstop. Plan does NOT rewrite Sona's CLAUDE.md or Evelynn's CLAUDE.md — those are already correct; we only need cross-links.

## Decision

1. Add a **Concern-split reviewer-auth protocol** section to each of `senna.md` and `lucian.md`, branching on the `[concern: ...]` tag that dispatches already inject.
   - `[concern: personal]` → existing `scripts/reviewer-auth.sh [--lane senna] gh pr review ...` path unchanged.
   - `[concern: work]` → `scripts/post-reviewer-comment.sh --pr N --repo missmp/<repo> --file <body-file>` under `duongntd99`, verdict posted as comment only. No APPROVE review, no `reviewer-auth.sh`.
2. Update the **Identity** section in both agent defs to name both paths and make clear the personal-concern preflight (`gh api user --jq .login` returning the reviewer handle) does NOT apply on work concern. Add an assert: on `[concern: work]`, active `gh` account MUST be `duongntd99` — run `gh auth switch --user duongntd99` first if not.
3. Add a **scope guard** to `scripts/reviewer-auth.sh` that refuses work-scope invocations (head repo matches `missmp/*`) with a clear error pointing at `scripts/post-reviewer-comment.sh`. This is defense-in-depth against the agent def being misread; it uses the same head-repo resolution already present in the anonymity scan block.
4. Add a **concern-split reviewer-auth** block to `agents/memory/agent-network.md` §Reviewer identity to reconcile line 258 (which currently claims reviewers always use `strawberry-reviewers`). Replace the single-row entry with a two-row split: personal → strawberry-reviewers{,-2}; work → duongntd99 + manual Duong approval.
5. Spot-update `agents/evelynn/CLAUDE.md` reviewer-failure fallback (line 225) — already references `post-reviewer-comment.sh` correctly. No change needed there; verify only. Spot-update `agents/sona/CLAUDE.md` line 196 ("the agent-def change is tracked separately on Evelynn's side") — replace the parenthetical inbox reference with a link to this plan once promoted.

## Tasks

### T1 — xfail test for reviewer-auth.sh work-scope refusal

- kind: test
- estimate_minutes: 15
- files: `scripts/tests/test-reviewer-auth-scope-guard.sh` (new). <!-- orianna: ok -->
- detail: Bats-less shell test following the existing `scripts/tests/` pattern. Cases: (a) `ANONYMITY_MOCK_REPO_URL=missmp/company-os scripts/reviewer-auth.sh gh pr review 1 --approve --body "-- reviewer"` → exits non-zero with message referencing `post-reviewer-comment.sh`; (b) same with `ANONYMITY_MOCK_REPO_URL=Duongntd/strawberry-app` → passes the scope check (the test runs with `ANONYMITY_DRY_RUN=1` so no real gh exec). Mark xfail initially (test exits 0 with skip marker citing plan `2026-04-24-reviewer-auth-concern-split.md` T3).
- DoD: test file committed in its own xfail-first commit per Rule 12; referenced from the plan; runs red against current `reviewer-auth.sh` once the xfail marker is flipped.

### T2 — Add concern-split protocol section to senna.md

- kind: agent-def
- estimate_minutes: 10
- files: `.claude/agents/senna.md`
- detail: Insert new `## Concern-split reviewer-auth` section after the existing `## Identity` section. Personal path unchanged. Work path: check `[concern: work]` tag on the dispatch prompt; run `gh auth switch --user duongntd99` as preflight; post verdict via `scripts/post-reviewer-comment.sh --pr N --repo <owner>/<repo> --file <body-file>`; Duong satisfies Rule 18 (b) manually from `harukainguyen1411`. Update existing `## Identity` bullets to say "on personal concern" where they currently say "always" for the `reviewer-auth.sh` preflight.
- DoD: section is unambiguous about which path to take given the concern tag; no contradictory "always" language remains; `-- reviewer` neutral signature on work-scope still stated.

### T3 — Add concern-split protocol section to lucian.md

- kind: agent-def
- estimate_minutes: 10
- files: `.claude/agents/lucian.md`
- detail: Parallel to T2. Insert `## Concern-split reviewer-auth` section; branch on `[concern: ...]` tag; personal uses default-lane `reviewer-auth.sh`; work uses `post-reviewer-comment.sh` under `duongntd99`. Update the existing `## Identity` "always" language to "on personal concern".
- DoD: mirror of T2 with Lucian's default-lane identity claim (`strawberry-reviewers`, no `--lane` flag).

### T4 — Add work-scope refusal guard to reviewer-auth.sh

- kind: script
- estimate_minutes: 20
- files: `scripts/reviewer-auth.sh`
- detail: After the anonymity-scan block resolves `_head_repo` (lines 90-111), add a new guard: if `_is_work == 1`, print a multi-line error pointing at `scripts/post-reviewer-comment.sh` and exit with code 4 (distinct from the existing exit 3 for anonymity). Reuse the existing head-repo resolution logic; do NOT duplicate. Must honour `ANONYMITY_MOCK_REPO_URL` so T1 tests can exercise it. The guard runs BEFORE decryption — no PAT should be decrypted for a rejected work-scope call.
- DoD: flip the T1 xfail marker; the test now runs and passes. Personal-scope invocations (mock URL e.g. `Duongntd/strawberry-app`) still reach the decrypt/exec step (or exit 0 via `ANONYMITY_DRY_RUN=1`).

### T5 — Reconcile agent-network.md reviewer identity table

- kind: docs
- estimate_minutes: 10
- files: `agents/memory/agent-network.md`
- detail: Replace the single-row "Reviewer identity" entry (line ~258) with a two-row split: `Reviewer — personal concern` → `strawberry-reviewers{,-2}` via `reviewer-auth.sh`; `Reviewer — work concern` → `duongntd99` via `post-reviewer-comment.sh`, Rule 18 (b) satisfied by Duong manually from `harukainguyen1411`. Update the "Reviewer codepath" and "Executor boundary" paragraphs immediately below to name both paths. Keep the executor-boundary prohibition — executors never source `reviewer-auth.sh` regardless of concern.
- DoD: no surviving claim that reviewers "always" use `strawberry-reviewers`; both concerns' paths are visible in the table and prose.

### T6 — Cross-link from sona.md CLAUDE and verify evelynn.md reviewer-failure fallback

- kind: docs
- estimate_minutes: 5
- files: `agents/sona/CLAUDE.md`, `agents/evelynn/CLAUDE.md`
- detail: `agents/sona/CLAUDE.md` line 196 — replace the parenthetical "inbox FYI sent 2026-04-24" with a link to `plans/implemented/personal/2026-04-24-reviewer-auth-concern-split.md` (will resolve post-promotion). `agents/evelynn/CLAUDE.md` line 225 — no change required; verify the `post-reviewer-comment.sh` reference is still accurate and add a one-line cross-reference to this plan after "Audit trail preserved; no approval claimed."
- DoD: both coordinator CLAUDE.md files cite this plan exactly once at the reviewer-split touchpoint; no new protocol language is introduced here (agent defs are the source of truth).

## Test plan

- **Invariant: reviewer-auth.sh refuses work-scope invocations.** T1 test exercises `ANONYMITY_MOCK_REPO_URL=missmp/*` and asserts non-zero exit + message citing `post-reviewer-comment.sh`. Protects against an agent following stale instructions and leaking reviewer PAT usage onto a `missmp/*` PR. Also asserts the guard runs before decryption (no `secrets/reviewer-auth.env` side-effect on refused calls).
- **Invariant: personal-scope invocations still work.** T1 test exercises `ANONYMITY_MOCK_REPO_URL=Duongntd/strawberry-app` with `ANONYMITY_DRY_RUN=1` and asserts clean exit 0 through the existing codepath. Protects against the guard being too eager and breaking Evelynn's Senna/Lucian flow.
- **Manual smoke (post-merge).** Next personal-concern PR: dispatch Senna + Lucian, confirm APPROVE reviews land as `strawberry-reviewers-2` and `strawberry-reviewers` respectively (unchanged behavior). Next work-concern PR: dispatch Senna + Lucian with `[concern: work]`, confirm verdicts land as PR comments under `duongntd99` with neutral `-- reviewer` signature; Duong posts Rule 18 (b) approval from `harukainguyen1411`.

## References

- `.claude/agents/senna.md`, `.claude/agents/lucian.md` — agent defs being updated
- `scripts/reviewer-auth.sh` — scope guard target
- `scripts/post-reviewer-comment.sh` — work-concern counterpart (already exists)
- `agents/sona/CLAUDE.md` §Identity Model, §Reviewer flow — work scope — authoritative protocol for work concern
- `agents/evelynn/CLAUDE.md` §Reviewer-failure fallback — personal concern fallback via same `post-reviewer-comment.sh`
- `agents/memory/agent-network.md` §Reviewer identity — table reconciliation target
- Work PR https://github.com/missmp/company-os/pull/114 — end-to-end proof of the work-concern flow (Yuumi posted Senna's verdict as comment)

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Owner named (Karma), concern tagged personal, all six tasks have concrete files, DoD, and estimates. T1 provides the xfail-first test required by Rule 12 and tests_required: true. The scope-guard + agent-def split is tightly scoped to a named invariant (reviewer-auth.sh must refuse work-scope) with no speculative abstraction. Semantic approval confirmed by caller: Duong handed this scope to Evelynn via Sona's FYI earlier today.
