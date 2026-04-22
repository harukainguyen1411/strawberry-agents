# 2026-04-22 — Batch promote 5 in-progress plans to implemented/personal/

## Plans promoted

All 5 plans promoted from in-progress to implemented/personal/ with full re-sign chains:

1. `plans/implemented/personal/2026-04-22-rule-16-akali-playwrightmcp-user-flow.md` — PR #28, body hash f7e07e4b
2. `plans/implemented/personal/2026-04-22-rule-18-self-merge-amendment.md` — PR #24, body hash 69b978d0
3. `plans/implemented/personal/2026-04-22-work-scope-reviewer-anonymity.md` — PR #25, body hash b131ac20
4. `plans/implemented/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md` — PR #23 (final 36afa9a), body hash 859fa430
5. `plans/implemented/personal/2026-04-20-strawberry-inbox-channel.md` — PR #18, body hash 48b06e40

## Key pattern: re-sign chain from in-progress to implemented

When a plan at in-progress needs to be promoted to implemented with body changes (adding ## Architecture impact and ## Test results sections):

1. Set `status: proposed`, strip all signatures
2. `git mv` to `proposed/personal/`, commit
3. Sign approved → promote → sign in_progress → promote → sign implemented → promote
4. All 3 gate checks pass cleanly when plan is well-formed

## Pre-commit hook patterns discovered

### Directory tokens in backticks crash awk
`architecture/` (trailing slash) in backticks causes awk i/o error at line ~281 of pre-commit-zz-plan-structure.sh. Remove backticks from directory-only references or add a suppressor. Any backtick path token the hook tries to `getline` from will crash if the path resolves to a directory.

### Comprehensive path detection by hook
The hook flags a token as a path if it matches `/^[-a-zA-Z0-9_.\/]+[.][a-zA-Z0-9]+$/` (has extension) OR contains `/`. This catches:
- `hookSpecificOutput.additionalContext` (has dot, looks like extension)
- `settings.json`, `inbox-watch.sh`, `old-msg.md` (all have extensions)
- `fixture/inbox-empty/` (contains slash)

For large plans with many such tokens, a Python script using the same regex logic is the most reliable way to add suppressors in bulk.

### Stale signature in working tree after failed commit
If orianna-sign.sh appends a signature but the commit fails (e.g., awk crash in hook), the signature lives in the working tree but not in git history. Before re-signing: remove the stale signature from frontmatter, fix the hook violation, then re-run orianna-sign.sh.

### Integration name blocks
Tokens like `strawberry-inbox` that are unanchored integration names (not real paths, not allowlisted) are blocked by Step C of the Orianna gate. Add `<!-- orianna: ok -- <reason> -->` to suppress.

### Architecture impact sections
For quick-lane plans with no architecture/ file changes, use:
```
architecture_impact: none
```
in frontmatter plus a `## Architecture impact` section in the body explaining why.
Do NOT put backtick-enclosed path tokens in the Architecture impact section without suppressors.

### Test results sections
Use a PR URL as evidence:
```
## Test results

- PR #N merged at <sha>: https://github.com/harukainguyen1411/strawberry-agents/pull/N
- All required checks green at merge.
```

## Stale root-subtree copy cleanup
The old `plans/in-progress/2026-04-20-strawberry-inbox-channel.md` (no personal/ prefix) was the tracked version. The personal/ version was untracked. Handled by:
1. `git rm plans/in-progress/2026-04-20-strawberry-inbox-channel.md`
2. `git add plans/in-progress/personal/2026-04-20-strawberry-inbox-channel.md`
3. `git mv` to proposed/personal/
4. All in one commit

## Final SHAs
- Setup commit: 0f74f23 (relocate to proposed, delete stale root copy)
- Suppressor fixes: e8db8e5
- Plan 1 sign chain: 55fe623 (approved) → f893e6b (promote) → cf100fc (in_progress) → b65c623 (promote) → 4433220 (implemented) → f8b234d (promote, pushed)
- Plan 2 sign chain: 5c8485a (approved) → 6564bbd (promote) → 2a82697 (in_progress) → 223be83 (promote) → 3cf67d9 (implemented) → 9909766 (promote, pushed)
- Plan 3 sign chain: f04802a (approved) → promote → 0c98fab (in_progress) → promote → a6acf15 (implemented) → 1c63aeb (promote, pushed)
- Plan 4 sign chain: e90e03d (approved) → promote → ad4f901 (in_progress) → promote → b12b334 (implemented) → 5d3ceb0 (promote, pushed)
- Plan 5 sign chain: a86a145 (approved) → promote → abc8b8f (in_progress) → promote → ef6a32e (implemented) → 094951e (promote, pushed)
