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
| `scripts/hooks/pre-commit-staged-scope-guard.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Prevents cross-agent commit sweeping (incidents: Syndra co-author sweep, Ekko `10f7581`). When `STAGED_SCOPE` env var (or `.git/COMMIT_SCOPE` file) is set, any staged path outside the declared list causes a hard reject (exit 1) with offending paths echoed. Unscoped commits warn (exit 0) if >10 files or >3 top-level dirs. `STAGED_SCOPE='*'` (exact asterisk) is the bulk-operation escape hatch. Follow-up adoption plan: `plans/proposed/personal/2026-04-22-agent-staged-scope-adoption.md`. | `0` = pass/escape hatch/warning; `1` = out-of-scope paths found |
| `scripts/hooks/pre-commit-zz-plan-structure.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Pre-commit structural lint for staged `plans/**/*.md`. Enforces 5 Orianna-parity rules at `git commit` time (see `architecture/plan-lifecycle.md` §Pre-commit structural lint): (1) canonical `## Tasks` heading required — variant spellings like `## Task breakdown (Foo)` rejected; (2) per-task `estimate_minutes: <int in [1,60]>` key:value required on task line; (3) test-task qualifiers (`xfail`/`test`/`regression`) require approved action verb (`Write`/`Add`/`Create`/`Update`) or `kind: test` token; (4) cited backtick paths must exist on disk (`<!-- orianna: ok -->` suppresses for prospective paths); (5) forward self-references (plan citing its own promoted path) require `<!-- orianna: ok -->`. Skips `plans/archived/**` and `plans/_template.md`. Grandfathering: hook only inspects staged diffs; quiet-on-disk plans are unaffected until next edit. |
| `scripts/hooks/pre-commit-t-plan-structure.sh` | Installed via dispatcher (legacy) | Legacy pre-commit linter enforcing rules 1–2 only (frontmatter + estimates). Superseded by `pre-commit-zz-plan-structure.sh` which extends coverage to rules 3–5. |
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

### `STAGED_SCOPE` env var for `orianna-sign.sh`

When the environment variable `STAGED_SCOPE` is set to a repo-relative plan path,
`orianna-sign.sh` scopes its signing commit to exactly that path via
`git commit -- <pathspec>`. This leaves any other files in the index untouched,
preventing concurrent coordinator sessions' staged work from riding into the signing
commit and triggering the one-file guard in `pre-commit-orianna-signature-guard.sh`.

Set `STAGED_SCOPE` only when the caller knows the exact destination path of the
plan being signed. `plan-promote.sh` exports `STAGED_SCOPE` automatically before
any `orianna-sign.sh` invocation it performs. Direct callers of `orianna-sign.sh`
may opt in by exporting the variable; when unset, behavior is unchanged.

Background: `STAGED_SCOPE` was introduced after Ekko hit the concurrent-staging race
while promoting `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md` — a
second coordinator session had staged unrelated files at the moment the signing commit
ran. See `plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md`.

## Notes

- Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) must be POSIX-portable bash — runnable on both macOS and Git Bash on Windows.
- Platform-specific scripts live under `scripts/mac/` (iTerm, launchd) and `scripts/windows/` (Task Scheduler, PowerShell wrappers).
- Full platform matrix: `architecture/platform-parity.md`.
