# Learnings: Migration Phase 1+2 Dry-Run (2026-04-18)

## What worked
- Bare clone + working clone approach was fast (~10s clone).
- git-filter-repo and gitleaks already installed — no setup time needed.
- gitleaks with `Duongntd/strawberry` allowlist regex cleanly blocked the known false positive.
- Both gitleaks scans (current tree + full history) were 0-leak after filtering.
- turbo build --dry-run resolved correctly on the filtered tree.

## Gotchas / fixes for real session

1. **`strawberry.pub` is a file, not a directory.** `rm -rf strawberry.pub/` with trailing slash is a no-op. Use `rm -f strawberry.pub` explicitly. Add to deletion script.

2. **Pre-commit gitleaks hook fires on orphan commit and scans old history.** The 4 "leaks" from the hook were in private paths that were filtered out. Not real leaks in the public tree. In the real session, expect this behavior; the post-commit gitleaks passes are the authoritative source of truth.

3. **True orphan isolation:** Working clone from bare repo still has `--all` reachable refs from old history. For the squash to be truly clean (1 commit), the orphan branch must be force-pushed to the remote as the new main. This ensures the remote has only 1 commit. The local `git log --all` showing 1063 commits is a local-only artifact of the clone's reflog.

4. **`npm ci` lockfile desync:** Pre-existing issue (`ulid@3.0.2` missing). Fix in strawberry before migration day. Does not affect migration correctness.

## Slug rewrite scope (17 files confirmed)
See `assessments/2026-04-18-migration-dryrun.md` §3. Runtime-critical files:
- `apps/myapps/functions/src/beeIntake.ts:38`
- `apps/myapps/functions/src/index.ts:187`
- `apps/private-apps/bee-worker/src/config.ts:18`
- `apps/coder-worker/system-prompt.md:3` (R14 — agent behavior)

## Time budget
Phase 1+2 dry-run: ~3 minutes. Real session with slug rewriting will add ~20 min for 17 files.
