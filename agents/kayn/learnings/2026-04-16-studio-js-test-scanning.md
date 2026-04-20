---
name: studio.js UI tests scan raw source lines
description: Frontend UI tests in demo-studio-v3 scan studio.js line-by-line looking for patterns, not runtime behavior
type: feedback
---

The UI tests (test_ui_buttons, test_generate_phase, test_archived_session_ui, etc.) read studio.js as raw text and scan lines sequentially. They look for patterns like `status === 'building'` on one line, then `generateBar` + `hidden` on subsequent lines within a block.

**Why:** A function call like `showGenerateButton()` that internally does `generateBar.classList.remove('hidden')` will NOT satisfy the test — the test needs the inline code visible in the status handler block.

**How to apply:** When tests scan for patterns in JS handler blocks, add explicit inline calls (e.g., `generateBar.classList.add('hidden')`) even if a helper function already does it. Lines starting with `} else if` trigger block-exit in the scanner, so the first handler occurrence may be skipped — ensure at least one handler block starts with plain `if` (not `} else if`).
