---
name: Avoid XPASS in TDD stubs
description: When writing xfail TDD tests, assert something that only the new implementation provides — not behavior that already exists
type: feedback
---

When writing @pytest.mark.xfail TDD stubs, every test must actually fail against the current code. If existing behavior already satisfies an assertion, the test will XPASS and the suite reports it as unexpected. Fix by adding an assertion that only the new implementation can satisfy (e.g., a new response field like `stopped: True`, or a renamed element like `stopBtn` instead of `archiveBtn`).

**Why:** First run of test_stop_and_archive.py had 3 XPASS because tests 2, 3, and 10 matched existing behavior. Had to tighten assertions.

**How to apply:** Before marking a test xfail, mentally verify: "does this assertion fail against the current code?" If unsure, run it without xfail first.
