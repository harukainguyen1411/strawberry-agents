---
title: Cafe-from-Home — Driving the Windows Agent Stack from Off-LAN
status: proposed
owner: pyke
created: 2026-04-08
gdoc_id: 1PDrMCBK2GZ5Tya1jiwK-JpQHr5FIZ0YSZNYjMVlVNXQ
gdoc_url: https://docs.google.com/document/d/1PDrMCBK2GZ5Tya1jiwK-JpQHr5FIZ0YSZNYjMVlVNXQ/edit
---

# Cafe-from-Home — Driving the Windows Agent Stack from Off-LAN

## Problem

Duong wants the following scenario to work:

- The Windows box (the agent runtime — Claude Code instances, MCP servers, secrets, the whole stack) stays at home, powered on, with a LAN connection.
- Duong takes his Mac to a cafe, hotel, conference, or any other off-LAN location with an internet connection of unknown quality and unknown trustworthiness.
- From the cafe, Duong drives the Windows agents through Claude Code's Remote Control transport (`claude --dangerously-skip-permissions --remote-control "Evelynn"`), the same way he does at home.
- He also wants the ability to **fully restart** Claude Code processes on the Windows box from the cafe, not just `/clear` them. `/clear` already works because it is just text injected into the existing Remote Control session; a hard restart needs an out-of-band mechanism.

Today this works **only on the home LAN**. Off-LAN, the Mac cannot reach the Windows Remote Control endpoint at all (NAT, no public IP, no port forward). The question is how to bridge that gap without trashing the security posture, and without using Tailscale (see Constraints).

## Constraints and Facts

- **Tailscale is out.** The Mac is a work machine. Duong cannot install personal VPN software on it. This was explicitly relitigated and confirmed; do not propose Tailscale variants.
- The Windows box is at a residential connection, behind consumer NAT, no static public IP, no existing port-forward.
- The Windows box runs as an admin-privileged Windows user account. **No BitLocker** on the system drive. This is pre-existing security debt, called out below in Threat Model but not blocking for this plan.
- Remote Control's actual transport, auth, and logging properties are **not yet fully characterized** (see the parallel Pyke-Review item in `2026-04-08-encrypted-secrets.md`, Required Change 1, research follow-up). Whatever option we pick here will sit *underneath* Remote Control as a transport substrate, so the unknowns about Remote Control itself remain orthogonal — but they do matter for the threat model below.
- The Mac side cannot install kernel extensions, system-wide VPN clients, or anything requiring admin on the work machine. Userspace tools, browser-based access, or per-app proxies are acceptable.
- Bandwidth at the cafe is best-effort. Whatever solution we pick must tolerate flaky links and reconnect cleanly.
- Duong wants this to be reversible — if a particular service turns out to be a bad fit, he wants to rip it out and try the next option without having permanently changed the home network.

## Threat Model

The core uncomfortable fact: **whatever path we open, we are exposing the Windows agent host to the open internet for the first time.** That host has:

- Admin-privileged user account.
- No full-disk encryption.
- Long-lived API keys and bot tokens (currently plaintext in `secrets/*.env`; the encrypted-secrets plan will fix the *plaintext* part but the keys are still on disk and decryptable by the Windows age key).
- A Claude Code process with `--dangerously-skip-permissions` that will execute arbitrary shell commands on whatever input it receives via Remote Control.

So the threat model has to answer four distinct questions:

1. **Who can reach the Windows box's listening surface at all?** (network reachability)
2. **What proves to the Windows box that an inbound connection is from the Mac and not from someone else?** (authentication of the transport)
3. **What proves to Remote Control specifically that the connected client is authorized?** (authentication of the application layer)
4. **If the transport substrate or its provider is compromised, what does the attacker get?** (blast radius)

### Adversaries to consider

