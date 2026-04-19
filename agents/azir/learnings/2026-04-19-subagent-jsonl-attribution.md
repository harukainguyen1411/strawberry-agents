# 2026-04-19 — Subagent attribution lives on disk, not in the hook

## Lesson

When designing per-subagent token/cost attribution, do NOT reach for the SubagentStop hook first. Its payload has no usage fields (verified at `https://code.claude.com/docs/en/hooks`): only `session_id`, `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active`, `cwd`, `permission_mode`, `hook_event_name`.

The data you actually want is already on disk, written by the harness, per-spawn, fully labeled:

- `~/.claude/projects/<slug>/<session>/subagents/agent-<id>.jsonl` — every assistant line has a full `usage` block (input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens, server_tool_use.*). First user line has the verbatim Evelynn prompt (task identity).
- `~/.claude/projects/<slug>/<session>/subagents/agent-<id>.meta.json` — two fields: `agentType` (roster name) and `description` (the Task-tool label, human-readable, <=80 chars, usually a clean task handle).

## Consequence for design

A scanner over `subagents/` on the existing cron is simpler and strictly more complete than any hook-based capture. It handles:

- Stateless agents that skip `/end-subagent-session` (Yuumi, Skarner) — captured.
- Crashed/aborted spawns — captured up to last assistant turn.
- Retroactive backfill — free, because the JSONLs are already there.
- Idempotency — immutable closed JSONLs, cache by mtime.

## Anti-pattern to avoid

Adding a sidecar-write to `/end-subagent-session` looked seductive (explicit, clean) but silently loses every spawn that skips the skill. Observability must not depend on cooperative agents.

## Tripwire

If Anthropic adds usage fields to SubagentStop payload later, the scanner still wins — but a hook *could* handle near-realtime (vs. 10-min cron). Revisit only if Duong wants sub-minute freshness.

## References

- ADR: `plans/proposed/2026-04-19-usage-dashboard-subagent-task-attribution.md`.
- Evidence: `~/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry-agents/1283cce9-*/subagents/agent-a142121c740c050bc.{jsonl,meta.json}`.
- Parent ADR: `plans/approved/2026-04-19-claude-usage-dashboard.md`.
