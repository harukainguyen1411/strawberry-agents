---
status: proposed
owner: unassigned
created: 2026-04-13
---

# Dark Strawberry — Site Trust Hardening

## Context

`darkstrawberry.com` and `apps.darkstrawberry.com` are being flagged by browser security extensions (Bitdefender TrafficLight) and some Chrome profiles show "Not Secure" despite a valid cert. Root causes:
- New domain with no reputation history
- "dark" keyword trips some heuristic filters
- Minimal content → looks like a parked/phishing site to scanners
- No HSTS, no CSP, no Permissions-Policy, no robots.txt, no sitemap, no ownership verification

Incognito loads cleanly because reputation/extensions are the issue, not the deploy.

## Goal

Make the site trusted by major browser reputation systems within 1–2 months. No users should see "Not Secure" or suspicious-site warnings on a clean browser profile.

## Priorities

### P0 — Today / this week

**M1. Submit to reputation databases (global unflag)**
- Google Safe Browsing false-positive: https://safebrowsing.google.com/safebrowsing/report_error/
- Bitdefender URL review: https://www.bitdefender.com/consumer/support/answer/29358/
- Norton Safe Web: https://safeweb.norton.com/report/submit
- Sucuri SiteCheck + URLVoid + VirusTotal scans — confirm no detections, file reports for any false-positives
- Acceptance: all three submissions filed, scan reports clean.

**M2. Harden HTTP security headers (`firebase.json`)**
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(), camera=(), microphone=(), interest-cohort=()`
- `Content-Security-Policy` in Report-Only mode first, tighten over 2 weeks
- Keep existing `X-Content-Type-Options: nosniff` + `X-Frame-Options: DENY`
- Acceptance: securityheaders.com grade A or A+, Mozilla Observatory score >80.

**M3. Add `/robots.txt` and `/sitemap.xml`**
- `robots.txt`: allow `Googlebot`, `Bingbot`; disallow scrapers if desired
- `sitemap.xml`: list landing + portal routes
- Acceptance: curl returns both, Google Search Console accepts the sitemap.

**M4. Submit to Google Search Console + Bing Webmaster Tools**
- Verify ownership via DNS TXT or Firebase meta tag
- Submit sitemap
- Acceptance: both consoles show "verified" + sitemap processed.

### P1 — Within 2 weeks

**M5. Fill out the landing page**
- Real hero copy, about section, "what it does" explanation, team page
- A parked-looking site triggers anti-phishing heuristics; content is the strongest trust signal
- Acceptance: landing page >500 words of real content, includes at least 3 images.

**M6. Privacy policy + Terms of Service pages**
- `/privacy` and `/terms` routes
- Can be generated via a boilerplate (e.g. privacypolicies.com) then reviewed
- Link from landing footer
- Acceptance: both pages live, linked from every page, reviewed by Duong.

**M7. Contact page**
- `/contact` with a real email (not a generic contact@)
- Acceptance: live page + reachable mailbox.

### P2 — Ongoing / medium term

**M8. Inbound links from reputable domains**
- Link from personal site / GitHub profile README / relevant dev blogs
- Boosts domain authority faster than time alone

**M9. Email authentication (if domain sends email)**
- SPF, DKIM, DMARC records in DNS
- Reputation systems cross-reference email reputation with web reputation

**M10. CSP tightening**
- Move CSP from Report-Only (M2) to enforced
- Remove `unsafe-inline` / `unsafe-eval` if present
- Acceptance: CSP enforced with no violations in 7 consecutive days of reports.

## What this won't fix

- **Domain age** — the #1 reputation factor. New domains get a ~6 month penalty regardless of content. Time fixes this naturally.
- **The word "dark"** in the domain — mild heuristic factor. Not worth rebranding over.
- **Paranoid corporate / ISP DNS filters** (Cisco Umbrella, OpenDNS) — these have their own policies; case-by-case submissions needed if users report.

## Things NOT to do

- Don't use URL shorteners pointing here — they kill reputation
- Don't load scripts from low-reputation CDNs
- Don't rename the domain — destroys what little reputation exists
- Don't remove the valid TLS cert or serve any mixed content

## Verification matrix

| Mitigation | What would have fixed today's "Not Secure" warning? |
|---|---|
| M1 (DB submissions) | Yes, once accepted (1–3 days per vendor) |
| M2 (security headers) | No — the warning is extension-driven, headers don't suppress extensions, but they raise scanner scores across the board |
| M3 (robots/sitemap) | Indirectly — removes "parked site" heuristic |
| M5 (real content) | Indirectly — empty sites score worse |

Main point: we ship M1 immediately (fastest real remediation), then stack M2–M7 for long-term reputation.
