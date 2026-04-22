# FastAPI Dependant graph contamination via patch-then-import

**Date:** 2026-04-22
**Session:** eleventh leg (2026-04-22-0cf7b28e)
**Context:** Writing integration tests for `demo-studio-v3` vanilla chat SSE handshake.

## The trap

When you do this in a test:

```python
with patch("auth.require_session_or_internal", return_value=session_id):
    import main as _main  # triggers FastAPI route registration
```

FastAPI analyzes the `Depends(require_session_or_internal)` at route-registration time and builds a cached Dependant graph. Under the patch, `require_session_or_internal` is a `MagicMock`. MagicMock's default signature is `*args, **kwargs`, so FastAPI records the route as needing query parameters named `args` and `kwargs`.

That graph is cached on `app.routes[i].dependant`. Unpatching later does NOT re-analyze. Subsequent real requests hit the cached graph and get:

```
422 Unprocessable Entity: [{"loc":["query","args"],"msg":"field required"},
                          {"loc":["query","kwargs"],"msg":"field required"}]
```

The failure mode is silent — the request doesn't even reach your handler. The 422 looks like a validation error, not a dependency-injection bug.

## The fix pattern

Autouse fixture that re-imports `main` after every test without any active patches:

```python
def _restore_clean_main():
    for mod in list(sys.modules.keys()):
        if mod in ("main", "agent_proxy"):
            del sys.modules[mod]
    import main as _main  # side effect: rebuild Dependant graph against real deps

@pytest.fixture(autouse=True)
def _restore_main_after_test():
    yield
    _restore_clean_main()
```

Inside each test, use `app.dependency_overrides` rather than (or in addition to) the `patch` block — `dependency_overrides` is how FastAPI expects you to swap Dependant bindings at test time:

```python
async def _bypass():
    return session_id

_main.app.dependency_overrides[_auth_mod.require_session_or_internal] = _bypass
```

## Generalization

Any library that analyzes function signatures at registration time (FastAPI's Depends, Typer's option introspection, Click's params auto-detection, Pydantic's validator registration) will cache results against whatever signature it sees at that moment. Patching the function BEFORE registration contaminates the cache. The `patch` context manager only reverts the object binding, not any cache the library built while the patch was active.

**Heuristic:** if a library uses `inspect.signature()` at import/registration time, patching before import creates cache contamination. Either (a) patch after registration using the library's official override surface, or (b) tear down and rebuild the cache after the patch exits.

## Anchors

- Source: `tools/demo-studio-v3/tests/test_chat_sse_handshake.py` — `_restore_clean_main` + `_restore_main_after_test` autouse fixture.
- Plan: `plans/proposed/work/2026-04-22-chat-sse-deadlock-fix.md`.
