---
title: Custom Slack MCP with purposed tools (replace dual-wrapper)
status: approved
concern: personal
owner: ekko
author: lux
created: 2026-04-24
kind: adr-lite
supersedes: dual-wrapper slack-bot / slack-user in .mcp.json
---

## 1. Problem + goal

Today `.mcp.json` contains two instances of `@modelcontextprotocol/server-slack` — `slack-bot` (xoxb-) and `slack-user` (xoxp-) — each exposing the same generic tool set (`slack_post_message`, `slack_get_channel_history`, …). Agents must therefore remember, at runtime, **three** independent facts per call: (1) which server prefix, (2) which `channel_id`, (3) whether the author identity matters for notification behaviour. That knowledge currently lives in `agents/memory/duong.md` as a prose pick-rule, which is exactly the wrong place for routing logic — memory drifts, and any agent that skips reading it makes the wrong call.

Goal: replace both wrappers with a single custom MCP (`slack`) whose **tool names encode intent**. `notify_duong(text)` carries "bot token → DM U03KDE6SS9J" in its name and implementation; the agent does not choose a token or a channel ID. Generic tools (`slack_post_message`) become internal details. Memory shrinks to workspace identifiers; the MCP's tool list becomes the canonical pick-rule.

## 2. Tool catalog

Notation: `(arg: type = default)`; token column = `bot` (xoxb-) or `user` (xoxp-); all tools return the Slack API payload on success and a structured MCP error on failure. All tools that take a `text` argument accept Slack mrkdwn.

| Tool | Signature | Token | Routing / behaviour | Primary failure modes |
|------|-----------|-------|---------------------|----------------------|
| `notify_duong` | `(text: str, thread_ts: str? = None)` | bot | `chat.postMessage` with `channel="U03KDE6SS9J"` hardcoded. Optional thread. | `channel_not_found` if Duong uninstalled the bot; `not_in_channel` impossible (DM). |
| `post_as_bot` | `(channel_id: str, text: str, thread_ts: str? = None)` | bot | `chat.postMessage`. Bot must be invited (`/invite @<bot>`) or channel must be public. | `not_in_channel`, `channel_not_found`. |
| `post_as_duong` | `(channel_id: str, text: str, thread_ts: str? = None)` | user | `chat.postMessage` with user token — ghost-writes as Duong. **Does not notify Duong.** | `missing_scope` if `chat:write` absent on user token. |
| `reply_in_thread` | `(channel_id: str, thread_ts: str, text: str, as: "bot"\|"duong" = "bot")` | caller picks | Thin wrapper over `post_as_bot` / `post_as_duong` with `thread_ts` required. Exists because replies legitimately happen as either identity and the dispatch is load-bearing. | inherits from underlying tool. |
| `add_reaction` | `(channel_id: str, timestamp: str, emoji: str)` | bot | `reactions.add` as bot. Default bot — reactions are attribution-light and the bot always has `reactions:write`. | `already_reacted`, `not_in_channel`. |
| `read_channel_history` | `(channel_id: str, limit: int = 20, oldest: str? = None, cursor: str? = None)` | user | `conversations.history`. User token chosen for broader default scope (public+private the user is in). | `channel_not_found`, `missing_scope`. |
| `read_thread` | `(channel_id: str, thread_ts: str, limit: int = 50)` | user | `conversations.replies`. Renamed from `read_dm_thread` — threads exist in channels too and the implementation is identical. | same as above. |
| `read_dm` | `(with_user_id: str, limit: int = 20)` | user | `conversations.open` (IM) → `conversations.history`. Convenience wrapper. | `user_not_found`. |
| `list_users` | `(query: str? = None, limit: int = 50)` | user | `users.list` with client-side filter on `query` against `name`, `real_name`, `profile.display_name`. | paginated; returns only first page by design (agents rarely need more). |
| `list_channels` | `(query: str? = None, member_only: bool = True, include_archived: bool = False)` | user | `conversations.list` with `types=public_channel,private_channel` (and `im` excluded); filter by `is_member` when `member_only=True`. | same. |
| `resolve_user` | `(handle: str)` | user | Convenience: takes `@name` or display name, returns `{user_id, real_name, tz}`. Avoids agents guessing U-IDs. | `user_not_found`. |

### Decisions vs. the draft list

