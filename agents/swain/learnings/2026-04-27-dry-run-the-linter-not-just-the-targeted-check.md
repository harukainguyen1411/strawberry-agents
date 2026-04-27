# Dry-run the full plan-structure linter, not just the targeted check Orianna flagged

**Context.** Orianna REJECTed ADR-2 twice on `check_qa_plan_frontmatter` (missing `qa_co_author`) then `check_qa_plan_body` (missing canonical sub-headings). Each REJECT only names the first failure encountered — Orianna's protocol short-circuits.

**The trap.** When a brief says "fix check X, then re-dispatch," the obvious move is to fix X and ship. But the linter is a chain — fixing X exposes Y, which exposes Z. Each round-trip costs a full Orianna dispatch + reject + re-dispatch cycle.

**The lesson.** When fixing any plan-structure linter REJECT, run the full chain locally before commit:

```bash
bash -c 'source scripts/_lib_plan_structure.sh \
  && check_plan_frontmatter <plan> \
  && check_task_estimates <plan> \
  && check_test_plan_present <plan> \
  && check_qa_plan_frontmatter <plan> \
  && check_qa_plan_body <plan> \
  && echo ALL-GREEN'
```

This caught the third issue on the ADR-2 chain: `tests_required: true` requires a literal `## Test plan` heading, but the plan had `## Verification`. Without the dry-run, Orianna pass #3 would have REJECTed and we'd be on round 4.

**Even better.** Add the dry-run to the routine for any plan amendment touching frontmatter or canonical headings — not just REJECT recovery. One extra command up-front saves a round-trip later.

**Naming gotcha worth remembering.** `## Test plan` is the canonical literal — not `## Verification`, not `## Verification plan`, not `## Tests`. Every author hits this once. The linter reads the heading by exact string match (mod trailing whitespace). Same pattern applies to the four §QA Plan sub-headings.
