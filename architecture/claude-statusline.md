# Claude Code Statusline — Usage Display

## Overview

`scripts/statusline/claude-usage.sh` is a small POSIX bash script wired to Claude Code's
`statusLine.command` hook. It reads the statusline JSON from stdin and prints a single
summary line to stdout. It never exits non-zero.

## Stdin JSON Schema (fields consumed)

| Field | Type | Description |
|---|---|---|
| `model.display_name` | string | Short model name shown at left of line |
| `context_window.used_percentage` | number | Context window fill % |
| `rate_limits.five_hour.used_percentage` | number | 5-hour rolling window usage % |
| `rate_limits.five_hour.resets_at` | integer | Unix epoch when 5h window resets |
| `rate_limits.seven_day.used_percentage` | number | 7-day rolling window usage % |
| `rate_limits.seven_day.resets_at` | integer | Unix epoch when 7d window resets |

All fields are optional; missing fields render as `--` placeholders.

## Output Format

```
<model> | ctx <N>% | 5h <P>% (resets HH:MM) | 7d <Q>% (resets <weekday>)
```

Example:

```
claude-sonnet-4-6 | ctx 12% | 5h 23% (resets 14:00) | 7d 41% (resets Sun)
```

## Color Thresholds

Colors are suppressed when stdout is not a TTY or `NO_COLOR` is set.

| Usage % | Color |
|---|---|
| ≤ 50% | Green |
| 51–80% | Yellow |
| > 80% | Red |

## Caveats

**Pro/Max-only**: The `rate_limits` object is only present for Pro and Max plan
accounts. Free or Team plan users will see `--` placeholders for 5h and 7d fields.
This is expected and handled gracefully.

**First-turn absence**: On the very first turn of a fresh session the statusline JSON
may not yet include `rate_limits` (Claude Code hasn't received a response with
rate-limit headers). The script degrades cleanly with `--` placeholders for that turn.

## Wire-up

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/strawberry-agents/scripts/statusline/claude-usage.sh"
  }
}
```

Use the **absolute path** — Claude Code invokes the command from the active project's
cwd, so a relative path will not resolve correctly across projects.

## Smoke Test

```sh
cat scripts/statusline/sample-payload.json | scripts/statusline/claude-usage.sh
```

## References

- Research note: `assessments/research/2026-04-26-claude-usage-statusline.md` (Lux, 2026-04-26)
- Plan: `plans/approved/personal/2026-04-26-statusline-claude-usage.md`
- Statusline schema: https://code.claude.com/docs/en/statusline
