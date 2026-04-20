# Managed Agent Tool Enforcement

When constraining a Managed Agent's tool access:

1. **agent_toolset_20260401 with default_config: {enabled: false}** should disable all built-in tools (bash, read, write, edit, glob, grep, web_search, web_fetch). But web_search/web_fetch may still leak through — unclear if this is a platform bug or a separate mechanism.

2. **Nuclear option: omit agent_toolset_20260401 entirely** from the tools array. The agent should only have MCP toolsets. Still needs validation — we tried this but the agent still showed web_search behavior.

3. **Hierarchy of enforcement** (from Lux):
   - Tool unavailability (strongest)
   - Permission gates (always_ask)
   - System prompt rules (~95% reliable)
   - In-conversation reminders (weakest)

4. **MCP tool descriptions** are a decision-point reinforcement — when the model is picking a tool, the description has high weight. Adding behavioral hints (e.g., "use this instead of generating content yourself") improves compliance.

5. **State machine prompts** are more reliable than prose for phase-based workflows. The model can pattern-match against discrete states.

6. **Every component must be in sync** when deploying: agent system prompt, MCP server tool definitions, backend API, Cloud Run env vars. Changing one without others causes confusing behavior.
