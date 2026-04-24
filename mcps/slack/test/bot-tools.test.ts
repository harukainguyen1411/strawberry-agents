/**
 * Tests for bot-token-routed tools:
 * notify_duong, post_as_bot, reply_in_thread(as="bot"), add_reaction
 *
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md (T7, C3)
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { spawnServer, type ServerHandle } from "./harness.js";

const mockInstances: Array<ReturnType<typeof createMockClient>> = [];

function createMockClient() {
  return {
    chat: {
      postMessage: vi.fn().mockResolvedValue({ ok: true, ts: "111.222" }),
    },
    reactions: {
      add: vi.fn().mockResolvedValue({ ok: true }),
    },
  };
}

vi.mock("@slack/web-api", () => {
  return {
    WebClient: vi.fn().mockImplementation(() => {
      const instance = createMockClient();
      mockInstances.push(instance);
      return instance;
    }),
    retryPolicies: {
      fiveRetriesInFiveMinutes: { retries: 5 },
    },
  };
});

describe("bot-token-routed tools", () => {
  let handle: ServerHandle;
  let botClient: ReturnType<typeof createMockClient>;

  beforeEach(async () => {
    mockInstances.length = 0;
    handle = await spawnServer();
    // First WebClient instantiated is bot (BOT_TOKEN passed first)
    botClient = mockInstances[0];
  });

  afterEach(async () => {
    await handle.close();
  });

  it("notify_duong routes through botClient with hardcoded channel", async () => {
    const result = await handle.client.callTool({
      name: "notify_duong",
      arguments: { text: "hello from test" },
    });
    expect(result.isError).toBeFalsy();
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "U03KDE6SS9J",
        text: "hello from test",
      })
    );
  });

  it("notify_duong propagates thread_ts when provided", async () => {
    await handle.client.callTool({
      name: "notify_duong",
      arguments: { text: "threaded reply", thread_ts: "111.222" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ thread_ts: "111.222" })
    );
  });

  it("post_as_bot routes through botClient with provided channel_id", async () => {
    await handle.client.callTool({
      name: "post_as_bot",
      arguments: { channel_id: "C12345", text: "bot message" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "C12345",
        text: "bot message",
      })
    );
  });

  it("post_as_bot propagates thread_ts when provided", async () => {
    await handle.client.callTool({
      name: "post_as_bot",
      arguments: { channel_id: "C12345", text: "reply", thread_ts: "333.444" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ thread_ts: "333.444" })
    );
  });

  it("reply_in_thread with as=bot routes through botClient", async () => {
    await handle.client.callTool({
      name: "reply_in_thread",
      arguments: { channel_id: "C12345", thread_ts: "111.222", text: "reply", as: "bot" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "C12345",
        thread_ts: "111.222",
      })
    );
  });

  it("reply_in_thread defaults as=bot when not provided", async () => {
    await handle.client.callTool({
      name: "reply_in_thread",
      arguments: { channel_id: "C12345", thread_ts: "111.222", text: "default reply" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalled();
  });

  it("add_reaction routes through botClient reactions.add", async () => {
    await handle.client.callTool({
      name: "add_reaction",
      arguments: { channel_id: "C12345", timestamp: "111.222", emoji: "thumbsup" },
    });
    expect(botClient.reactions.add).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "C12345",
        timestamp: "111.222",
        name: "thumbsup",
      })
    );
  });

  it("notify_duong returns isError for missing text arg (zod validation)", async () => {
    // Missing required arg — MCP SDK returns isError:true with validation details
    const result = await handle.client.callTool({
      name: "notify_duong",
      arguments: {},
    });
    expect(result.isError).toBe(true);
    expect(botClient.chat.postMessage).not.toHaveBeenCalled();
  });

  it("add_reaction returns isError for missing emoji arg (zod validation)", async () => {
    const result = await handle.client.callTool({
      name: "add_reaction",
      arguments: { channel_id: "C12345", timestamp: "111.222" },
    });
    expect(result.isError).toBe(true);
    expect(botClient.reactions.add).not.toHaveBeenCalled();
  });
});
