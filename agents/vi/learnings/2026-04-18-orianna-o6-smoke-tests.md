# O6 Smoke Tests — Orianna Fact-Checker Gate

Date: 2026-04-18
Session: O6 Phase — Smoke Tests + Verification

## Key findings

### LLM path broken — wrong claude CLI flags

`scripts/orianna-fact-check.sh` uses two flags that don't exist in the installed
claude CLI version:
- `--non-interactive` → correct flag is `-p` / `--print`
- `--system "..."` → correct flag is `--system-prompt "..."`

Same problem in `scripts/orianna-memory-audit.sh`:
- Uses `--subagent orianna --non-interactive --prompt` — `--subagent` and
  `--non-interactive` are both unknown options.

Impact: every LLM path invocation falls back to exit 1 (unknown option) from
claude CLI. The gate accidentally still blocks (because claude_exit=1 triggers
the block path in orianna-fact-check.sh), but for the wrong reason.

### Bash fallback correctly routes and reports

The bash fallback (`scripts/fact-check-plan.sh`) works correctly for this-repo
paths. It correctly:
- Flags nonexistent paths as block
- Demotes cross-repo claims to warn when strawberry-app checkout is absent
- Writes conforming reports with `claude_cli: absent`
- Exits 1 on block findings, 0 on clean

### O6.3 gate behavior: accidentally correct

plan-promote.sh exits non-zero when orianna-fact-check.sh exits non-zero,
which happens because the LLM invocation fails with exit 1. The plan stays in
proposed/. The gate integration itself (plan-promote.sh step 3.5) is correct.

### O6.2 clean plan test: real finding surfaced

The "clean" plan `plans/approved/2026-04-19-public-app-repo-migration.md` is
NOT clean — it references `agents/evelynn/memory/MEMORY.md` which doesn't exist
(the actual file is `agents/evelynn/memory/evelynn.md`). The gate correctly
flags this as block. This is a real stale path, not a false positive.

### O6.8 dogfood findings (real signal)

Running the gate against `plans/in-progress/2026-04-19-orianna-fact-checker.md`:
- Block on `agents/orianna/{profile.md,memory/MEMORY.md,...}` — FALSE POSITIVE.
  The bash checker doesn't expand brace notation; treats brace-expansion
  shorthand as a literal path. Files exist individually.

Running against `plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md`:
- Block on `plans/approved/2026-04-19-orianna-fact-checker.md` — REAL. The ADR
  moved from approved/ to in-progress/ but the task list still references the
  old approved/ path.
- Block on `assessments/memory-audits/2026-04-19-memory-audit.md` — FALSE POSITIVE.
  This is a described future output in the task spec, not a required existing file.

### O6.5 memory audit: blocked by bad CLI flags

`orianna-memory-audit.sh` exits 1 immediately with "unknown option --subagent".
Cannot complete until CLI flags are fixed.

## Task results summary

| Task | Result | Notes |
|------|--------|-------|
| O6.1 | PASS | Bad plan verified present (Jayce's work) |
| O6.2 | PARTIAL | Bash fallback works; LLM path broken; clean plan had a real stale-path hit |
| O6.3 | PASS (accidental) | Gate blocks bad plan, plan stays in proposed; reason is wrong CLI exit not claim verification |
| O6.4 | PASS | Fallback fires, log message correct, claude_cli: absent in report |
| O6.5 | FAIL | orianna-memory-audit.sh blocked by --subagent unknown flag |
| O6.6 | PASS | Absent-checkout case: warn with checkout path. Present-checkout case untestable (no checkout) |
| O6.7 | PASS | Bad plan removed, committed, pushed |
| O6.8 | COMPLETE | Gate blocks ADR with 1 false positive; blocks task list with 1 real + 2 false positives |

## Fixes needed

1. Fix `scripts/orianna-fact-check.sh`: replace `--non-interactive` with `-p`,
   replace `--system` with `--system-prompt`, remove `--print` (implied by `-p`).
2. Fix `scripts/orianna-memory-audit.sh`: `--subagent orianna --non-interactive`
   → use `-p` with `--system-prompt` or `--append-system-prompt`. The `--subagent`
   flag does not exist; the right approach is `--agent` or just `--system-prompt`.
3. Add brace-expansion token handling to `fact-check-plan.sh`: tokens containing
   `{` and `}` should be skipped (they are documentation shorthand, not real paths).
4. Stale path in task list: update task-list references from
   `plans/approved/2026-04-19-orianna-fact-checker.md` to
   `plans/in-progress/2026-04-19-orianna-fact-checker.md`.

## Methodology notes

- Always check the actual report content, not just exit codes — the exit code
  can be accidentally correct for the wrong reason (e.g., LLM crash vs. claim block).
- Piping to `head` can mask exit codes — always capture with a separate `echo $?`.
- O6.2 "clean plan passes" assumption was wrong because the specific plan chosen
  had a real stale path. Pick plans with no path claims for clean-pass tests, or
  use a synthetic minimal plan.
