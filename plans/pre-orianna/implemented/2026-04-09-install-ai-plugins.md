---
name: install-ai-plugins
status: approved
owner: evelynn
date: 2026-04-09
---

# Install Firecrawl + Context7 Claude Code plugins

Install two plugins to the user scope (`~/.claude/`) on this Windows machine. Non-interactive CLI only — do not attempt to invoke slash commands.

## Context

Duong wants Firecrawl (web crawling for AI) and Context7 (up-to-date library docs MCP) available to all agents in this Claude Code session and future sessions on this box. Docs confirm `claude plugin` has a CLI subcommand surface with `--scope user`.

Reference: https://code.claude.com/docs/en/discover-plugins.md

## Scope

User scope only (`~/.claude/plugins/`). No repo commits. No `.mcp.json` edits in this repo. No API key configuration (`/firecrawl:setup` is interactive and belongs to Duong).

## Steps

1. **Probe the CLI surface.** Run `claude plugin --help` and `claude plugin marketplace --help`. Capture full output. If either subcommand does not exist, STOP and report — do not fall back to slash commands.

2. **Install Firecrawl from the official marketplace.** Run:
   ```
   claude plugin install firecrawl@claude-plugins-official --scope user
   ```
   Capture exit code and full stdout/stderr.

3. **Add the Context7 marketplace.** Run:
   ```
   claude plugin marketplace add upstash/context7
   ```
   (If the CLI subcommand for marketplace add differs from the slash form, use the CLI form observed in step 1's help output.) Capture output.

4. **Install Context7.** Run:
   ```
   claude plugin install context7@upstash-context7 --scope user
   ```
   Capture output.

5. **Verify.** Run `claude plugin list` (or equivalent from the help output). Confirm both plugins appear. If the CLI lacks a list subcommand, inspect `~/.claude/settings.json` or `~/.claude/plugins/` directly and report what you see.

## Non-goals

- Do NOT run `/firecrawl:setup` — that needs Duong's Firecrawl API key.
- Do NOT run `/reload-plugins` — that's a slash command; plugins will activate on the next Claude Code restart.
- Do NOT modify any repo files.
- Do NOT commit anything.

## Reporting

Report back to Evelynn with:
- Help output from step 1 (so we lock in the real subcommand surface for future runs)
- Exit code + output from each install command
- Final verification output (what `claude plugin list` or the settings.json shows)
- Any anomalies or blockers

If any step errors, STOP and report — do not improvise alternatives without checking in.
