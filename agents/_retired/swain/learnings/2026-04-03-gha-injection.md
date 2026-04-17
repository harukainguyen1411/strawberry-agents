# GitHub Actions: Workflow Input Injection

`${{ github.event.inputs.* }}` and `${{ github.event.pull_request.body }}` in `run:` blocks are shell-interpolated before execution. Malformed values (single quotes, `$()`, backticks) can break or execute arbitrary commands.

**Fix:** Always pass via `env:` block, then reference as `$VAR` in the shell script. This applies to ALL user-controlled GitHub Actions expressions in `run:` blocks.

**Caught this twice in one session** — once in Pyke's workflow, once in Ornn's merge-notify workflow.
