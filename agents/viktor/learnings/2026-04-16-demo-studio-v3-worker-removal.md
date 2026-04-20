# 2026-04-16 — Demo Studio v3 Worker Removal (Step 0)

## Context

Refactor task: remove the parallel worker system from demo-studio-v3 entirely. Plan at `company-os/plans/2026-04-16-demo-studio-v3-refactor.md`.

## What was done

- Deleted `workers/` directory (base.py, pool.py, research.py, branding.py, journey.py, passes.py, tokenui.py, __init__.py)
- Deleted `orchestrator.py`
- Removed all worker imports and orchestration code from `main.py` (~420 lines removed)
- Inlined `_firestore_increment` into `config_patch.py` — the function was a single pure helper with no side effects, trivial to copy
- Deleted 9 worker test files
- Added fastapi/uvicorn deps to `demo-factory/requirements.txt` alongside existing deps

## Gotchas

### git stash pop conflict
Ran `git stash` to test pre-existing failures, then `git stash pop` failed because pytest had written to `test-results.json` and `test-run-history.json`. Fix: `git checkout` those two files first, then `git stash pop` succeeds.

### Pre-existing test failure: test_all_test_descriptions_are_at_least_two_sentences
This meta-test in `test_test_dashboard.py` scans all test docstrings and requires at least two sentences. Vi's new TDD tests (test_worker_removal.py, test_agent_prompt_update.py) have single-sentence docstrings, so this test was already failing before the refactor. Not caused by worker removal.

### demo-factory naming conflict
`/company-os/tools/demo-factory/` already had a full factory implementation. When scaffolding a new FastAPI service for Service 3, add `main.py` alongside existing code rather than replacing it. Existing modules (factory.py, apple.py, etc.) are the implementation — the new main.py wraps them.

## Test results after refactor
- `tests/test_worker_removal.py` — 6/6 PASSED
- Broader suite: 408 passed, 1 pre-existing failure (docstring meta-test)
