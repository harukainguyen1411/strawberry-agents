# Appending to an in-progress plan — two linter pitfalls + signature invalidation

**Date:** 2026-04-23
**Context:** Caller asked for a "T-list that §5 promises but is missing" — plan actually had §5 Phase 1-3 w/ T1-T13 + 59 substeps + 20 xfail tests + Orianna's in-progress signature already. Correct move: APPEND, not replace. But appending to an Orianna-signed plan surfaces three sharp edges:

## 1. Appending invalidates the body-hash signature

The `orianna_signature_in-progress` frontmatter field is a body-hash of the plan content at signing time. Any edit that changes non-frontmatter content — even a pure append — flips the hash. Pre-commit may reject future edits on the same plan until Orianna re-signs. **Mitigation:** flag the re-sign requirement as an explicit OQ in the addendum itself (I did this as §5.4 R3), and consider whether the addendum warrants promotion or stays in-place under the existing signature.

## 2. The `h)` banned-time-unit check false-positives on common prose

`scripts/hooks/pre-commit-t-plan-structure.sh` and `pre-commit-zz-plan-structure.sh` both scan `## Tasks` section prose (after stripping backtick spans) for the literal substrings `h)`, `(d)`, `hours`, `days`, `weeks`. The `h)` check hits any word that ends in `h` followed by `)` — including `push)`, `path);`, `fresh)`, `rough)`. If a pre-existing Tasks-section bullet contains one of those patterns, the linter only catches it when the file is re-staged. **Mitigation:** rewrite parenthetical closures that land after an `h`-terminating word. E.g. `(commit, push)` → `(commit, then push —` or `(commit and push)`.

## 3. Awk I/O crash on backtick-quoted `.remember/` is blocking, not noise

Per my earlier sessions I had noted "awk I/O error on trailing-slash dirs is stderr noise." **This is wrong when the directory actually exists on disk.** If a new un-suppressed backtick span `` `.remember/` `` lands in a plan, awk's internal getline attempts to open the dir, crashes with exit 2, and the hook returns non-zero. Previous sessions didn't hit this because their `.remember/` refs had `<!-- orianna: ok -->` markers from the start. **Mitigation:** add the suppressor marker the first time the backtick token appears, same-line. Do NOT rely on a header-level "covers the whole doc" marker — the per-line awk rule scans per line.

## 4. Concurrent agent-def staging trips isolation

If prior session left `.claude/agents/*.md` staged (common when multiple agents edit their own defs), running any pre-commit hook that walks staged files will re-lint those and fail for unrelated reasons. `git reset HEAD -- <those>` before your own commit to isolate scope. Only the file(s) YOU edit should be staged.

## When to apply

Next time you append to a plan that is already `in-progress` with Orianna's signature:
1. Read the full plan first — the T-list you're being asked to write may already exist under a different framing.
2. If gaps are real, APPEND with a `## <section>.<subsection>` rather than replacing an existing numbered section.
3. Audit your additions for `h)` / `(d)` / `hours` / `days` / `weeks` before staging.
4. Add `<!-- orianna: ok -- reason -->` to every backtick-quoted prospective path on the same line.
5. Explicitly flag the signature-invalidation in the addendum itself as an OQ for the implementer to re-sign with Orianna.
