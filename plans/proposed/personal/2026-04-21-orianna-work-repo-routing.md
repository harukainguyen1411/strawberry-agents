---
title: Orianna claim-contract — work-concern repo routing
status: proposed
owner: karma
created: 2026-04-21
date: 2026-04-21
concern: personal
complexity: quick
orianna_gate_version: 2
tags: [orianna, claim-contract, routing, work-concern, infra]
tests_required: true
architecture_impact: none
---

## Context

Four work-concern ADRs are about to be migrated into `plans/proposed/work/`. Their path-shaped backticks cite paths inside the work data repo at `~/Documents/Work/mmp/workspace/company-os/` (for example `apps/demo-studio/backend/session_store.py` <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim -->). Orianna's current claim-contract (`agents/orianna/claim-contract.md` §5) and bash fallback (`scripts/fact-check-plan.sh` `route_path`) route apps/ <!-- orianna: ok -- directory prefix token --> and .github/workflows/ <!-- orianna: ok -- directory prefix token --> exclusively to the strawberry-app checkout. Every work-concern plan will therefore fail the proposed → approved gate on the first `test -e` until routing learns about a third repo root.

This plan extends the claim-contract with a concern-aware routing layer: when the plan's frontmatter carries `concern: work`, apps/ <!-- orianna: ok -- directory prefix token, not a path existence claim -->, dashboards/ <!-- orianna: ok -- directory prefix token, not a path existence claim -->, and .github/workflows/ <!-- orianna: ok -- directory prefix token, not a path existence claim --> resolve against `~/Documents/Work/mmp/workspace/company-os/` instead of strawberry-app. Default behavior is unchanged — plans without `concern: work` (including `concern: personal` and legacy plans without the field) keep the existing two-repo routing. The LLM prompt (`agents/orianna/prompts/plan-check.md` Step C routing bullet) is updated in lockstep so both the claude-cli path and the bash fallback behave identically.

Scope is deliberately narrow: one script, one prompt, one contract doc, one xfail regression test. No new claim categories, no allowlist changes, no signature-format changes.

## Tasks

1. **kind:** test (xfail, committed first per Rule 12)
   **estimate_minutes:** 15
   **files:** `scripts/test-fact-check-work-concern-routing.sh` (new) <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim -->
   **detail:** Regression test asserting concern-aware routing. Create a scratch plan with `concern: work` frontmatter and a backtick token `apps/demo-studio/backend/session_store.py` <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim -->. Run `fact-check-plan.sh` against it. Expected (post-impl): token routes to the work-concern checkout root (`$WORK_CONCERN_REPO`, default `~/Documents/Work/mmp/workspace/company-os`), not `$STRAWBERRY_APP`. Also assert the negative case: an identical plan with `concern: personal` still routes apps/ <!-- orianna: ok -- directory prefix token, not a path claim --> to `$STRAWBERRY_APP` (backward compatibility). The initial commit marks the test xfail (grep for `XFAIL:` banner or `exit 0` with a skip note referencing this plan slug). Talon flips xfail → pass in the implementation commit.
   **DoD:** test script exists, is executable, prints `XFAIL: orianna-work-repo-routing` on stdout, exits 0, and is referenced in the implementation commit message. <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim -->


2. **kind:** impl
   **estimate_minutes:** 25
   **files:** `scripts/fact-check-plan.sh`
   **detail:** Step 1 — add WORK_CONCERN_REPO variable <!-- orianna: ok -- shell variable assignment prose, not a path claim --> next to the existing STRAWBERRY_APP constant. Step 2 — parse the plan's YAML frontmatter for a `concern:` field (simple `sed`/`awk` between the first two `---` lines — no full YAML parser). Store in a shell variable `PLAN_CONCERN`, default empty string. Step 3 — in `route_path()`, when `PLAN_CONCERN = "work"`, route apps/* <!-- orianna: ok -- glob pattern in routing description, not a filesystem claim -->, dashboards/* <!-- orianna: ok -- glob pattern in routing description, not a filesystem claim -->, and .github/workflows/* <!-- orianna: ok -- glob pattern in routing description, not a filesystem claim --> to `$WORK_CONCERN_REPO` instead of `$STRAWBERRY_APP`. All other branches unchanged. Step 4 — extend the cross-repo checkout-missing warn finding to name whichever repo root was expected (strawberry-app vs work-concern) so the author can see which checkout is absent.
   **DoD:** `bash scripts/test-fact-check-work-concern-routing.sh` passes (xfail flipped to pass in this commit); `bash scripts/test-fact-check-false-positives.sh` still passes unchanged (backward-compat guard). <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim -->

