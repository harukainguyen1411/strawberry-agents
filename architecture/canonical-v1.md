# canonical-v1 — lock manifest

**Version:** v1 (2026-04-27)
**Lock-tag git ref:** `canonical-v1` (annotated tag at the commit that introduces this file)
**Bypass log:** [`architecture/canonical-v1-bypasses.md`](./canonical-v1-bypasses.md)

This is the hand-curated freeze point for the strawberry-agents personal+work agent system. It pins the agent definitions, the routing manifest, the universal invariants in `CLAUDE.md`, and the runtime hook configuration in `.claude/settings.json` to known blob SHAs at lock-tag time. Any in-week edit to a path enumerated below is either:

1. accompanied by a `Lock-Bypass: <reason>` trailer on the commit AND a row in the bypass log, or
2. preceded by disabling the lock via the manual disable mechanism below.

The Saturday `/canonical-retro` skill (T.COORD.4) is the cadence at which the bypass log is reconciled and the next-version `canonical-v(N+1)-rationale.md` ADR is dispatched.

---

## Manual disable mechanism

The lock is intentionally cheap to disable. Future enforcement scripts (T.P3.1 and onward) MUST honor either of:

- **Env var:** `CANONICAL_V1_LOCK=off` — process-local bypass, no commit needed.
- **Marker file:** `.canonical-v1-unlocked` (single empty file at repo root) — checkout-local bypass, no commit needed (file is `.gitignore`d).

**When to use:** The system is expected to iterate frequently in its early lifetime. For any planned amendment session that will deliberately churn paths in the lock set (e.g. a new agent role, a routing rewrite, a settings.json hook change), set the marker file or env var at the start of the session to suppress the lock-violation surface in the dashboard, do the work, and remove the marker / unset the env var when the session closes. Bypass-log entries are NOT required for work done while the lock is disabled — that is the point of the disable mechanism. Use `Lock-Bypass:` trailers only for surgical in-flight edits that don't warrant a full disable cycle.

The bypass log and the disable mechanism are complementary: the trailer is for one-line corrections; the disable is for whole sessions of churn.

---

## Lock set — agent definitions

```
ec0ff5c647488e10f540a801bfb1e8fa0f467e24  .claude/agents/akali.md
94b6375b6ee945b36904f79fda9c9657adb2874c  .claude/agents/aphelios.md
ff4da95a526edbac0f5e21f5265542431d4a2659  .claude/agents/azir.md
5c50c5ecc66e25101758d589dcd8998c8e5a4337  .claude/agents/caitlyn.md
509be04d5be5bfce00bf5674c1908b7944e29e22  .claude/agents/camille.md
ceb1e7dbefb3c865e533d2ef6e2e9c3c5f9279ae  .claude/agents/ekko.md
80ef66b8bcb1a312e71413a90591083e18f72344  .claude/agents/evelynn.md
0350c45b285ee314203447fc489b690864ed0031  .claude/agents/heimerdinger.md
e03f40dba6e76a43441ca822f366922c851a4a75  .claude/agents/jayce.md
eaaab80747b9727cbe427a293d24f0e5c6c6e7e3  .claude/agents/karma.md
ab199f1314a6bc1a544a2953c98cf0ff325d20b1  .claude/agents/kayn.md
af72105deb20f6978e613066338cc8964f064f37  .claude/agents/lissandra.md
c52146d41f4839322e95f8a0fce6893195ea860a  .claude/agents/lucian.md
11063ecbdcf35f311a7cdfddd5ac9f58daf951a6  .claude/agents/lulu.md
c8feb050e1fe2802de123c578c643a3a188ddb4e  .claude/agents/lux.md
f9b8d958e0e70a6c7d5467bdf8ebe6d234d4dffb  .claude/agents/neeko.md
5321667e193cd8f7198c4a773c1ef6744f15340f  .claude/agents/orianna.md
485657ab77e734585c3377090a812e5b5ed662bc  .claude/agents/rakan.md
906d673a979b5e6d173dafe36d327f2e7e4aeacc  .claude/agents/senna.md
c778068d6a365b37259370be223c1b787909b525  .claude/agents/seraphine.md
494087224d3d6da7aadf4e6dad5e7d483d68783d  .claude/agents/skarner.md
4d3c6b241d85b249e8a34e064d90ce2ba83efb41  .claude/agents/sona.md
cc1b777e64e008fac9d9ba40ed7bb80c73053863  .claude/agents/soraka.md
12532f286b6354f9dceba17abc4382c9db79d3bf  .claude/agents/swain.md
49873348feb57b228d47631b28359f0d8848f98f  .claude/agents/syndra.md
ab41c741b895c39505e3157e9d4c93c9b54743d7  .claude/agents/talon.md
3b2dd04945a714eec6db644f13bf3b41ab0a82a0  .claude/agents/vi.md
e82d4b4436dd39e177bfcccfea2e47a45188a8bc  .claude/agents/viktor.md
291ab0e908ad6a3f1cd409f0e6b6261ddc51bf9a  .claude/agents/xayah.md
b4bf2b89266dec6b54ee8d8bc237dbf7df6f9925  .claude/agents/yuumi.md
```

