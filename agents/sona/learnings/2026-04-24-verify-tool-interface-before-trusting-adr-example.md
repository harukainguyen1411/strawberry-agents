# Verify tool interface before trusting ADR example blocks

**Date:** 2026-04-24
**Severity:** medium
**last_used:** 2026-04-24

## What happened

Swain's secretary ADR §4.2 contained a stdout-capture template for `tools/decrypt.sh`. Heimerdinger read the actual script rather than trusting the ADR's example block and found a real mismatch: the ADR assumed a stdout-output model, but `tools/decrypt.sh` already implements `--exec` mode (ciphertext via stdin, `--target` runtime env-file, `--exec --`). The ADR example would have produced incorrect implementations — executors following it would have tried to pipe plaintext through stdout, violating Rule 6.

## The generalizable rule

**Architect-to-implementer handoffs always merit a tool-code spot-check before breakdown.**

ADRs are written at a higher abstraction than the implementation. The example blocks in an ADR are often written from memory or from a prior version of the tool. By the time the ADR reaches breakdown, the tool may have evolved.

For any ADR that references an existing tool or script:
1. Read the actual tool source before trusting the example.
2. If the example disagrees with the source, the source wins — update the ADR example, don't implement the example.
3. This is especially critical for tools with security implications (decrypt.sh, secrets injection, auth flows).

## Operational pattern

When dispatching Aphelios/Kayn for breakdown:
- Include explicit instruction: "Read the actual source of any referenced tool before accepting the ADR's example block as correct."
- Or dispatch Heimerdinger for a spot-check pass on tool references before the breakdown agent runs.

## Source

Heimerdinger OQ-P1-4 resolution for Swain secretary ADR. The five new tasks T-new-A..E emerged directly from this discovery.
