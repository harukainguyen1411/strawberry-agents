---
status: proposed
concern: <personal|work>
owner: <agent-name>
created: <YYYY-MM-DD>
orianna_gate_version: 2
tests_required: <true|false>
tags: [<tag1>, <tag2>]
related:
  - plans/<path-to-related-plan>.md
---

# <Plan title>

## 1. Problem & motivation

<Describe the problem this plan solves and why it matters.>

## 2. Decision

<State the decision taken. Be specific about what will be built/changed.>

### Scope — out

- <List things explicitly excluded from this plan.>

## 3. Design

<Describe the technical approach, architecture, or sequence of changes.>

## 4. Non-goals

- <Non-goal 1>

## 5. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| <risk> | <mitigation> |

## 6. Tasks

- [ ] **T1** — <task description>. estimate_minutes: <1-60>. Files: `<file>` (new|updated). DoD: <done condition>.

Total estimate: <N> minutes.

## Test plan

<Describe what tests cover this plan. If tests_required is false, state why.>

## Rollback

<Describe how to undo this plan if something goes wrong.>

## Open questions

- **OQ1** — <question>. Recommendation: <answer or defer>.
