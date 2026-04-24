# Custom Slack MCP — vitest + InMemoryTransport patterns

**Session:** 2026-04-24 — custom-slack-mcp C1–C4 implementation

## Key patterns

### InMemoryTransport for MCP testing (avoids subprocess spawn)
Use `InMemoryTransport.createLinkedPair()` from `@modelcontextprotocol/sdk/inMemory.js` to wire a server and client in-process. `vi.mock('@slack/web-api')` applies because both server and client share the same module registry. No process spawn, no stdio plumbing.

```ts
const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
await server.connect(serverTransport);
await client.connect(clientTransport);
```

### it.fails() xfail lifecycle with vitest
- `it.fails(desc, fn)` passes when `fn` throws/rejects; fails (XPASS) when `fn` succeeds.
- For C2 xfail: callTool on nonexistent tool throws → it.fails() passes → `npm test` exits 0.
- For C3 impl: callTool succeeds → it.fails() detects XPASS → `npm test` exits 1.
- Fix in C3: convert `it.fails()` to `it()`. Don't mix `expect(...).rejects.toThrow()` inside `it.fails()` — the rejects assertion resolves (passes) so it.fails() sees no failure (XPASS in C2).

### vi.mock instance capture pattern
Use a module-level array to capture WebClient instances created by server:
```ts
const mockInstances: ReturnType<typeof createMockClient>[] = [];
vi.mock("@slack/web-api", () => ({
  WebClient: vi.fn().mockImplementation(() => {
    const instance = createMockClient();
    mockInstances.push(instance);
    return instance;
  }),
  retryPolicies: { fiveRetriesInFiveMinutes: { retries: 5 } },
}));
// In beforeEach: mockInstances.length = 0; then after spawnServer: botClient = mockInstances[0]
```

### --passWithNoTests for scaffold commits
Add `--passWithNoTests` to `test:unit` script so C1 scaffold (no test files) doesn't block pre-commit hook:
```json
"test:unit": "vitest run --passWithNoTests"
```

### Heredoc syntax blocks pretooluse-plan-lifecycle-guard.sh
The bashlex AST scanner (exit 3 = parse error) blocks git commit commands using POSIX heredoc syntax (`<<'EOF'`). Use simple `-m "message"` for commits, or write message to a temp file separately.

### strawberry repo remote is local-only
The `strawberry` repo at `~/Documents/Personal/strawberry/` has remote `Duongntd/strawberry` which no longer exists on GitHub. MCP server code in `mcps/` is committed locally to branches but cannot be pushed. This is expected per Ekko's history (commits are direct-to-local-main).

### tdd.enabled:true required for pre-push TDD gate
Set `"tdd": { "enabled": true }` in `package.json` to opt the package into the TDD gate checks. The pre-push hook only validates xfail-first and regression-test rules for packages with this flag set.
