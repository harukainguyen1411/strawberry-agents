# Orianna-ok suppressor fixes must be committed before the sign commit

## Date
2026-04-21

## Summary
The `pre-commit-orianna-signature-guard.sh` hook enforces that signing commits touch ONLY the `orianna_signature_<phase>` line. If you fix a `<!-- orianna: ok -->` suppressor and then run `orianna-sign.sh`, the sign script appends the signature line to the plan, but the commit then contains BOTH the suppressor change AND the signature line. The hook blocks it with "found other added content".

## Fix
Always commit body fixes (suppressors, section additions, frontmatter additions) in a SEPARATE commit before running `orianna-sign.sh`. The sign commit must start from a clean working tree where the only staged change is the newly-appended `orianna_signature_<phase>` line.

## Recovery if you hit this
1. `git restore --staged <plan>` to unstage the plan
2. The sign script already wrote the signature to the plan file. Remove the signature line from the plan frontmatter (edit the file, delete the `orianna_signature_*:` line).
3. Commit the body fix (the suppressor change) alone.
4. Re-run `orianna-sign.sh` — it will run Orianna again (LLM call) and re-append the signature cleanly.

## Workflow
```
# Fix body/suppressor first:
edit plan.md  # add suppressors
git add plan.md && git commit -m "chore: add suppressor for X"

# Then sign:
bash scripts/orianna-sign.sh <plan> <phase>
```
