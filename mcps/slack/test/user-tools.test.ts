/**
 * Tests for user-token-routed tools:
 * post_as_duong, reply_in_thread(as="duong"), read_channel_history,
 * read_thread, read_dm, list_users, list_channels, resolve_user
 *
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md (T8, C3)
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { spawnServer, type ServerHandle } from "./harness.js";

const mockInstances: Array<ReturnType<typeof createMockClient>> = [];

function createMockClient() {
  return {
    chat: {
      postMessage: vi.fn().mockResolvedValue({ ok: true, ts: "111.222" }),
    },
    conversations: {
      history: vi.fn().mockResolvedValue({ ok: true, messages: [{ text: "hello", ts: "111.222" }] }),
      replies: vi.fn().mockResolvedValue({ ok: true, messages: [{ text: "thread msg", ts: "111.223" }] }),
      open: vi.fn().mockResolvedValue({ ok: true, channel: { id: "D12345" } }),
      list: vi.fn().mockResolvedValue({
        ok: true,
        channels: [
          { id: "C11111", name: "general", is_member: true, is_archived: false },
          { id: "C22222", name: "random", is_member: false, is_archived: false },
        ],
      }),
    },
    users: {
      list: vi.fn().mockResolvedValue({
        ok: true,
        members: [
          {
            id: "U03KDE6SS9J",
            name: "duong",
            real_name: "Duong Nguyen",
            tz: "Asia/Ho_Chi_Minh",
            profile: { display_name: "duong" },
          },
        ],
      }),
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

describe("user-token-routed tools", () => {
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

  it("post_as_duong routes through userClient", async () => {
    await handle.client.callTool({
      name: "post_as_duong",
      arguments: { channel_id: "C12345", text: "ghost written" },
    });
    expect(userClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "C12345",
        text: "ghost written",
      })
    );
    expect(botClient?.chat?.postMessage).not.toHaveBeenCalled();
  });

  it("reply_in_thread with as=duong routes through userClient", async () => {
    await handle.client.callTool({
      name: "reply_in_thread",
      arguments: { channel_id: "C12345", thread_ts: "111.222", text: "user reply", as: "duong" },
    });
    expect(userClient.chat.postMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "C12345",
        thread_ts: "111.222",
      })
    );
    expect(botClient?.chat?.postMessage).not.toHaveBeenCalled();
  });

  it("read_channel_history calls conversations.history via userClient", async () => {
    const result = await handle.client.callTool({
      name: "read_channel_history",
      arguments: { channel_id: "C12345" },
    });
    expect(result.isError).toBeFalsy();
    expect(userClient.conversations.history).toHaveBeenCalledWith(
      expect.objectContaining({ channel: "C12345" })
    );
  });

  it("read_channel_history applies default limit=20", async () => {
    await handle.client.callTool({
      name: "read_channel_history",
      arguments: { channel_id: "C12345" },
    });
    expect(userClient.conversations.history).toHaveBeenCalledWith(
      expect.objectContaining({ limit: 20 })
    );
  });

  it("read_thread calls conversations.replies via userClient", async () => {
    await handle.client.callTool({
      name: "read_thread",
      arguments: { channel_id: "C12345", thread_ts: "111.222" },
    });
    expect(userClient.conversations.replies).toHaveBeenCalledWith(
      expect.objectContaining({
        channel: "C12345",
        ts: "111.222",
      })
    );
  });

  it("read_dm opens IM then calls conversations.history via userClient", async () => {
    await handle.client.callTool({
      name: "read_dm",
      arguments: { with_user_id: "U99999" },
    });
    expect(userClient.conversations.open).toHaveBeenCalledWith(
      expect.objectContaining({ users: "U99999" })
    );
    expect(userClient.conversations.history).toHaveBeenCalledWith(
      expect.objectContaining({ channel: "D12345" })
    );
  });

  it("list_users calls users.list via userClient", async () => {
    await handle.client.callTool({
      name: "list_users",
      arguments: {},
    });
    expect(userClient.users.list).toHaveBeenCalled();
  });

  it("list_channels calls conversations.list via userClient with correct types", async () => {
    await handle.client.callTool({
      name: "list_channels",
      arguments: {},
    });
    expect(userClient.conversations.list).toHaveBeenCalledWith(
      expect.objectContaining({
        types: "public_channel,private_channel",
      })
    );
  });

  it("resolve_user returns user_id and real_name from users.list", async () => {
    const result = await handle.client.callTool({
      name: "resolve_user",
      arguments: { handle: "duong" },
    });
    expect(result.isError).toBeFalsy();
    const content = result.content as Array<{ type: string; text: string }>;
    const parsed = JSON.parse(content[0].text);
    expect(parsed.user_id).toBe("U03KDE6SS9J");
    expect(parsed.real_name).toBe("Duong Nguyen");
    expect(parsed.tz).toBe("Asia/Ho_Chi_Minh");
  });
});
