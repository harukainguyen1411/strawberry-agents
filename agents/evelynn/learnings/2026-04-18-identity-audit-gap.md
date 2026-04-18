---
agent: evelynn
date: 2026-04-18
topic: identity misconfiguration blind spot
tags: [git, security, identity, audit, startup]
---

# Identity Audit Gap — git global config + gh keyring drift

## Summary

Built the Strawberry agent system with rules on account separation (harukainguyen1411 human, Duongntd agent), on never-leak-secrets, on every PR having proper review and attribution. Ran it for weeks. Didn't audit the one thing that silently powers every commit: `git config --global user.email` and `gh auth status`.

Result: every Strawberry commit in recent weeks was tagged `duong.nguyen.thai@missmp.eu` (work email leaked into personal repos), AND every agent push went under `duongntd99` (Duong's personal legacy handle, id 107381386) instead of `Duongntd` (the real agent account, id 103487096). Two separate leaks compounding.

Neither was caught by:
- Pre-commit hooks (none scanned identity)
- PR reviews (reviewers didn't look at commit author)
- Plan promote checks (Orianna checks paths, not authors)
- Session startup (no heartbeat auth check)

It was caught because **Jhin's review of PR #19 flagged a blob-SHA mismatch** on `reference.md`. Fixing that forced a retry, which surfaced the gitleaks config issue, which led me to check `git config --get-all --show-origin user.email`, which revealed the global work-email leak, which led me to `gh auth status`, which revealed the wrong-account leak.

## The fix

- `gh auth login` (device-code flow) as the real Duongntd account.
- `gh auth switch -u Duongntd` + logged out duongntd99.
- `git config --global user.email 103487096+Duongntd@users.noreply.github.com` + `user.name Duongntd`.
- PR #20 (merged) added `scripts/hooks/pre-commit-email-guard.sh` rejecting `@missmp.eu` / `@mmp.*` emails on personal repos.

## The generalizable lesson

**Identity is infrastructure.** It's not a "setup once and forget" concern — it can drift silently any time a tool inherits parent config (Cursor, VS Code, fresh clone from another machine, a corporate push of git defaults). For an agent system that routes work across accounts, identity audit belongs in the startup checklist alongside `heartbeat.sh`.

## Recommended follow-ups

1. **Add identity sanity check to `agents/health/heartbeat.sh`** — verify `gh auth status` shows the expected active account and `git config --global user.email` matches the expected noreply pattern. Fail loud if not.

2. **Pre-push hook for cross-account PRs** — if pushing to `harukainguyen1411/*`, assert `gh auth status` active is `Duongntd` (agent) and commit author email matches. Catches the "switched accounts mid-session" case.

3. **Session-start memory reconciliation** — when Evelynn boots, read `git config --global user.email` and compare against a `expected_identity` field in memory. Log discrepancies.

4. **Don't store PATs in the repo long-term** — the encrypted `github-triage-pat.age` went stale (401). Device-code flow via `gh auth login` is the right default for local accounts. Encrypted PATs are only for CI, and should have a rotation cadence + expiry alert.

## What worked well

- gh CLI device-code flow: token never touched chat or disk, Duong approved via browser, keyring updated automatically.
- Fail-closed email guard at commit-time: one hook file, covers every personal repo, blocks future leaks without trusting humans or agents to audit identity.
- Catching this via dogfood (Jhin's review) rather than an explicit audit. Reinforces that good review discipline surfaces systemic problems, not just code smells.

## What didn't work

- **Relying on memory files for identity facts.** Memory said "Duongntd is the agent account" and "harukainguyen1411 is the human." Both were true, but reality had `duongntd99` squatting in the agent slot. Memory can describe *intent* but can't verify *state*.
- **Trusting the encrypted PAT in repo.** 401'd on first use. No monitoring of PAT validity.
- **Running for weeks without noticing the work email in `git log`.** Every `git log --format='%ae'` would have surfaced it instantly. Worth baking into session-start or daily cron.
