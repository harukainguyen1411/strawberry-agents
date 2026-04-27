# PR #126 — handle HTTP 422 in config_mgmt_client `_handle_error`

**Repo:** missmp/company-os
**Verdict:** COMMENT (advisory LGTM, no blockers)
**Head SHA:** 8f97da9c9f212894b6ae54ecb9ebb64050d69bd3

## Scope

3-line addition: 422 branch in `_handle_error` mapping FastAPI `detail` array → `ValidationError(detail)`. Restores W3 ADR §D7 ("validation payload surfaces in tool_result content"). Single file + new integration test file.

## Findings

- **Axis A:** 422 branch placed before catch-all `RuntimeError`, does not shadow the 400+VALIDATION_FAILED branch. `ValidationError(detail)` ctor shape matches existing usage (`details: list[dict]`).
- **Axis D NIT:** `resp.json()` at line 59 is unwrapped; prior block at lines 49–53 wraps the same call in `try/except`. Non-JSON 422 bodies (proxy/LB) would raise `json.JSONDecodeError` from inside `_handle_error`. Fix: reuse already-parsed `body` from line 50 (`body.get("detail", [])`).
- **Axis E NIT:** Test file has unused `AsyncMock` and `os` imports.
- **Cross-lane note (Lucian):** Rule 5 — `tools/demo-studio-v3/` is outside `apps/**`, impl commit should use `chore:` not `fix:`.

## What worked

- Re-fetched head SHA before review (Rule 2 reviewer-discipline).
- Cloned PR branch and read `config_mgmt_client.py` + `tool_dispatch.py` directly, not via `gh pr diff`. Verified line numbers from file (Rule 1 phantom-citation guard).
- Traced the T1b assertion to its actual return path in `_handle_set_config` (line 257) — confirmed `validation == _DETAIL_PAYLOAD` (flat list) is correct for the both-calls-422 path, NOT the line-296 dict shape.

## Heuristic

When reviewing a defensiveness pattern (try/except around parsing) extended with a new branch — always check whether the new branch reuses the wrapped-and-handled value or re-invokes the unwrapped call. The latter is a silent regression of the original defensiveness.
