# sys.path.append (not sys.path.insert) for sibling-package wiring

**Date:** 2026-04-24
**Severity:** high
**last_used:** 2026-04-24

## What happened

Viktor's company-os PR #32 used `sys.path.insert(0, ...)` to wire the `config_mgmt_client` sibling package. Senna flagged it as a correctness landmine: `sys.path.insert(0, ...)` makes the sibling package shadow the owning package on all name lookups, including for modules from the owning package's other submodules.

## The rule

For sibling-package path wiring (adding a non-installed package to `sys.path` so it can be imported), use **`.append`**, not `.insert(0, ...)`.

```python
import sys, os
sys.path.append(os.path.join(os.path.dirname(__file__), "../config_mgmt_client"))
```

**Why `insert(0, ...)` is wrong:**
- It places the sibling at the front of `sys.path`, ahead of the owning package.
- Any module in the sibling package with the same name as a module in the owning package shadows the owning-package version.
- The shadow is silent: unit tests pass (they only import the leaf module they care about), but any code path that imports through the owning package's `__init__` hits the wrong module and fails with a cryptic `AttributeError` or `ImportError`.

**Why `importlib.util.spec_from_file_location` doesn't work here:**
- It works for leaf imports (a single file with no dependencies).
- If the target module has transitive imports through its package's other modules (e.g., `config_mgmt_client` calls `from .base import BaseClient`), those relative imports fail because the package is not on `sys.path`.
- Conclusion: `importlib` is only viable for self-contained single-file modules.

## Shadow-landmine severity

**Tests pass, production fails.** The failure surface is:
- Any call path that imports through the owning package's namespace rather than directly through the sys.path-appended sibling.
- Failure mode: `AttributeError: module '<name>' has no attribute '<method>'` — often looks like a version mismatch, not an import shadowing.

## Review signal

When a PR introduces `sys.path.insert(0, ...)` for a sibling-package import, treat this as a REQUEST CHANGES item unless the submitter can demonstrate that the sibling has no name collisions with the owning package.
