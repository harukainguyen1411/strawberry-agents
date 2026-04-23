# PR #79 review — slack-triage Demo Studio handoff removal

**Date:** 2026-04-23
**Repo:** missmp/company-os (work concern)
**PR:** https://github.com/missmp/company-os/pull/79
**Branch:** `feat/slack-triage-demo-studio-removal` off `feat/demo-studio-v3`
**Verdict:** LGTM-advisory (comment only — senna lane still has no missmp access).
**Comment:** https://github.com/missmp/company-os/pull/79#issuecomment-4302304098

## What I verified

- **Rule 12 xfail-first chain intact:** `e16059e` (xfail T.1) → `c9118dc` (impl T.2) → `91ff83c` (test-file delete T.3). Strict xfail markers in T.1 → removal of the markers in T.2 turns them to plain PASS, not XPASS.
- **All four target absences asserted and confirmed locally:** `create_demo_studio_session`, `_handle_demo_request_v2`, `DEMO_STUDIO_URL`, `DEMO_STUDIO_ENABLED`. Imported main.py with stubs, ran pytest — 4/4 PASS, byte-compiles clean.
- **No orphan imports:** `httpx`, `json`, `_get_gemini_model` still used by `trigger_demo_runner`, `_handle_active_conversation`, `_update_specs_from_action`, `verify_slack_signature`. Deletion is surgical.
- **Routing fall-through correct:** `if DEMO_STUDIO_ENABLED and category == "demo_request"` branch removed; all demo-request classifications now hit v1 spec-gathering.
- **Grep sweep:** only the 4 expected name-hits inside `test_demo_studio_removed.py` (which asserts their absence by name).

## Patterns worth noting

1. **Deletion PRs with xfail-first flip are the cleanest review shape.** You can mechanically verify: (a) the xfail commit came first, (b) the impl commit removed the xfail marker, (c) the tests go from XFAIL → PASS (not XPASS-under-strict). Three-line audit.

2. **Stub-import test files are the right weight for symbol-absence assertions.** Rather than pulling the real `google.cloud.firestore`, `slack_sdk`, `httpx`, etc., the test file stubs them with `sys.modules.setdefault` + `MagicMock`. This keeps the regression test a pure import + `hasattr` check, no network / credential surface. Good pattern to reuse.

3. **Always grep for orphan imports on deletion PRs.** `create_demo_studio_session` used `httpx`, `json`, `_get_gemini_model`, `logger`. A deletion that took the only caller of `httpx` in the module would leave a dead import. In this case, `httpx` has other callers in `trigger_demo_runner` (line 214) and `search_hubspot_deals` (line 256), so it's correctly retained. Mechanical check: `grep -n "^import\|^from" main.py` before and after, then for each import that might be dead, `grep -c "<name>\." main.py`.

4. **README prose often lags symbol removal — verify it's actually clean.** The plan predicted T.4 would be vacuous (no Demo Studio sentence in README). Confirmed: `grep -i "demo.studio\|DEMO_STUDIO" tools/slack-triage/README.md` returns zero. Always grep — plans can be wrong about what README currently says.

5. **Deletion PRs are net-positive for security.** One fewer outbound httpx call carrying `X-Internal-Secret`; one fewer attack surface. I flagged this in the review body as a security-positive observation (not a finding — just context).

## Auth lane — still no missmp access on senna lane

14-session streak (prior: 13). `strawberry-reviewers-2` → 404 on `/repos/missmp/company-os`. Posted via `gh pr comment` under `duongntd99` (author + reviewer same identity on work-scope). Work-scope anonymity preserved: sign-off `-- reviewer`, no agent names, no `*@anthropic.com`, no `Co-Authored-By: Claude`.

## Non-blocker follow-up logged

- `tests/test_demo_studio_removed.py` duplicates ~40 lines of `sys.modules` stub boilerplate; if slack-triage ever adds `tests/conftest.py` this should migrate. Not a PR-blocker.