## Lock set — shared includes

```
db0ebda99e5ce2accbc18dc66ca94ce92d3fc530  .claude/agents/_shared/ai-specialist.md
890b8993bd0122b11994169714bac43e880929fa  .claude/agents/_shared/architect.md
26886c06555f68c5240237205744e48daf3b6814  .claude/agents/_shared/breakdown.md
9b72247b1b763984824af17fc57c291f579c177a  .claude/agents/_shared/builder.md
54d402aa9f0a8495e0f9ba339c446d06106c9dbf  .claude/agents/_shared/coordinator-intent-check.md
e12c6a82dd8bf9b151c148d37cd50e4183ca4c4b  .claude/agents/_shared/coordinator-routing-check.md
a8795c0b6913f2cdc20db85a3040ba37e9b19c0b  .claude/agents/_shared/feedback-trigger.md
a799a3e5f630570c3a989b508668a0c7cdb64ce6  .claude/agents/_shared/frontend-design.md
ef9ff5206f574595e308b0b9ddbd82d0fae3cf76  .claude/agents/_shared/frontend-impl.md
23531a318c40e958974bb94ef5f29e5823adbf09  .claude/agents/_shared/no-ai-attribution.md
84de55709652dcb39ffa5e5c2742455a65d839d3  .claude/agents/_shared/opus-planner-rules.md
341cbca13660a7efc007b82622ae9f3cd46fb42e  .claude/agents/_shared/quick-executor.md
8aa166a4dacd857e93b1d5ad084872c60085ca90  .claude/agents/_shared/quick-planner.md
d6925e258871489abd575d9a1fcd08a24c4ab28f  .claude/agents/_shared/reviewer-discipline.md
8948512517dc35d90e0971c80e5228fe0accd10e  .claude/agents/_shared/sonnet-executor-rules.md
2cb20d52e9ce94222df1cfe83768a54c34c949b0  .claude/agents/_shared/test-impl.md
4263914f10e04398beb7464bf6656466f90e7dd9  .claude/agents/_shared/test-plan.md
```

## Lock set — routing manifest

```
bc4a94977d572ab418a3a7986e76638a55488d44  agents/memory/agent-network.md
```

## Lock set — universal invariants

`CLAUDE.md` rules 1–22 (the entire "Critical Rules — Universal Invariants" block — frozen as a unit; rule additions/edits require a bypass or disable).

```
7f9ce8921acc70b4bbda660b6559c4849b192799  CLAUDE.md
```

## Lock set — runtime configuration

```
215937270962c317e5cb9185318a5994f7a763ae  .claude/settings.json
```

---

## Bypass discipline

Any commit that touches a path in the lock set above MUST either:

- include a `Lock-Bypass: <reason>` trailer (severity is recorded in the bypass log, not the trailer), AND a row in [`architecture/canonical-v1-bypasses.md`](./canonical-v1-bypasses.md) keyed by commit SHA, OR
- be made while the lock is disabled per the manual disable mechanism above.

`--no-verify` is not a substitute for either — the pre-push hook and CI flag undeclared lock-set edits as `kind: lock-violation` regardless of how they got past local hooks.

The Saturday `/canonical-retro` skill reconciles the bypass log: every row's `reconciled` boolean flips true when the next-Saturday retro's output ADR (`plans/proposed/personal/YYYY-MM-DD-canonical-v(N+1)-rationale.md`) cites the bypass SHA in its rationale.

---

*Hand-curated by Evelynn per `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` T.COORD.3. Manifest-SHA fingerprints regenerate when the lock advances to v2 — see the retro ADR for the v1 → v2 transition rationale.*
