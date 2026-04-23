# 2026-04-23 — Loop 2d S3/S4 POST /session grep audit

## Task
T.COORD.3 / T.W0.2 from the firebase-auth-loop2d-slack-removal plan.

## What was audited
Four sibling services in `company-os/tools/`: demo-factory, demo-config-mgmt, demo-preview, demo-dashboard.
Patterns: `requests.post`, `httpx.post`, `fetch(`, `curl`, `"/session"` bare literal, template-string `/session`, `DEMO_STUDIO_URL`, `demo-studio-v3.*session`.

## Finding
Zero callers of `POST /session` (the bare Slack entrypoint). Full detail in plan T.W0.2 block.

Notable non-hits to be aware of:
- `demo-factory/demo_validate.py` has `requests.post` to `WS_BASE` (api.missmp.tech) — not demo-studio.
- `demo-factory/main.py` has `httpx.post` to `S4_VERIFY_URL` (verification service) — not demo-studio.
- `demo-dashboard/dashboard.html` has `fetch(...)` calls to `/sessions` (plural, list endpoint) and `/session/{id}/close` (sub-resource) — both are correct exclusions.

## Grep methodology note
The `for svc in "a b c d"` pattern (space-joined string in quotes) silently treats all 4 as a single service name and matches nothing. Always use `for svc in a b c d` (unquoted, space-separated) or an array. Caught this on first attempt.
