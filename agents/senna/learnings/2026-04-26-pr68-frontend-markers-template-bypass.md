# PR #68 — Stream E PR-marker lint job: template-scaffold bypass

**Verdict:** REQUEST_CHANGES

## Top finding (critical)

The `.github/pull_request_template.md` ships uncommented marker scaffold lines (`Design-Spec: <plan-path-or-figma-link>`, `Accessibility-Check: pass | deferred-<reason>`, `Visual-Diff: ...`) wrapped in an HTML comment block. `gh pr view --json body` returns the raw body including HTML comments. `pr-lint-frontend-markers.sh` matches `^Design-Spec:` line-anchored without HTML-comment awareness — so a PR opened from the template that NEVER touches the markers still PASSES the gate (placeholder strings are non-empty).

This silently disarms Rule 22 for every PR opened via the template.

## Pattern: PR-body lint scripts must strip HTML comments first

Whenever a CI lint scans GitHub PR body for required markers, and the PR template ships marker scaffolding inside `<!-- ... -->`, the lint must either:
1. Strip `<!-- ... -->` blocks (multi-line sed) before grep, OR
2. Reject template-literal placeholder values explicitly (`<…>`, `pass | deferred-<reason>`, etc.) via a denylist.

Test fixture coverage must include "PR opened from template, no edits" — otherwise the false-positive is undetectable.

## Other notes

- `case` patterns mixing `apps/*/src/*.vue` and `apps/*/src/**/*.vue` is redundant — bash `case` `*` already matches `/`.
- `GITHUB_OUTPUT` `files=$X` with space-separated values is fragile vs the multiline delimiter protocol.
- `case`-pattern UI-glob misses `composables/`, `layouts/`, `stores/`, `views/`, `app/**`, `.html`, `.svg`, Tailwind config — D-OQ-5 acknowledges v1 risk.

## Process

- Concern: personal. Used `scripts/reviewer-auth.sh --lane senna`.
- Preflight `gh api user --jq .login` returned `strawberry-reviewers-2` ✓.
- Submitted via `gh pr review 68 --request-changes --body-file ...`.
