# Learnings: Workflow cleanup + YAML quote stripping

## Date
2026-04-21

## Workflow deletion (Task 1)

- Branch protection GET returning 404 on `strawberry-agents` confirms no protection is
  configured (consistent with Duongntd lacking admin + free-plan GitHub Pro requirement).
  No required-check unregistration needed before deleting workflows.
- When the task says "9" but lists 8 files — delete exactly what's listed, note the
  discrepancy in the PR body.
- `ops:` prefix is correct for `.github/workflows/` deletions (infra/ops only, no apps/).

## YAML quote stripping in awk (Task 2)

- `concern: "work"` — awk stripping only whitespace leaves `"work"` with quotes.
  The routing check `[ "$PLAN_CONCERN" = "work" ]` then fails, silently defaulting
  to personal/strawberry-app routing.
- Fix: add `gsub(/^["'"'"']|["'"'"']$/, "", val)` after the whitespace strip in awk.
  In shell, the single-quote inside double-quote regex requires careful escaping in
  heredocs — use `\x27` in Bash test scripts for clarity, but the awk gsub approach works fine.

## Trap cleanup in test helpers

- Adding `trap "rm -rf ..." EXIT INT TERM` at the start of a helper and `trap - EXIT INT TERM`
  at the end (reset trap after cleanup) prevents report-dir litter on interrupted runs.
- The trap pattern in a function scope resets cleanly — the outer script trap (if any) is
  not affected since we explicitly reset with `trap -`.

## Test case coverage gap

- Adding explicit `dashboards/` and `.github/workflows/` test cases is important even when
  the routing code covers them — transitive coverage through `apps/` doesn't catch if the
  routing switch is accidentally narrowed to just `apps/`.