3. **kind:** impl (prompt)
   **estimate_minutes:** 10
   **files:** `agents/orianna/prompts/plan-check.md`
   **detail:** In Step C routing bullet list, add a sub-bullet under the apps/ <!-- orianna: ok -- directory prefix token in prose, not a path claim -->, dashboards/ <!-- orianna: ok -- directory prefix token in prose, not a path claim -->, .github/workflows/ <!-- orianna: ok -- directory prefix token in prose, not a path claim --> entry: "If the plan's frontmatter has `concern: work`, route these prefixes to the work-concern checkout instead. Missing checkout emits the same `warn` finding, named against the work-concern path." Keep wording concise — the bash fallback and the LLM path must agree.
   **DoD:** LLM and bash describe identical routing; the added sub-bullet references `concern: work` explicitly.

4. **kind:** doc
   **estimate_minutes:** 10
   **files:** `agents/orianna/claim-contract.md`
   **detail:** §5 "Two-repo routing rules" is renamed "Repo routing rules" and gains a third section listing the work-concern repo root, with explicit note that the third root only activates when the plan frontmatter declares `concern: work`. Add one paragraph at the end of §5 explaining the default-safe behavior: plans without the field (or with `concern: personal`) keep the original two-repo routing. Do not bump `contract-version` — this is a compatible extension of an existing rule, not a breaking change; `orianna_gate_version: 2` covers it.
   **DoD:** §5 describes three repo roots and the concern-based toggle; contract-version unchanged; `rg "concern: work" agents/orianna/claim-contract.md` returns at least one hit.

## Test plan

Invariants to protect:

- **I1 — Work-concern routing activates only when declared.** A plan with `concern: work` and a token `apps/demo-studio/backend/session_store.py` <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim --> routes the `test -e` against `$WORK_CONCERN_REPO`, not `$STRAWBERRY_APP`. Asserted by `scripts/test-fact-check-work-concern-routing.sh` positive case. <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim -->
- **I2 — Backward compatibility.** A plan with `concern: personal` (or no `concern:` field at all) continues to route apps/* <!-- orianna: ok -- glob pattern in routing description, not a filesystem claim --> to `$STRAWBERRY_APP`. Asserted by `scripts/test-fact-check-work-concern-routing.sh` negative case <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim --> AND by the unchanged `scripts/test-fact-check-false-positives.sh` continuing to pass.
- **I3 — Missing-checkout warn finding names the right repo.** When the routed repo root directory is absent, the emitted warn finding's anchor-text includes the repo root path (strawberry-app or work-concern) so the author can diagnose which checkout to restore. Asserted by a third case in the new test that unsets `WORK_CONCERN_REPO` to a nonexistent dir and greps the report for the expected path.

Test runner: `bash scripts/test-fact-check-work-concern-routing.sh` <!-- orianna: ok -- cross-repo work-concern path or test-script reference; not a strawberry-agents filesystem claim --> — modeled on `scripts/test-fact-check-false-positives.sh` (same PASS/FAIL tally style, same REPORT_DIR handling).

Out of scope for this plan: updating orianna-fact-check.sh <!-- orianna: ok -- script reference; file does not exist and is not claimed to exist --> LLM-path wrapper (the prompt change in Task 3 is sufficient — the wrapper just dispatches the prompt); any reconciliation of pre-existing work-concern plans already in plans/proposed/work/ <!-- orianna: ok -- directory path token, not a file existence claim --> (none exist yet — this plan lands before the migration).

## Architecture impact

None — this plan edits `scripts/fact-check-plan.sh`, `agents/orianna/prompts/plan-check.md`, and `agents/orianna/claim-contract.md` only. No architecture docs change (claim-contract.md is an agent operational doc, not under the architecture directory). No new service integrations, schema changes, or repo structural changes.

## Test results

`bash scripts/test-fact-check-work-concern-routing.sh` — 8 passed, 0 failed (run 2026-04-22, all I1/I2/I3 invariants and additional quoted-YAML and prefix cases verified). `bash scripts/test-fact-check-false-positives.sh` — backward-compat guard also passes unchanged.
