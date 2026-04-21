# Bash deny on builder agents is builder-specific, not session-wide

**Date:** 2026-04-21
**Session:** 0cf7b28e (third leg)
**Trigger:** Viktor `a3e3a4b74e415d38f` and Jayce `a9aa507e61a3f6f23` were both Bash-denied on MAD.C. Sona inferred Bash was session-wide unavailable and self-executed the xfail-flip commits and conftest patch directly. Duong flagged the drift.

## What happened

Two consecutive builder agents (Viktor, Jayce) refused Bash on the same task. Sona treated this as a session-wide Bash denial and stepped in as executor — running `pytest`, writing xfail-flip commits, patching `conftest.py` directly via coordinator Bash. This violates the coordinator-never-executes rule.

The actual pattern: Ekko, Rakan, Heimerdinger, and Vi all ran Bash fine this same leg. The deny was builder-agent-specific (likely sandbox permission profile tied to those agent definitions or that task context), not a session property.

## Correct response

When a builder agent (Viktor, Jayce) is Bash-denied on an implementation task:
1. Note the deny in session state.
2. Try a different agent class — tester agents (Vi, Rakan) and advisor/devops agents (Ekko, Heimerdinger) are not builder-class and may have different sandbox profiles.
3. Only escalate to Duong if all agent classes are denied and the task cannot proceed.
4. Never self-execute as coordinator. The coordinator-never-executes rule has no "if all else fails" carve-out.

## Generalizable rule

"Bash deny on a builder agent" is evidence about that agent's sandbox profile in that context — not a statement about the session or other agent classes. Always try a tester or devops agent before concluding Bash is unavailable.
