---
date: 2026-04-25
created: 2026-04-25
concern: work
status: approved
author: karma
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: true
---

# PR #32 RUNWAY E2E blockers — F1 wrong factory_bridge import, F2 .env.local baked into image

## Context

Two production blockers verified by Akali QA + Sona on PR #32 (`feat/demo-studio-v3`,
HEAD `ab51372`, repo missmp/company-os). Both are config/wiring fixes. Single PR is fine.

**F1 — wrong factory_bridge module imported.** In `tools/demo-studio-v3/tool_dispatch.py` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
the `_default_trigger_build` closure (line 127) does `import factory_bridge` and calls
`factory_bridge.trigger_factory(session_id)`. v1 is a scaffold whose body short-circuits
when `session["status"] != "approved"` (no UI route reaches that state in the v3 flow)
and whose `factory_client.start_build` is an unimplemented `TODO(BD.F.2)`. v2 lives
alongside at `tools/demo-studio-v3/factory_bridge_v2.py` and is fully wired (calls <!-- orianna: ok -- cross-repo path in missmp/company-os -->
`factory_client_v2.start_build`, persists `buildId`/`projectId` to the session doc).
v2 signature: `async def trigger_factory_v2(session_id: str, project_id: str | None = None)`
— drop-in compatible with the existing single-arg call shape. Fix is a one-line import
flip + symbol rename. No adapter needed.

`main.py` already migrated to v2 at the call site (line 2737 calls
`factory_bridge_v2.trigger_factory_v2(...)`); only `tool_dispatch.py` was missed in
that migration. `main.py` lines 87-88 still carry dead `import factory_bridge` /
`from factory_bridge import trigger_factory` lines — clean those in the same PR.

**F2 — `.env.local` baked into the prod Docker image.** `tools/demo-studio-v3/main.py` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
line 5 calls `load_dotenv(".env.local", override=False)`. The file
`tools/demo-studio-v3/.env.local` exists in the repo with `S5_BASE=http://localhost:8090`
on line 20. The Dockerfile's `COPY` ships it into the image because
`tools/demo-studio-v3/.dockerignore` (verified at `ab51372`) lists only `.env`,
`.agent-ids.env`, `__pycache__`, `*.pyc`, `.git` — `.env.local` is NOT excluded. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
Result: in prod, `os.getenv("S5_BASE")` returns `http://localhost:8090`, the iframe
in `session.html` points to localhost, preview never loads.

Fix shape: add `.env.local` and `.env.*.local` to `.dockerignore`. **No `--set-env-vars`
change needed** — `main.py:2363` already falls back to `PREVIEW_URL` when `S5_BASE` is
unset (`os.getenv("S5_BASE") or os.getenv("PREVIEW_URL", "")`), and `PREVIEW_URL` is
already wired in `tools/demo-studio-v3/deploy.sh` line 37 as
`https://demo-preview-4nvufhmjiq-ew.a.run.app`. Once `.env.local` is excluded from the
image, the fallback chain produces the correct prod URL with zero deploy-script change.

**F2 sequencing note:** the `.dockerignore` change does not take effect until the next
image build + redeploy. RUNWAY E2E re-verification must happen post-redeploy.

## Rule 13 (regression test policy)

Both fixes are bug fixes confirmed in QA → Rule 13 requires a regression test in the
same branch. F1 is partially covered by the existing
`tools/demo-studio-v3/tests/test_pr32_hotfix_imp1_imp2.py::test_s1_no_dead_v1_factory_branch_in_source` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
which asserts on `main.py` source only — extend coverage to `tool_dispatch.py` and add
a `.dockerignore` assertion for F2.

Rule 12 (xfail-first) does not apply: these are not net-new feature work for a
TDD-enabled service; they are config/wiring fixes to an existing flow.

## Tasks

### T1. F1 fix — flip tool_dispatch.py to factory_bridge_v2

