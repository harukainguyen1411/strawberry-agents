---
date: 2026-04-19
task: O4.1, O4.2, O4.3
plan: plans/in-progress/2026-04-19-orianna-fact-checker-tasks.md
---

# Orianna O4 — memory-audit prompt, script, runbook

## What was built

- **O4.1** `agents/orianna/prompts/memory-audit.md`: pinned prompt. Specifies sweep
  scope (agents/*/memory/**, agents/*/learnings/**, agents/memory/**), cross-repo
  handling via `git fetch origin/main` on strawberry-app before any apps/** claim
  check, report format per ADR §4.3, and read-only operating discipline.

- **O4.2** `scripts/orianna-memory-audit.sh`: POSIX sh script. Prereq checks for
  claude CLI (exits 2 if absent — memory audit is LLM-only, no bash fallback).
  Fetches fresh SHAs from both repos. Builds task prompt from O4.1 file. Invokes
  `claude --subagent orianna --non-interactive`. Commits and pushes report under
  `chore:` prefix. Shape is GitHub Actions-compatible (no interactive prompts,
  clean exit codes).

- **O4.3** `agents/orianna/runbook-reconciliation.md`: five-step reconciliation
  flow per ADR §4.4. Names Evelynn as delegator, Yuumi as default fixer for simple
  edits, owning agent for contextual judgment. Documents `needs-reconciliation` →
  `reconciled` frontmatter transition.

## TDD seed

`agents/orianna/learnings/2026-04-19-o4-tdd-stale-seed.md` plants two known-stale
path claims:
- `scripts/migrate-hetzner-to-gce.sh` — does not exist in this repo
- `apps/discord-relay/config/hetzner.json` — does not exist in strawberry-app

The first manual audit run should produce block findings for both.

## Notes

- The script searches for any `YYYY-MM-DD-*.md` report file if the canonical path
  is not found — handles the case where Orianna writes a slightly-timestamped variant.
- `bash -n` passes on the script (POSIX syntax verified).
- Acceptance criteria verified: prompt has 11 ## headings (>=3), runbook has 5
  numbered steps (>=5).
