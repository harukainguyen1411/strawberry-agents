# pytest patch target: module-level import vs direct import

Date: 2026-04-23
Context: P1 S3 stream (factory_build.py wiring into main.py)

## Problem

Tests scaffold: `patch("config_mgmt_client.fetch_config", ...)` and `patch("factory_build.run_build_from_config", ...)`.

If `main.py` does `from config_mgmt_client import fetch_config` and then calls `fetch_config(session_id)`, the patch on `config_mgmt_client.fetch_config` does NOT bind — `main.fetch_config` is already bound to the original function object.

## Fix

Import the module, not the function:

```python
import config_mgmt_client as _config_mgmt_mod
import factory_build as _factory_build_mod
```

Then call via module attribute:
```python
_config_mgmt_mod.fetch_config(session_id)
_factory_build_mod.run_build_from_config(...)
```

This way, `patch("config_mgmt_client.fetch_config", ...)` replaces the attribute on the module object, and the caller resolves it at call time — patch binds correctly.

## Exception classes

For exception types in `except` clauses (not for calling), direct imports are fine:
```python
from factory_build import BuildFailed  # OK — used in except clause only
```

## When patch targets module-level attribute directly

If the patch target is `factory_build.WSClient`, that's the `WSClient` attribute on the `factory_build` module object. Since `factory_build.py` does `from ws_client import WSClient`, the attribute `factory_build.WSClient` exists on the module and patch replaces it there — callers inside `factory_build.py` that use `WSClient()` directly pick it up because Python resolves module globals at call time.

## Reusable rule

> Patch where the name is looked up, not where it is defined.
>
> - Caller uses `from X import f` → patch at `caller_module.f`
> - Caller uses `import X; X.f()` → patch at `X.f`
> - Intra-module (same file uses `f()`) → patch at `that_module.f`

## Query param observability: embed in URL string, not via `params=`

Context: W1 (2026-04-23) snapshot_config force flag

If a test asserts `"force=true" in mock_post.call_args.args[0]`, it is checking the raw URL string (first positional arg to requests.post). The `requests` library appends `params={"force": "true"}` to the URL internally, but `call_args.args[0]` captures only the original string passed to the function — not the assembled URL.

Fix: embed query params directly in the URL string when test observability is needed:
```python
endpoint = f"{url}/v1/config?force=true" if force else f"{url}/v1/config"
requests.post(endpoint, ...)
```

The `params=` kwarg is invisible to callers checking `call_args.args[0]`. If you control the implementation (not the test), prefer the direct-URL approach when tests assert URL content.
