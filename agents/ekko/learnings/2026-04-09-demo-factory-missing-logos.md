# Demo Factory: Missing Logo/Thumbnail on Passes

## Root Causes Found

### 1. `website=` parameter crash (most impactful)

`factory.py` calls `research_brand(..., website=brief_website)` but `research.py:research_brand()` had no `website` parameter. Any demo run with a briefing that contained an explicit website URL would crash with a `TypeError` during the research step — before any logos were uploaded. Result: both Apple and Google passes had no images at all.

**Fix:** Added `website: str = ""` parameter to `research_brand`. When provided, skips domain guessing and uses the URL directly.

### 2. Google `heroImage` was never set

`gpay.py` set `titleImage` on the class and `logo` on the object, but never `heroImage` (the wide banner shown at the top of the Google pass detail view). This is a separate field from `logo`.

**Fix:** Added `heroImage` to the Google object template using the horizontal wordmark URL (falls back to square icon). Also added a `google.heroImage` verification check.

### 3. `logoRenderedBase64` is NOT populated by research pipeline

`factory.py` checks `research.get("logoRenderedBase64")` to use a pre-rendered Playwright PNG. But `research_brand()` in Python never calls `screenshot_brand.js` — that script is only run later for the HTML review page. So `logoRenderedBase64` is always None on a fresh run, and logo upload always falls back to URL download.

This is a known limitation, not a bug per se. The Playwright path was intended for future integration. If the URL download fails (e.g. SVG logo), logos will silently be missing.

### 4. `walletstudio_update_project_images` MCP tool is irrelevant to factory.py

The MCP tool `walletstudio_update_project_images` is a Claude Code tool for agents, not a Python SDK function. `factory.py` correctly uses `project.set_project_images()` via `WSClient` directly. No wiring needed.

## Files Changed

- `company-os/tools/demo-factory/research.py` — added `website` parameter
- `company-os/tools/demo-factory/gpay.py` — added `heroImage` and verification check
