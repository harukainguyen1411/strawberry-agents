# Whack-a-mole to redesign

**Trigger:** three rounds of UI "bugfixes" ship green against static string-match tests; bug stays live in the real UI. Duong loses patience.

**Symptom class:** when the same bug keeps returning after each patch, the patch is wrong in kind, not in detail. Pushing harder on the patch direction is wasted motion. The system has a structural flaw.

**Lesson:** when I see ≥2 regressions of the same bug, stop patching and ask:
1. What's the actual root architecture? (Are there two code paths competing? Is the dedup key racy? Is there a shared state with implicit contracts?)
2. What would a correct system look like?
3. Does Duong want to redesign or keep patching?

Escalate the choice. Don't unilaterally keep patching.

**Corollary — test quality:** static string-match / source-grep tests are near-worthless for UI behavior. They assert the presence of certain code, not that the code works. Real tests exercise runtime: JSDOM, happy-dom, or Playwright against a real service. Proxy traps for state-variable access are the gold pattern for "assert this never happens."

**Corollary — AI pace vs human weeks:** Azir initially estimated 2.5 weeks for the redesign. Duong flipped that to ~30min/part. AI-native pace is real. Scale my time estimates down ~10-30x from human gut feel.

**Corollary — role overrides beat stuck agents:** Vi got stuck in an interrupt loop. Caitlyn's stated role is "audit only, doesn't write tests." Duong explicitly overrode. Caitlyn wrote the tests, caught drift Vi wouldn't have, shipped faster. Roles are defaults, not rules.
