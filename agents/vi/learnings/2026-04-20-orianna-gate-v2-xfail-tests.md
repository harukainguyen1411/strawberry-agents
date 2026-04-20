# Orianna Gate v2 — xfail Test Authoring

**Session:** 2026-04-20
**Branch:** feat/orianna-gate-v2-tests
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/5

## What was done

Wrote all 9 xfail test tasks (T5.1–T5.7, T7.2, T11.1) for the Orianna-gated plan lifecycle ADR.
38 individual test cases across 7 runnable POSIX bash scripts + 1 assessment report stub.

## Key patterns used

### xfail guard pattern (for bash tests against absent scripts)

When the target script/lib does not exist yet, print per-case XFAIL lines and exit 0.
This lets CI record structured results without failing the TDD gate build:

```sh
if [ ! -f "$TARGET_SCRIPT" ]; then
  printf 'XFAIL  target-script.sh not present — N cases xfail\n'
  for c in CASE_1 CASE_2; do printf 'XFAIL  %s\n' "$c"; done
  printf '\nResults: 0 passed, N xfail (expected)\n'
  exit 0
fi
```

### Sourceable lib tests

For lib files (`_lib_*.sh`), source the lib then call functions directly:
```sh
. "$LIB"
rc=0; check_estimate_minutes "$F" 2>/dev/null || rc=$?
```
The lib must export functions; the test just sources it and calls them.

### Multi-phase smoke harness structure

T5.7 smoke harness chains: sign approved → verify → edit+stale → resign → sign in-progress
→ promote → sign implemented → promote → post-hoc verify all 3 sigs.
T7.2 offline-fail is a hermetic case appended at the end of the same file — runs in a
PATH-sanitized subshell where `claude` is absent.

### Cross-platform date command

For `date -v-1H` (macOS) vs `--date='1 hour ago'` (GNU/Linux):
```sh
date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
  date -u --date='1 hour ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
  printf '2026-04-20T00:00:00Z'
```

## Test count by file

| File | Cases |
|------|-------|
| `scripts/test-orianna-hash-body.sh` | 4 |
| `scripts/test-orianna-verify-signature.sh` | 6 |
| `scripts/hooks/test-pre-commit-orianna-signature.sh` | 4 |
| `scripts/test-orianna-estimates.sh` | 7 |
| `scripts/test-orianna-architecture.sh` | 5 |
| `scripts/test-orianna-sibling-grep.sh` | 2 |
| `scripts/test-orianna-lifecycle-smoke.sh` | 10 (T5.7×9 + T7.2) |
| `assessments/2026-04-21-orianna-gate-smoke.md` | stub |

## Fragility notes

- T5.2 and T5.3 fixture commits use `awk` to inject signature lines before closing `---`; the awk pattern assumes the standard two-`---` frontmatter structure. Unusual frontmatter (nested YAML, multiple `---` blocks) would break fixture setup.
- T5.5 architecture verifier uses both macOS (`-v-1H`) and GNU date syntax — needs the fallback chain to work on CI.
- T5.7 smoke harness is the most complex; it creates a full git repo with multiple commits. Its xfail guard only checks for orianna-sign.sh and orianna-verify-signature.sh — if plan-promote.sh exists but those don't, the guard still triggers correctly.
- T7.2 hermetic PATH test (`PATH=/usr/bin:/bin`) should work on macOS and Linux but may need adjustment if sh builtins differ.
