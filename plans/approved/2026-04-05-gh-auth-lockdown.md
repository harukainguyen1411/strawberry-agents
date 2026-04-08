---
title: GitHub Auth Switching Lockdown
status: approved
owner: pyke
created: 2026-04-05
---

# GitHub Auth Switching Lockdown

## Problem

Agents are launched under the `harukainguyen1411` account (collaborator, subject to branch protection). But any agent can run `gh auth switch` or `gh auth login` via Bash to pivot to `duongntd99` (repo owner, bypasses branch protection). This defeats the two-account security model.

## Threat Surface

1. `gh auth switch` — direct account swap
2. `gh auth login` — authenticate as a different user
3. `gh auth setup-git` — reconfigure git credential helper
4. `GH_TOKEN` override — agent sets env var to a different token
5. `git remote set-url` — swap remote to use a different credential
6. Direct API calls (`curl`) with Duong's token (if discoverable)

## Solution: Multi-Layer Defense

### Layer 1: Claude Code PreToolUse Hook (Primary)

Add a `PreToolUse` hook in the project `.claude/settings.json` that intercepts all Bash tool calls and blocks dangerous patterns.

**Hook script:** `scripts/gh-auth-guard.sh`

```bash
#!/bin/bash
# Reads the Bash command from stdin (JSON with "input" field containing "command")
# Exit 2 = block the tool call with a message

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.input.command // empty')

# Patterns to block
BLOCKED_PATTERNS=(
  "gh auth switch"
  "gh auth login"
  "gh auth setup-git"
  "gh auth token"
  "git credential"
  "git remote set-url"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qi "$pattern"; then
    echo '{"decision":"block","reason":"Blocked by Pyke: GitHub auth switching is not permitted. You are locked to harukainguyen1411."}' >&2
    exit 2
  fi
done

exit 0
```

**settings.json entry:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": "bash scripts/gh-auth-guard.sh"
      }
    ]
  }
}
```

### Layer 2: GH_TOKEN Environment Lock

Set `GH_TOKEN` in the agent launch environment (already done for VPS via secrets/agent-github-token). For local CLI sessions, ensure the launch script exports `GH_TOKEN` from the secrets file before starting Claude Code.

When `GH_TOKEN` is set, `gh` CLI uses it exclusively and `gh auth switch` has no effect on API calls. This is a passive defense — even if Layer 1 is somehow bypassed, the token pins the identity.

**Action:** Update agent launch scripts to always `export GH_TOKEN=$(cat secrets/agent-github-token)` before invoking `claude`.

### Layer 3: Git Config Lock

Set the git credential helper to always use the agent token for github.com:

```bash
git config --local credential.https://github.com.helper '!f() { echo "password=$(cat /path/to/secrets/agent-github-token)"; }; f'
```

This ensures `git push` uses the agent token regardless of `gh auth` state.

### Layer 4: Audit Trail

Add a `PostToolUse` hook that logs all Bash commands containing `gh` or `git push` to `~/.strawberry/ops/git-audit.log` with timestamp and agent name. This doesn't block anything but provides an audit trail for review.

## Implementation Steps

1. Create `scripts/gh-auth-guard.sh` with the blocking logic above
2. Add PreToolUse hook to `.claude/settings.json`
3. Update agent launch scripts to export `GH_TOKEN`
4. Add git credential helper config to repo setup
5. Create PostToolUse audit hook script (`scripts/gh-audit-log.sh`)
6. Add PostToolUse hook to `.claude/settings.json`
7. Test: verify `gh auth switch` is blocked, `gh api user` returns harukainguyen1411

## Limitations

- Agents could theoretically read the token file at `secrets/agent-github-token` and use `curl` directly. Mitigation: this is already the agent's own token, so no privilege escalation.
- If Duong's personal token is discoverable on disk (e.g., `~/.config/gh/hosts.yml`), an agent could extract it. Mitigation: Layer 1 blocks `gh auth token` which is the easy path; reading arbitrary config files is harder to block without breaking legitimate file reads.
- The hook relies on pattern matching. Obfuscated commands (e.g., `eval`, base64 decode) could bypass it. Mitigation: agents are LLMs following instructions, not adversarial humans — pattern matching is sufficient for the threat model.

## Risk Assessment

Low risk. All layers are additive — they don't modify existing workflows. The PreToolUse hook only affects Bash calls matching specific patterns. False positives are unlikely since no legitimate agent workflow needs to switch GitHub accounts.
