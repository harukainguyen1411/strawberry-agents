# Subagent definition caching — mid-session edits don't take effect

**Date:** 2026-04-08 (Mac evening session)
**Context:** Enforcing Rule 15 (every `.claude/agents/<name>.md` must declare `model:`) mid-session.

## What happened

Duong flagged that running every subagent on Opus was wasteful and added a new rule: every `.claude/agents/<name>.md` must declare a `model:` frontmatter field. I had a general-purpose subagent add `model: opus|sonnet|haiku` to all 7 existing agent definitions. The edit committed cleanly (`eb6c0a9`). I then spawned Katarina multiple times for the protocol migration, expecting Sonnet. She ran on Opus every time.

Caught via Duong's Max plan usage dashboard screenshot: weekly Sonnet-only usage = 0%. Not "low" — actually zero. Nothing had touched Sonnet tonight despite the frontmatter fix.

## Root cause

Claude Code loads all `.claude/agents/<name>.md` files into an in-memory subagent registry at session startup. Once loaded, edits to those files on disk do NOT trigger a re-read. The session's understanding of each subagent type is frozen at launch.

When I spawned `subagent_type: katarina`, the Agent tool looked up Katarina in the cached registry. The cached version had no `model:` frontmatter (because my edit landed post-startup). Per the Agent tool's precedence rules, no definition-level model → inherit from parent → Opus.

The Agent tool description says: *"Optional model override for this agent. Takes precedence over the agent definition's model frontmatter. If omitted, uses the agent definition's model, or inherits from the parent."* That's correct for the semantics — but the "agent definition's model" reads from the cached registry, not the file on disk.

## The fix (two layers)

**This session's workaround:** pass `model:` explicitly on every Agent tool call. The explicit override takes precedence over both the cached definition and any inheritance. First successful test was Katarina spawning with `model: "sonnet"` for the clean-jsonl resolver fix — confirmed by Sonnet quota beginning to move.

**Permanent fix:** restart the Claude Code session. A fresh session re-reads all `.claude/agents/*.md` files and caches the current (post-edit) versions. This is why tonight's session is being closed immediately after the Rule 15 rollout — the next Evelynn will honor the frontmatter naturally.

## Generalizable lesson

**Any mid-session edit to a subagent profile (tools allowlist, model, description, system prompt body) requires either explicit per-spawn overrides OR a session restart to take effect.** This applies to:

- `model:` field — silent Opus inheritance, quota bleed
- `tools:` field — subagent keeps the old tool surface, might fail or succeed with wrong capability
- Description — routing won't update; the old description still drives auto-invocation decisions
- Body — system prompt stays stale

Practical implications:

1. When you ship a rule that mandates a profile change (like Rule 15), plan for a session restart as part of the rollout. Don't try to "enforce it live."
2. If you must operate post-edit before restart, pass the relevant parameters explicitly at every spawn. For model specifically: `model: "sonnet"` (or `"opus"` / `"haiku"`) on every Agent tool call.
3. Adding a NEW `.claude/agents/<name>.md` file mid-session makes the new subagent type UNAVAILABLE until restart — the registry can't discover it.
4. Session-end handoffs should flag "fresh session will pick up X" for anything that was edited but couldn't be tested live.

## Related memories

- `feedback_agent_model_explicit.md` — tightened during this session to cover the caching trap and first-failure case
- `feedback_no_general_purpose_fallback.md` — tightened during this session to require explicit `model:` override when general-purpose is unavoidable
- CLAUDE.md Rule 15 — the rule that triggered the discovery

## Open question for a future plan

Does Claude Code have a hot-reload mechanism for subagent definitions that I missed? (Worth a quick doc check next session — if there is one, the whole workaround becomes unnecessary. If there isn't, that's feature-request territory for the Claude Code team.)
