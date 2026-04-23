# Learning: Claude Code Routines — research spike findings

**Date:** 2026-04-23
**Session:** Ekko subagent — routines research spike

## Key findings for future reference

1. **Routines is real and in research preview since 2026-04-14.** Available on Pro/Max/Team/Enterprise with Claude Code on the web. Not GA yet.

2. **Minimum schedule interval is 1 hour.** Can't schedule more frequently than hourly. `/schedule` CLI creates scheduled triggers; web UI needed for API and GitHub triggers.

3. **`gh` CLI is NOT pre-installed in cloud sessions.** Must install via environment setup script + `GH_TOKEN` env var. Any routine that uses `gh` commands must account for this.

4. **`secrets/` directory is absent in cloud sessions.** Gitignored files don't clone. Age-encrypted secrets are unusable in cloud routines without storing credentials as environment variables.

5. **Branch push restriction:** By default, routines can only push to `claude/`-prefixed branches. "Allow unrestricted branch pushes" must be explicitly enabled to push to main.

6. **Pre-commit hooks run in cloud sessions** because `.claude/settings.json` is part of the repo clone.

7. **No automatic retry and no built-in alerting on failure.** Must build alerting into the routine prompt via MCP connectors.

8. **Dynamic input via API trigger only** (`text` field in POST body). Scheduled triggers have static prompts. Repo state (cloned fresh) is the primary dynamic input source.

9. **Concurrent runs race on git push** — no native locking. Need pull-before-push guard in session prompt for routines that commit.

10. **User `~/.claude/CLAUDE.md` does not transfer to cloud sessions.** Only repo-level CLAUDE.md is available.

## File race during research

The research spike file `assessments/research/2026-04-23-claude-code-routines-spike.md` was created during a session where Orianna was also running a plan-promote. Orianna's commit swept the spike file in alongside the plan file (commit 8717331). This is the parallel-agent staging contamination pattern from prior learnings — but in reverse (someone else's commit swept MY file in). The file content is correct; the commit attribution is Orianna's plan-promote. No functional harm.
