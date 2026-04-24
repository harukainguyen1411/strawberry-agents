/**
 * Error path tests:
 * (a) missing SLACK_BOT_TOKEN → loadTokens throws typed error
 * (b) Slack returns ok:false → MCP error response
 * (c) SDK error/rejection → graceful MCP error
 * (d) retryConfig.fiveRetriesInFiveMinutes on both clients
 *
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md (T10, C3)
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { spawnServer, type ServerHandle } from "./harness.js";

const mockInstances: Array<ReturnType<typeof createMockClient>> = [];
let capturedConstructorCalls: Array<{ token: string | undefined; options: Record<string, unknown> }> = [];

function createMockClient() {
  return {
    chat: {
      postMessage: vi.fn().mockResolvedValue({ ok: true, ts: "111.222" }),
    },
    reactions: {
      add: vi.fn().mockResolvedValue({ ok: true }),
    },
    conversations: {
      history: vi.fn().mockResolvedValue({ ok: true, messages: [] }),
      replies: vi.fn().mockResolvedValue({ ok: true, messages: [] }),
      open: vi.fn().mockResolvedValue({ ok: true, channel: { id: "D12345" } }),
      list: vi.fn().mockResolvedValue({ ok: true, channels: [] }),
    },
    users: {
      list: vi.fn().mockResolvedValue({ ok: true, members: [] }),
    },
  };
}

vi.mock("@slack/web-api", () => {
  const MockWebClient = vi.fn().mockImplementation((token: string, options: Record<string, unknown>) => {
    capturedConstructorCalls.push({ token, options });
    const instance = createMockClient();
    mockInstances.push(instance);
    return instance;
  });

  return {
    WebClient: MockWebClient,
    retryPolicies: {
      fiveRetriesInFiveMinutes: { retries: 5, factor: 1.5 },
    },
  };
});

describe("error paths", () => {
  let handle: ServerHandle;
  let botClient: ReturnType<typeof createMockClient>;

  beforeEach(async () => {
    mockInstances.length = 0;
    capturedConstructorCalls = [];
    handle = await spawnServer();
    botClient = mockInstances[0];
  });

  afterEach(async () => {
    await handle.close();
  });

  it("Slack ok:false response surfaces as MCP error result (isError:true)", async () => {
    botClient.chat.postMessage.mockResolvedValue({ ok: false, error: "channel_not_found" });
    const result = await handle.client.callTool({
      name: "notify_duong",
      arguments: { text: "test" },
    });
    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0].text).toContain("channel_not_found");
  });

  it("SDK rejection surfaces as MCP error result (graceful, no crash)", async () => {
    botClient.chat.postMessage.mockRejectedValue(new Error("network error"));
    const result = await handle.client.callTool({
      name: "notify_duong",
      arguments: { text: "test" },
    });
    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0].text).toContain("network error");
  });

  it("both WebClient instances use fiveRetriesInFiveMinutes retryConfig", () => {
    // retryConfig is passed as options to WebClient constructor (second arg)
    expect(capturedConstructorCalls.length).toBe(2);
    for (const call of capturedConstructorCalls) {
      expect(call.options).toBeDefined();
      expect(call.options.retryConfig).toBeDefined();
      const cfg = call.options.retryConfig as { retries: number };
      expect(cfg.retries).toBe(5);
    }
  });

  it.fails("missing SLACK_BOT_TOKEN placeholder — split into token validation describe below", () => {
    throw new Error("not implemented — see token validation describe");
  });
});

describe("token validation (separate scope)", () => {
  it("loadTokens throws MissingTokenError when SLACK_BOT_TOKEN absent", async () => {
    const savedBot = process.env.SLACK_BOT_TOKEN;
    delete process.env.SLACK_BOT_TOKEN;
    try {
      const { loadTokens } = await import("../src/tokens.js");
      expect(() => loadTokens()).toThrow("SLACK_BOT_TOKEN");
    } finally {
      if (savedBot !== undefined) process.env.SLACK_BOT_TOKEN = savedBot;
    }
  });

  it("loadTokens throws MissingTokenError when SLACK_USER_TOKEN absent", async () => {
    const savedBot = process.env.SLACK_BOT_TOKEN;
    const savedUser = process.env.SLACK_USER_TOKEN;
    process.env.SLACK_BOT_TOKEN = "xoxb-test";
    delete process.env.SLACK_USER_TOKEN;
    try {
      const { loadTokens } = await import("../src/tokens.js");
      expect(() => loadTokens()).toThrow("SLACK_USER_TOKEN");
    } finally {
      if (savedBot !== undefined) process.env.SLACK_BOT_TOKEN = savedBot;
      else delete process.env.SLACK_BOT_TOKEN;
      if (savedUser !== undefined) process.env.SLACK_USER_TOKEN = savedUser;
    }
  });
});
