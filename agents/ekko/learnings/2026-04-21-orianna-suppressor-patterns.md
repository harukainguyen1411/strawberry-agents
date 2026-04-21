# Learnings — Orianna suppressor patterns for cross-repo ADR plans

**Date:** 2026-04-21
**Session:** ekko — session-state-encapsulation ADR signing

## What I learned

### Claim-contract §8 line-scope rule

`<!-- orianna: ok -->` is **strictly line-scoped**. A bulk suppressor comment on one line (e.g. a section heading or preamble block) suppresses tokens ONLY on that line — not on subsequent lines in the same section. Every prose line with a bare module name, path token, or file reference needs its own inline suppressor.

### Effective suppressor placement

1. **Inline after the token** — place `<!-- orianna: ok -->` immediately after the backtick-quoted token on the same line: `` `session.py` <!-- orianna: ok --> ``
2. **Future-file label** — for test files or scripts that do not yet exist, use a descriptive label: `` `test_foo.py` <!-- orianna: ok — future test file, will exist after task SE.X.Y --> ``
3. **Scope reference label** — for path tokens that are scope strings (grep patterns, directory refs): `` `tools/demo-studio-v3/` <!-- orianna: ok — scope reference to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path --> ``

### Common pitfall: fenced code blocks

Tokens inside triple-backtick code blocks (` ``` ` or ` ```python `) do NOT need suppressors — Orianna skips them. Only prose/markdown tokens need suppressors.

### Stale path references block the gate

If a sibling ADR was promoted (e.g. from proposed/ to approved/), any reference to its old path in the current plan will block the gate. Always update cross-ADR path references to reflect the current file location before running the sign script.

### Iteration strategy for large suppressor sets

With 29 block findings across dozens of lines:
1. Read the report carefully — it lists exact line numbers per finding
2. Work section by section, fixing all tokens per line in one edit
3. Commit after the batch, then run the sign script
4. The sign script often surfaces new issues (stale paths, etc.) after the first big suppressor pass

### plan-promote.sh requires both arguments

`scripts/plan-promote.sh <plan-file> <target-status>` — both positional args required. `approved`, `in-progress`, `implemented`, `archived` are valid target statuses.

### orianna-sign.sh behavior

- Exits 0 on clean gate, appends `orianna_signature_approved` to frontmatter, commits automatically
- The signed commit is NOT pushed — `plan-promote.sh` pushes it
- `plan-promote.sh` verifies the signature then moves the file and pushes
