# Advisory — MAD / SE.E grep-gate allowlist for `config_mgmt_client`

Date: 2026-04-21
Author: Camille (advisory only — no implementation)
Scope: OQ-MAD-3; coordination between MAD (dashboard-tab ADR) and SE (session-state ADR §4.5 / Rule 4).

## 1. Which PR owns the allowlist entry?

Land the allowlist entry in the **MAD PR**, not the SE PR.

The SE.E.2 gate is a *mechanism*; the MAD handler is a *caller*. Gate-rule changes should ship atomically with the consumer that needs the exemption — otherwise either (a) MAD lands red, or (b) SE lands with a pre-baked exemption for a file that does not yet exist, inviting silent drift. Ship the handler file and the one-line allowlist delta together in MAD; reviewers see cause-and-effect on one diff. SE.E.2 owns the *engine*; MAD owns *this row*.

## 2. Allowlist shape — path prefix, glob, or explicit list?

Recommend an **explicit file list** (not a prefix, not a glob).

- Prefix (`tools/demo-studio-v3/handlers/`) fails closed on intent but open on scope: any new file dropped under the prefix auto-inherits the exemption. That is exactly the drift Rule 4 exists to prevent.
- Filename globs (`*dashboard*`) are semantically meaningless and fragile across renames.
- Explicit file list (e.g. `tools/demo-studio-v3/handlers/managed_sessions.py`) forces every new caller to go through a review that touches the gate config. The audit trail is the git blame on the allowlist file itself.

Pair it with the existing `# azir: config-boundary` escape hatch for *line-level* exemptions (tests, migration scripts). Two tiers: explicit-file allowlist for structural callers; inline comment for one-off lines.

## 3. Bypass risk in the grep pattern itself

A literal `config_mgmt_client` grep catches the happy path only. Real bypass vectors:

- **Aliased import**: `from tools.demo_studio_v3 import config_mgmt_client as cmc` — still contains the token; caught.
- **Module-object import**: `import tools.demo_studio_v3.config_mgmt_client` — caught.
- **`from ... import fetch_config`** — **NOT caught**. The token `config_mgmt_client` never appears at the call site. This is a real hole.
- **`importlib.import_module("...config_mgmt_client")`** — caught (string literal present), but **`importlib.import_module(variable)`** defeats static grep entirely.
- **Star imports** from a re-exporting shim — fully defeats the gate.

Mitigations: (a) extend the pattern to cover `fetch_config|fetch_schema|patch_config` symbol names as a secondary grep, (b) forbid `from config_mgmt_client import *` explicitly, (c) forbid dynamic `importlib` with non-literal args under `tools/demo-studio-v3/`. Upgrade path: replace grep with a 30-line AST check (`ast.Import`/`ast.ImportFrom` walker) when SE.E.2 graduates.

## 4. Pre-commit vs. CI

Both, with distinct severity. Pre-commit hook = fast fail, advisory (warn + allow with `--no-verify`-equivalent opt-in for local experimentation — though per Strawberry Rule 14, `--no-verify` is forbidden in this repo; map that posture into company-os). CI = required status check, non-bypassable, gates merge. Pre-commit alone invites local skips; CI alone wastes reviewer cycles on preventable failures. Run the same script from both entry points so drift is impossible.

## 5. Summary

MAD PR carries the row. Explicit file list. Extend pattern to catch `from ... import` and star imports. Enforce at pre-commit and CI.