- **Cafe Wi-Fi neighbor** — passive sniffing on the cafe LAN. Mitigated by any TLS-on-the-wire transport.
- **Cafe Wi-Fi captive portal / MITM proxy** — active TLS interception by a hostile or misconfigured network operator. Mitigated by transports that pin certificates or use mTLS rather than relying on the cafe's CA store.
- **Internet-wide drive-by scanner** — Shodan-style port scans on the Windows residential IP. Mitigated by *not* exposing a public listening port at all (i.e., outbound-only tunnels rather than port forwards).
- **Compromise of the third-party tunnel/relay provider** — Cloudflare, ZeroTier controllers, Twingate connectors, etc. Each option's blast radius differs; spelled out per-option below.
- **Stolen Mac** (left at the cafe table while Duong goes to the bathroom) — the Mac has the credentials for whatever transport we pick. Mitigated by short-lived auth, OS-level disk encryption on the Mac (work IT policy presumably already enforces FileVault), and revocable client identities.
- **The Claude model itself going off-script while Duong is offline** — orthogonal to this plan but worth naming, because exposing the agent stack to remote control means *anyone with the credential* can drive it, and the authorization story has to be explicit.

### Pre-existing security debt this plan does not fix

- Windows account is admin. Should be standard user with UAC, but that's a separate hardening plan.
- No BitLocker. Should be enabled. Separate plan.
- Long-lived API keys with no rotation cadence. Encrypted-secrets plan addresses storage; rotation cadence is its own follow-up.

This plan should be approved with the understanding that opening the cafe path *increases* the cost of those debts, because a previously-LAN-only host is now reachable from somewhere outside the house. If Duong wants to do hardening before opening the path, that's a defensible call too.

## Options

Three real options evaluated, plus one anti-option for the record.

### Option A — Cloudflare Tunnel (`cloudflared`) with Cloudflare Access

**How it works.** Run `cloudflared` as a Windows service on the home box. It opens an outbound persistent connection to Cloudflare's edge — **no inbound port, no port-forward, no public IP needed**. Cloudflare publishes a hostname like `agents.duong.example` that proxies to a chosen local port on the Windows box. Cloudflare Access sits in front of that hostname and enforces an identity check (Google/GitHub/email-OTP/mTLS client cert) before any traffic reaches the tunnel. The Mac connects via either a normal browser (for web-protocol services) or `cloudflared access tcp` (a small userspace binary on the Mac) for raw TCP.

**Pros.**
- **No inbound port on Windows.** Pure outbound from the home side. Residential ISP / NAT / firewall don't need to know.
- **Identity-aware proxy in front.** Cloudflare Access turns "is this connection from the Mac" into "did this user complete an OIDC flow with my chosen identity provider in the last N hours." Replaces ambient network trust with explicit user auth.
- **Mac side is one userspace binary** (`cloudflared`), no kernel extension, no admin install. Acceptable on a work Mac.
- **Free tier covers single-user use.** Cloudflare Access is free for up to 50 users.
- **Cloudflare terminates TLS at the edge with their cert; the tunnel from edge to home is also TLS.** Cafe MITM cannot intercept because the Mac validates Cloudflare's cert against the public CA chain, and Cloudflare validates the tunnel against its own cert pinning.
- **Reversible.** Stop the Windows service, delete the tunnel from the Cloudflare dashboard, done. No residue on the home network.

**Cons.**
- **Cloudflare is in the trust path.** Cloudflare can technically MITM the connection (they hold both ends of the TLS). Blast radius if Cloudflare or a compromised Cloudflare employee targets Duong: full read/write of Remote Control traffic. Realistic threat for a personal agent stack? Low. But it's on the record.
- **Requires a domain.** Duong needs a domain on Cloudflare DNS (or willing to register one). Dollars-per-year, not blocking.
- **Raw TCP path requires the `cloudflared access tcp` client on the Mac.** Userspace, but it's a binary the work Mac has to permit running. Should be fine on standard FileVault+Gatekeeper Macs but worth confirming.
- **Cloudflare Access OIDC flows expect a browser** — the first connection from a new Mac requires opening a Cloudflare-hosted login page. After that, a JWT is cached locally. Manageable, slightly clunky.

