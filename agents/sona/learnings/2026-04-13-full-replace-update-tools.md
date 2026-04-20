# Learning: Full-Replace Update Tools Are Footguns

**Date:** 2026-04-13
**Context:** wallet-studio MCP tooling; 4Paws demo incident (token ID 10912)

## What Happened

`update_token_ui` sent the caller-supplied payload as the full request body to the API. The API was a PUT (full replace), not a PATCH (partial update). A caller who only wanted to update one field sent an incomplete object — the API accepted it and replaced the entire token UI config, losing all other fields.

In practice: a generic German template was sent as the update payload, and it completely overwrote the 4Paws demo (10912), which had custom FNOL flows, share buttons, claim mailto links, and personalisation hooks. The demo was live and needed by a client (Gary) that day.

## Root Cause

The tool did not fetch the existing object before writing. It passed through whatever it received directly to a PUT endpoint. Any caller sending partial data causes silent data loss — no error, no warning.

## Fix Applied

Replaced `update_token_ui`, `update_ios_template`, `update_gpay_template` with patch variants:
- `patch_token_ui`
- `patch_ios_template`
- `patch_gpay_template`

Each patch tool follows the GET→merge→PUT pattern:
1. Fetch the current object from the API
2. Deep-merge the caller's partial payload over the fetched object
3. PUT the merged result back

This makes partial updates safe regardless of whether the underlying API is PATCH or PUT.

## Key Lesson

**Always check whether the API uses PATCH or PUT before building an update tool.**

- If PATCH: a passthrough tool is safe — the server does the merge
- If PUT: the tool MUST do GET→merge→PUT itself, or callers will silently lose fields

Any tool named `update_*` that wraps a PUT endpoint without a prior GET is a footgun. Audit existing tools for this pattern and replace them.

## Recovery

The original content was extracted from a previous tool call result still in the session context (Kayn's earlier read of the token). This only worked because the session was still live. If the session had closed, the content would have been unrecoverable without a database backup.

**Mitigation going forward:** patch tools eliminate the risk entirely. No full-replace writes allowed.
