# Signing ceremony cost scales with body-edit distance

**Date:** 2026-04-21
**Context:** SE ADR went through 8+ sign iterations across multiple Ekko runs; MAD+BD were re-signed cleanly in a single pass.

## Lesson

The Orianna signing ceremony cost is dominated by how many times the plan body has been edited since the last signature, not by plan length. When a plan body is edited mid-signing-loop (to fix a failing claim), Orianna must re-hash and re-verify the entire body, which can trigger cascading failures on other claims that reference the edited section. This compounds when multiple ADRs are batched in the same Ekko dispatch.

**Practical rule:** Before dispatching Ekko to sign an ADR, check whether the plan body has been edited since it was last signed (or drafted). If yes, budget 3–5x the signing time of a clean-body plan. If two or more recently-edited ADRs are in the batch, split into separate Ekko dispatches.

**Hygiene:** `.orianna-sign-stderr.tmp` is written to the working tree during every sign attempt and is not auto-cleaned. Add it to `.gitignore` or include a cleanup step in the Ekko sign delegation prompt. The untracked file is invisible to commits but pollutes `git status` across sessions.

## Complementary learning

See `2026-04-21-ekko-signing-context-ceiling.md` for the token-budget constraint (≤2 ADRs per Ekko dispatch). This learning is the complementary cost model: even within the ≤2 ADR limit, recently-edited bodies multiply iteration count. Both constraints apply independently.
