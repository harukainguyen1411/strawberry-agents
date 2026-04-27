"""
T10 — xfail: asserts existence of an end-to-end demo artifact at
assessments/personal/2026-04-*-team-mode-comms-e2e-demo.md containing
required schema elements.

Plan: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md T10
"""
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
ASSESSMENTS_DIR = REPO_ROOT / "assessments" / "personal"

PLAN_ID = "2026-04-27-agent-team-mode-comms-discipline"

REQUIRED_SCHEMA_FIELDS = [
    "team_name",       # team identity
    "task_done",       # completion marker in transcript
    "shutdown_request",  # clean shutdown initiated
    "shutdown_ack",    # clean shutdown acknowledged
]


def _find_demo_artifact():
    """Find the e2e demo artifact by glob pattern."""
    if not ASSESSMENTS_DIR.exists():
        return None
    matches = list(ASSESSMENTS_DIR.glob("2026-04-*-team-mode-comms-e2e-demo.md"))
    return matches[0] if matches else None


@pytest.mark.xfail(reason=f"{PLAN_ID}: T11 not landed", strict=True)
def test_e2e_demo_artifact_exists():
    """End-to-end demo artifact must exist under assessments/personal/."""
    artifact = _find_demo_artifact()
    assert artifact is not None, (
        f"No e2e demo artifact found matching "
        f"assessments/personal/2026-04-*-team-mode-comms-e2e-demo.md"
    )


@pytest.mark.xfail(reason=f"{PLAN_ID}: T11 not landed", strict=True)
def test_e2e_demo_has_required_schema():
    """Demo artifact must contain team_name, completion markers, and clean shutdown sequence."""
    artifact = _find_demo_artifact()
    if artifact is None:
        pytest.fail("Demo artifact not found — T11 not landed")
    text = artifact.read_text()
    for field in REQUIRED_SCHEMA_FIELDS:
        assert field in text, (
            f"Required schema field '{field}' not found in demo artifact"
        )


@pytest.mark.xfail(reason=f"{PLAN_ID}: T11 not landed", strict=True)
def test_e2e_demo_has_at_least_two_teammates():
    """Demo artifact must document at least 2 teammates (DoD requirement)."""
    artifact = _find_demo_artifact()
    if artifact is None:
        pytest.fail("Demo artifact not found — T11 not landed")
    text = artifact.read_text()
    # At minimum two teammate handles must appear in SendMessage contexts
    teammate_refs = re.findall(r'SendMessage.*?to["\s:]+(\w+)', text, re.IGNORECASE)
    unique_recipients = set(teammate_refs)
    assert len(unique_recipients) >= 2, (
        f"Demo artifact must show ≥2 unique SendMessage recipients, "
        f"found: {unique_recipients}"
    )
