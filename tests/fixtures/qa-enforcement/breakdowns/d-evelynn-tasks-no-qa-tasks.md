---
status: proposed
project: agent-network-v1
concern: personal
owner: evelynn
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P2
qa_plan: required
---

# Fixture D — Non-breakdown identity (evelynn) adds ## Tasks without ### QA Tasks (ACCEPT)

## Context

This fixture exercises D5 Surface 2 case (d): a non-breakdown identity (`evelynn`)
commits an amendment adding a `## Tasks` section without a `### QA Tasks` subsection.
The breakdown-qa-tasks linter is identity-gated: it only enforces the `### QA Tasks`
requirement when `STRAWBERRY_AGENT` is `aphelios` or `kayn`. For any other identity
the commit must be accepted.

## Decision

Some decision authored by Evelynn as coordinator. The `## Tasks` section here is
coordination-level only; the QA Tasks contract applies only to Aphelios/Kayn
breakdown agents.

## QA Plan

**UI involvement:** no

- Output surface: stdout

## Tasks

- T1: Dispatch Aphelios for the breakdown
  owner: evelynn
  est_minutes: 5
- T2: After breakdown lands, dispatch Orianna to promote
  owner: evelynn
  est_minutes: 5
