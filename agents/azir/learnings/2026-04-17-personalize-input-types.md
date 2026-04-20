# Learning — personalizePage input types ADR (2026-04-17)

## Context
Azir drafted ADR for adding type selector (text/number/email/select) to `personalizePage` in `wallet-studio/core/mmp-app`. Mid-session Duong dropped validation scope; Viktor landed the cue delta first and reported two findings that materially changed the plan.

## Gotchas worth remembering

1. **tse `Params` is `map[string]string`** (`core/tse/api/v1/web/media_types.go:451`). Any future typed-input work on personalize/preferences/claims flows must stringify before `setParams`. Don't assume JSON numbers work — they don't.

2. **`CueValidateJson` runs without `cue.Concrete(true)`.** Cue catches `options: []` but NOT a missing `options` field on a `select` param. Anywhere cue is used as a "backstop" for frontend-authored configs, the backstop has holes. Enforce at the authoring layer or add `cue.Concrete(true)` to the validator. Raised this to Viktor — not fixed this session.

3. **Editing ADRs in place** (status flip draft → in-progress, append to §Change Log) kept history tight and removed "which version did Seraphine read?" ambiguity. Same pattern as Step 2 ADR lock. Keep it.

4. **Scope-drop pattern**: when Duong drops scope mid-ADR, always add a §Change Log entry with what was removed AND why — otherwise Seraphine reads a clean spec and may re-introduce the dropped work. Saved me from a Seraphine re-asking loop here.

5. **Discriminated union + optional `type`** is the right backward-compat pattern for adding variants to an existing frontend config schema. `type?: 'text'` means old configs without the field behave exactly as before, no migration, no cue break.

## Non-gotchas (skip next time)
- Don't re-read the ADR to "verify" edits — Edit tool errors if the old_string doesn't match; trust it.
