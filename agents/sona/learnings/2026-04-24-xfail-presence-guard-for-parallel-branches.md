# Xfail presence guard for parallel xfail+impl branches (2026-04-24)

## Context

W3 config-flow used a complex-lane parallel dispatch: Rakan authored xfails on
`test/w3-config-schema-flip-xfail` while Viktor ran the impl on a separate branch.
The two branches are not merged when either is written. Rakan's xfails import from
the impl module that doesn't exist yet in the xfail branch.

## Pattern observed

Rakan introduced a `_w3_impl_present()` helper that checks whether the impl module
is importable before running the xfail suite. If the impl isn't present, the tests
degrade gracefully (skip or xfail on missing-import, rather than erroring at
collection time). This avoids the alternative failure mode where `pytest` crashes
at collection and blocks CI on the xfail branch.

## The lesson

When dispatching Rakan or Vi to author xfails on a parallel branch that will be
developed alongside (not downstream of) the impl branch:

1. **Use an `_impl_present()` presence guard** at the top of each xfail test file.
   The guard returns `False` when the impl module is not importable; tests that
   depend on it are decorated `@pytest.mark.skipif(not _impl_present(), ...)`.
2. The presence guard means the xfail branch is always CI-green before the impl
   lands — it won't block parallel development or cause false failures in the test
   suite of the xfail-only branch.
3. Once the impl lands and the branches are merged, the guard evaluates `True` and
   the xfails activate.

## Dispatch instruction

Add to Rakan / Vi task prompts for complex-lane parallel dispatch:
> "Your xfail branch will be developed in parallel with the impl branch — they
> will not be merged when you author these tests. Write a `_impl_present()` guard
> that returns True only when the impl module is importable. Gate all test
> functions that import from the impl on this guard so CI stays green on your
> branch before the impl lands."

## last_used
2026-04-24
