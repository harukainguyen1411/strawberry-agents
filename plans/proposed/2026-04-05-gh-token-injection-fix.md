---
status: proposed
owner: pyke
---

# Fix: GH_TOKEN Not Reaching Agent Sessions

## Problem

Agents launch but `$GH_TOKEN` is empty in the session (`echo $GH_TOKEN | wc -c` returns 1). The token file exists, has correct permissions (600), and contains the harukainguyen1411 PAT — but the token is not present in the launched shell.

## Root Cause

Shell scoping bug in `mcps/agent-manager/server.py`, `launch_agent`.

The current command:
```sh
GH_TOKEN=$(cat '/path/to/token') GITHUB_TOKEN=$(cat '/path/to/token') cd /workspace && export GH_TOKEN GITHUB_TOKEN && claude --model ...
```

**`VAR=$(cmd) some_command`** sets an environment variable for that **single command only** (`cd` in this case). It does NOT create a shell variable. The subsequent `export GH_TOKEN GITHUB_TOKEN` then exports **empty** shell variables — the cat output was never stored.

This is a standard shell scoping pitfall: inline `VAR=value cmd` is not the same as `VAR=value; cmd`.

## Fix

Change the injection to use `export VAR=$(cmd)`:

```sh
export GH_TOKEN=$(cat '/path/to/token') && export GITHUB_TOKEN=$(cat '/path/to/token') && cd /workspace && claude --model ...
```

`export VAR=$(cmd)` assigns the command substitution to the shell variable and exports it in one step — persisting across subsequent `&&`-chained commands.

## File to Change

`mcps/agent-manager/server.py`, line ~396:

```python
# CURRENT (broken)
launch_cmd = f"GH_TOKEN=$(cat '{quoted_path}') GITHUB_TOKEN=$(cat '{quoted_path}') cd {WORKSPACE} && export GH_TOKEN GITHUB_TOKEN && claude --model {model_flag}"

# FIXED
launch_cmd = f"export GH_TOKEN=$(cat '{quoted_path}') && export GITHUB_TOKEN=$(cat '{quoted_path}') && cd {WORKSPACE} && claude --model {model_flag}"
```

## Verification

After fix, launch any agent and verify:
```sh
echo $GH_TOKEN | wc -c      # should return 94 (token length + newline), not 1
gh api user --jq '.login'    # should return harukainguyen1411
```

## Security Note

The `export VAR=$(cat file)` form still does not print the token value in the shell command visible in scrollback — the substitution happens in the shell's own process. The token value never appears as a literal string in the iTerm write text command. Security posture is unchanged.

## Scope

Single-line change in `mcps/agent-manager/server.py`. No other files need changes.
