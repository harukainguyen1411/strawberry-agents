# PR #64 Local Manual Testing — Feedback

**Branch:** `fix/akali-qa-bugs-2-3-4` (missmp/company-os PR #64)
**Worktree:** `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-fix-bugs-234`
**Date:** 2026-04-21
**Tester:** Duong

## Running services

- Demo Studio v3: http://localhost:8082
- S5 Preview: http://localhost:8083
- Dashboard: http://localhost:8082/dashboard
- Stop: `kill 11654 12336` or `pkill -f uvicorn`

## Feedback

<!-- Write freely below. Bug / nit / question / idea — any shape is fine. -->

## Findings from first manual run (auto-recorded)

### Bug 5 — CRITICAL — `/session/{id}/preview` iframe 404
- `static/studio.js:225` still sets `previewFrame.src = '/session/' + sessionId + '/preview'`.
- The S1 preview route was intentionally removed (BD.B.7/B.8 — see `tests/test_preview_deleted_from_s1.py` which asserts 404).
- JS was never updated to point at S5 (`S5_BASE/preview/<id>` or equivalent).
- Result: iframe loads 404 on every session open. S5 fullview "Open in new tab" may still work since it's wired differently; inline iframe does not.
- Owner candidate: Talon (wire studio.js to `window.__s5Base` or inject `S5_BASE` into session page HTML).

### Bug 1 — likely Akali flake, not a real prod outage (per Duong)
Duong's read: Akali's `startup_anthropic_failed: 401` on `00016-5rw` was flaky — prod key in Secret Manager is fine. Recommend dropping Bug 1 as a blocker for PR #64 and re-probing prod chat directly before any key rotation. No rotation action needed until re-probe fails.

### Local chat — HTTP 500 until real key loaded
- `POST /session/{id}/chat` with valid cookie → `500 {"error":"Error code: 401 - authentication_error"}`.
- Expected locally (dummy `ANTHROPIC_API_KEY=sk-ant-dummy-not-real`). Will pass once you rotate the prod key.
- Side note: the endpoint returns the raw Anthropic error body (including `request_id`). Non-prod behavior; in prod Senna already flagged similar leak patterns — worth re-checking the handler wraps this rather than passing through.

### Papercut — `load_dotenv(override=True)` in main.py fights shell env
Exports made at service launch (`BASE_URL`, `MANAGED_AGENT_MCP_INPROCESS`, etc.) get silently overwritten by whatever's in `.env`. Made local reconfiguration painful — Ekko had to monkey-patch `dotenv.load_dotenv` via a bootstrap shim to get a clean local boot. Fix candidates: `load_dotenv(override=False)` (preferred) or drop `load_dotenv` entirely in production entry points and rely on Cloud Run env binding + shell env locally.

### Local dev runbook gap
There is no `tools/demo-studio-v3/README.md` section describing how to boot locally against `demo-studio-staging` Firestore. Today you need to know: `FIRESTORE_DATABASE=demo-studio-staging`, `FIRESTORE_PROJECT_ID=mmpt-233505`, `MANAGED_AGENT_MCP_INPROCESS=1`, `BASE_URL=http://localhost:<port>`, override `.env` precedence, two services (studio + S5 preview). Worth a 30-line runbook.

## Duong feedback below
Does not have an alternative way to create new session from the UI, we can add firebase auth as login for users with missmp account
Dashboard still show old servers (demo studio mcp and wallet studio mcp). Needs to change this to the other 4 services (s2 - s5)

---

ok set, now it will auto compact. Please do pre-save soon after this, you only have 27% left. Here
  is the plan, we ditch the whole managed agent thing. Let's go with Swain plan to build the this
  chat natively. Switch back to coordinator mode, but make sure everything run through the gate now.
  If you get stuck with gh permission, try gh auth switch, there should be account available for
  both orianna admin bypass and access to PR. You have all the secrets and env available to you. Try
  everything you can to make this e2e work. When I wake up, I should be able to see a working
  product: I can chat with the agent, I can configure the project. The preview works, I can build
  with the build service and the verification works. Run QA using playwright mcp to see if it
  actually works, run test etc e2e. Then if you still have capacity, couple things you could fix:
  add firebase auth login as main mechanism of authentication, so @missmp user can just login and
  use the service; fix the dashboard so that it shows 5 services instead of the old ones with mcps
  and managed agents; fix the UI so it looks nicer and smoother with the agent. One critical thing
  to note, you shall not call any tools or change which require approval request, because I would
  not be able to accept it. Route everything through subagents. If it hit a blocker, find a way to
  unblock, don't try to do it yourself. I'll put this into the feedback file. Revisit it from time
  to time to refresh your memory after compact
   Don't try to run everyone in parallel. You have the whole night, the thing that can stop you is
  you running too many subagent and blow up the usage.