- Kind: bugfix
- Estimate_minutes: 5
- Files: `tools/demo-studio-v3/tool_dispatch.py` (lines 125-130). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- Detail: in `_default_trigger_build`, replace `import factory_bridge` with
  `import factory_bridge_v2` and replace
  `factory_bridge.trigger_factory(session_id)` with
  `factory_bridge_v2.trigger_factory_v2(session_id)`. Update the docstring
  reference from `factory_bridge` to `factory_bridge_v2`.
- DoD: file imports `factory_bridge_v2` only; no remaining `factory_bridge` reference
  in `tool_dispatch.py`; existing tests in `tools/demo-studio-v3/tests/` pass locally.

### T2. F1 cleanup — drop dead v1 imports from main.py

- Kind: refactor
- Estimate_minutes: 3
- Files: `tools/demo-studio-v3/main.py` (lines 87-88). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- Detail: delete `import factory_bridge` and `from factory_bridge import trigger_factory`.
  Leave `import factory_bridge_v2` (line 89) intact. The comment at line 2734
  ("S1: v1 branch ... removed — version is always 2.") can stay as historical context.
- DoD: `grep -n "import factory_bridge\b\|from factory_bridge\b" tools/demo-studio-v3/main.py`
  returns no matches; module still imports cleanly.

### T3. F1 v1-module disposition — leave for follow-up

- Kind: chore
- Estimate_minutes: 2
- Files: none in this PR; documentation only.
- Detail: do NOT delete `tools/demo-studio-v3/factory_bridge.py` in this PR. The file <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  is still referenced by tests
  (`test_factory_bridge_no_translation.py`, `test_phase2_mcp_direct.py`) which assert
  on the absence/shape of certain symbols. After T1+T2 it has zero runtime importers,
  but pulling those test references and the file itself is a separate scoped change.
  Add a TODO line in the v1 module docstring noting "no runtime importers as of
  PR #32 fix; deletion tracked in follow-up".
- DoD: `factory_bridge.py` docstring carries a one-line follow-up note; no other
  changes to the v1 module.

### T4. F2 fix — exclude .env.local family from Docker image

- Kind: bugfix
- Estimate_minutes: 3
- Files: `tools/demo-studio-v3/.dockerignore`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- Detail: append two lines:
  ```
  .env.local
  .env.*.local
  ```
  Do not touch other entries. Verify locally with
  `cd tools/demo-studio-v3 && docker build -t test . && docker run --rm test ls -la /app | grep env` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  to confirm `.env.local` is absent from the image (optional — Akali post-redeploy
  E2E is the canonical verification).
- DoD: `.dockerignore` contains `.env.local` and `.env.*.local`; `.env` line preserved.

### T5. F2 — no deploy.sh change

- Kind: chore
- Estimate_minutes: 1
- Files: none.
- Detail: `tools/demo-studio-v3/deploy.sh` already sets `PREVIEW_URL`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  `main.py:2363` falls back from `S5_BASE` to `PREVIEW_URL`. No `--set-env-vars`
  edit needed. Documenting here so Talon does not over-reach.
- DoD: deploy.sh untouched.

### T6. Regression tests

- Kind: test
- Estimate_minutes: 10
- Files: `tools/demo-studio-v3/tests/test_pr32_hotfix_imp1_imp2.py` (extend) <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  OR a new `tools/demo-studio-v3/tests/test_pr32_runway_f1_f2.py` (Talon's call; <!-- orianna: ok -- prospective path, created by this plan -->
  prefer extending the existing hotfix file for locality).
- Detail: add three asserts:
  1. `tool_dispatch.py` source contains `import factory_bridge_v2` and contains
     `factory_bridge_v2.trigger_factory_v2(`; does NOT contain
     `import factory_bridge\n` or `factory_bridge.trigger_factory(`.
  2. `main.py` source does NOT contain `import factory_bridge\n` and does NOT
     contain `from factory_bridge import trigger_factory`.
  3. `tools/demo-studio-v3/.dockerignore` contains a line matching `.env.local` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
     and a line matching `.env.*.local`.
  Plan ref string: `2026-04-25-pr32-runway-blockers-f1-f2`.