**Auth story.** Layered: (1) outbound tunnel cert pinned to Cloudflare edge, (2) Cloudflare Access OIDC requires Duong to sign in via his identity provider before the tunnel passes traffic to Windows, (3) Remote Control's own auth (whatever it is) sits on top. Three independent gates. Stolen Mac without the OIDC session cookie ≠ instant access; stolen Mac mid-session = attacker has a window equal to the JWT lifetime, which can be set short (1 hour).

**Blast radius if compromised.** Cloudflare account compromise = full access. Mitigation: enable hardware-key 2FA on the Cloudflare account, use a dedicated Cloudflare account for this purpose only.

### Option B — ZeroTier

**How it works.** ZeroTier creates a virtual layer-2 network (a "ZeroTier network") with its own private IP space (e.g., `10.147.x.x`). Each member machine runs the ZeroTier client and joins the network with a node ID; the network admin (Duong) authorizes nodes via the ZeroTier Central web UI. Once joined, member machines can reach each other by virtual IP as if on the same LAN. Mac talks to Windows on the ZeroTier IP, Remote Control listens on that IP, done.

**Pros.**
- **Conceptually identical to Tailscale**, which Duong already understands. Same mental model: peer-to-peer overlay network, NAT-traversed, mostly-direct connections with relay fallback.
- **Free tier covers up to 25 nodes.** Two nodes is well inside it.
- **No inbound port-forward on the home network.** Outbound from both ends to ZeroTier's controllers; peer-to-peer once a session is established.
- **Mac client is userspace** (a launch agent + tun device). The tun device is the catch — see Cons.
- **Network-layer reachability.** Once joined, *any* TCP/UDP service on Windows is reachable from Mac without per-service config. Future-proof: if Duong adds another service later (web UI, MCP debug port, etc.), no extra work.

