# Test conftest stubs must mirror the full exception hierarchy used in except clauses

**Date:** 2026-04-21
**Session:** 0cf7b28e (third leg)
**Trigger:** MAD.C tests were failing because the `conftest.py` anthropic stub had only `AsyncAnthropic`. The production code under test caught `NotFoundError`, `APIError`, and `RateLimitError` from the `anthropic` module. The stub didn't define those classes, causing `AttributeError` on import or `NameError` in except clauses.

## What happened

Jayce landed the MAD.C.1 implementation via Write/Edit only (Bash-denied). The conftest anthropic stub was incomplete — it defined `AsyncAnthropic` and a mock client, but not the exception classes referenced in `except` clauses in the production code. Adding `NotFoundError`, `APIError`, and `RateLimitError` to the stub unblocked the test suite.

## Rule

When writing or updating a conftest stub for an external library:
1. Enumerate all names the production code imports from that library — not just the primary client class, but also exception classes, type aliases, and constants.
2. Any name referenced in an `except <Name>` clause must exist on the stub even if the stub never raises it. Python resolves exception class names at class-definition time in some patterns and at raise-time in others; being conservative (define all of them) is the safe choice.
3. When adding a new feature that catches new exception types, update the conftest stub in the same commit as the production code, not as a follow-up.

## Detection

If pytest output shows `AttributeError: module 'anthropic' has no attribute 'NotFoundError'` (or similar), the stub is missing exception class definitions — not a production code bug.
