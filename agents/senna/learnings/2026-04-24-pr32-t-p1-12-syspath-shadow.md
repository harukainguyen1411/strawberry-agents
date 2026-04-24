# PR #32 T.P1.12 delta review — `sys.path.insert(0, ...)` shadowing lesson

**Date:** 2026-04-24
**Repo:** missmp/company-os
**PR:** #32 (demo-studio-v3 god PR)
**Commit reviewed:** 64eb3623 (Viktor, T.P1.12 wire-up)
**Verdict:** request changes (posted as PR comment via duongntd99 per work-scope protocol)
**Review URL:** https://github.com/missmp/company-os/pull/32#issuecomment-4312670667

## The big find — sibling-package sys.path shadowing

When two siblings under `tools/` share module names (here: `main.py`, `config_mgmt_client.py`, `project.py`), doing `sys.path.insert(0, sibling_path)` inside one sibling's module flips import resolution order for **every subsequent bare import in the same process**.

Concretely in this PR:
- `demo-studio-v3/main.py` line 35 inserts `demo-factory/` at sys.path[0].
- Line 91 then `import config_mgmt_client`.
- Both siblings define that module. After the insert, demo-factory's (S3-side, different API) wins.
- S1's `except config_mgmt_client.ValidationError` (line 1928) and `config_mgmt_client.snapshot_config(...)` (line 1924) become runtime AttributeErrors on any test path that touches them.

The three T.P1.12 tests pass because FACTORY_REAL_BUILD=1 explicitly bypasses the S2 fetch code. But any later test in the same pytest process that hits those branches will fail in surprising ways.

**Safer patterns:**
1. `importlib.util.spec_from_file_location` — imports one specific file without touching sys.path. The fixture `tests/fixtures/ws_client_fault.py` in this same PR already uses this pattern correctly.
2. `sys.path.append(...)` — puts the sibling at the END, so the owning package still wins on name collisions.

## Pattern to check in future reviews

When a review delta contains `sys.path.insert(0, ...)`, always:
1. List sibling files under the inserted directory.
2. Cross-check against imports in the caller module AFTER the insert line.
3. Any name collision = potential silent shadow.

`ls <inserted_dir>/*.py | awk -F/ '{print $NF}' | sort` + `grep -E "^(import|from) " caller.py | ...` is enough.

## Other useful bits from this review

- **Module-level test-fallback stores (here `session._mem_store`) always need an autouse conftest fixture to clear them.** The existing conftest already has this exact pattern for `managed_sessions_list_cache` — point reviewers at existing examples rather than debating whether it's needed.
- **Weakening a fail-fast kwarg signature (required → optional-with-default) for test convenience is a production contract regression.** Almost always the test seed should pass an explicit test-scoped value instead.
- **Scope creep:** a cross-service prod bug fix stapled into a feat: commit in a different service. Flag it but don't block on it alone — the fix being correct is what matters; commit-hygiene is a separate concern.
- **Weak failure-path assertions:** `status == "failed"` passes on any exception. Always suggest asserting `failureReason` (or equivalent) to actually exercise the fault-injection contract.

## Work-scope auth protocol reminder

For missmp/* PRs: post as `duongntd99` with `gh pr comment` (NOT `gh pr review`), sign `-- reviewer`. I had to re-run `gh auth switch --user duongntd99` mid-session after a transient identity slip to `harukainguyen1411` (probably from a parallel tool call). The `gh api user --jq .login` preflight caught it. Keep that preflight.

## Rule compliance spot-checks confirmed

- Rule 12 (xfail precedes impl, same branch): d5eb1d59 added xfail file on feat/demo-studio-v3 → 64eb3623 removes xfails + wires impl. Same branch. Correct ordering.
- Rule 18(a): PR has no required checks configured (empty statusCheckRollup). Vacuously satisfied. PR currently CONFLICTING against main, but that's a merge-queue concern not a code-quality one.
- FACTORY_REAL_BUILD=0 production path: unchanged, falls through to existing HTTP call. Verified.
