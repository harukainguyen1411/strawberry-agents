---
status: proposed
owner: katarina
created: 2026-04-13
---

# Retroactively strip skill-body leaks from existing transcripts

## Context

We just ported the skill-body detector from workspace into `scripts/clean-jsonl.py` (commit `e2962ff`). It prevents future leaks at clean-time. But existing transcripts under `agents/*/transcripts/` were cleaned with the old code and still contain leaked skill bodies — e.g. "# Brainstorming Ideas Into Designs", "# Update Config Skill", "# Building LLM-Powered Applications with Claude" appearing mid-file where only `## Duong —` / `## <Agent> —` headers should exist.

A survey found 9 transcripts with mid-file `# ` headers. Some are genuine (e.g. a user pasting a header-like line), most are skill-body leaks.

## Goal

Write a one-shot Python script `scripts/strip-skill-body-retroactive.py` that walks `agents/*/transcripts/*.md`, detects skill-body leaks inside speaker sections, and strips them in-place. Back up originals first. Commit the cleaned transcripts.

## Approach

1. Parse each transcript into (header, [sections]) where header is everything before the first `## ` and each section starts with `## <Speaker> — <timestamp>`.
2. Within each section body, if a line starting with `# ` (H1) is found AND the following 5000 chars contain ≥3 `## ` headers AND the block is ≥500 chars — treat it as a leaked skill body. Strip from that `# ` line up to (but not including) the next `## <Speaker> — <timestamp>` header or end of file.
   - Use the same heuristic as `looks_like_skill_body()` in `scripts/clean-jsonl.py:181`.
   - Be careful: the stripped block may contain its own `## H2`s that look like speaker headers. Distinguish speaker headers by the pattern `^## [A-Z][A-Za-z]+ — \d{4}-\d{2}-\d{2}T`.
3. Write cleaned content back. Print a summary: `<path>: stripped N bytes`.
4. `--dry-run` flag to preview without writing.

## Steps

1. Create branch worktree `retro-skill-body-strip` via `scripts/safe-checkout.sh`.
2. Write `scripts/strip-skill-body-retroactive.py`.
3. Run with `--dry-run` on all transcripts, show diff summary.
4. Run for real. Verify with `grep -E "^# [A-Z]" agents/*/transcripts/*.md | grep -v ":1:"` — should only show line-1 title headers.
5. Commit: `chore: strip skill-body leaks from historical transcripts`.
6. Push, PR, merge.

## Non-goals

- Don't touch `scripts/clean-jsonl.py` — already done.
- Don't re-run the cleaner against original jsonl (many are gone / rotated).
- Don't delete the script after use — keep it as a reusable audit tool.

## Verification

- After run: no mid-file `# ` H1s remain in any transcript (except intentional ones from the user paste).
- Spot-check 2-3 files manually to ensure surrounding `## Speaker` sections still parse correctly.
- `git diff --stat` shows only deletions from transcript files.
