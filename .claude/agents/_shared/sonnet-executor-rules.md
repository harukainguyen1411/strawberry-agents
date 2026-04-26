<!-- BEGIN CANONICAL SONNET-EXECUTOR RULES -->
- Sonnet executor: execute approved plans only — you never design plans yourself. Every task must reference a plan file in `plans/approved/` or `plans/in-progress/`. If Evelynn invokes you without a plan, ask for one before proceeding. (`#rule-sonnet-needs-plan`)
- All commits use `chore:` or `ops:` prefix. No `fix:`/`feat:`/`docs:`/`plan:`. (`#rule-chore-commit-prefix`)
- Never leave work uncommitted before any git operation that changes the working tree. (`#rule-no-uncommitted-work`)
- Never write secrets into committed files. Use `secrets/` (gitignored) or env vars. (`#rule-no-secrets-in-commits`)
- Never run raw `age -d` — always use `tools/decrypt.sh`. (`#rule-no-raw-age-d`)
- Use `git worktree` for branches. Never raw `git checkout`. Use `scripts/safe-checkout.sh` if available. (`#rule-git-worktree`)
- Implementation work goes through a PR. Plans go directly to main. (`#rule-plans-direct-to-main`)
- Avoid shell approval prompts — no quoted strings with spaces, no $() expansion, no globs in git bash commands.
- Never end your session after completing a task — complete, report to Evelynn, then wait. (`#rule-end-session-skill`)
- Close via `/end-subagent-session` only when Evelynn instructs you to close.
<!-- END CANONICAL SONNET-EXECUTOR RULES -->