- **Kept `notify_duong`, `post_as_bot`, `post_as_duong`, `add_reaction`.** These encode pure intent.
- **Renamed `read_dm_thread` → `read_thread`** and added a separate `read_dm` — the original conflated "reading a thread (any channel)" with "reading a DM conversation" and the Slack API treats them differently (`conversations.replies` vs `conversations.history` on an IM channel).
- **Kept `reply_in_thread` with an `as` enum** (not `as_bot: bool`). Enum leaves room for a future `"system"` identity without a signature break.
- **Added `resolve_user`** — small but high-leverage. Today agents paste raw U-IDs from memory; this lets them pass `"duong"` or a display name.
- **`add_reaction` defaults to bot.** User-token reactions exist but (a) they notify nothing extra and (b) bot attribution is clearer in channel history.
- **Dropped a generic `post_message(channel, text, as=...)`.** That's the exact "agent makes a runtime choice" pattern this spec is replacing. Three purposed tools beat one polymorphic one.

## 3. Impl shape

**Language: TypeScript** with `@modelcontextprotocol/sdk` and `@slack/web-api`.

Rationale, not dogma:

- Matches upstream `@modelcontextprotocol/server-slack` — if we ever need to cherry-pick upstream behaviour we read their source directly.
- `@slack/web-api`'s `WebClient` is strongly typed end-to-end (method args + response shapes). The Python `slack_sdk` equivalent is duck-typed dicts.
- The tool bodies are thin — essentially `client.chat.postMessage({...})`. The value is in the argument schema (zod) and TS+zod is the cleanest way to write that on this SDK.
- Other mcps in `mcps/` (evelynn, discord, cloudflare, gcp) are shell-script launchers over npm/pip packages; none are "our own code in Python." No precedent to break.

Cost: adds a `node_modules` install step the first time the server runs. Mitigated by `npx`-style packaging or a committed `package-lock.json` + one-time `npm ci`.

**Single file for v1** (`src/server.ts`, ~250 lines). Each tool is a `server.tool("name", schema, async (args) => { ... })` block. Promote to `src/tools/<name>.ts` only when any single tool grows past ~40 lines. Shared WebClient instances (`botClient`, `userClient`) + constants (`DUONG_USER_ID`, `TEAM_ID`) live at top of file.

**Deps:** `@modelcontextprotocol/sdk`, `@slack/web-api`, `zod`. No other runtime deps. `typescript` + `tsx` (for stdio run without a build step) as dev deps.

## 4. File layout

**Decision: keep the `/Users/duongntd99/Documents/Personal/strawberry/mcps/slack/` location**, restructured. Reasons:

- Consistent with every other MCP in `.mcp.json` (evelynn, discord, cloudflare, gcp all live in `strawberry/mcps/<name>/`).
- Keeps the `strawberry-agents` repo focused on agents/plans/memory; MCP server code is infra.
- The existing path is already hardcoded in the current `.mcp.json` — in-place replacement is a smaller migration.

Proposed layout under `/Users/duongntd99/Documents/Personal/strawberry/mcps/slack/`:

```
slack/
├── package.json
├── package-lock.json
├── tsconfig.json
├── README.md                  # brief; refs this spec
├── src/
│   └── server.ts              # all tools, ~250 lines
└── scripts/
    ├── start.sh               # the MCP entrypoint (new)
    └── start.sh.bak-dual      # old npm-wrapper start.sh, retained one release for rollback
```

`scripts/start.sh` (new) reads both tokens from `secrets/slack-bot-token.txt`, exports them as env, and `exec tsx src/server.ts`. No CLI arg (no more `--token-kind`).

## 5. Secret handling

**Keep the single-file layout** at `/Users/duongntd99/Documents/Personal/strawberry-agents/secrets/slack-bot-token.txt` in existing key=value format:

```
bot_token=xoxb-...
user_token=xoxp-...
```

Rationale: one server process now needs both tokens, so one file with both is strictly simpler than two files requiring two `grep+cut`s. The "bot-token.txt" filename is a minor misnomer post-migration; acceptable — rename optional (see OQ-1).

### start.sh contract

