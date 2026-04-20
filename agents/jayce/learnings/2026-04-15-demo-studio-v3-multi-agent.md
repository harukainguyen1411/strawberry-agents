# Demo Studio v3 — Multi-Agent Orchestration Learnings

## asyncio module-level import matters for patching

When a test patches `main.asyncio.create_task`, `asyncio` must be imported at the module level in `main.py` (`import asyncio`), not inside a function scope. Local imports create a local binding that isn't patchable via `patch("main.asyncio.create_task")`.

## sys.path corruption via package directory

Inserting a directory that IS a package (e.g., inserting the parent of `factory/`) into `sys.path` can shadow the package namespace. Symptom: `AttributeError: module 'factory' has no attribute 'config_store'`. Fix: don't put the package's parent on sys.path from within the package; use absolute imports and insert path at the bridge level.

## google.cloud stubs need all sub-modules

When stubbing `google.cloud` in test preambles, also stub `google.cloud.storage` explicitly — importing `factory.config_store` may trigger `from google.cloud import storage` which fails without the stub.

## SSE addEventListener vs onmessage

Custom SSE event types (e.g., `worker_started`) require `eventSource.addEventListener('worker_started', handler)`. The `onmessage` handler only fires for unnamed events. Tests scan JS source for `addEventListener` calls with the event type string.

## git stash pop can pull in other agents' changes

If another agent modified files and stashed them in the same branch, `git stash pop` may pull those changes into your working tree. Always check `git diff --name-only HEAD` after stash pop and restore any files you didn't intend to modify with `git checkout HEAD -- <file>`.

## Pre-commit hooks re-run the full test suite

The demo-studio-v3 pre-commit hook runs the full test suite. If a test added by another agent fails (e.g., `clearAgentStatus` on stopped), the commit will be blocked even if it's not your test. Restore the test file to HEAD before committing.
