# 2026-04-19 — Orianna fact-check gate (O3.1–O3.4)

## What was built

- `scripts/orianna-fact-check.sh` — LLM wrapper; detects claude CLI via
  `command -v`; falls back to bash fallback on absence; sources pinned prompt
  from a separate file rather than inline heredoc.
- `scripts/fact-check-plan.sh` — POSIX bash fallback; uses awk to extract
  inline backtick spans and fenced-code tokens; applies two-repo routing
  (strawberry vs strawberry-app); checks path existence with `test -e`.
- `agents/orianna/prompts/plan-check.md` — pinned prompt file for Orianna
  `plan-check` mode; sourced at runtime by orianna-fact-check.sh.
- `scripts/plan-promote.sh` modified — gate inserted between step 3 and step 4
  (before Drive unpublish); exits 1 on block findings with no bypass flag.
- `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` — seeded bad plan with
  known-false claims for smoke testing.
- `scripts/__tests__/orianna-fact-check.xfail.bats` — xfail bats tests (TDD).

## Patterns learned

### realpath --relative-to doesn't work on macOS
Use `${PATH#"$REPO_ROOT/"}` to strip repo root prefix from absolute paths.
`realpath --relative-to` exists on macOS but exits 1 for this use case.

### Glob/template token filtering is essential for bash fallback
ADR-style plans contain many `agents/*/memory/**` and `<placeholder>` tokens
in backtick spans. Without filtering these, the bash fallback produces dozens
of false block findings on documentation-style plans. Added:
- `case *\**` — skip glob patterns
- `case *\<*\>*` — skip template placeholders

### Two-repo routing for absent checkout
When strawberry-app checkout is absent, cross-repo path claims become `warn`
not `block` per ADR §4.5. This is correct behavior - the fallback must never
over-report in a way that blocks a valid plan.

### .claude/agents/ is write-protected
Cannot create `.claude/agents/orianna.md` via Bash or Write tools — user
permission required. O1.1 must be done manually by Duong or via a separate
authorized session. The scripts function correctly without it (bash fallback
doesn't need it; LLM path would fail at runtime on `--subagent orianna`).

### xfail bats tests for shell scripts
Pattern: `# xfail: <task-id> — <description>` comment at top. Tests that
require future state (seeded bad plan, etc.) are marked `skip` with a clear
reason. Non-skip tests (syntax checks, fallback detection) must pass
immediately after xfail commit.

## Known gaps (out of scope for this session)

- O1.1 `.claude/agents/orianna.md` — requires write permission to .claude/agents/
- O1.1 is a dependency for the LLM path (`--subagent orianna`) to resolve
- O3.2 (bash fallback) is the only path that currently works end-to-end
- Integration name checking (`Firebase GitHub App`) is LLM-only — bash fallback
  cannot catch it, which is documented expected behavior in ADR §3.2
