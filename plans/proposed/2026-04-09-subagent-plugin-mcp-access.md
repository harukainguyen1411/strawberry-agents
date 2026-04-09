---
name: subagent-plugin-mcp-access
status: proposed
owner: evelynn
date: 2026-04-09
---

# Subagent plugin MCP access

## Problem

All Strawberry agent definitions use an explicit `tools:` allowlist (e.g., `tools: Read, Write, Edit, Glob, Grep, Bash`). Per Claude Code docs, `tools:` is an allowlist — anything not listed is denied, including MCP tools. Plugin MCP tools (context7, firecrawl, firebase, playwright, etc.) are therefore blocked from every subagent. Proven this session: Yuumi couldn't see Firecrawl despite it being installed at user scope.

## Root cause

`tools:` = allowlist → strips MCP inheritance.
`disallowedTools:` = denylist → inherits everything (including MCPs) minus what's listed.

Default (no `tools:` field) = inherit all tools from parent session, including MCPs.

## Fix

Convert each Sonnet executor's `tools:` allowlist to `disallowedTools:` denylist. This retains safety constraints (no spawning subagents from subagents, etc.) while allowing MCP tools to propagate from the parent session.

## Agent treatment

### Convert to `disallowedTools:` (need MCP access)

| Agent | Current `tools:` | Proposed `disallowedTools:` |
|---|---|---|
| katarina | `Read, Write, Edit, Glob, Grep, Bash` | `Agent` (cannot spawn sub-subagents) |
| fiora | `Read, Write, Edit, Glob, Grep, Bash` | `Agent` |
| yuumi | `Read, Write, Edit, Glob, Grep, Bash` | `Agent` |
| shen | `Read, Write, Edit, Glob, Grep, Bash` | `Agent` |
| lissandra | `Read, Glob, Grep, Bash` | `Agent, Write, Edit` (keep read-only) |
| bard | `Read, Write, Edit, Glob, Grep, Bash, WebFetch` | `Agent` |
| syndra | `Read, Write, Edit, Glob, Grep, Bash, WebFetch` | `Agent` |
| swain | `Read, Write, Edit, Glob, Grep, Bash, WebFetch` | `Agent` |
| pyke | `Read, Write, Edit, Glob, Grep, Bash, WebFetch` | `Agent` |

### Keep explicit `tools:` allowlist (should stay minimal)

| Agent | Reason |
|---|---|
| poppy | Haiku minion — intentionally minimal, one-file edits only. Keep `tools: Read, Write, Edit` |

## Plugin skills per agent

The `skills:` frontmatter injects full skill content into a subagent's startup context (token cost per spawn — be selective). Only assign skills that directly match the agent's domain.

| Agent | Add to `skills:` |
|---|---|
| katarina | `coderabbit:code-review`, `frontend-design:frontend-design` |
| fiora | `coderabbit:code-review`, `coderabbit:autofix` |
| lissandra | `coderabbit:code-review` |
| yuumi | `claude-md-management:revise-claude-md` |
| syndra | `goodmem:mcp`, `skill-creator:skill-creator` |
| bard | `goodmem:mcp` |
| shen | _(none — git/security work doesn't need plugin skills)_ |
| swain | _(none — architectural planning; MCPs inherited is enough)_ |
| pyke | _(none — security audits; MCPs inherited is enough)_ |
| poppy | _(none — stays minimal)_ |

Existing `skills:` entries (e.g., `agent-ops` on katarina) must be preserved — append, don't replace.

## Implementation steps

1. For each agent in the "convert" table: open `.claude/agents/<name>.md`, replace the `tools:` frontmatter line with the corresponding `disallowedTools:` line.
2. For each agent in the skills table: add the listed skills to the existing `skills:` frontmatter (append; preserve existing entries like `agent-ops`).
3. Verify Poppy's definition is unchanged.
4. Commit to main with `chore:` prefix (no PR needed — agent definitions travel on main).
5. Report back to Evelynn with a diff summary.

## Testing

After Evelynn runs `/reload-plugins` or restarts, she spawns a fresh Katarina with a prompt that calls `mcp__plugin_context7_context7__resolve-library-id` for `vue`. If the tool resolves, MCP propagation is confirmed.

## Non-goals

- Do not change the system prompt body of any agent definition.
- Do not touch `coder-worker` agent definition (separate repo, different hardening rules).
- Do not add `mcpServers:` frontmatter — inheritance is sufficient; explicit listing is only needed for servers not in the parent session.
- Do not assign Figma skills to any agent yet — Figma API token not set up.
