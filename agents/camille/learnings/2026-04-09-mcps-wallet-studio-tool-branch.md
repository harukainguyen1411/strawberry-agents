---
date: 2026-04-09
topic: mcps wallet-studio tool addition workflow
---

# mcps Wallet Studio Tool Addition Workflow

When adding a new MCP tool to the wallet-studio package in mcps:

- Changes span three files: `walletstudio-api.ts` (static operations), `tool-contracts.ts` (tool schema + description), `server.ts` (preInterceptor logic)
- The mcps repo may be on a feature branch when work is handed off — always check `git status` before branching
- New branches should be cut from the working branch state (not necessarily main), then PR targets main
- The `UpdateProjectImages` pattern (GET current, merge fields, PUT full object) is the correct approach for partial updates since the Wallet Studio API uses full-object PUT
