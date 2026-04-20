# TDD discipline with subagents

When using Caitlyn/Vi for test writing and Ekko/Jayce for implementation:

1. **Never dispatch the builder until the test is confirmed failing.** Multiple times this session, a builder was dispatched before or simultaneously with the test writer, leading to fixes without proper test coverage.

2. **Test quality > test quantity.** Agents produce granular tests (one per assertion). Duong prefers consolidated tests — one test checking all 4 badge colors, not 4 separate tests. Consolidate early.

3. **False passes are worse than no tests.** The `_icon_is_gated_on_failures` helper matched a CSS rule instead of the JS template, giving a false pass. Always verify a "passing" test by checking the actual behavior.

4. **Server-side rendering beats client-side JS for simple UI.** Dynamic component filter buttons failed 3 times with different JS approaches. Server-side Python rendering worked immediately.

5. **Pre-commit should run the full suite when it's fast enough.** No reason to subset when the suite is ~6 seconds. Running only unit tests missed dashboard test regressions.
