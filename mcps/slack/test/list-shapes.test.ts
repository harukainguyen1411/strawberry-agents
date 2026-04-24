/**
 * Tests for list/resolve shape contracts:
 * list_users client-side filtering, list_channels is_member filter,
 * resolve_user @ stripping and return shape.
 *
 * Plan: plans/in-progress/personal/2026-04-24-custom-slack-mcp.md (T11, C3)
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
      list: vi.fn().mockResolvedValue({
        ok: true,
        channels: [
          { id: "C11111", name: "general", is_member: true, is_archived: false },
          { id: "C22222", name: "random", is_member: false, is_archived: false },
          { id: "C33333", name: "archived-ch", is_member: true, is_archived: true },
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
            profile: { display_name: "Duong" },
          },
          {
            id: "U99999",
            name: "alice",
            real_name: "Alice Smith",
            tz: "UTC",
            profile: { display_name: "alice-work" },
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

describe("list/resolve shape tests", () => {
  let handle: ServerHandle;
  let userClient: ReturnType<typeof createMockClient>;

  beforeEach(async () => {
    mockInstances.length = 0;
    handle = await spawnServer();
    userClient = mockInstances[1];
  });

  afterEach(async () => {
    await handle.close();
  });

  it("list_users filters by query against name field", async () => {
    const result = await handle.client.callTool({
      name: "list_users",
      arguments: { query: "duong" },
    });
    expect(result.isError).toBeFalsy();
    const content = result.content as Array<{ type: string; text: string }>;
    const members = JSON.parse(content[0].text);
    expect(members).toHaveLength(1);
    expect(members[0].id).toBe("U03KDE6SS9J");
  });

  it("list_users filters by query against real_name field", async () => {
    const result = await handle.client.callTool({
      name: "list_users",
      arguments: { query: "Alice" },
    });
    const content = result.content as Array<{ type: string; text: string }>;
    const members = JSON.parse(content[0].text);
    expect(members).toHaveLength(1);
    expect(members[0].id).toBe("U99999");
  });

  it("list_users filters by query against profile.display_name field", async () => {
    const result = await handle.client.callTool({
      name: "list_users",
      arguments: { query: "alice-work" },
    });
    const content = result.content as Array<{ type: string; text: string }>;
    const members = JSON.parse(content[0].text);
    expect(members).toHaveLength(1);
    expect(members[0].id).toBe("U99999");
  });

  it("list_users returns all when no query provided", async () => {
    const result = await handle.client.callTool({
      name: "list_users",
      arguments: {},
    });
    const content = result.content as Array<{ type: string; text: string }>;
    const members = JSON.parse(content[0].text);
    expect(members).toHaveLength(2);
  });

  it("list_channels member_only=true filters to is_member channels only", async () => {
    const result = await handle.client.callTool({
      name: "list_channels",
      arguments: { member_only: true },
    });
    expect(result.isError).toBeFalsy();
    const content = result.content as Array<{ type: string; text: string }>;
    const channels = JSON.parse(content[0].text);
    expect(channels.map((c: { id: string }) => c.id)).toContain("C11111");
    expect(channels.map((c: { id: string }) => c.id)).not.toContain("C22222");
    expect(channels.map((c: { id: string }) => c.id)).not.toContain("C33333");
  });

  it("list_channels member_only=false returns all non-archived channels", async () => {
    const result = await handle.client.callTool({
      name: "list_channels",
      arguments: { member_only: false },
    });
    const content = result.content as Array<{ type: string; text: string }>;
    const channels = JSON.parse(content[0].text);
    expect(channels.map((c: { id: string }) => c.id)).toContain("C11111");
    expect(channels.map((c: { id: string }) => c.id)).toContain("C22222");
    expect(channels.map((c: { id: string }) => c.id)).not.toContain("C33333");
  });

  it("list_channels passes correct types param to API", async () => {
    await handle.client.callTool({
      name: "list_channels",
      arguments: {},
    });
    expect(userClient.conversations.list).toHaveBeenCalledWith(
      expect.objectContaining({ types: "public_channel,private_channel" })
    );
  });

  it("resolve_user strips @ prefix before searching", async () => {
    const result = await handle.client.callTool({
      name: "resolve_user",
      arguments: { handle: "@duong" },
    });
    expect(result.isError).toBeFalsy();
    const content = result.content as Array<{ type: string; text: string }>;
    const resolved = JSON.parse(content[0].text);
    expect(resolved.user_id).toBe("U03KDE6SS9J");
    expect(resolved.real_name).toBe("Duong Nguyen");
    expect(resolved.tz).toBe("Asia/Ho_Chi_Minh");
  });

  it("resolve_user without @ prefix also works", async () => {
    const result = await handle.client.callTool({
      name: "resolve_user",
      arguments: { handle: "alice" },
    });
    const content = result.content as Array<{ type: string; text: string }>;
    const resolved = JSON.parse(content[0].text);
    expect(resolved.user_id).toBe("U99999");
  });

  it("resolve_user returns typed user_not_found error for unknown handle", async () => {
    const result = await handle.client.callTool({
      name: "resolve_user",
      arguments: { handle: "unknown_person_xyz" },
    });
    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0].text).toContain("user_not_found");
  });
});
