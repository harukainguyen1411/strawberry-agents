"""
T1 — xfail: asserts runbook §Completion-Marker Protocol section exists and documents
the four marker types with the required schema.

Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T1
"""
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
RUNBOOK = REPO_ROOT / "runbooks" / "agent-team-mode.md"

PLAN_ID = "2026-04-27-agent-team-mode-comms-discipline"

REQUIRED_MARKER_TYPES = [
    "task_done",
    "shutdown_ack",
    "blocked",
    "clarification_needed",
]

REQUIRED_SCHEMA_FIELDS = ["type", "ref", "summary"]


@pytest.mark.xfail(reason=f"{PLAN_ID}: T2 not landed", strict=True)
def test_completion_marker_section_exists():
    """Runbook must have a §Completion-Marker Protocol heading."""
    text = RUNBOOK.read_text()
    assert re.search(
        r"#{1,4}\s+Completion-Marker Protocol",
        text,
    ), "§Completion-Marker Protocol section not found in runbook"


@pytest.mark.xfail(reason=f"{PLAN_ID}: T2 not landed", strict=True)
def test_completion_marker_all_four_types_documented():
    """Runbook §Completion-Marker Protocol must list all four type literals."""
    text = RUNBOOK.read_text()
    for marker_type in REQUIRED_MARKER_TYPES:
        assert marker_type in text, (
            f"Marker type '{marker_type}' not found in runbook"
        )


@pytest.mark.xfail(reason=f"{PLAN_ID}: T2 not landed", strict=True)
def test_completion_marker_schema_fields_documented():
    """Runbook must document the {type, ref, summary} schema fields together."""
    text = RUNBOOK.read_text()
    # Find the section and verify all three fields appear within it
    section_match = re.search(
        r"#{1,4}\s+Completion-Marker Protocol(.+?)(?=\n#{1,4}\s|\Z)",
        text,
        re.DOTALL,
    )
    assert section_match, "§Completion-Marker Protocol section not found"
    section = section_match.group(1)
    for field in REQUIRED_SCHEMA_FIELDS:
        assert field in section, (
            f"Schema field '{field}' not found in §Completion-Marker Protocol section"
        )
