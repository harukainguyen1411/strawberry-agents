# Git Identity Enforcement

## Overview

Strawberry enforces that all commits carry the neutral `Duongntd` identity rather than persona-named agent identities (e.g. `Viktor <viktor@strawberry.local>`). This document describes the three-layer model in effect as of 2026-04-25.

**Reference plan:** `plans/approved/personal/2026-04-25-resolved-identity-enforcement.md`

## Why three layers?

PR #45 introduced a PreToolUse shell-source scanner as the sole gate. Lucian's review found nine structural bypasses (NEW-BP-4 through NEW-BP-12): line-continuation, backtick expansion, `$(...)` command substitution, `eval`, `sh -c`, `bash -c`, `git commit-tree`, `$VAR` indirection. Each bypass exploits the same root cause: **PreToolUse is pre-execve — it sees shell source, not resolved values.** Every regex tightening opens another indirection door. The arms race is unbounded.

The pivot (Option A from Lucian's review): move the primary gate to hooks that read **post-expansion ground truth**.

## Three-layer model

### Layer 1: PreToolUse advisory (defense-in-depth)

**File:** `scripts/hooks/pretooluse-subagent-identity.sh`
**When:** Before the Bash tool executes a shell command
**What it does:** Rewrites worktree git config to the neutral identity, and scans the command source for obvious persona patterns. Blocks trivial unobfuscated cases early (shortens feedback loop).
**Limitation:** Cannot catch any bypass that hides the persona string behind shell expansion. Not the primary gate.

### Layer 2: pre-commit primary gate

**File:** `scripts/hooks/pre-commit-resolved-identity.sh`
**When:** After `git commit` is invoked but before the commit object is written
**What it does:** Reads `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT`. By this point all shell expansion is finished — git has resolved config + env + command-line overrides into a single identity string. Applies persona-name regex and `@strawberry.local` email pattern against the resolved strings.
**Coverage:** Catches every NEW-BP-4..12 bypass variant (they all produce the same observable at commit time: a resolved persona identity). Does NOT cover `git commit-tree` (which skips pre-commit hooks) — that is Layer 3's responsibility.

### Layer 3: pre-push backstop

**File:** `scripts/hooks/pre-push-resolved-identity.sh`
**When:** Before `git push` sends commits to a remote
**What it does:** For each new commit in the push range, runs `git cat-file commit <sha>` and inspects the `author` and `committer` header lines in the raw commit object. Rejects any sha whose headers match the persona denylist.
**Coverage:** Closes the `git commit-tree` path (NEW-BP-10) — plumbing commands that bypass pre-commit hooks. Also serves as a final catch-all for commits created without the pre-commit hook installed (e.g. on a machine without `scripts/install-hooks.sh` run).
**Note:** No Orianna carve-out at push time. Orianna pushes commits with neutral identity.

## Regex and allowlist

### Persona denylist

Full roster from `agents/memory/agent-network.md`:

```
Viktor, Lucian, Senna, Aphelios, Xayah, Caitlyn, Akali, Karma, Talon,
Azir, Swain, Kayn, Lux, Sona, Evelynn, Orianna
```

Applied as case-insensitive word-boundary match against the full resolved identity string (name + email).

Additionally, any identity with `@strawberry.local` email domain is blocked.

### Allowlist

The **neutral identity** passes unconditionally:

```
Duongntd <103487096+Duongntd@users.noreply.github.com>
```

### Orianna carve-out

Orianna is the sole deliberate exception. The carve-out is scoped to **pre-commit only**:

- `pre-commit-resolved-identity.sh`: honors `STRAWBERRY_AGENT=orianna` or `CLAUDE_AGENT_NAME=orianna` — exits 0 without checking.
- `pre-push-resolved-identity.sh`: **no carve-out**. Orianna pushes neutral identity at push time.

**Update (2026-04-25) — `plans/approved/personal/2026-04-25-orianna-identity-protocol-alignment.md`:**
`agents/orianna/memory/git-identity.sh` now sets the neutral `Duongntd` identity directly
(replacing the former `orianna@strawberry.local` / `Orianna` persona identity). Orianna's
persona signal is now carried exclusively in the `Promoted-By: Orianna` commit body trailer.
This eliminates the amend-shuffle previously required on every plan promotion. The Layer 2
`STRAWBERRY_AGENT=orianna` carve-out is **retained as defense-in-depth** but is no longer
load-bearing — a clean Duongntd commit short-circuits before the carve-out check matters.

## Bypasses closed by this design

| Bypass | Layer that closes it |
|--------|---------------------|
| Direct `git config user.name Viktor` | Layer 2 (pre-commit) |
| NEW-BP-4: line-continuation in command | Layer 2 (resolved at commit time) |
| NEW-BP-5: backtick expansion | Layer 2 |
| NEW-BP-6: `$(...)` command substitution | Layer 2 |
| NEW-BP-7: `eval "..."` wrapper | Layer 2 |
| NEW-BP-8: `$V` variable indirection | Layer 2 |
| NEW-BP-9: `cat /file` indirection | Layer 2 |
| NEW-BP-10: `git commit-tree` plumbing | Layer 3 (pre-push) |
| NEW-BP-11: `sh -c "..."` wrapper | Layer 2 |
| NEW-BP-12: `bash -c "..."` wrapper | Layer 2 |
| GIT_AUTHOR_NAME env var | Layer 2 (git var resolves env) |

## Out of scope

- **Server-side `pre-receive` hook**: deferred. Client-side pre-push is sufficient for Strawberry's threat model (single-developer + agent fleet, all pushes from machines we control). Revisit if multi-machine or untrusted-runner scenario emerges.
- **Retroactive sweep of historical commits**: separate ops task.
- **CLAUDE.md universal-invariants update**: wait one week post-merge; promote to invariant only after hooks bake without false positives.

## Installation

```sh
bash scripts/install-hooks.sh
```

Both hooks are auto-discovered by the dispatcher (naming convention `pre-commit-*.sh` and `pre-push-*.sh`). Safe to re-run.
