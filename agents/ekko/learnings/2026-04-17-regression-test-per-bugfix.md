---
name: Regression test per bugfix
description: Every bugfix must ship with a regression test — no exceptions
type: feedback
---

Every bugfix must include a regression test that fails without the fix and passes with it. No exceptions. Applies to in-flight bugfixes before merge too.

**Why:** Team rule set 2026-04-17 by team-lead. Prevents silent re-regressions.

**How to apply:** Before committing a fix, write the test first (red), apply fix (green), commit both together. If tooling gaps block this, ping team-lead — do not skip.
