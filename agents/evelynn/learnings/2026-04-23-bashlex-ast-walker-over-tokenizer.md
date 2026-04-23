# Bashlex AST walker is strictly stronger than tokenizer-based shell scanning for bypass detection

**Date:** 2026-04-23
**Source:** PR #31 — physical guard, rounds 1-4
**Session shard:** 26406c02

## The finding

When scanning shell scripts for path-manipulation or privilege-escalation patterns, tokenizer-based approaches miss entire bypass classes that AST-based parsing catches:

- `.list` children in compound commands (tokenizer sees the outer structure; AST sees subcommands)
- `word.parts` substitution chains (`$(...)` expansions within arguments)
- `eval` and `bash -c` re-parse targets (tokenizer stops at the string boundary; AST can recursively parse the inner string)

All four Senna review rounds on PR #31 found real bypasses. Rounds 1-2 drove the switch from tokenizer to bashlex AST walker. Rounds 3-4 found structural edge cases in the AST traversal itself (`.list` children not walked, word.parts substitutions not flattened). All four rounds required new xfail tests first, then fixes.

## Actionable pattern

Any future shell-script scanning hook (path checks, verb allowlists, injection detection) should use bashlex AST traversal from the start, not a tokenizer or regex approach. The bashlex `parse_string()` function + recursive node walking is the correct baseline. Budget 3-4 review passes for a new scanner — edge cases surface iteratively, not on first pass.

## Cost signal

Four Senna review rounds for one guard PR is the expected cost for security-critical bash scanners. This is not dysfunction — it's the correct signal that the problem is harder than it looks. Do not short-circuit review rounds on enforcement gates.