**Cons.**
- **Tun/tap device on the Mac.** ZeroTier installs a virtual network interface, which on macOS requires a kernel extension or system extension. **This is the same blocker that killed Tailscale on the work Mac.** ZeroTier on macOS uses a System Extension (newer, post-kext); the work IT policy may or may not permit it. **Critical question for Duong: is the issue with Tailscale specifically the "personal VPN software" policy framing, or is it specifically the tun device / system extension?** If it's the former, ZeroTier might be allowed because it's framed as "virtual networking" rather than "VPN." If it's the latter, ZeroTier hits exactly the same wall.
- **ZeroTier Inc. is in the trust path.** Same shape as Cloudflare: they run the controllers and the relay infra. Blast radius if compromised: control over network membership (could add a malicious node), and potentially traffic interception via relays (mitigated if connections are direct peer-to-peer, but you can't always guarantee that).
- **Network-layer access means network-layer blast radius.** If the ZeroTier credential on the Mac is stolen, the attacker gets to *every* port on the Windows box, not just Remote Control. Less surgical than Option A.
- **No built-in identity-aware auth.** Authentication is "did the network admin authorize this node ID." Once authorized, that node has full network access until revoked. Stolen Mac = full access until Duong notices and revokes from the ZeroTier dashboard.

**Auth story.** Single layer at the network: node membership. Application-layer auth (Remote Control) sits on top, which is the only thing protecting the Windows box from a stolen-Mac scenario.

**Blast radius if compromised.** ZeroTier controller compromise = attacker can join malicious nodes to Duong's network. Mitigation: 2FA on ZeroTier Central, audit the member list periodically. Stolen Mac = full LAN-equivalent access until manual revocation.

### Option C — Twingate

**How it works.** Zero-trust remote access. Run a Twingate "Connector" as a Windows service on the home box; it makes outbound connections to Twingate's controllers — no inbound ports needed on home. The Mac runs the Twingate Client app (userspace). Duong defines "Resources" (specific host:port pairs on the Windows box) and assigns them to users/groups. Auth is via OIDC (Google, GitHub, etc.) with optional device posture checks.

**Pros.**
- **No port-forward on home, no public IP.** Same outbound-tunnel shape as Cloudflare.
- **Identity-aware per-resource access.** Even more granular than Cloudflare Access — Duong can grant access to "Remote Control port on Windows" specifically, not "the whole Windows host."
- **Free tier covers small personal use** (2 users, limited connectors, but enough for one Mac + one Windows).
- **Mac client is userspace, no kext, no system extension required for the recent versions.** This is the key differentiator from ZeroTier — Twingate explicitly markets itself as "no VPN, no tun device" and uses a userspace proxy approach. **Most likely to actually be installable on a work Mac.**
- **OIDC auth with short-lived tokens.** Stolen Mac mid-session has a bounded window.
- **Reversible.** Uninstall connector + client, delete the resource from the dashboard.

**Cons.**
- **Twingate is in the trust path.** Same shape as Cloudflare and ZeroTier. Blast radius: traffic interception if the Twingate control plane is compromised. Mitigation: 2FA on Twingate account.
- **Less battle-tested than Cloudflare for the specific use case** of tunneling a single TCP service. Cloudflare Tunnel has been around longer and is more documented for "ssh/tcp through the edge" patterns.
- **Per-resource model means per-service config.** If Duong adds another local port later, he has to define another Resource. Slight friction vs. ZeroTier's "everything is reachable" model.
- **Work Mac compatibility still needs verification.** The marketing says "no VPN" but Duong should test the installer on the actual work Mac before committing.

**Auth story.** Layered: (1) outbound connector tunnel TLS, (2) Twingate OIDC at the application layer per resource, (3) Remote Control's own auth on top. Same shape as Cloudflare with more granularity.

**Blast radius if compromised.** Twingate account compromise = attacker can grant themselves resource access. Mitigation: hardware 2FA. Stolen Mac = bounded by OIDC token lifetime.

### Option D (anti-option, for the record) — Reuse Remote Control over the public internet

**How it works.** If Remote Control's transport already has a "connect to a public address" mode, just open a port on the home router, forward it to Remote Control's listening port on Windows, and connect from the Mac directly.

**Why this is rejected.** Three reasons:
1. **We don't yet know what Remote Control's transport guarantees are.** The encrypted-secrets review (Required Change 1, research follow-up) explicitly flags this as an open question. Until we know whether Remote Control even has TLS, mutual auth, replay protection, and rate limiting, exposing it to the open internet would be reckless.
2. **Direct port-forward = unauthenticated drive-by exposure.** Shodan finds open ports within hours. Even if Remote Control has good auth, every drive-by connection is a potential 0-day vector.
3. **Residential ISP terms of service.** Many residential ISPs prohibit running "servers" on the connection. Whether enforced or not, it's a nuisance to be on the wrong side of.

Not recommended under any circumstances. Listed only so the option is on the record as considered and rejected.

## Recommendation

**Option A — Cloudflare Tunnel with Cloudflare Access — is the recommended primary path.**

Why, in order of importance:

1. **Mac-side compatibility is the highest-risk axis.** Cloudflare's Mac-side requirement is a single userspace binary (`cloudflared`) with no tun device, no system extension, no kernel module. This is the most likely to actually work on a locked-down work Mac. Twingate is the close second but has a slightly less proven track record for the specific TCP-tunnel pattern. ZeroTier almost certainly hits the same wall as Tailscale.
2. **Identity-aware proxy auth gives the best stolen-Mac story.** Short-lived JWTs from an OIDC provider mean the credential lifetime on the Mac is bounded, and revocation is one dashboard click.
3. **Outbound-only on the home side** means Duong's residential router and ISP don't need to know anything is happening. No port-forward, no DDNS, no router config drift.
4. **The smallest, most surgical exposure.** A single named resource (the Remote Control TCP port) reachable to a single authenticated identity. Future services can be added explicitly when they're needed.
5. **Reversibility is trivial.** Stop the Windows service, delete the tunnel from the dashboard. No residue.

**Twingate is the recommended fallback** if Cloudflare turns out to have a quirk that breaks the use case (e.g., the `cloudflared access tcp` binary doesn't behave well with Remote Control's framing, or Cloudflare Access OIDC flows are too clunky for repeated cafe use). The architectural shape is nearly identical and switching costs are low.

**ZeroTier is recommended only if Twingate also fails on the work Mac** and Duong is willing to test the system-extension approval on the work-managed laptop.

## Implementation Outline (high-level)

This is a sketch of the work, not a step-by-step. Implementer fills in details after approval.

### Phase 1 — Cloudflare Tunnel baseline

1. Duong registers a domain on Cloudflare (or moves an existing domain to Cloudflare DNS). One-time. ~$10/yr.
2. Create a dedicated Cloudflare account for the agent stack. Enable hardware-key 2FA before doing anything else.
3. Install `cloudflared` as a Windows service on the home box. Authenticate to Cloudflare. Create a named tunnel, e.g. `strawberry-home`.
4. Configure the tunnel to expose the Remote Control listening port as a TCP ingress with a hostname like `remote-control.agents.duong.example`.
5. Enable Cloudflare Access on that hostname. Configure an Access policy: "Identity = Duong's chosen IdP; session lifetime = 1 hour."
6. On the Mac, install `cloudflared` (userspace binary, `brew install cloudflared`). Verify no admin/kext/system-extension prompt.
7. From Mac, run `cloudflared access tcp --hostname remote-control.agents.duong.example --url localhost:<chosen-local-port>`. This opens a local listener on the Mac that tunnels through Cloudflare to Windows.
8. Point Mac-side Remote Control client at `localhost:<chosen-local-port>`.
9. End-to-end test from home (on the same LAN, just to verify the tunnel works) and then from a phone hotspot (off-LAN reality check) before relying on it from a real cafe.

### Phase 2 — Operational hardening

1. Document the rotation cadence for the Cloudflare API tokens used by `cloudflared` (rotate every N days; N depends on the Required-Change-2 rotation plan from the encrypted-secrets review).
2. Wire `cloudflared` Windows service into the existing log/monitoring setup so failed tunnel reconnects are visible.
3. Add a one-line "is the tunnel up?" health check to Pyke's session-start checklist.
4. Document the disable / kill-switch procedure: how to fully revoke Mac access in under 60 seconds if the Mac is lost. (Cloudflare Access: revoke the user from the Access application. Tunnel: stop the Windows service. Both should be one-click.)

### Phase 3 — Remote process restart capability

This is a separate concern from the transport. `/clear` works today because it is text injected into an already-running Remote Control session. **Full process restart of Claude Code on Windows requires a Windows-side wrapper service** that:

- Listens on a small local port (or a named pipe) for restart commands.
- Authenticates the caller (shared secret? mTLS? fed by the same Cloudflare Tunnel as a second resource?).
- Stops and restarts the Claude Code processes safely (graceful shutdown, wait for exit, relaunch with the same flags, log result).

**Recommendation: scope the restart wrapper as a follow-up plan, not part of this one.** Reasoning:

- The transport plan (Cloudflare Tunnel) is independently valuable and unblocks the cafe use case immediately for everything except restart.
- The restart wrapper has its own design questions (auth, process lifecycle, what counts as "graceful," whether to support partial restarts of just one Claude Code instance vs. all of them, how to surface failures back to Duong) that deserve their own plan and review pass.
- Shipping the transport first and then layering restart on top is the cleanest sequence — restart-over-tunnel can reuse the same Cloudflare ingress with a second hostname or path-based routing.

A separate plan file (`plans/proposed/2026-XX-XX-windows-agent-restart-wrapper.md`) should be drafted by Pyke after this transport plan is approved and the transport is actually working in the field.

## Open Questions for Duong

1. **What exactly is the work Mac's "no VPN" policy?** Is it the system-extension/tun-device class of software that's blocked, or is it framed as "personal VPN clients" specifically? This determines whether Twingate (no tun) is a real fallback and whether ZeroTier (system extension) is dead on arrival. **Critical — answer changes the recommendation if Cloudflare doesn't pan out.**
2. **Are you willing to register or move a domain to Cloudflare DNS?** Cloudflare Tunnel needs a hostname under a Cloudflare-managed zone. ~$10/yr for a fresh domain, or free if you already own one and are willing to migrate DNS. Not technically blocking — there are workarounds with `*.trycloudflare.com` ephemeral hostnames — but the production path needs a real domain.
3. **What identity provider do you want to use for Cloudflare Access?** GitHub, Google, email-OTP, or something else? Affects how login feels at the cafe (browser flow once per JWT lifetime).
4. **JWT session lifetime preference?** I'm proposing 1 hour as the default — short enough that a stolen-Mac window is bounded, long enough that you're not re-authing every 10 minutes mid-cafe-session. Acceptable, or do you want shorter / longer?
5. **Does the existing Remote Control transport actually tolerate a TCP proxy in front of it?** I'm assuming it's a normal TCP-framed protocol that doesn't care about source IP or rely on multicast / broadcast / link-local features. If it has any of those, the tunnel breaks. **Pyke needs to test this on the home LAN before committing to Cloudflare end-to-end** — easy to do: run `cloudflared access tcp` against a local target and see if Remote Control survives the extra hop.
6. **Restart wrapper: same plan or separate?** I'm recommending separate. Confirm.
7. **Windows hardening order of operations.** This plan opens a path *before* fixing the BitLocker / non-admin-account / key-rotation debt. Do you want to:
   - (a) Ship the cafe path now and accept the increased exposure on the existing debt, or
   - (b) Block the cafe path until at least BitLocker is enabled and the encrypted-secrets plan is implemented?
   Pyke prefers (b) but it's a tradeoff between speed and posture. Your call.
8. **Cafe connection sanity check for first run.** Do you have a "trusted off-LAN test environment" — your phone hotspot, a friend's apartment, anything that isn't actually a cafe — where the first end-to-end test can happen? First-time deployment in a real adversarial cafe network is asking for a frustrating debug session. Recommend testing from a phone hotspot first.

## Rollback / Reversibility

**Cloudflare Tunnel (Option A) — full rollback in under 5 minutes:**

1. Stop the `cloudflared` Windows service: `sc stop cloudflared` (or via Services.msc).
2. Disable the service: `sc config cloudflared start=disabled`.
3. Delete the tunnel from the Cloudflare dashboard (`Zero Trust → Networks → Tunnels → strawberry-home → Delete`).
4. Delete the Access application from the dashboard.
5. Optionally: revoke any Cloudflare API tokens that were issued for the tunnel.

After this, the Windows box has no inbound exposure of any kind, identical to its pre-cafe-plan state. The home network and router are untouched throughout — no port forwards were ever created. The Mac retains the `cloudflared` binary (`brew uninstall cloudflared` removes it) but it does nothing without an active tunnel on the other end.

**No persistent residue on the home network or the Windows box** beyond:
- The `cloudflared` binary in `Program Files`
- The Windows service registration
- A tunnel credentials file in `%USERPROFILE%\.cloudflared\` (delete it)

Switching to Option B (Twingate) or Option C (ZeroTier) after rolling back A is unblocked — the options don't conflict with each other and could in principle be installed side-by-side during a transition, though there's no reason to.

**Restart wrapper rollback** (when that lands as a separate plan): stop the wrapper service, remove its tunnel resource. Independent of the transport.

## Out of Scope (future work)

- Full process restart wrapper (separate plan).
- Windows account hardening (separate plan: standard user, UAC, BitLocker).
- Long-lived API key rotation cadence (follow-up to encrypted-secrets plan).
- Multi-user access (more than one Mac, phone-side full access, etc.).
- Hardware-key WebAuthn for Remote Control auth itself (depends on Remote Control transport investigation).
- Audit logging of every cafe session (who connected from where, when) — Cloudflare Access provides this for free at the access layer; surfacing it into the agent system is future work.

## Pyke's note

The cafe path is a posture downgrade — there is no version of "exposing the Windows agent host to the open internet" that is *better* than "only reachable on the home LAN." The honest framing is that the convenience is worth a measured risk *if* the transport is identity-gated, the credential lifetime is short, the rollback is one click, and the pre-existing security debt on the Windows box is acknowledged and on a fix-it list. Cloudflare Tunnel + Cloudflare Access is the cleanest way to take that trade. Don't open the path until you've tested the rollback procedure works — the rollback is the only thing that lets you treat this as a reversible experiment instead of a permanent posture change.

— Pyke
