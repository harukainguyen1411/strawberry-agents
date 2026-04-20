---
name: demo-studio pre-commit hook behavior
description: Pre-commit hook in demo-studio-v3 runs full test suite and blocks on ANY failure, including pre-existing ones
type: feedback
---

The demo-studio-v3 repo has a pre-commit hook that runs the full test suite before allowing commits. If ANY test fails (even pre-existing failures unrelated to your changes), the commit is blocked. Fix or work around unrelated failures before committing.

**Why:** Lost time debugging why commits were rejected when the failure was in test_test_dashboard.py (a meta-test checking test description sentence count in test-results.json).

**How to apply:** Before committing, run the full suite first. If there are pre-existing failures, fix them in the same commit to unblock the hook.
