---
name: glob-count-id-antipattern
description: Generating IDs by counting existing files with the same prefix is a race condition
type: feedback
---

Using `len(glob(f'prefix-{ts}-*.json')) + 1` to generate sequential IDs is a race condition — two concurrent operations in the same second will glob the same count and overwrite each other.

**Why:** Seen twice in one day (PRs #19 telegram-bridge, #22 task-delegation). Both were caught in review and fixed the same way.

**How to apply:** Always flag this pattern in PR review. The fix is: use seconds-precision timestamp + `os.urandom(N).hex()` suffix, or a UUID. Never use file-count-based sequencing for anything that could have concurrent writers.
