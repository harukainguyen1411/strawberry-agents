# Key Scripts

Reference table for operational scripts. See `architecture/platform-parity.md` for platform coverage.

## Core Lifecycle Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/plan-promote.sh <file> <stage>` | `bash scripts/plan-promote.sh plans/proposed/foo.md approved` | Move a plan out of `proposed/` — runs Orianna gate, moves file, rewrites `status:`, commits, pushes. Valid stages: `approved`, `in-progress`, `implemented`, `archived`. Never use raw `git mv` for this. |
| `scripts/safe-checkout.sh <branch>` | `bash scripts/safe-checkout.sh my-branch` | Safe branch switch via git worktree — never use raw `git checkout` |
| `tools/decrypt.sh` | Called internally by scripts needing secrets | Decrypt age-encrypted secrets; keeps plaintext in child process env only. Never call `age -d` directly. |

## Quality / Security Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/hooks/pre-commit-secrets-guard.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Guards: `BEGIN AGE` outside encrypted/, raw `age -d` outside helper, bearer-token shapes, decrypt-and-scan staged files |
| `scripts/lint-subagent-rules.sh` | `bash scripts/lint-subagent-rules.sh` | Diff canonical inline rule blocks in `.claude/agents/*.md` against Sonnet-executor and Opus-planner reference sets, reporting drift |
| `scripts/list-agents.sh` | Via `/agent-ops list` | List all agents (TSV or JSON) |
| `scripts/new-agent.sh <name>` | Via `/agent-ops new <name>` | Scaffold a new agent directory |

## Orianna Signing Scripts

These scripts implement the Orianna-signed plan lifecycle (ADR `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md`). `orianna-hash-body.sh` exists; the remaining three are **inbound** (Jayce T2.1, T2.2, T2.3) and documented here for reference before they land.

| Script | Usage | Purpose | Exit codes |
|--------|-------|---------|-----------|
| `scripts/orianna-sign.sh` | `bash scripts/orianna-sign.sh <plan.md> <phase>` | Entry point for Orianna's signing flow. Validates source directory for the requested phase, invokes the phase-appropriate Orianna check prompt via `claude` CLI (no mechanical fallback), then on clean pass: computes body hash via `orianna-hash-body.sh`, appends `orianna_signature_<phase>:` to plan frontmatter, commits with `orianna@agents.strawberry.local` author identity and required trailers (`Signed-by: Orianna`, `Signed-phase:`, `Signed-hash:`). Does **not** push. Phase must be one of `approved`, `in-progress`, `implemented`. | `0` — signed successfully; `1` — check failed (plan unchanged); `2` — usage or pre-condition error (wrong source dir, file not found, `claude` CLI unavailable) |
| `scripts/orianna-verify-signature.sh` | `bash scripts/orianna-verify-signature.sh <plan.md> <phase>` | Verifies that the named phase signature is valid. Four checks: (1) body-hash in frontmatter matches current body; (2) the commit that introduced the signature line has author email `orianna@agents.strawberry.local`; (3) that commit carries matching `Signed-by`, `Signed-phase`, `Signed-hash` trailers; (4) that commit's diff is scoped to only the plan file. Emits a human-readable diagnosis on stderr for each failed check. Called by `plan-promote.sh` before every phase transition. | `0` — signature valid; `1` — one or more checks failed (stderr identifies which); `2` — usage or missing signature field |
| `scripts/orianna-hash-body.sh` | `bash scripts/orianna-hash-body.sh <plan.md>` | Computes SHA-256 of a plan file's body (content after the second `---` frontmatter delimiter). Normalization applied before hashing: strip frontmatter, normalize CRLF→LF, strip trailing whitespace per line. Prints 64-hex SHA-256 string on stdout. Sourced (via invocation) by both `orianna-sign.sh` and `orianna-verify-signature.sh` to guarantee they agree on the hash value. | `0` — hash printed to stdout; `1` — file not found or usage error |
| `scripts/hooks/pre-commit-orianna-signature-guard.sh` | Installed via `scripts/install-hooks.sh` | Pre-commit hook that enforces the valid shape of Orianna signing commits (§D1.2). When the commit author is `orianna@agents.strawberry.local`, asserts: diff touches exactly one file under `plans/`; diff adds exactly one `orianna_signature_<phase>:` frontmatter line (no other content changes); all three trailers (`Signed-by: Orianna`, `Signed-phase:`, `Signed-hash:`) are present and consistent with the frontmatter value. Rejects any Orianna-authored commit that does not meet this shape, preventing silent misuse of the agent identity. | `0` — commit is valid or not an Orianna signing commit; `1` — shape violation (blocks commit) |

## Notes

- Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) must be POSIX-portable bash — runnable on both macOS and Git Bash on Windows.
- Platform-specific scripts live under `scripts/mac/` (iTerm, launchd) and `scripts/windows/` (Task Scheduler, PowerShell wrappers).
- Full platform matrix: `architecture/platform-parity.md`.
