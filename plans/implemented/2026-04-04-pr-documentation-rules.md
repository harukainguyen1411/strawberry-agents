---
status: proposed
owner: pyke
date: 2026-04-04
---

# PR Documentation Rules

## Problem

PRs with architecture changes or significant feature work sometimes land without updating the corresponding docs. This leaves `architecture/` and `README.md` files stale — particularly `apps/myapps/README.md`, which is used as triage context for the Discord bot.

## Approach

PR template checklist + reviewer responsibility. No automation.

## Why Not Automate?

- File-change heuristics produce false positives (touching `mcps/` doesn't always mean architecture changed)
- The mapping between code and docs requires context only the authoring agent has
- We have reviewers (Lissandra, Rek'Sai) — let them enforce it
- Solo setup — CI checks add maintenance overhead without proportional value

## Implementation

### 1. Update PR Template

Add a documentation checklist to `.github/pull_request_template.md`:

```markdown
## Documentation Checklist
- [ ] Architecture change? Updated relevant `architecture/` doc
- [ ] New feature or removed feature? Updated relevant `README.md`
- [ ] Changes agent communication or MCP tools? Updated `agent-network.md`
- [ ] N/A — no documentation updates needed
```

The opener checks the relevant boxes. Unchecked boxes signal to reviewers that docs may be missing.

### 2. Reviewer Guideline in GIT_WORKFLOW.md

Add a "Review Protocol" section:

- Reviewers must verify documentation checklist is accurate
- If the PR touches `mcps/`, `architecture/`, or `agents/memory/agent-network.md` — corresponding docs must be updated
- If the PR adds/removes features — `README.md` must reflect the change
- Block the PR if docs are missing for qualifying changes

### 3. Agent-network.md Rule

Add under Protocol: "When opening a PR, check the documentation checklist in the PR template. If your change touches architecture, MCP tools, or features, update the relevant docs *in the same PR*."

## Effort

~5 minutes to update the template and add the guideline sections. Zero ongoing maintenance.