```bash
#!/usr/bin/env bash
set -euo pipefail
TOKEN_FILE="/Users/duongntd99/Documents/Personal/strawberry-agents/secrets/slack-bot-token.txt"
[ -f "$TOKEN_FILE" ] || { echo "slack-mcp: missing $TOKEN_FILE" >&2; exit 1; }

BOT_TOKEN="$(grep '^bot_token=' "$TOKEN_FILE"  | head -1 | cut -d= -f2-)"
USER_TOKEN="$(grep '^user_token=' "$TOKEN_FILE" | head -1 | cut -d= -f2-)"
[ -n "$BOT_TOKEN"  ] || { echo "slack-mcp: bot_token missing"  >&2; exit 1; }
[ -n "$USER_TOKEN" ] || { echo "slack-mcp: user_token missing" >&2; exit 1; }

cd "$(dirname "$0")/.."
exec env \
  SLACK_BOT_TOKEN="$BOT_TOKEN" \
  SLACK_USER_TOKEN="$USER_TOKEN" \
  SLACK_TEAM_ID="${SLACK_TEAM_ID:-T18MLBHC5}" \
  DUONG_USER_ID="${DUONG_USER_ID:-U03KDE6SS9J}" \
  npx -y tsx src/server.ts
```

`server.ts` reads env on boot, constructs two `WebClient` instances, fails fast if either token is absent. `DUONG_USER_ID` and `SLACK_TEAM_ID` are env-configurable but default-baked — so the only machine-local state is tokens.

## 6. Migration

### `.mcp.json`

Replace the two entries (lines 40–63 of the current file) with one:

```json
"slack": {
  "type": "stdio",
  "command": "bash",
  "args": [
    "/Users/duongntd99/Documents/Personal/strawberry/mcps/slack/scripts/start.sh"
  ],
  "env": {
    "SLACK_TEAM_ID": "T18MLBHC5",
    "DUONG_USER_ID": "U03KDE6SS9J"
  }
}
```

Tool names exposed to Claude become `mcp__slack__notify_duong`, `mcp__slack__post_as_bot`, etc.

### Fallback retention

Keep `scripts/start.sh.bak-dual` (the current bot/user script renamed) for one release cycle — lets Duong flip back by reverting `.mcp.json` only if the new server misbehaves. Delete it in the next cleanup pass once the new server has a week of clean operation.

### Consumer audit

`grep` results for `mcp__slack` / `slack-bot` / `slack-user` across `strawberry-agents` (excluding `.claude/worktrees/`):

| Location | Reference | Action |
|----------|-----------|--------|
| `.mcp.json` | `slack-bot`, `slack-user` entries | replace per above |
| `agents/memory/duong.md` | `mcp__slack-bot__slack_post_message` in prose | rewrite per §7 |
| `agents/ekko/memory/MEMORY.md` L154 | dual-wrapper note | supersede note + pointer to this spec |
| `agents/ekko/learnings/2026-04-24-dual-slack-mcp-wiring.md` | historical | leave untouched; learnings are immutable |
| `agents/ekko/learnings/2026-04-24-slack-mcp-wiring.md` | historical | leave untouched |
| `agents/lux/learnings/2026-04-09-slack-to-claude-code-architecture.md` | external reference (`mpociot/claude-code-slack-bot`) — not our tool name | no action |
| `plans/in-progress/work/2026-04-23-firebase-auth-loop2d-slack-removal.md` L162 | `slack-triage-sa` — unrelated GCP SA name | no action |

**Conclusion:** only `.mcp.json`, `agents/memory/duong.md`, and Ekko's live memory need edits. No agent-def references the old tool names. No script outside `mcps/slack/` touches them.

### Cutover sequence (for Ekko's implementation PR)

1. Build `mcps/slack/` per §3–§5 (new server + start.sh; rename old start.sh to `start.sh.bak-dual`).
2. Smoke: invoke each tool from a scratch Claude session.
3. Single commit updates `.mcp.json` + `agents/memory/duong.md` + Ekko's MEMORY.md line atomically.
4. Restart Claude session to pick up `.mcp.json` changes.
5. One-week soak; then delete `start.sh.bak-dual`.

## 7. Memory updates

Replace lines 12–29 of `agents/memory/duong.md` (the current `## Slack` section including the token pick-rule table) with:

```markdown
## Slack

- Workspace: `merisier.slack.com`, team `T18MLBHC5`
- Duong's user ID: `U03KDE6SS9J`
- Routing is encoded in MCP tool names — see `mcp__slack__*`. Canonical
  agent→Duong notification: `mcp__slack__notify_duong(text)`. Do not
  reconstruct routing from memory; if a tool for an intent is missing,
  file it against the custom-slack-mcp plan rather than improvising with
  generic post tools.
```

