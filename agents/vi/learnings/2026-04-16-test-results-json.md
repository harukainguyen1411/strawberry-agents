---
name: test-results.json must be staged with commits
description: Pre-commit hook reads test-results.json — stale cached data causes failures; always stage it alongside test file changes
type: feedback
---

The demo-studio-v3 pre-commit hook runs the full test suite and reads test-results.json for metadata checks (e.g., 2-sentence description requirement). If test-results.json is stale from a previous run, the hook fails even though the actual tests pass.

**Why:** The conftest_results_plugin writes test-results.json during the test run, but the description check test reads the version on disk which may be from a prior run if not staged.

**How to apply:** Always stage `test-results.json` and `test-run-history.json` alongside test file changes when committing in demo-studio-v3.
