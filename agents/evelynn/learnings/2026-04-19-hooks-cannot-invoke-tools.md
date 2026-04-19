# Hooks cannot invoke in-session tools — additionalContext is the ceiling

**Context:** Duong asked for a hook that auto-creates a TaskList entry after every Agent tool call. My first instinct was "not possible, hooks are shell scripts outside the model loop." He pushed back correctly — verify, don't guess. Dispatched claude-code-guide to check.

**Finding:** verified. Claude Code hooks (PostToolUse et al.) are isolated shell scripts. They cannot call in-session tools like TaskCreate. The ceiling of hook→model communication is `hookSpecificOutput.additionalContext` — a string injected into Claude's context on the next turn. Claude *reads* it and *chooses* whether to act. No forced tool call, no direct tool invocation.

**Applied pattern for the TaskCreate-on-Agent-spawn use case:**

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Agent",
      "hooks": [{
        "type": "command",
        "command": "jq ... | printf '{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"REMINDER: TaskCreate for subagent X — Y. Set owner=X.\"}}' ..."
      }]
    }]
  }
}
```

This lands in commit `3c7d3c4` of strawberry-agents. Verified working across the session — every Agent spawn triggers the reminder, Evelynn creates the task reflexively.

**Lesson for future hook design:**
1. Do not assume — verify via claude-code-guide or docs.
2. additionalContext is the universal hook→model channel. Any behavior that needs "the model should do X next" should shape the additionalContext string, not try to invoke X directly.
3. If you need durable state, write to disk and have the additionalContext point the model at the file — but most of the time an in-context reminder is enough.

**Secondary lesson:** Verify-before-ruling beats yo-yo debate. Duong asked "are you sure?" — dispatched a check, came back in a minute, answer locked. Cheaper than arguing from priors.