That's it. No table, no prefix choice, no "which token for what." ~5 lines vs. ~18. The memory now documents **identity** (team, user ID) — not **routing**.

Ekko's MEMORY.md L154 gets a one-line supersede note pointing at this spec; the historical wiring detail stays for archaeology.

## 8. Open questions

**OQ-1: Rename `secrets/slack-bot-token.txt` → `secrets/slack-tokens.txt`?**
- a (cleanest): rename the file at migration time; update `start.sh`, any docs.
- b (balanced): leave the filename, add a comment line inside.
- c (quick-with-debt): leave everything, note the misnomer in this spec.
- **Recommended: b.** Filename rename touches ignore rules, doc refs, and Ekko's MEMORY.md — cost out of proportion with the gain. A `# contains both bot_token= and user_token=` comment inside the file is sufficient.

**OQ-2: Should `notify_duong` auto-prefix the sending agent's name?**
- Context: today the bot posts `"<msg>"`; agent identity is only visible in history via Slack attribution on the same bot user. Evelynn, Lux, Ekko all speak as the same bot.
- a (cleanest): add a required `from_agent: str` arg; server prefixes `[evelynn] <msg>`. Forces the agent to name itself.
- b (balanced): optional `from_agent` arg, auto-prefix when provided.
- c (quick-with-debt): no prefix, relies on the agent writing its own name in `text`.
- **Recommended: b.** Avoids forcing existing callers to update while making the "good path" one arg away. Can tighten to (a) later once call sites are known.

**OQ-3: Rate-limit / retry policy inside the server?**
- `@slack/web-api` does `retryConfig` natively (exponential backoff on 429).
- **Recommended (inline): enable default `retryConfig: RetryOptions.fiveRetriesInFiveMinutes` on both clients.** Not a fork — just a setting. Noting here so Ekko doesn't skip it.

**OQ-4: Do we expose a `search_messages` tool?**
- Slack's `search.messages` requires a user token and the `search:read` scope. Useful for agents answering "did Duong mention X recently."
- **Recommended (inline): defer.** Not in the current draft-list intent set. Add on first real need; cheap to add.

**Genuinely needing Duong's input:** only OQ-1 (cosmetic — file rename y/n). OQ-2/3/4 are inline-resolved; Ekko can proceed on the defaults above unless Duong wants to override.

**OQ-1 resolution (Evelynn, 2026-04-24):** Accept Lux's recommended default **b** — leave filename, add `# contains both bot_token= and user_token=` comment inside the file. Rename costs ripple through `start.sh` + docs + ignore rules for zero behavioural gain; per simplicity-first, keep the path stable.

## 9. Non-goals

- Not migrating the Discord MCP — that's its own shape.
- Not changing how other agents discover MCPs. `.mcp.json` remains the registry.
- Not introducing a new MCP category (e.g., "notification MCP"). This is still `mcp__slack__*`.
- No database, no persistence, no caching. The server is stateless over Slack's API.

## 10. Success criteria

1. `.mcp.json` has one `slack` entry; `slack-bot` / `slack-user` are gone.
2. `mcp__slack__notify_duong("hello")` from a fresh session delivers a notifying DM to Duong.
3. `agents/memory/duong.md` `## Slack` section is ≤ 10 lines and contains no tool-name or token-prefix strings.
4. `grep -rn "slack-bot\|slack-user" strawberry-agents/ --exclude-dir=worktrees` returns zero hits in live (non-learnings, non-historical) files.
5. Rollback: reverting `.mcp.json` to the two-entry form with the retained `start.sh.bak-dual` restores prior behaviour in < 2 minutes.

## Tasks

**Breakdown by Kayn, 2026-04-24.** Four commits (C1 scaffold → C2 xfail tests → C3 impl → C4 migration) per Rule 12. Tasks T1–T5 land in C1, T6–T11 in C2, T12–T22 in C3, T23–T27 in C4. C1–C3 commit inside `/Users/duongntd99/Documents/Personal/strawberry/mcps/slack/` (separate repo from strawberry-agents). C4 commits inside `strawberry-agents/`. Executor: Ekko (owner per frontmatter) — Sonnet tier is sufficient; all tasks are thin wrappers with typed SDKs and locked decisions. Total estimate: ~395 AI-min across 27 tasks.

