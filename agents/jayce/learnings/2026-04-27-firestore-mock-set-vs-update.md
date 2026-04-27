# Firestore mock: .set(merge=True) vs .update() — test assertion gap

**Date:** 2026-04-27
**Context:** ADR-3 T-merge (`feat/adr-3-seed-fail-loud`)

## Pattern

`session.update_session_status(session_id, status)` in `tools/demo-studio-v3/session.py` uses:

```python
db.collection(SESSIONS).document(session_id).set(
    {"status": status, "updatedAt": firestore.SERVER_TIMESTAMP},
    merge=True,
)
```

Integration tests that mock the Firestore `doc_ref` and check `mock_doc_ref.update.called`
to verify a status write will **silently fail** — `.update()` is never called; `.set()` is.
The behavioral contract ("status field written with value X") is met, but the mock assertion
is over-specified at the method level.

## Fix pattern

When asserting "status was written to Firestore", check BOTH `.update()` AND `.set()`:

```python
# Check .update() path
marked_via_update = False
if mock_doc_ref.update.called:
    for c in mock_doc_ref.update.call_args_list:
        arg = c.args[0] if c.args else c.kwargs.get("data", {})
        if isinstance(arg, dict) and "target_value" in str(arg.get("status", "")):
            marked_via_update = True

# Check .set(..., merge=True) path — used by session.update_session_status
marked_via_set = False
if mock_doc_ref.set.called:
    for c in mock_doc_ref.set.call_args_list:
        arg = c.args[0] if c.args else c.kwargs.get("document_data", {})
        if isinstance(arg, dict) and "target_value" in str(arg.get("status", "")):
            marked_via_set = True

assert marked_via_update or marked_via_set
```

## Why this matters

xfail tests written before impl may correctly describe the behavioral contract
but over-specify the mock method. After T-impl lands and xfail markers are removed,
the test will fail even though the implementation is correct. The T-merge step
is the right place to catch and fix this, not the xfail test itself (which was
written without knowing the impl's internal choice of Firestore write method).
