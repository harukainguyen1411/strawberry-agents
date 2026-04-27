"""
T6 — asserts stale rules are absent or amended across memory, learnings,
and shared rules files per the T6 enumeration in the plan.

Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T6/T7
"""
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=Path(__file__).parent,
        text=True,
    ).strip()
)

SONA_MEMORY = REPO_ROOT / "agents" / "sona" / "memory" / "sona.md"
EVELYNN_MEMORY = REPO_ROOT / "agents" / "evelynn" / "memory" / "evelynn.md"
AGENT_NETWORK = REPO_ROOT / "agents" / "memory" / "agent-network.md"
EVELYNN_LEARNINGS = REPO_ROOT / "agents" / "evelynn" / "learnings" / "index.md"
SONNET_RULES = REPO_ROOT / ".claude" / "agents" / "_shared" / "sonnet-executor-rules.md"


def test_sona_memory_one_shot_rule_has_teammate_carveout():
    """sona.md must qualify 'background subagents are one-shot' with a teammate carveout."""
    text = SONA_MEMORY.read_text()
    stale_line = "Background subagents are one-shot; SendMessage drops after termination. Re-spawn with full context."
    assert stale_line not in text, (
        "sona.md still contains the unqualified 'Background subagents are one-shot' rule "
        "without a teammate carveout — T7 cleanup not landed"
    )


def test_evelynn_memory_teamcreate_scope_is_policy_aligned():
    """evelynn.md TeamCreate scope must match runbook Policy ('any work that may iterate')."""
    text = EVELYNN_MEMORY.read_text()
    stale_scope = 'When Duong says "have a team work on this", ALWAYS use TeamCreate'
    assert stale_scope not in text, (
        "evelynn.md still contains the stale TeamCreate scope "
        "('When Duong says...') — T7 cleanup not landed"
    )


def test_evelynn_memory_self_close_rule_references_conditional_clause():
    """evelynn.md agent self-close rule must reference the conditional teammate clause."""
    text = EVELYNN_MEMORY.read_text()
    assert "teammate-lifecycle" in text, (
        "evelynn.md self-close rule does not reference _shared/teammate-lifecycle.md "
        "conditional clause — T7 cleanup not landed"
    )


def test_agent_network_references_runbook_and_teammate_mandate():
    """agent-network.md must reference the runbook and teammate-default mandate."""
    text = AGENT_NETWORK.read_text()
    assert "agent-team-mode.md" in text, (
        "agents/memory/agent-network.md does not reference runbooks/agent-team-mode.md "
        "— T7 cleanup not landed"
    )


def test_evelynn_learnings_deployment_session_lesson_superseded():
    """evelynn learnings index must mark the 2026-04-17 deployment-pipeline lesson as superseded."""
    text = EVELYNN_LEARNINGS.read_text()
    assert "SUPERSEDED 2026-04-27" in text, (
        "evelynn learnings index does not mark 2026-04-17 lesson as SUPERSEDED 2026-04-27 "
        "— T7 cleanup not landed"
    )


def test_sonnet_executor_rules_has_teammate_lifecycle_pointer():
    """_shared/sonnet-executor-rules.md must contain a teammate-lifecycle pointer."""
    text = SONNET_RULES.read_text()
    assert "teammate-lifecycle" in text, (
        "_shared/sonnet-executor-rules.md does not reference _shared/teammate-lifecycle.md "
        "— T7 cleanup not landed"
    )
