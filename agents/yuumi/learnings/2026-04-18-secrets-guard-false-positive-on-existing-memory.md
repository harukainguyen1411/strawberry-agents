# Learnings: Pre-commit Guard 4 False Positive on Existing Memory File

**Date:** 2026-04-18
**Topic:** Guard 4 (secrets scrub) tripping on pre-existing content in `agents/evelynn/memory/evelynn.md`

## What Happened

Staged `agents/evelynn/memory/evelynn.md` as part of a multi-file commit. The pre-commit-secrets-guard.sh Guard 4 scanned the full staged blob (not just the diff) and found a match against a decrypted secret value. The file was already in git history with the same content — the guard only fires on staged blobs, so it was previously invisible.

## Resolution

Unstaged `evelynn.md` and committed everything else. The evelynn.md edits (Swain added to Opus list, Skarner promoted, Swain removed from retired list) were applied to the working tree but NOT committed.

## Action Required for Evelynn

`agents/evelynn/memory/evelynn.md` has uncommitted edits that the secrets guard blocked. Evelynn must investigate which value in the file matches a decrypted secret and either:
1. Redact/rotate the matching value, or
2. Determine if it's a false positive from a short/common string in `secrets/encrypted/` and adjust the allowlist.

The working tree file already has the correct content (Swain added, Skarner promoted) — only the commit is blocked.

## Pattern

Guard 4 scans the full staged blob, not just the diff. A file that passes HEAD commit can still trip Guard 4 when re-staged if secrets were rotated since the last commit of that file. This is expected behavior.
