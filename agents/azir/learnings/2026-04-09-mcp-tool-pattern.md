# MCP Tool Pattern for Custom Logic

When adding an MCP tool that requires multi-step logic (GET-modify-PUT), use a `preInterceptor` in `server.ts` that short-circuits with a `ToolResult`. The tool contract in `tool-contracts.ts` gets a fake `operationId` that only the interceptor handles. The actual API operations (`GetProjectInfo`, `UpdateProject`) are called inside the interceptor.

This pattern is already used for `UploadAssetFile`, `SetupClaims`, and `ListJourneyActions`.
