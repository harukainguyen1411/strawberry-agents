# Learning: Plan promotion — meta-example paths need orianna:ok suppressors

**Date:** 2026-04-21
**Session:** Sona dispatch — karma claim-contract plan promotion

## What happened

Promoting `2026-04-21-orianna-claim-contract-work-repo-prefixes.md` to `approved` via `orianna-sign.sh` initially produced 15 block findings. The plan's purpose was to *fix* a class of false-positive path findings, so its own body was full of example paths that illustrated the problem — paths like `tools/demo-studio-v3/agent_proxy.py`, `apps/bee/server.ts`, `tools/encrypt.sh` (future file), and `scripts/test-fact-check-concern-root-flip.sh` (new file to be created).

Orianna's gate correctly blocked these as path-shaped tokens that didn't exist. They were all legitimate meta-examples or future-state references, not factual claims about what currently exists.

## Fix pattern

Add `<!-- orianna: ok -->` inline suppressors directly after the token on the same line. The suppressor applies per-line — one suppressor on a line suppresses all tokens on that line. For lines with many tokens, one trailing suppressor is sufficient.

Suppressor placement examples:
- Inline after a single token: `` `tools/demo-studio-v3/agent_proxy.py` <!-- orianna: ok --> ``
- After a list on one line: `... \`apps/\` <!-- orianna: ok -->, \`dashboards/\` <!-- orianna: ok -->, \`.github/workflows/\` <!-- orianna: ok -->`
- In a DoD line: `` `bash scripts/test-fact-check-concern-root-flip.sh` <!-- orianna: ok --> passes ``

## Canonical cases for suppression

1. **Example paths that illustrate the problem** — paths the plan describes as currently broken, which don't exist in the expected location
2. **Future-state paths** — files to be created by the plan's own tasks (e.g. new test scripts)
3. **Opt-back list items that don't yet exist** — `tools/encrypt.sh` was on the proposed opt-back list but not yet created
4. **Cross-repo paths used as examples** — paths that live in a different repo than the concern default

## Process note

The plan file was untracked when the session started. It must be committed before `plan-promote.sh` or `orianna-sign.sh` will accept it — those scripts check for uncommitted changes via `git status`. Commit the untracked plan first, then iterate with `orianna-sign.sh` until clean.

## Sign phase aliases

`orianna-sign.sh` uses underscore for multi-word phase names: `in_progress` (not `in-progress`). `plan-promote.sh` uses hyphen (`in-progress`). Always use `orianna-sign.sh <file> in_progress` then `plan-promote.sh <file> in-progress`.
