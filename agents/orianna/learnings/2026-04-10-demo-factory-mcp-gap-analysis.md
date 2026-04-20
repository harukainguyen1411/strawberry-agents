# Demo Factory MCP Gap Analysis

When auditing whether a Python pipeline should move to agent + MCP, the key question
is: what percentage of the pipeline's API calls are already covered by existing MCP tools?

For the demo factory:
- ~75% of WS API calls in the Apply phase are covered by `walletstudio` MCP tools.
- The remaining gaps are: `upload_asset`, `update_project`, `create/get_external_pass`.
- Playwright-dependent steps (visual QA, logo rendering) should stay as HTTP microservices
  callable as agent tools — not inlined into MCP.
- The LLM orchestration steps (research, generate) are already Claude calls and map
  naturally to agent tool-use patterns with no additional MCP work needed.

Rule of thumb: if >60% of API surface is already in MCP and the orchestration logic is
sequential with clear error boundaries, migration to agent skill is warranted.
