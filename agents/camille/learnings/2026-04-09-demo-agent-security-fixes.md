# Demo Agent Security Fixes — 2026-04-09

## Context
Jhin's PR review on `feat/demo-agent-system-2026-04-09` flagged six issues in the demo factory pipeline services.

## Fixes Applied

### Pattern: INTERNAL_SECRET for inter-service auth
- Both `/run` (demo-runner) and `/state` (slack-triage) now require `Authorization: Bearer <INTERNAL_SECRET>` header.
- `_post_state()` in demo-runner and `trigger_demo_runner()` in slack-triage both send the header on outbound calls.
- Single env var `INTERNAL_SECRET` shared across all services via the shared `.env` file in `demo-factory/`.
- Add to `.env.example` and `.env` as empty placeholder — operator must fill it.

### Pattern: Fail closed on missing secrets
- `verify_slack_signature()` previously returned `True` when `SLACK_SIGNING_SECRET` was unset (fail open).
- Fixed to return `False` and log a warning — any missing signing secret means reject the request.
- General rule: authentication helpers must fail closed, not open.

### GCS client lifecycle (Go)
- `storage.NewClient()` was called on every `readConfig()` invocation — expensive and leaks connections.
- Fix: declare `gcsClient *storage.Client` as package-level var, initialize once in `main()` when `GCS_BUCKET` is set, and `defer gcsClient.Close()`.
- `readConfig()` now checks `gcsClient == nil` and returns an error rather than panicking.

### Upload ordering (factory.py)
- `upload_config` was called before `create_test_pass` — the config was missing pass data at upload time.
- Moved upload to immediately after `create_test_pass` and `_write_json`.

### Exception handler state
- Pipeline exception handler was posting state `"building"` with raw exception text.
- Fixed to post state `"failed"` with a user-friendly message — never leak internal errors to Slack.
