---
name: Test docstrings must have 2+ sentences
description: demo-studio-v3 enforces minimum 2-sentence descriptions on all tests via test_all_test_descriptions_are_at_least_two_sentences
type: feedback
---

The demo-studio-v3 test suite includes a meta-test that validates all test docstrings have at least 2 sentence-ending punctuation marks. A docstring like "Returns status of all workers (pending, running, complete, or failed)." counts as 1 sentence because the period inside parens doesn't match the regex `[.!?](?:\s|$)`.

**Why:** Enforces descriptive test documentation that explains both what the test checks and why it matters.

**How to apply:** Always write 2-sentence docstrings for tests. First sentence: what the test verifies. Second sentence: what failure means or why it matters.
