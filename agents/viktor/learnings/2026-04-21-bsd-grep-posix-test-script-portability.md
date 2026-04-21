# BSD grep vs GNU grep in test scripts — macOS portability pattern

**Date:** 2026-04-21
**Context:** T9 implementation in memory-consolidation-redesign PR. `test-boot-chain-order.sh` D2 check used `grep -oE '[0-9]+\. [^\n]+'` to extract numbered list entries from a YAML block-scalar file. On macOS (BSD grep), `[^\n]` inside a character class is treated as "not backslash or n" — not "not newline". So the regex matched only one character after the space, producing garbage output (e.g., "7. a" instead of "7. agents/evelynn/memory/open-threads.md"). The fallback path (using `grep -E '^\s*[0-9]+\.'`) was correctly POSIX-portable but was never reached because the first grep returned non-empty (but wrong) output.

**Fix pattern:** Replace BSD-incompatible `grep -oE '[^\n]+'` with `grep -E '^\s*[0-9]+\.'` (whole-line match). This is POSIX-portable and extracts the full line correctly on both macOS and Linux.

**Rule reference:** CLAUDE.md Rule 10 — scripts in `scripts/` must be POSIX-portable bash.

**Generalizable:** Any test script that uses `grep -oE` with `[^\n]` or character classes relying on `\n` as a newline escape is broken on macOS BSD grep. Always prefer line-anchored patterns (`^` / `$`) and full-line greps over `-o` with embedded escape sequences when POSIX portability is required.

**Second pattern (N7 scope):** Migration smoke tests that check "no references to deleted file X" must scope their grep carefully. Historical records (transcripts, learnings, agent memory histories) legitimately reference deleted script names. The correct approach is to check only live boot surfaces: `.claude/agents/*.md`, coordinator CLAUDE.md files, and non-test production scripts. Exclude test scripts (self-referential: they check for the script's own absence).
