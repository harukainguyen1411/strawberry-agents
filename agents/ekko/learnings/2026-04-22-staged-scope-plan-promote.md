# Learning: staged-scope plan promote (proposed → approved → in-progress)

**Date:** 2026-04-22
**Task:** Promote `plans/proposed/personal/2026-04-22-orianna-sign-staged-scope.md`

## Issues encountered

### 1. Null signature fields in frontmatter trigger idempotency guard
The plan was authored with explicit `orianna_signature_approved: null` fields.
`orianna-sign.sh` idempotency guard uses awk to find the field name — it matches
`null` values the same as real values. Fix: remove null-value signature fields
entirely from the frontmatter before signing. The script expects those fields
to be absent, not null.

### 2. Plan structure hook blocks on bare script names in prose
`pre-commit-zz-plan-structure` (lib-plan-structure) extracts backtick-wrapped
tokens and does `test -e <token>` from repo root. Bare filenames like
`orianna-sign.sh` or `plan-promote.sh` fail because the files live at
`scripts/orianna-sign.sh`. Fix: use full relative paths (`scripts/orianna-sign.sh`)
in prose, or add `<!-- orianna: ok -->` on every affected line.

### 3. Signed-but-unstaged state after commit failure
When the signing commit is blocked (by hook or contamination), `orianna-sign.sh`
has already written the signature to the file but not committed. On next run,
the idempotency guard fires ("already has signature"). Fix: remove the written
signature from the frontmatter, then fix remaining issues, then re-sign.

### 4. Directory path tokens with trailing slash crash awk
Backtick-enclosed directory paths like `` `plans/proposed/` `` in the plan body
crash the awk getline used by lib-plan-structure. Add `<!-- orianna: ok -->` on
those lines.

### 5. Orianna gate blocks on wrong test directory path
The plan referenced `scripts/tests/` but the repo uses `scripts/__tests__/`
(also `scripts/hooks/tests/`). This is a real factual block — correct the path.
Orianna correctly identified this; it's not a format issue.

### 6. plan-promote.sh uses `in-progress` not `in_progress`
The second arg to plan-promote.sh is `in-progress` (hyphen), while orianna-sign.sh
takes `in_progress` (underscore). These are different scripts with different
conventions.

## Successful sequence
1. `git restore --staged .` — always clean before signing
2. Fix all body issues and commit them (before signing — sig-guard requires single file)
3. `orianna-sign.sh <plan> approved` — gate + sign
4. `plan-promote.sh <plan> approved` — move + push
5. `git restore --staged .`
6. `orianna-sign.sh <plan-in-new-location> in_progress` — task gate + sign
7. `plan-promote.sh <plan-in-new-location> in-progress` — move + push
