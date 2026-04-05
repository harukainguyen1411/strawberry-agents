# Claude Billing: Subscription vs API for Agent System

## Context

Duong's agent system runs multiple Claude Code agents concurrently. This doc compares Claude subscription plans vs API billing for this use case.

Duong currently has a **Claude Pro subscription ($20/mo)** and uses **extra usage bundles** (up to 30% discount) when he hits the cap.

## Two Separate Billing Systems

**These are completely independent.** Anthropic treats the Claude subscription and the API Console as distinct products.

| | Subscription (Pro/Max) | API (Console) |
|---|---|---|
| **Billing** | Monthly fee + optional extra usage | Prepaid credits, pay-as-you-go |
| **Discount** | Up to 30% via usage bundles | No bundle discount available |
| **Wallet** | Subscription billing | Console credits (separate) |
| **Credits expire** | N/A (monthly cycle) | 1 year from purchase |
| **Auto mode** | No | Yes |
| **Concurrent agents** | Single session | Unlimited |

The 30% usage bundle discount on Pro/Max does **not** carry over to API credits. They are separate systems.

## Plans Overview

| | Pro ($20/mo) | Max ($100/mo) | Max ($200/mo) | API (pay-per-use) |
|---|---|---|---|---|
| **Model access** | Opus, Sonnet, Haiku | Opus, Sonnet, Haiku | Opus, Sonnet, Haiku | All models |
| **Usage limits** | Soft cap, throttled | 5x Pro | 20x Pro | No limits |
| **Concurrent agents** | 1 session | 1 session | 1 session | Unlimited |
| **Claude Code** | Yes (Sonnet default) | Yes (Opus default) | Yes (Opus default) | Yes (any model) |
| **Auto mode** | No | No | No | Yes (API/Team/Enterprise) |

## Subscription Extra Usage & Bundles

When Duong exceeds his Pro plan limits, extra usage kicks in at standard API rates. He can pre-purchase **usage bundles** for up to 30% off (bigger bundles = bigger discount, max $2000/mo). These bundles cover all subscription products: Claude chat, Claude Code, Claude Desktop, mobile, Cowork, and third-party integrations.

## API Billing

- **Prepaid credits**: Purchase in Console before use. Deducted per successful call.
- **Auto-reload**: Optional — buys more when balance drops below threshold.
- **Expiry**: Credits expire 1 year from purchase.
- **No discounts**: Full published rates, no bundle mechanism.

Standard API pricing:

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Cached input (per 1M) |
|---|---|---|---|
| **Opus 4** | $15.00 | $75.00 | $1.50 |
| **Sonnet 4** | $3.00 | $15.00 | $0.30 |
| **Haiku 3.5** | $0.80 | $4.00 | $0.08 |

With prompt caching (automatic in Claude Code, ~90% cheaper cached reads), real-world costs drop significantly.

## Team Plan Comparison

| | API | Team Standard | Team Premium |
|---|---|---|---|
| **Per-seat cost** | None | $25/mo ($20 annual) | $125/mo ($100 annual) |
| **Per-token rates** | Standard API rates | Same (for extra usage) | Same (for extra usage) |
| **Included usage** | None (pure pay-per-use) | ~1.25x Pro | ~6.25x Pro |
| **Min seats** | N/A | 5 | 5 |
| **Auto mode** | Rolling out | Yes (research preview) | Yes (research preview) |
| **Concurrent sessions** | Unlimited | Yes | Yes |

**Per-token rates are identical** — Team extra usage is billed at standard API rates.

**Team minimum cost** (solo user): 1 Premium + 4 Standard = $180/mo (annual) or $225/mo (monthly). Most seats go unused.

### API advantages over Team
- No seat minimum — pay only for what you use
- No seat management overhead
- Multiple API keys for per-agent cost isolation
- Direct programmatic access (not just Claude Code)

### Team advantages over API
- Auto mode available now (research preview) — API rollout in progress
- Included usage allowance reduces overage costs
- Admin tools, SSO, centralized billing
- Claude web/desktop/mobile access for team members

## Key Factors for Agent System

1. **Concurrency**: Pro/Max are single-session. Team and API both support concurrent sessions.

2. **Auto mode**: Required for autonomous agents. Available on Team (now, research preview) and API (rolling out). Not on Pro or Max.

3. **Cost**: Subscription + bundles (30% off) is cheaper per token than raw API. Team has same API rates but requires 5 seats minimum. For a solo user, Team's seat overhead makes it uneconomical.

4. **Model flexibility**: API allows mixing models per agent (Haiku for simple tasks, Sonnet for standard, Opus for complex). Subscriptions lock to plan defaults.

## Recommendation

**For Duong's multi-agent system (solo operator):**
- **API is the right choice** — no seat minimums, same per-token rates as Team, full flexibility
- Team requires 5 seats ($180-225/mo) for a solo user — wasted spend
- Monitor API auto mode rollout; it's the only missing piece vs Team

**For personal interactive use:**
- **Keep Pro + usage bundles** — 30% bundle discount is the best per-token rate available
- Pro handles Claude chat, Claude Code (single session), desktop, mobile

**Hybrid approach**: Pro subscription for personal use + API credits for the agent system.

## Current Setup (as of 2026-04-05)

Agent operations now run on Duong's **team plan** subscription. API keys are no longer injected into agent launches. Agents authenticate via Claude Code's logged-in session automatically.

API keys are retained only for app development:
- `apps/contributor-bot/` — uses Anthropic SDK directly
- Any future app that calls the API programmatically

## Cost Isolation

With team plan auth, per-agent cost granularity via API keys is no longer available. Options if needed later:
- Re-enable API keys for cost-sensitive agents (hybrid)
- Use `/cost` per session and log in session closing
- Wait for team plan admin tools to provide per-session breakdowns
