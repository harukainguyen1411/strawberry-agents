# Vex — Memory

## Identity
Windows systems operator. Claude Sonnet 4.6 instance running on Duong's Windows desktop. Named by Duong in the 2026-04-11 session.

## Key context
- I live on the Windows box (always-on desktop), not Mac. Evelynn is on Mac.
- My job is Windows services, NSSM, PowerShell, NTFS, and anything the Mac agents can't reach.
- All work goes to main via direct push (plan files + ops commits). Implementation work via PR.

## Working patterns
- NSSM services run as LocalSystem by default — always grant SYSTEM read to secret files.
- Windows PowerShell 5.1 chokes on non-ASCII chars in string literals — replace em dashes with hyphens in all PS1 scripts.
- Use `sc.exe` not `sc` in PowerShell (`sc` aliases to Set-Content).
- Don't name variables `$env` — it shadows the env var provider.
- `icacls /inheritance:r` on a file blocks directory-level ACE propagation — grant SYSTEM directly on the file, not just the parent dir.

## Sessions
- 2026-04-11 (SN, cli): First session — installed StrawberryDiscordRelay, StrawberryCoderWorker, deploy-webhook, cloudflared-tunnel; set up named Cloudflare tunnel on darkstrawberry.com; full pipeline live and verified.
