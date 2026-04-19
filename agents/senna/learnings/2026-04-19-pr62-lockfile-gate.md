# 2026-04-19 — PR #62 (Phase 1 apps-restructure rename)

## Finding

PR #62 did a wholesale `git mv apps/myapps apps/darkstrawberry-apps` with workspace+workflow+runtime rewrites, but did NOT regenerate `package-lock.json`. The lockfile still encoded `apps/myapps` at 27+ positions. Result: `npm ci` failed with `EUSAGE` across every CI job that installed deps (Lint+Test+Build, E2E, Vitest, Playwright, preview) — all required checks red.

## Lesson

For any rename PR touching npm workspaces, the lockfile is a second source of truth and must be regenerated in the same PR. Scanning `package.json` alone is insufficient — grep the lockfile too. This is a recurring class of bug: configuration-level rename looks complete because every visible config points at the new name, but the generated/derived artefact (lockfile, `turbo.json` cache, `.firebaserc` project map) still encodes the old path.

Also flagged: `.gitleaks.toml` allowlist regex `apps/myapps/\.cursor/skills/.*` silently goes dead after rename — either false positives appear or a suppressed real hit starts matching. Always grep dotfiles (`.gitleaks.toml`, `.prettierignore`, `.eslintignore`, `.gitattributes`) during rename review.

## Reviewer-lane mechanics worked

`--lane senna` routed to `strawberry-reviewers-2`; my CHANGES_REQUESTED sits cleanly alongside Lucian's APPROVED under `strawberry-reviewers`. Separate accounts, separate review slots — GitHub will not let Lucian's approval mask my block. The PR #45 masking incident is structurally prevented.
