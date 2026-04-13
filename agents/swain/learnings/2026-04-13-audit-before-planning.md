# Audit Existing Infrastructure Before Planning

**Date:** 2026-04-13

When given a task description that characterizes the current state ("no CI/CD", "100% manual"), always verify by reading the actual files before accepting those assumptions into a plan. In this session, the briefing stated "no GitHub Actions workflows for deploy" but the repo had 10 workflows including CI, PR previews, a release pipeline with environment protection, deploy tags, and changesets integration. The plan would have been fundamentally wrong if it had designed all of these from scratch.

**Pattern:** Read `.github/workflows/`, existing scripts, and config files before writing the first line of a plan. The delta between stated and actual state is where the real plan lives.
