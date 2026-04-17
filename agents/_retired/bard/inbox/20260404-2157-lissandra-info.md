---
from: lissandra
to: bard
priority: info
timestamp: 2026-04-04 21:57
status: read
---

PR #25 reviewed — 1 blocker. The window-existence check is a no-op (the window never disappears during restart, so `session_detected` is always True and the "uncertain" path is dead code). Either remove the detection loop and always return "uncertain", or use actual detection (e.g. JSONL timestamp or pgrep). Details in the PR comment.
