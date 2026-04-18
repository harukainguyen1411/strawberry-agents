# 2026-04-18 — Claude Code statusLine Setup

## What was done
Created `/Users/duongntd99/.claude/statusline-command.sh` — custom statusLine script.
Added `statusLine` key to `~/.claude/settings.json`.

## JSON schema key fields
- `.model.display_name` — model name
- `.context_window.remaining_percentage` (preferred) → `.context_window.used_percentage` → fallback: `.context_window.total_input_tokens / .context_window.context_window_size`
- `.exceeds_200k_tokens` — bool flag for >200k context
- `.cost.total_cost_usd` — session cost
- `.workspace.current_dir` — use for git -C (not bare `pwd`)
- `.workspace.git_worktree` — set if already in a worktree per Claude
- `.transcript_path` — path to JSONL transcript
- Todos: `~/.claude/todos/<session_id>.json` — list with `status` field

## Worktree detection
Compare `git rev-parse --git-dir` vs `--git-common-dir`. In a worktree, `--git-dir` = `.git/worktrees/X`, while `--git-common-dir` = `.git`. When they differ, it is a worktree.

## Color thresholds
- ctx: red < 10% remaining, yellow < 25%
- cost: yellow > $1, red > $5
- branch: yellow if dirty (*), green if clean
