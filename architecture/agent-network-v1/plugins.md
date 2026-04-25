# Plugins

19 plugins are installed at user scope (`~/.claude/plugins/`). They are available to all top-level Claude Code sessions and to subagents as **deferred tools**.

## Sub-agent Access

Plugin MCP tools are available to subagents as deferred tools. **Subagents must call `ToolSearch` to load the schema before invoking any MCP tool** — calling without schema load fails with `InputValidationError`. This is not optional; it applies to every plugin tool call.

## Key Plugins

| Plugin | Purpose | Notes |
|--------|---------|-------|
| `context7` | Fetch live library/framework docs | Use before answering questions about any library/SDK/CLI — training data may be stale |
| `firecrawl` | Web scraping, search, crawling, page interaction | Use `firecrawl:firecrawl` skill for structured invocation |
| `playwright` | Browser automation | Available as deferred tools; subagents need ToolSearch first |
| `figma` | Design-to-code workflows | Use `figma:figma-use` skill before any `use_figma` tool call |
| `firebase` | Firebase project management | Available as deferred tools |
| `coderabbit` | AI code review | Use `coderabbit:code-review` skill for PR review workflows |
| `pr-review-toolkit` | PR analysis — tests, types, silent failures | Specialized review pass separate from coderabbit |
| `superpowers` | Core agent skills: TDD, debugging, planning, parallel dispatch | Most useful: `superpowers:dispatching-parallel-agents`, `superpowers:systematic-debugging` |
| `frontend-design` | High-fidelity UI implementation | Use `frontend-design:frontend-design` skill |
| `goodmem` | Memory/embedder management | Use `goodmem:help` for overview; `goodmem:mcp` for MCP tool reference |
| `agent-ops` | Agent coordination — inbox, roster, scaffold | Available as a skill; use `/agent-ops` to send messages, list agents, scaffold new ones |
| `skill-creator` | Create and improve skills | Use `skill-creator:skill-creator` skill |

## Subagent Plugin Access Policy

Per `plans/approved/2026-04-09-subagent-plugin-mcp-access.md`:

- Subagents with matching skill names in their `skills:` frontmatter get the full plugin skill.
- Plugin MCP tools (deferred) are accessible to all subagents but require ToolSearch first.
- Subagent definitions should list only the plugins they actually use in `skills:` to keep their context focused.
