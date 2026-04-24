# PR #115 review — demo-preview dotenv auto-load

**Date:** 2026-04-24
**Repo:** missmp/company-os
**PR:** https://github.com/missmp/company-os/pull/115
**Base:** feat/demo-studio-v3
**Verdict:** LGTM (advisory) — posted as comment, not GitHub Review

## What changed

- `tools/demo-preview/server.py`: adds `from dotenv import load_dotenv` + `load_dotenv()` + `load_dotenv(".env.local", override=False)` right after the jinja2 import guard.
- `tools/demo-preview/requirements.txt`: adds `python-dotenv>=1.0.0`.

Mirrors PR #114's pattern for the sibling service.

## Findings

Both non-blocking suggestions:

1. **Import-guard consistency** — `jinja2` has `try/except ImportError` with a friendly hint; `dotenv` import is bare. Would raise `ModuleNotFoundError` if deps not installed. Minor style nit.
2. **CWD-relative path** — `load_dotenv(".env.local", ...)` is CWD-sensitive. The first bare `load_dotenv()` uses python-dotenv's upward-search (robust). Suggested `BASE_DIR / ".env.local"` but BASE_DIR is defined below, so would need reordering.

No security, correctness, or secrets issues.

## Protocol note (new today)

Work-scope reviewer protocol shifted: post verdict as PR **comment** via `duongntd99` account (`gh auth switch --user duongntd99` then `gh pr comment -F body.md`), NOT as a GitHub Review via `scripts/reviewer-auth.sh`. Duong approves manually from `harukainguyen1411`. The `scripts/reviewer-auth.sh --lane senna` path still applies to personal-concern PRs — this is a work-concern-only protocol change.

Rule 18 (a): `statusCheckRollup` empty on this PR → no required checks → vacuously satisfied. Rule 18 (b): Duong's manual approval covers this.

## Signature

Signed body with `-- reviewer` (neutral, work-scope anonymity). No agent names, no reviewer handles, no Anthropic refs.

## Comment URL

https://github.com/missmp/company-os/pull/115#issuecomment-4311587394
