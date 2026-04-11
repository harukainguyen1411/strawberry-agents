# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 AM (CLI, opus-4.6): Git workflow, 4 PRs, ops separation with Syndra.
- 2026-04-03 PM (CLI, opus-4.6): Main audit + housekeeping. PR #8.
- 2026-04-03 Late PM (CLI, opus-4.6): Memory commit gap + monorepo migration plan.
- 2026-04-03 Evening (CLI, opus-4.6): Migration exec (PR #10), pipeline infra (PR #11), VPS setup.
- 2026-04-03 Late evening (CLI, opus-4.6): VPS SSH fix — ssh.socket issue on Ubuntu 24.04.
- 2026-04-04 Night (CLI, opus-4.6): Discord-CLI integration — full infra deploy + two-pass bridge.
- 2026-04-04 AM (CLI, opus-4.6): Incident response — memory wipe + MCP config loss.
- 2026-04-04 PM (CLI, opus-4.6): Ops day — workflow policies, gitleaks, branch protection, PRs #15-#24.
- 2026-04-05 AM (CLI, sonnet-4.6): B1 commit ratio tracker (PR #26), GH_TOKEN injection fix (PR #29 review).
- 2026-04-05 PM (CLI, opus-4.6): Resolved harukainguyen1411 write access.
- 2026-04-05 Late PM (CLI, opus-4.6): GH auth lockdown (PR #33), main divergence plan, Telegram token audit, zsh fix.
- 2026-04-08 (subagent, opus-4.6[1m]): Reviewed Evelynn's age-based encrypted-secrets plan. Approve-with-changes. 8 required edits, key ones: argv leak in `secret-use.sh @SECRET@` → use env-into-child-only; gitleaks allowlist for `.age`; NTFS icacls (chmod is no-op on Windows); compromise = rotate at provider not just re-encrypt (git history forever); pre-commit guards for plaintext leaks into agent memory.
- 2026-04-08 (subagent, opus-4.6[1m]): Bridge clarification — no Claude Desktop↔Claude Code bridge; transport is Remote Control (`claude --remote-control`). Revised encrypted-secrets Required Change 1 (bootstrap discipline) to name Remote Control and flag its logging/persistence/auth as research follow-up (open question, non-blocking). Authored `plans/proposed/2026-04-08-cafe-from-home.md` — recommends Cloudflare Tunnel + Access over ZeroTier/Twingate, Tailscale explicitly ruled out (work Mac). Restart wrapper deferred to follow-up plan.
- 2026-04-09 (subagent, opus-4.6[1m]): Authored `plans/proposed/2026-04-09-autonomous-pr-lifecycle.md`. Two-identity model: `harukainguyen1411` = Worker (opens PRs, cannot merge), new `strawberry-bot` collaborator account = Gatekeeper (reviews + merges). CodeRabbit = required status check (blocking on security/bug, advisory on style). Lissandra (Sonnet) logic review + Syndra (Opus) architecture review + CodeRabbit = structured review protocol with 13-item checklist in `ops/review/checklist.md`. Branch protection JSON committed to `ops/github/branch-protection.json`, applied via script, weekly drift audit. Bot runs as Windows NSSM poller under `claude -p` (Max subscription, not API) with kill-switch. PAT stored age-encrypted `secrets/encrypted/strawberry-bot-pat.age`, classic scope `repo`, 90-day rotation. Open questions for Duong: (a) CODEOWNERS + Pyke as required 4th reviewer on `.github/`, `secrets/`, `ops/github/`, `scripts/pre-commit-*`; (b) bot permission to close stale failed PRs.
- 2026-04-09 (subagent, delivery-pipeline team, opus-4.6[1m]): Delivery pipeline security assessment REV 3 — all-local on Windows under NSSM, Cloud Run decommissioned.
- 2026-04-09 (subagent, opus-4.6[1m]): Authored `plans/proposed/2026-04-09-windows-autonomous-isolation.md`. Mac/Windows split: Mac = interactive (Evelynn, full closing protocol), Windows = autonomous coder-worker (no agent state commits). Key findings: `git add .` in git.ts must be scoped to `apps/myapps/`; commit prefix uses `fix:` not `chore:`; systemPromptPath default is stale. 4 must-do changes (M1-M4), 2 should-do (S1-S2). No conflict risk since Windows never pushes to main. Hard invariant: Mac and Windows must never share the same git clone.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main (except agent state).
- Three-tier commit policy: agent state → main direct; ops config → main direct; feature work → PR.
- gitleaks pre-commit hook for secret scanning.
- Branch protection on main + two-account model (Duongntd = owner bypass, harukainguyen1411 = agent account).
- Git safety: commit immediately, use worktrees for concurrent branches, safe-checkout.sh wrapper.
- Ops separation (Option 3b): ephemeral -> ~/.strawberry/ops/, durable stays in git.
- Journal/ and last-session.md -> gitignored.
- Agent state belongs on main only. Never commit agents/ to feature branches.
- Session closing order: all agents first, Pyke verifies, Evelynn closes last.
- Agent memory commits: direct to main, no PRs.
- Discord-CLI: two-pass bridge — triage (cheap) + delegation (full Evelynn).
- GH auth lockdown: PreToolUse hook + GH_TOKEN env lock + credential helper + audit trail.

## Infrastructure
- VPS: Hetzner CX22, 37.27.192.25, Ubuntu 24.04 (Helsinki DC 2)
  - Runner: strawberry-runner (self-hosted,linux,x64), systemd managed
  - PM2 processes: discord-bot, discord-bridge

## Open items
- PR #33 (gh-auth-lockdown) — open, awaiting merge
- PR #26 (commit-ratio-tracker) — open, awaiting merge
- Telegram token in .mcp.json — plaintext, needs rotation + move to secrets/
- Main divergence plan — proposed, awaiting approval
- 8 stale merged branches — need deletion
- SubagentStop hook plan proposed (2026-04-11) — needs stdin shape testing before implementation

## Security lessons
- NEVER auto-resolve agent state conflicts. Always manually merge.
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
- Ubuntu 24.04 uses ssh.service + ssh.socket, not sshd.service.
- PM2 env_file is not a real option — use wrapper scripts.
- Claude CLI: use -p not --message, redirect stdin with < /dev/null.
- Never leave work uncommitted before any git branch operation.
- Always check current branch before committing.
- Fine-grained PATs can't access collaborator repos — use classic PAT with repo scope.
- zsh history expansion breaks `!` in double-quoted strings — use single quotes for git credential helpers.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.