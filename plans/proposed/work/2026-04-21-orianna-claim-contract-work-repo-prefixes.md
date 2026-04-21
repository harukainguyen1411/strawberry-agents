---
title: Orianna claim-contract — concern-based resolution root flip
status: proposed
owner: karma
created: 2026-04-21
date: 2026-04-21
concern: work
complexity: normal
orianna_gate_version: 2
tags: [orianna, claim-contract, routing, work-concern, infra]
tests_required: true
---

## Context

The four work-concern ADRs in `plans/proposed/work/` (`2026-04-20-managed-agent-dashboard-tab.md`, `2026-04-20-managed-agent-lifecycle.md`, `2026-04-20-s1-s2-service-boundary.md`, `2026-04-20-session-state-encapsulation.md`) each failed `orianna-sign.sh approved` with between 7 and 29 block findings. The reports at `assessments/plan-fact-checks/2026-04-20-*-2026-04-21T02-*.md` share a single root cause: path-shaped backtick tokens such as `tools/demo-studio-v3/agent_proxy.py`, `company-os/tools/demo-studio-v3/main.py`, and `company-os/company-os-backend/...` are resolved against this repo (or strawberry-app) and `test -e` fails because those paths live inside the work monorepo at `~/Documents/Work/mmp/workspace/`.

The precedent plan (`plans/in-progress/personal/2026-04-21-orianna-work-repo-routing.md`) attempted to fix this by adding concern-aware routing for a fixed set of prefixes — `apps/`, `dashboards/`, `.github/workflows/`. That approach does not scale: the work side is a growing monorepo whose top-level layout will keep changing (`company-os/`, `tools/demo-studio-v3/`, `mcps/`, `secretary/`, `ops/`, `wallet-studio/`, and more). Enumerating prefixes guarantees a recurring tail of "add another prefix" plans.

This plan replaces the prefix-whitelist model with a resolution-root flip. When a plan's frontmatter declares `concern: work`, Orianna's default resolution root for every path-shaped token becomes `~/Documents/Work/mmp/workspace/`. The opt-back list — the small, stable set of prefixes that always resolve against this repo regardless of concern — is made explicit and short: `agents/`, `plans/`, `scripts/`, `assessments/`, `architecture/`, `.claude/`, `secrets/`, and the individual files `tools/decrypt.sh` and `tools/encrypt.sh`. (Bare `tools/` is NOT on the opt-back list, because the ADRs cite `tools/demo-studio-v3/...` which lives in workspace.) A plan with `concern: personal` or no `concern:` field keeps the existing two-repo routing unchanged — this is a work-concern-only reframing.

The change spans three lockstepped surfaces that must agree: `agents/orianna/claim-contract.md` §5 (doc), `scripts/fact-check-plan.sh` `route_path` (bash fallback), and `agents/orianna/prompts/plan-check.md` Step C (claude-cli path). A single xfail regression test asserts three invariants across the flip.

Open verification note: §5 of the contract currently enumerates two repo blocks and a later follow-on plan (precedent) extends it with three work-prefixes. The spec below treats §5 as-of-main at the moment Talon starts; if the precedent lands first, Talon rebases on top of it and replaces (rather than adds to) the concern-aware prefix block.

## Tasks

1. **kind:** test (xfail, committed first per Rule 12)
   **estimate_minutes:** 25
   **files:** `scripts/test-fact-check-concern-root-flip.sh` (new) <!-- orianna: ok -->
   **detail:** Regression test asserting the resolution-root flip. Four subcases. Subcase one — plan with `concern: work` and a token `tools/demo-studio-v3/session_store.py`. Expected (post-impl): resolves against `~/Documents/Work/mmp/workspace/tools/demo-studio-v3/session_store.py` and passes `test -e` (the real file exists). Subcase two — plan with `concern: work` and a token `agents/sona/memory/sona.md`. Expected: the opt-back list keeps this resolving against this repo, and passes because the file exists here; the test explicitly greps the generated report to confirm the anchor-text references the strawberry-agents path, not the workspace path. Subcase three — plan with `concern: work` and a token `any/unknown/nested/path.py` where the file does not exist in workspace. Expected: a `block` finding is emitted whose anchor-text names the workspace root, proving the default root flipped. Subcase four — plan with `concern: personal` and a token `apps/bee/server.ts`. Expected: behavior unchanged from today (route to strawberry-app per current §5), no regression. Initial commit marks all four subcases xfail; Talon flips them to pass in the impl commit.
   **DoD:** test script exists, is executable, prints `XFAIL: orianna-concern-root-flip` on stdout, exits 0 pre-impl, and is referenced in the impl commit message. <!-- orianna: ok -->

2. **kind:** impl
   **estimate_minutes:** 35
   **files:** `scripts/fact-check-plan.sh`
   **detail:** Introduce a constant `WORK_CONCERN_ROOT="${WORK_CONCERN_ROOT:-$HOME/Documents/Work/mmp/workspace}"` alongside the existing `STRAWBERRY_APP` constant (renaming any `WORK_CONCERN_REPO` left behind by the precedent plan to the new name, or keeping the old name as an alias). In `route_path()`, when `$PLAN_CONCERN = "work"`, apply the new logic in this order. First, check an opt-back list of prefixes that always resolve against this repo: `agents/`, `plans/`, `scripts/`, `assessments/`, `architecture/`, `.claude/`, `secrets/`, and the exact file tokens `tools/decrypt.sh`, `tools/encrypt.sh`. Tokens matching any opt-back entry resolve against the strawberry-agents working tree. Second, every other path-shaped token resolves against `$WORK_CONCERN_ROOT`. Drop the earlier prefix-whitelist branch entirely — it is subsumed by the root flip. The existing missing-checkout warn finding continues to name whichever root was expected. When `$PLAN_CONCERN` is not `"work"`, behavior is identical to the pre-flip code path: the original two-repo routing applies.
   **DoD:** `bash scripts/test-fact-check-concern-root-flip.sh` passes (four subcases flipped from xfail to pass); `bash scripts/test-fact-check-false-positives.sh` still passes unchanged; running `scripts/fact-check-plan.sh plans/proposed/work/2026-04-20-managed-agent-lifecycle.md` drops block findings on all `tools/demo-studio-v3/*` and `company-os/*` tokens.

