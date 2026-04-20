---
name: Check working tree before writing xfail tests
description: If another agent already applied the fix, xfail tests will XPASS — check git diff first to understand current state
type: feedback
---

When writing TDD xfail tests, the working tree may already contain the implementation fix from another agent. Tests that should xfail will instead XPASS.

**Why:** Multiple agents work in parallel on the same branch. By the time Vi writes tests, Ekko or Jayce may have already applied the fix.

**How to apply:** Before writing xfail tests, run `git diff HEAD -- <relevant files>` to check if the fix is already in the working tree. If it is, the tests will XPASS — report this to the lead and ask whether to remove xfail markers.
