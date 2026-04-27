"""
T3 — asserts _shared/teammate-lifecycle.md exists with required clauses,
and all 11 teammate-eligible agent defs embed the include marker.

Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T3/T4/T5
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
SHARED_LIFECYCLE = REPO_ROOT / ".claude" / "agents" / "_shared" / "teammate-lifecycle.md"
AGENTS_DIR = REPO_ROOT / ".claude" / "agents"

TEAMMATE_ELIGIBLE_AGENTS = [
    "senna",
    "lucian",
    "viktor",
    "talon",
    "rakan",
    "jayce",
    "vi",
    "ekko",
    "akali",
    "karma",
    "yuumi",
]

REQUIRED_CLAUSES = [
    "team_name",           # detect mode
    "SendMessage",         # substantive-output rule
    "task_done",           # completion-marker obligation
    "shutdown_request",    # shutdown handling
    "shutdown_ack",        # conditional self-close
]

INCLUDE_MARKER = "<!-- include: _shared/teammate-lifecycle.md -->"


def test_teammate_lifecycle_file_exists():
    """_shared/teammate-lifecycle.md must exist."""
    assert SHARED_LIFECYCLE.exists(), (
        f"_shared/teammate-lifecycle.md not found at {SHARED_LIFECYCLE}"
    )


def test_teammate_lifecycle_required_clauses():
    """teammate-lifecycle.md must contain all required clauses."""
    text = SHARED_LIFECYCLE.read_text()
    for clause in REQUIRED_CLAUSES:
        assert clause in text, (
            f"Required clause '{clause}' not found in teammate-lifecycle.md"
        )


def test_all_teammate_eligible_agents_have_include():
    """All 11 teammate-eligible agent defs must embed the include marker."""
    missing = []
    for agent_name in TEAMMATE_ELIGIBLE_AGENTS:
        agent_file = AGENTS_DIR / f"{agent_name}.md"
        if not agent_file.exists():
            missing.append(f"{agent_name}.md (file not found)")
            continue
        text = agent_file.read_text()
        if INCLUDE_MARKER not in text:
            missing.append(f"{agent_name}.md (marker absent)")
    assert not missing, (
        "Agent defs missing teammate-lifecycle include marker:\n"
        + "\n".join(f"  - {m}" for m in missing)
    )
