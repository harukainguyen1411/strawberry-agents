# Learning: main.py as a shared file causes repeated backend crashes

**Date:** 2026-04-15
**Context:** Demo Studio v3 Phase A+B sprint with 6-agent team

## Problem
Multiple agents (Jayce, Kayn) editing `main.py` simultaneously caused uvicorn auto-reload crashes every time a file was saved mid-edit. The backend went down 4+ times during the sprint.

## Root cause
Uvicorn's `--reload` flag watches for file changes and restarts immediately — even if the file is in an invalid (mid-edit) state. When two agents both have main.py open, each save triggers a restart.

## Solution that worked
Rule: "Build in separate files (workers.py, phase.py, config_patch.py), wire into main.py last with a minimum 2-3 line import + include_router only. Request approval before touching main.py."

This worked but required repeated enforcement — agents found reasons to edit main.py early.

## Better approach for next time
1. At sprint start, explicitly assign main.py ownership to ONE agent at a time
2. Consider disabling auto-reload during active multi-agent sprints (`--no-reload`)
3. Enforce the "separate file" pattern in the initial task brief, not as a correction mid-sprint
4. The pattern to follow: `phase.py` (router) → `main.py` (2-line wire-in) is the gold standard
