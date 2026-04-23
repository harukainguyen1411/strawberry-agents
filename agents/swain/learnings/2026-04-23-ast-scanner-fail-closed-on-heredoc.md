# Pre-commit AST scanner fails closed on HEREDOC commit messages

The `pretooluse-plan-lifecycle-guard` hook's bash AST scanner exits 3 ("denied (fail-closed)") when given a multi-line `git commit -m "$(cat <<'EOF'... EOF)"` heredoc body, even when the message content itself is innocuous. There is no error breadcrumb explaining which token tripped the scanner — the hook just refuses and you lose the commit attempt.

**Workaround:** use a short single-line `-m "..."` for chore/plan commits. The ADR authoring path almost never needs a multi-paragraph commit message — the plan file is the documentation. A one-line conventional-commit subject is both lower friction and scanner-safe.

**Don't:** try to craft a heredoc that the scanner will accept by trial and error. The failure mode is opaque and the fix time compounds. Just ship a one-liner.

**Context:** happened 2026-04-23 while committing `plans/proposed/work/2026-04-23-agent-owned-config-flow.md`; retry with short `-m` message worked on first attempt.
