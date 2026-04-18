---
date: 2026-04-19
topic: A7 orphan-path sentinel — methodology and findings
---

# A7 Orphan-Path Sentinel — Methodology and Findings

## Task

Cross-repo migration audit: verify every file at `migration-base-2026-04-18` (SHA `af2edbc0`) on `Duongntd/strawberry` is accounted for in exactly one of strawberry-app, strawberry-agents, or the retired allowlist.

## Methodology that worked

1. `git ls-tree -r --name-only <tag> | sort` on the local clone gives the exact committed base tree — clean, no untracked noise.
2. `gh api "repos/<owner>/<repo>/git/trees/main?recursive=1"` returns the full tree; pipe through python3 to filter `type != 'tree'` (only blobs) and sort. Much faster than cloning.
3. Build retired.txt programmatically by testing each base path against retired prefixes — avoids manual listing errors.
4. `python3 set arithmetic` for orphan and duplicate checks is more reliable than `comm` shell commands (no sort assumption issues, no heredoc sandbox problems).

## Findings

- **4 orphans**: `apps/myapps/.cursor/skills/` Cursor IDE skill files. ADR §2.4 flagged them as "strip or move" but no disposition landed in either migration. Neither migration tree included them.
- **39 accidental duplicates**: files that ended up in both strawberry-app and strawberry-agents. Root cause: the A1 history filter (`--invert-paths` dropping public paths) appears to have kept more in strawberry-agents than intended — `docs/`, code-only hooks (`pre-commit-unit-tests`, `pre-push-tdd`, `pre-commit-artifact-guard`), `tests/`, most `tools/` besides `decrypt.sh`, and several unclassified scripts.
- **4 intentional dual-tracked items** correctly present in both repos: `.gitignore`, `scripts/install-hooks.sh`, `scripts/hooks/pre-commit-secrets-guard.sh`, `tools/decrypt.sh`.

## Key insight on retired allowlist construction

The plan mentions `strawberry-b14/` and `strawberry.pub/` as retired but these are untracked directories — they don't appear in `git ls-tree` output and are therefore not base-tree candidates. Only committed files need to be in the retired allowlist.

## Verdict: needs-remediation

The migration is not AG7-G2 clean. Phase A6 must not proceed. Two fix tracks:
1. Resolve the 4 `.cursor/skills/` orphans (disposition decision needed from Evelynn/Duong).
2. Remove the 39 accidental duplicates from strawberry-agents via targeted cleanup commit.