### Phase C1 — Scaffold + token loader (commits in `strawberry/mcps/slack/`)

- [ ] **T1** — Init TS project skeleton. estimate_minutes: 15. Files: `mcps/slack/package.json`, `mcps/slack/tsconfig.json`, `mcps/slack/.gitignore`. DoD: `package.json` declares `type: "module"`, deps `@modelcontextprotocol/sdk`, `@slack/web-api`, `zod`; devDeps `typescript`, `tsx`, `vitest`, `@types/node`; `tsconfig.json` targets `ES2022` + `moduleResolution: "bundler"` + `strict: true`; `.gitignore` excludes `node_modules/` and `dist/`.
- [ ] **T2** — Install and lockfile. estimate_minutes: 10. Files: `mcps/slack/package-lock.json`, `mcps/slack/node_modules/` (gitignored). DoD: `npm install` completes clean; `package-lock.json` committed.
- [ ] **T3** — Token-loader module. estimate_minutes: 30. Files: `mcps/slack/src/tokens.ts`. DoD: exports `loadTokens()` that reads `SLACK_BOT_TOKEN` + `SLACK_USER_TOKEN` from env, throws a typed error naming the missing var when absent; exports `DUONG_USER_ID` + `SLACK_TEAM_ID` with env overrides and defaults `U03KDE6SS9J` / `T18MLBHC5`. No MCP handlers yet.
- [ ] **T4** — Bootstrap stub `src/server.ts`. estimate_minutes: 20. Files: `mcps/slack/src/server.ts`. DoD: minimal stdio MCP server that registers zero tools and starts cleanly; imports `loadTokens()` and fails fast on missing tokens; used by C2 tests to assert "no tool found" errors.
- [ ] **T5** — `start.sh` entrypoint + header comment in secret file. estimate_minutes: 20. Files: `mcps/slack/scripts/start.sh`, `secrets/slack-bot-token.txt` (edit only — add `# contains both bot_token= and user_token=` header per OQ1). DoD: `start.sh` matches §5 contract exactly (reads both tokens, exports as env, `exec npx -y tsx src/server.ts`); `chmod +x`; running it with missing file or missing keys exits non-zero with clear stderr. **[TOP-LEVEL]** because `secrets/slack-bot-token.txt` is in the `strawberry-agents/` repo (gitignored) — Ekko must edit it out-of-band, not in the `mcps/slack/` commit.

**C1 commit** (in `mcps/slack/` repo): `chore: scaffold custom slack mcp (T1-T5)`.

### Phase C2 — xfail integration tests (commits in `strawberry/mcps/slack/`)

All tests use `vitest`, spawn `src/server.ts` via stdio MCP client, and mock `@slack/web-api`'s `WebClient` via `vi.mock` to avoid real Slack calls. Must FAIL against C1 HEAD (no handlers registered → every tool call errors with "tool not found"). Rule 12 satisfied.

- [ ] **T6** — Test harness. estimate_minutes: 40. Files: `mcps/slack/test/harness.ts`, `mcps/slack/vitest.config.ts`. DoD: `harness.ts` exports `spawnServer()` returning a connected MCP client + a `mockWebClient` handle for asserting `chat.postMessage` / `reactions.add` / etc. calls; `vitest.config.ts` enables `test.globals`, points at `test/**/*.test.ts`.
- [ ] **T7** — Bot-token-routed tool tests. estimate_minutes: 45. Files: `mcps/slack/test/bot-tools.test.ts`. DoD: xfail tests for `notify_duong`, `post_as_bot`, `reply_in_thread(as="bot")`, `add_reaction` — assert (a) call routes through `botClient`, (b) `notify_duong` passes `channel="U03KDE6SS9J"`, (c) `thread_ts` propagates when provided, (d) zod rejects missing required args.
- [ ] **T8** — User-token-routed tool tests. estimate_minutes: 45. Files: `mcps/slack/test/user-tools.test.ts`. DoD: xfail tests for `post_as_duong`, `reply_in_thread(as="duong")`, `read_channel_history`, `read_thread`, `read_dm`, `list_users`, `list_channels`, `resolve_user` — assert (a) each routes through `userClient`, (b) API method and args match §2 table, (c) `read_dm` does `conversations.open` → `conversations.history` sequence.
- [ ] **T9** — `from_agent` prefix tests (OQ2). estimate_minutes: 20. Files: `mcps/slack/test/from-agent.test.ts`. DoD: xfail tests asserting `notify_duong({text, from_agent: "evelynn"})` posts `"[evelynn] <text>"`; omitting `from_agent` posts bare `text`; same behaviour for `post_as_bot` and `post_as_duong`.
- [ ] **T10** — Error path tests. estimate_minutes: 40. Files: `mcps/slack/test/errors.test.ts`. DoD: xfail tests cover (a) missing `SLACK_BOT_TOKEN` env → server fails fast on boot with typed error; (b) Slack returns `ok:false, error:"channel_not_found"` → MCP error response shape; (c) malformed JSON from SDK mock → graceful MCP error, no crash; (d) 429 retry engages (assert `retryConfig.fiveRetriesInFiveMinutes` on both clients via SDK constructor-call inspection).
- [ ] **T11** — List/resolve shape tests. estimate_minutes: 25. Files: `mcps/slack/test/list-shapes.test.ts`. DoD: xfail tests assert `list_users({query})` filters on `name`/`real_name`/`profile.display_name` client-side; `list_channels({member_only: true})` filters by `is_member`; `resolve_user("@duong")` strips `@` and returns `{user_id, real_name, tz}`.

