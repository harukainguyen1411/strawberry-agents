# Plan alignment audit patterns — 2026-04-23

## Task

Bulk-audit 13 personal plans (10 proposed, 3 approved) against the simplified
Orianna gate criteria from PR #30.

## Key findings patterns

### Already-implemented but not promoted
Two plans had Test results sections showing they were already implemented (PR #20
merged) but still sat at `status: proposed`. Plans can accumulate implementation
evidence in their body without being promoted if the promotion step is blocked or
skipped. Audit should flag these as close candidates.

Plans affected: orianna-work-repo-routing (8/0 test results), orianna-sign-staged-scope
(PR #20 merged, test results present).

### PR #30 targets-a-script-being-archived pattern
Three plans will be obsoleted by PR #30 because their primary subject files
(scripts/orianna-sign.sh, scripts/plan-promote.sh, scripts/fact-check-plan.sh)
are being archived by PR #30 T2. Before closing them, check whether the plans
contain concepts worth porting to the new regime (e.g. work-concern routing
concept from orianna-work-repo-routing should survive in the new Orianna agent
prompt even if the bash script is gone).

### test task check: "kind: test" vs prose description
The simplified gate test-task check looks for either `kind: test` on a task line
OR a task title matching `^(write|add|create|update) .* test`. A plan can have
a detailed test plan section describing xfail tests in prose without having a
standalone task entry with `kind: test`. The subagent-permission-reliability plan
hit this: T1's DoD described xfail tests but T1 itself had `kind: script`. Fix:
add a T0 with `kind: test`, or change T1's kind and title.

### delete-semantics in rollback sections
Several plans mention "delete" in their Rollback sections only. These are safe:
the primary execution path is additive. Only flag "delete" in Task bodies (forward
execution), not in Rollback sections.

## Audit approach that worked well
Static grep approach was efficient:
1. Read frontmatter (orianna_gate_version, tests_required, orianna_signature fields)
2. `grep -n "kind: test\|write.*test\|add.*test"` for test task check
3. `grep -n "\bdelete\b\|\bremove\b\|\brm -rf\b\|\bgit rm\b"` for delete semantics
4. Content-drift check: read the plan context and mentally diff against PR #30 task list

For large plans (>25k tokens), use grep with specific patterns rather than Read.