- DoD: three new asserts green locally; existing
  `test_s1_no_dead_v1_factory_branch_in_source` still green.

## Test plan

- **Unit / source asserts (Rule 13).** Three new asserts in T6 protect the invariants:
  - tool_dispatch.py uses factory_bridge_v2 (F1 regression guard)
  - main.py has no dead v1 factory_bridge imports (cleanup guard)
  - .dockerignore excludes the .env.local family (F2 regression guard)
  Run: `cd tools/demo-studio-v3 && pytest tests/test_pr32_hotfix_imp1_imp2.py -q`.

- **No new xfail.** Rule 12 does not apply; these are config/wiring fixes, not
  feature additions to a TDD-enabled service.

- **Post-redeploy E2E (canonical RUNWAY verification).** Akali re-runs the existing
  RUNWAY E2E flow against staging after image rebuild + Cloud Run redeploy. The flow
  already covers: session creation → approval → factory build trigger → preview iframe
  load. Both blockers surface in that flow:
  - F1 surfaces as `factory_bridge.trigger_factory` returning the "approved" guard
    error or never reaching `factory_client.start_build`. After T1, the v2 path runs
    end-to-end with `buildId`/`projectId` persisted to the session doc.
  - F2 surfaces as `window.__s5Base === "http://localhost:8090"` and a broken iframe.
    After T4 + redeploy, `__s5Base` falls back to `PREVIEW_URL`
    (`https://demo-preview-4nvufhmjiq-ew.a.run.app`) and the iframe loads.

- **Sequencing.** Single PR with T1+T2+T3+T4+T6. Merge → image rebuild → Cloud Run
  redeploy → Akali RUNWAY E2E re-run. F2 explicitly does not ship until the redeploy.

## Open questions

None. v2 signature confirmed drop-in compatible. PREVIEW_URL fallback confirmed in
main.py. .dockerignore content confirmed at ab51372.

## References

- PR: https://github.com/missmp/company-os/pull/32 (HEAD ab51372, branch feat/demo-studio-v3)
- Verified files at ab51372:
  - `tools/demo-studio-v3/tool_dispatch.py:125-130` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  - `tools/demo-studio-v3/factory_bridge.py` (v1 scaffold, status==approved guard, TODO BD.F.2) <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  - `tools/demo-studio-v3/factory_bridge_v2.py:19-60` (drop-in compatible) <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  - `tools/demo-studio-v3/main.py:5,87-89,2363,2737` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  - `tools/demo-studio-v3/.env.local:20` (S5_BASE=http://localhost:8090) <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  - `tools/demo-studio-v3/.dockerignore` (5 lines, no .env.local) <!-- orianna: ok -- cross-repo path in missmp/company-os -->
  - `tools/demo-studio-v3/deploy.sh:37` (PREVIEW_URL already set) <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- Related test: `tools/demo-studio-v3/tests/test_pr32_hotfix_imp1_imp2.py` <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- Related test: `tools/demo-studio-v3/tests/test_dotenv_override.py` (T.GAP.2 regression) <!-- orianna: ok -- cross-repo path in missmp/company-os -->

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has clear owner (karma), no unresolved TBD/TODO in gating sections, and six concretely-described tasks with file paths, line numbers, and DoD. F1/F2 are well-scoped config/wiring fixes with verified evidence at HEAD ab51372. Rule 13 regression coverage is satisfied via T6's three source-level asserts extending an existing hotfix test file. Rule 12 non-applicability (config/wiring, not new feature in TDD service) is correctly reasoned. Sequencing (single PR → rebuild → redeploy → Akali RUNWAY E2E) is explicit.