**C2 commit** (in `mcps/slack/` repo): `chore: xfail tests for all 11 slack mcp tools (T6-T11)` — must be run against C1 HEAD and confirmed red before implementation.

### Phase C3 — Handler implementation (commits in `strawberry/mcps/slack/`)

All tasks edit `mcps/slack/src/server.ts`. Order matters only in that T12–T14 must land before any tool handler compiles.

- [ ] **T12** — WebClient construction + retry config (OQ3). estimate_minutes: 20. Files: `mcps/slack/src/server.ts`. DoD: `botClient` and `userClient` instantiated with `retryConfig: RetryOptions.fiveRetriesInFiveMinutes`; exported for handler use; T10 retry-config test passes.
- [ ] **T13** — Shared zod schemas + response-envelope helper. estimate_minutes: 25. Files: `mcps/slack/src/server.ts`. DoD: common schemas (`channelId`, `threadTs`, `text`, `userId`) defined once; helper `okEnvelope(payload)` / `errEnvelope(slackError)` returns MCP-compliant response shapes.
- [ ] **T14** — `from_agent` prefix helper (OQ2). estimate_minutes: 10. Files: `mcps/slack/src/server.ts`. DoD: `applyAgentPrefix(text, from_agent?)` returns `"[${from_agent}] ${text}"` when provided, else `text`; unit-tested inline.
- [ ] **T15** — `notify_duong` handler. estimate_minutes: 20. Files: `mcps/slack/src/server.ts`. DoD: zod schema `{text, thread_ts?, from_agent?}`; calls `botClient.chat.postMessage({channel: DUONG_USER_ID, text: applyAgentPrefix(...), thread_ts})`; T7 + T9 subsets pass.
- [ ] **T16** — `post_as_bot` + `post_as_duong` handlers. estimate_minutes: 25. Files: `mcps/slack/src/server.ts`. DoD: both handlers with `{channel_id, text, thread_ts?, from_agent?}`; correct client routing; T7 + T8 + T9 subsets pass.
- [ ] **T17** — `reply_in_thread` dispatch handler. estimate_minutes: 20. Files: `mcps/slack/src/server.ts`. DoD: zod enum `as: "bot"|"duong"` default `"bot"`; required `thread_ts`; delegates to `post_as_bot`/`post_as_duong` internals; T7 + T8 reply subsets pass.
- [ ] **T18** — `add_reaction` handler. estimate_minutes: 15. Files: `mcps/slack/src/server.ts`. DoD: schema `{channel_id, timestamp, emoji}`; calls `botClient.reactions.add`; T7 subset passes.
- [ ] **T19** — `read_channel_history` + `read_thread` + `read_dm` handlers. estimate_minutes: 40. Files: `mcps/slack/src/server.ts`. DoD: three handlers per §2 table; `read_dm` performs `conversations.open` → `conversations.history`; cursor/limit defaults applied; T8 read subset passes.
- [ ] **T20** — `list_users` + `list_channels` handlers. estimate_minutes: 35. Files: `mcps/slack/src/server.ts`. DoD: `users.list` with client-side query filter; `conversations.list` with `types=public_channel,private_channel` and `is_member` filter when `member_only=true`; T11 passes.
- [ ] **T21** — `resolve_user` handler. estimate_minutes: 20. Files: `mcps/slack/src/server.ts`. DoD: strips leading `@`; searches `users.list` by `name`/`display_name`/`real_name`; returns `{user_id, real_name, tz}` or typed `user_not_found` error; T11 resolve subset passes.
- [ ] **T22** — Error-envelope plumbing + final green. estimate_minutes: 25. Files: `mcps/slack/src/server.ts`. DoD: all Slack API errors surface as MCP errors via `errEnvelope`; missing-token boot error wired; all of T7–T11 green; `npm test` clean.

