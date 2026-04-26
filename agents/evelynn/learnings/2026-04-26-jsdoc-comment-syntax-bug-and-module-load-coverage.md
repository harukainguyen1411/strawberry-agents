# JSDoc comment-syntax bug and module-load coverage gap

**Date:** 2026-04-26
**Session:** 9c8170e8-221a-4350-97cb-aad8c9907db1 (Leg 6)
**Topic:** Regression test design — comment-syntax bugs and module-import coverage

## What happened

Senna's review of PR #93 (T.P2.3 decision-rollup fidelity) caught a production-fatal bug that CI did not surface:

`tools/retro/lib/sources.mjs:9` had a JSDoc comment block that contained `*/` as part of a path-glob pattern (`agents/*/memory/...`). The `*/` sequence prematurely terminated the multi-line comment, leaving `memory is not defined` as a bare reference, producing:

```
ReferenceError: memory is not defined
```

at module load time. The module was broken for any caller that imports it.

CI was green because the test suite used static fixture tests that never actually imported `sources.mjs`. The broken module was never executed in the test harness.

## Lessons

1. **Comment-syntax bugs require import-execution probes, not just static fixture tests.** A test that asserts on fixture data can pass even when the module-under-test cannot be imported. The only way to catch module-load errors is to run a test that actually `import`s the module (even if it only checks that the import succeeds).

2. **When writing regression tests for module-level code changes, include at least one test that exercises the import path.** A minimal smoke: `import { someExport } from './sources.mjs'; assert(typeof someExport !== 'undefined')`.

3. **JSDoc path globs are a comment-terminator trap.** Any `*/` sequence inside a `/* ... */` comment block ends the comment. Path globs (`agents/*/memory/`, `**/*.md`) cannot appear verbatim inside `/* */` comments. Fix: use `//` single-line comments for documentation that includes glob patterns, or escape the asterisk in the prose (e.g. write `*\/` or `[*]/`).

4. **CI green does not mean module-load clean.** When a PR modifies modules that are imported at runtime but tested via static fixtures, flag this pattern to the reviewer. Senna's code review caught it; the automated gate did not.

## When to apply

Whenever delegating implementation of a module that has both: (a) changed syntax in the source (comments, string literals, template literals) AND (b) test fixtures that don't import the module directly. Require the PR author or a follow-up Talon dispatch to add an import-smoke test.
