# Shared-lib review checklist — learnings from P1.2 (`scripts/deploy/_lib.sh`)

Context: reviewed PR #179 (`scripts/deploy/_lib.sh`) against
`plans/in-progress/2026-04-17-deployment-pipeline.md`. Three architectural
gaps slipped past TDD-green + shellcheck-clean + ADR-contract-match. Codify
them so future shared-library reviews catch them in the first pass.

## Checklist for any shared `_lib.sh` / library surface

### 1. Enumerate helpers against ADR by name, not by count

TDD test plans pin *behavior* (FM-1..FM-N). ADR prose can name additional
helpers inline that the test plan doesn't enumerate. In P1.2, the test
plan covered 8 FMs but ADR §4 also named `dl_cd_firebase_root` in the
`cd` + `trap` paragraph — easy to miss because it's in prose, not a table.

**Check:** grep the ADR for every `function-name(` or `<helper>` mention
and cross-reference the library. Missing helpers mean surface scripts
will reinvent the contract inconsistently.

### 2. JSONL / structured log must carry `schema_version`

If the ADR promises "schema grows additively" (common pattern for
audit logs / events / IPC payloads), the payload **must** include a
`schema_version` field from record one. Without it, readers have no
way to branch on version, and "additive-safe" becomes a lie the first
time a reader needs to distinguish old vs new records.

**Check:** any JSONL/JSON event stream → first field is `schema_version`.
Start at `1`. Cheap forward-compat.

### 3. Source-safety = explicit re-source guard

A library marked "safe to source" is not actually safe if it can be
sourced twice transitively (which happens the moment you have a
dispatcher that sources the lib *and* invokes surface scripts that
also source it). Function redefinition is harmless; top-level state
(caches, read-only vars, counters) is not.

**Standard guard pattern:**

```bash
if [ "${_LIB_LOADED:-}" = "1" ]; then
    return 0
fi
_LIB_LOADED=1
```

**Check:** every `_lib.sh` opens with a guard before any function
definition or top-level statement.

## Secondary checks worth running on any shell library

- **State leakage via exported globals.** Exported vars set by one
  function and read by another are fine for sequential pairs but bite
  under composition (dispatcher nesting, parallel invocations). Either
  document the contract ("one active X per shell") or stack-scope.
- **Subprocess cost per call.** Any helper that execs a CLI (e.g.
  `firebase login:list`, `gcloud auth`) pays ~500ms–1s. Fine once,
  expensive under a dispatcher. Memoize via exported cache var when
  the result is idempotent within a shell lifetime.
- **Portability: python3, gnu-only flags, `/dev/urandom` pipe hangs.**
  Rule 10 says POSIX-portable for macOS + Git Bash. python3 is not a
  given on Git Bash. `awk` + `date +%s` is the reliable fallback. For
  IDs, avoid `head -c` on `/dev/urandom` in pipelines (SIGPIPE races);
  use `awk` with srand from date+pid, or `od -An -N16 -tx1`.
- **Time precision.** `date +%s` × 1000 is second-precision in ms
  units, not true ms. If ms precision ever matters, `$EPOCHREALTIME`
  (bash 5+, present on Git Bash) is the drop-in.

## Meta-learning: reviewer division of labor

Jhin does bug hunt, I do architectural fit. The three gaps above were
all architectural — they passed bug-hunt because the library *worked*
as tested, but composition with future surface scripts (P1.8–P1.11)
would have degraded. Architectural review must ask: **"will the next
three scripts that consume this library compose cleanly, or will they
each have to work around the same sharp edges?"** If the answer is
the latter, fix the library now.