**C3 commit** (in `mcps/slack/` repo): `feat: implement 11 slack mcp tool handlers (T12-T22)`.

### Phase C4 — Migration (commits in `strawberry-agents/`)

Cross-repo phase. `start.sh.bak-dual` rename happens in the `mcps/slack/` repo as a separate tiny commit; everything else is one atomic commit in `strawberry-agents/`.

- [ ] **T23** — Rename old dual-wrapper `start.sh` → `start.sh.bak-dual`. estimate_minutes: 5. Files: `mcps/slack/scripts/start.sh.bak-dual` (renamed from old content preserved pre-T5). DoD: the prior npm-wrapper script is preserved under the `.bak-dual` name for one-week rollback per §6; commit in `mcps/slack/` repo: `chore: retain old dual-wrapper slack start.sh as bak-dual for rollback`.
- [ ] **T24** — `.mcp.json` — drop `slack-bot` + `slack-user`, add single `slack` entry. estimate_minutes: 15. Files: `/Users/duongntd99/Documents/Personal/strawberry-agents/.mcp.json`. DoD: matches §6 spec exactly (command `bash`, args pointing at `mcps/slack/scripts/start.sh`, env `SLACK_TEAM_ID` + `DUONG_USER_ID`); JSON valid. **[TOP-LEVEL]** — `.mcp.json` is coordinator-owned top-level infra.
- [ ] **T25** — Rewrite `agents/memory/duong.md` Slack section. estimate_minutes: 15. Files: `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/memory/duong.md`. DoD: lines 12–29 replaced with the 5-line `## Slack` block from §7 verbatim; no tool-name or token-prefix strings remain; success criterion §10.3 satisfied. **[TOP-LEVEL]** — `agents/memory/duong.md` is a shared top-level memory file.
- [ ] **T26** — Ekko MEMORY.md supersede note. estimate_minutes: 5. Files: `/Users/duongntd99/Documents/Personal/strawberry-agents/agents/ekko/memory/MEMORY.md`. DoD: L154 dual-wrapper note gets a one-line `**Superseded 2026-04-24** by plans/approved/personal/2026-04-24-custom-slack-mcp.md` appended; historical wiring detail preserved.
- [ ] **T27** — Grep-verify success criteria §10.4 + restart-session smoke. estimate_minutes: 10. Files: none (verification only). DoD: `grep -rn "slack-bot\|slack-user" strawberry-agents/ --exclude-dir=worktrees --exclude-dir=learnings --exclude=*.bak-dual` returns zero hits; after Claude-session restart, `mcp__slack__notify_duong("migration smoke")` delivers DM per §10.2.

**C4 commit** (in `strawberry-agents/` repo, atomic): `chore: migrate to custom slack mcp (T24-T26)` — covers `.mcp.json`, `agents/memory/duong.md`, `agents/ekko/memory/MEMORY.md`.

### Open questions

None. OQ1–OQ4 all resolved in the plan body or at dispatch. No fresh OQs surfaced by this breakdown.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Ownership is clear (ekko), author is lux, all four open questions are resolved inline (OQ1 by Evelynn, OQ2–4 by Lux with recommended defaults). The tool catalog encodes intent — each of the 11 tools has a named invariant and routing rule, with `reply_in_thread`'s enum dispatch justified on load-bearing identity dispatch grounds rather than speculative extensibility. TypeScript choice is argued from concrete affordances (upstream parity, typed `@slack/web-api`, zod schemas) not dogma. Migration scope is genuinely lean: three files edited atomically, one-release rollback window via retained `start.sh.bak-dual`, and success criteria are measurable (grep-verifiable, <2min rollback). Simplicity-first throughout; no WARN.
