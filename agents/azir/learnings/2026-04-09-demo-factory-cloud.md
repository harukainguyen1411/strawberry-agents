# Demo Factory Cloud Pipeline

## Key decisions

- **Cloud Run over Cloud Functions gen2** for factory-runner: factory.py has a complex Python env (Playwright, Pillow) that is much easier to package as a Dockerfile. Cloud Functions gen2 works but adds friction. Cloud Run already used for signal-board on GCP.
- **Direct subprocess over Agent SDK**: factory.py is a self-contained CLI with its own orchestration. Agent SDK adds indirection with no benefit. `subprocess.Popen` with log streaming is the right call.
- **Two-service architecture**: slack-webhook (thin, fast, < 3s) and factory-runner (long, up to 30 min) must be separate Cloud Run services because Slack requires a 200 within 3s.
- **GCS for artifacts, git optional**: raw run artifacts go to GCS always. wallet-demo.md commit to git is opt-in to avoid noise in git history during iteration.
- **parity_check.py already integrated**: no changes needed to include parity in the cloud pipeline — it runs inside factory.py subprocess.

## Cost reference

~$0.65–1.60 per demo run (bulk is research + generate, 4–6 Claude calls). ~$30/month at 20 demos/month.
