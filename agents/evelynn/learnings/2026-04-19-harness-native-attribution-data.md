# Subagent attribution data is already on disk — just scan it

**Context:** Duong asked for per-subagent per-task token attribution in the usage dashboard. My first frame was "wire a SubagentStop hook that logs tokens." Azir verified against Claude Code docs: SubagentStop payload has no usage fields. Dead end.

**Real mechanism:** Claude Code's harness writes two files for every subagent spawn, in every project, always:
- `~/.claude/projects/<slug>/<session-id>/subagents/agent-<id>.jsonl` — full per-turn transcript including `usage` blocks (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`) on every assistant message
- `~/.claude/projects/<slug>/<session-id>/subagents/agent-<id>.meta.json` — `{agentType, description}` with the Task-tool label Evelynn passed

**Implication:** all subagent observability should flow from those files. No capture code needed. A post-hoc scanner walks the directory tree, sums usage per `agent-<id>`, joins with meta.json for agent name + task description, writes an aggregate JSON. Works retroactively on every spawn that's ever happened.

**Also:** `total_tokens` should explicitly exclude `cache_read_input_tokens` — loops over-read cache but are not billed fresh.

**Use this for:**
- Cost attribution (who's burning the Max quota)
- Loop-detection (agent with wildly outlier turn counts / cache-creation spikes)
- Task-level cost observability (e.g. "PR #25 drive loop burned 60k tokens")
- Any future "which agent produced which commit" cross-reference

**Don't use it for:**
- Real-time streaming (scanner runs on cron, not live — v2 concern)
- Live-agent state (the jsonl is append-only and incomplete mid-spawn)

**Key cross-reference:** `plans/approved/2026-04-19-usage-dashboard-subagent-task-attribution.md` (post v1/v2 split) documents this. T0 of v1 = SubagentStop hook amendment to persist `closed_cleanly` sentinel into `~/.claude/strawberry-usage-cache/subagent-sentinels/<session_id>` (since `/tmp` is volatile).
