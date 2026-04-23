# 2026-04-23 — PR #34 subagent-denial-probe phase-1 review

## PR

- harukainguyen1411/strawberry-agents#34 — Karma-owned phase-1 diagnostic
  probe for subagent Edit/Write/Bash permission denials
- Branch: `feat/subagent-denial-probe`
- Files: `scripts/subagent-denial-probe.sh` (new), `scripts/hooks/tests/subagent-denial-probe.test.sh` (new, 20 tests), `.claude/settings.json` (PostToolUse wire-up), `scripts/hooks/test-hooks.sh` (aggregate wiring)

## Verdict

COMMENT (advisory LGTM) — two non-blocking suggestions, three cross-lane notes for Lucian.

## What end-to-end testing caught

Posting-without-looking would have missed:

1. **Read-only log dir path** — `mkdir -p ... || exit 0` handles the case where `dirname "$LOG_PATH"` is not writable; the subsequent `>> "$LOG_PATH"` also has `|| true`. Both belt and braces are needed, because `mkdir -p` can succeed if the dir already exists even if it's unwritable. Verified by `chmod a-w` on parent — got stderr "Permission denied" but exit 0 as required.

2. **Concurrent writers via `>>` append** — 10 parallel probe invocations all produced valid JSON rows. POSIX guarantees `write(2)` of size < `PIPE_BUF` is atomic with O_APPEND; macOS `PIPE_BUF=512` and these rows are ~200 bytes. Safe as-is. Would not be safe for multi-kilobyte payloads.

3. **`jq -c '.tool_input // {} | keys'` on non-object** — exits rc=5 on string or array. The `|| printf '[]'` fallback catches it. Row is still written with empty `tool_input_keys`. Good behavior for a non-blocking diagnostic but loses fidelity. Flagged S1.

4. **Empty-string vs unset envs** — `${CLAUDE_AGENT_NAME:-${STRAWBERRY_AGENT:-unknown}}` handles both uniformly (colon form). The subsequent `[ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"` is redundant but not a bug.

5. **Shell metacharacters in agent name** — `jq --arg agent_name "name;rm -rf /"` escapes properly. No command execution. No injection surface via stdin either — `$INPUT` is always argv to printf/jq, never interpolated.

## POSIX portability checklist (reusable)

For any script targeted at Rule 10 scope:
- [ ] `#!/usr/bin/env bash` (POSIX-portable bash, not pure sh)
- [ ] No `[[ ]]` — use `[ ]`
- [ ] No `<<<` here-strings — use `printf '%s' "$x" | ...`
- [ ] No `${var,,}` / `${var^^}` — use `tr '[:upper:]' '[:lower:]'`
- [ ] No bash arrays — use positional params or space-separated strings
- [ ] `date -u +...` works everywhere; `date -u -Iseconds` is GNU-only
- [ ] `mkdir -p` / `rm -f` are POSIX
- [ ] `case $x in *"substr"*) ...;; esac` is POSIX and works for substring scan
- [ ] shellcheck clean at default level

## Cross-lane (Lucian) notes for plan-fidelity reviews

- Plan env var `CLAUDE_SUBAGENT_NAME` → impl `CLAUDE_AGENT_NAME` (+ `STRAWBERRY_AGENT` fallback)
- Plan JSONL `dispatch_ordinal` → impl omits (tied to unresolved OQ1)
- Plan test path `tests/hooks/test_subagent_denial_probe.sh` → impl `scripts/hooks/tests/subagent-denial-probe.test.sh`

Each could be intentional resolution of a plan open question. Flag, don't block.

## Scoping caveat worth remembering

`PostToolUse` with `"matcher": "Edit|Write|Bash"` fires on **every** matching tool call in the coordinator session, including the coordinator's own. The "subagent" framing of the probe is aspirational — the log will include parent-context rows. Phase-2 consumer must correlate by `session_id` or filter explicitly. Plan OQ1 ("does PostToolUse fire inside child subagent context?") is still open — if it doesn't, the probe catches only parent calls and is misnamed.

## Lane identity

`scripts/reviewer-auth.sh --lane senna` preflight: `strawberry-reviewers-2` ✓.
Lucian's lane (`strawberry-reviewers`) had already posted APPROVED; my COMMENT
slotted in separately — the two-lane architecture held. No masking.

## Friction

- `safe-checkout.sh` denied by sandbox because I had an empty stash in flight (false positive, but correct precaution — the sandbox notices working-tree risk even when my stash was a no-op). Workaround: fetched files via `gh api repos/.../contents/<path>?ref=feat%2F...` with URL-encoded slash in the branch ref. `-f ref=...` doesn't set a URL query param, you have to embed in the path.
- `gh pr review --comment --body-file ...` outputs nothing on success, only on error. Always verify via `gh api repos/.../pulls/N/reviews` after posting.
