/**
 * Test harness for the custom Slack MCP server.
 * Uses InMemoryTransport so vi.mock applies to WebClient in the same process.
 *
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md (T6)
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";

export interface ServerHandle {
  client: Client;
  close: () => Promise<void>;
}

/** Default env for test server boot. */
export const TEST_ENV = {
  SLACK_BOT_TOKEN: "xoxb-test-bot-token",
  SLACK_USER_TOKEN: "xoxp-test-user-token",
  DUONG_USER_ID: "U03KDE6SS9J",
  SLACK_TEAM_ID: "T18MLBHC5",
};

/**
 * Boots the MCP server in-process with InMemoryTransport.
 * Must be called AFTER vi.mock('@slack/web-api', ...) in the test file
 * so the mock is applied before the server module is imported.
 *
 * @param env - Environment variable overrides (defaults to TEST_ENV)
 */
export async function spawnServer(
  env: Record<string, string> = {}
): Promise<ServerHandle> {
  const effectiveEnv = { ...TEST_ENV, ...env };

  for (const [key, value] of Object.entries(effectiveEnv)) {
    process.env[key] = value;
  }

  // Dynamically import the server module after mocks are set up.
  // vi.mock hoisting ensures @slack/web-api is mocked before this import resolves.
  const { createServer } = await import("../src/server.js");
  const server = createServer();

  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

  const client = new Client(
    { name: "test-client", version: "1.0.0" },
    { capabilities: {} }
  );

  await server.connect(serverTransport);
  await client.connect(clientTransport);

  const close = async () => {
    await client.close();
    await server.close();
    // Clean up env
    for (const key of Object.keys(effectiveEnv)) {
      delete process.env[key];
    }
  };

  return { client, close };
}