3. **kind:** impl (prompt)
   **estimate_minutes:** 15
   **files:** `agents/orianna/prompts/plan-check.md`
   **detail:** Rewrite the Step C routing bullet under `concern: work` to match the new model. Replace the prefix-whitelist language with the root-flip language. State plainly that for `concern: work` plans, every path-shaped token resolves against the work monorepo at `~/Documents/Work/mmp/workspace/` by default; list the opt-back prefixes (the same set as the bash fallback) as the single exception. Keep the personal / unlabeled path description unchanged. Run a read-through to confirm the bash fallback and the LLM prompt describe identical behavior.
   **DoD:** Step C names the resolution-root flip explicitly, enumerates the opt-back list once, and makes no reference to `apps/`, `dashboards/`, or `.github/workflows/` as work-concern prefixes (they are no longer special once the root flips).

4. **kind:** doc
   **estimate_minutes:** 15
   **files:** `agents/orianna/claim-contract.md`
   **detail:** Rewrite §5 "Repo routing rules" around the concern-based resolution root. Section structure: (one) when frontmatter is `concern: work`, the default resolution root for every path-shaped token is `~/Documents/Work/mmp/workspace/`; the opt-back list enumerates the strawberry-agents infra prefixes that continue to resolve here (`agents/`, `plans/`, `scripts/`, `assessments/`, `architecture/`, `.claude/`, `secrets/`, `tools/decrypt.sh`, `tools/encrypt.sh`). (two) when frontmatter is `concern: personal` or no `concern:` field is present, the existing strawberry-agents + strawberry-app two-repo routing applies as described pre-change. (three) unknown-prefix behavior is preserved: for `concern: work`, any path not matching the opt-back list flows into the workspace root and is checked with `test -e` — a miss is a block finding, not an info finding. For non-work plans, the unknown-prefix info finding rule is unchanged. Note explicitly that bare `tools/` is NOT on the opt-back list because work-concern plans cite `tools/demo-studio-v3/*` which lives in workspace; only the two specific helper files inside `tools/` are opted back. Do not bump `contract-version` — the behavior for non-work plans is unchanged; `orianna_gate_version: 2` already covers this.
   **DoD:** §5 reads as a resolution-root rule with an opt-back list; the opt-back list enumeration in §5 matches exactly the list in `scripts/fact-check-plan.sh` and in `agents/orianna/prompts/plan-check.md`; `grep "resolution root" agents/orianna/claim-contract.md` returns at least one hit.

## Test plan

Invariants to protect:

- **I1 — Work-concern root flip.** A plan with `concern: work` and a token `tools/demo-studio-v3/session_store.py` resolves against `$WORK_CONCERN_ROOT/tools/demo-studio-v3/session_store.py` (the real file at `~/Documents/Work/mmp/workspace/tools/demo-studio-v3/session_store.py`) and the fact-check emits no block finding on that token. Asserted by subcase one of `scripts/test-fact-check-concern-root-flip.sh`. <!-- orianna: ok -->
- **I2 — Opt-back list keeps strawberry-agents infra local.** A plan with `concern: work` and a token `agents/sona/memory/sona.md` resolves against the strawberry-agents working tree, not the workspace root. Anchor-text in the generated report names the strawberry-agents path. Asserted by subcase two. This invariant is the whole reason the opt-back list exists — without it, every work-concern plan would lose the ability to cite agent memory, plan files, and helper scripts.
- **I3 — Default root for work plans is workspace, not strawberry-agents.** A plan with `concern: work` citing `any/unknown/nested/path.py` (not on the opt-back list, not present in workspace) emits a block finding whose anchor-text names the workspace root as the expected location. This proves the flip happened at the root level, not just for a handful of whitelisted prefixes. Asserted by subcase three.
- **I4 — Backward compatibility for non-work plans.** A plan with `concern: personal` and a token `apps/bee/server.ts` continues to route to strawberry-app per the pre-flip §5 rules; the existing `scripts/test-fact-check-false-positives.sh` continues to pass unchanged. Asserted by subcase four and by the unchanged legacy test.

Test runner: `bash scripts/test-fact-check-concern-root-flip.sh` <!-- orianna: ok -->. Modeled on `scripts/test-fact-check-false-positives.sh` for PASS/FAIL tally style and REPORT_DIR handling. The runner sets `WORK_CONCERN_ROOT` to a fixture path in a temp dir for subcase three to make the "missing file in workspace" assertion deterministic across machines, and unsets any override for subcases one, two, and four so they exercise the real `$HOME/Documents/Work/mmp/workspace/` root (or skip subcase one with a clear message if that root is absent on the current machine — do not silently pass).

Out of scope: touching the four failing ADRs themselves; changing `orianna_gate_version` or `contract-version`; altering allowlist behavior; adding further opt-back entries beyond the list above (future additions arrive via a small patch plan when a load-bearing infra path is missing).
