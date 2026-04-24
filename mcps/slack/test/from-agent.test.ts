/**
 * Tests for from_agent prefix behavior (OQ2 resolution).
 * notify_duong({text, from_agent: "evelynn"}) → posts "[evelynn] <text>"
 * Omitting from_agent → posts bare text.
 * Same for post_as_bot and post_as_duong.
 *
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md (T9, C3)
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

describe("from_agent prefix", () => {
  let handle: ServerHandle;
  let botClient: ReturnType<typeof createMockClient>;
  let userClient: ReturnType<typeof createMockClient>;

  beforeEach(async () => {
    mockInstances.length = 0;
    handle = await spawnServer();
    botClient = mockInstances[0];
    userClient = mockInstances[1];
  });

  afterEach(async () => {
    await handle.close();
  });

  it("notify_duong with from_agent prefixes message as [agent] text", async () => {
    await handle.client.callTool({
      name: "notify_duong",
      arguments: { text: "task complete", from_agent: "evelynn" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ text: "[evelynn] task complete" })
    );
  });

  it("notify_duong without from_agent posts bare text", async () => {
    await handle.client.callTool({
      name: "notify_duong",
      arguments: { text: "bare message" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ text: "bare message" })
    );
  });

  it("post_as_bot with from_agent prefixes message", async () => {
    await handle.client.callTool({
      name: "post_as_bot",
      arguments: { channel_id: "C12345", text: "bot msg", from_agent: "jayce" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ text: "[jayce] bot msg" })
    );
  });

  it("post_as_bot without from_agent posts bare text", async () => {
    await handle.client.callTool({
      name: "post_as_bot",
      arguments: { channel_id: "C12345", text: "bare bot msg" },
    });
    expect(botClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ text: "bare bot msg" })
    );
  });

  it("post_as_duong with from_agent prefixes message", async () => {
    await handle.client.callTool({
      name: "post_as_duong",
      arguments: { channel_id: "C12345", text: "duong msg", from_agent: "ekko" },
    });
    expect(userClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ text: "[ekko] duong msg" })
    );
  });

  it("post_as_duong without from_agent posts bare text", async () => {
    await handle.client.callTool({
      name: "post_as_duong",
      arguments: { channel_id: "C12345", text: "bare duong msg" },
    });
    expect(userClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({ text: "bare duong msg" })
    );
  });
});
