"""Tests for --since-last-compact flag in scripts/clean-jsonl.py.

Five cases:
  a) no marker + flag -> non-zero exit + error substring
  b) one isCompactSummary mid-stream + flag -> output contains only post-marker entries
  c) two isCompactSummary markers -> slice at the last
  d) no isCompactSummary but <command-name>compact</command-name> user message -> fallback
  e) flag absent -> output byte-equal to baseline run

All marked xfail pending T2 implementation.
"""

import json
import subprocess
import sys
import textwrap

import pytest

SCRIPT = "scripts/clean-jsonl.py"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_user_record(text, uuid=None, timestamp="2024-01-01T00:00:00.000Z", is_compact_summary=None):
    rec = {
        "type": "user",
        "uuid": uuid or f"u-{text[:8].replace(' ', '_')}",
        "timestamp": timestamp,
        "message": {"role": "user", "content": text},
    }
    if is_compact_summary is not None:
        rec["isCompactSummary"] = is_compact_summary
    return json.dumps(rec)


def make_assistant_record(text, uuid=None, timestamp="2024-01-01T00:01:00.000Z"):
    return json.dumps({
        "type": "assistant",
        "uuid": uuid or f"a-{text[:8].replace(' ', '_')}",
        "timestamp": timestamp,
        "message": {"role": "assistant", "content": text},
    })


def make_compact_summary_record(uuid=None, timestamp="2024-01-01T00:02:00.000Z"):
    """A harness-injected compact boundary record with isCompactSummary: true."""
    return json.dumps({
        "type": "user",
        "uuid": uuid or "compact-boundary",
        "timestamp": timestamp,
        "isCompactSummary": True,
        "message": {"role": "user", "content": "Session compacted."},
    })


def make_slash_compact_record(uuid=None, timestamp="2024-01-01T00:02:00.000Z"):
    """A user record containing the slash-command compact marker."""
    return json.dumps({
        "type": "user",
        "uuid": uuid or "slash-compact",
        "timestamp": timestamp,
        "message": {
            "role": "user",
            "content": "<command-name>compact</command-name>",
        },
    })


def run_script(tmp_path, jsonl_content, extra_args=None):
    """Write a session file and invoke clean-jsonl.py via subprocess."""
    session_file = tmp_path / "aaaabbbbccccdddd.jsonl"
    session_file.write_text(jsonl_content, encoding="utf-8")

    cmd = [
        sys.executable, SCRIPT,
        "--agent", "testbot",
        "--session", "aaaabbbbccccdddd",
        "--project-dir", str(tmp_path),
        "--out", str(tmp_path / "out.md"),
    ]
    if extra_args:
        cmd.extend(extra_args)

    result = subprocess.run(cmd, capture_output=True, text=True)
    out_path = tmp_path / "out.md"
    output_text = out_path.read_text(encoding="utf-8") if out_path.exists() else ""
    return result, output_text


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.xfail(reason="impl pending T2", strict=True)
def test_a_no_marker_fail_loud(tmp_path):
    """Case a: flag set, no compact boundary -> non-zero exit + error message."""
    jsonl = "\n".join([
        make_user_record("Hello world", uuid="u1", timestamp="2024-01-01T00:00:00.000Z"),
        make_assistant_record("Hi there", uuid="a1", timestamp="2024-01-01T00:01:00.000Z"),
    ])
    result, _ = run_script(tmp_path, jsonl, extra_args=["--since-last-compact"])
    assert result.returncode != 0
    assert "CLEANER: no compact boundary found" in result.stderr


@pytest.mark.xfail(reason="impl pending T2", strict=True)
def test_b_single_is_compact_summary(tmp_path):
    """Case b: one isCompactSummary marker mid-stream -> only post-marker entries in output."""
    jsonl = "\n".join([
        make_user_record("Before compact", uuid="u1", timestamp="2024-01-01T00:00:00.000Z"),
        make_assistant_record("Before response", uuid="a1", timestamp="2024-01-01T00:01:00.000Z"),
        make_compact_summary_record(uuid="compact1", timestamp="2024-01-01T00:02:00.000Z"),
        make_user_record("After compact", uuid="u2", timestamp="2024-01-01T00:03:00.000Z"),
        make_assistant_record("After response", uuid="a2", timestamp="2024-01-01T00:04:00.000Z"),
    ])
    result, output = run_script(tmp_path, jsonl, extra_args=["--since-last-compact"])
    assert result.returncode == 0
    assert "Before compact" not in output
    assert "Before response" not in output
    assert "After compact" in output
    assert "After response" in output


@pytest.mark.xfail(reason="impl pending T2", strict=True)
def test_c_two_compact_markers_last_wins(tmp_path):
    """Case c: two isCompactSummary markers -> slice at the LAST one."""
    jsonl = "\n".join([
        make_user_record("Leg one", uuid="u1", timestamp="2024-01-01T00:00:00.000Z"),
        make_compact_summary_record(uuid="compact1", timestamp="2024-01-01T00:01:00.000Z"),
        make_user_record("Leg two", uuid="u2", timestamp="2024-01-01T00:02:00.000Z"),
        make_compact_summary_record(uuid="compact2", timestamp="2024-01-01T00:03:00.000Z"),
        make_user_record("Leg three", uuid="u3", timestamp="2024-01-01T00:04:00.000Z"),
        make_assistant_record("Final answer", uuid="a3", timestamp="2024-01-01T00:05:00.000Z"),
    ])
    result, output = run_script(tmp_path, jsonl, extra_args=["--since-last-compact"])
    assert result.returncode == 0
    assert "Leg one" not in output
    assert "Leg two" not in output
    assert "Leg three" in output
    assert "Final answer" in output


@pytest.mark.xfail(reason="impl pending T2", strict=True)
def test_d_slash_command_fallback(tmp_path):
    """Case d: no isCompactSummary but slash-command user message -> fallback detection."""
    jsonl = "\n".join([
        make_user_record("Old stuff", uuid="u1", timestamp="2024-01-01T00:00:00.000Z"),
        make_assistant_record("Old response", uuid="a1", timestamp="2024-01-01T00:01:00.000Z"),
        make_slash_compact_record(uuid="slash1", timestamp="2024-01-01T00:02:00.000Z"),
        make_user_record("New stuff", uuid="u2", timestamp="2024-01-01T00:03:00.000Z"),
        make_assistant_record("New response", uuid="a2", timestamp="2024-01-01T00:04:00.000Z"),
    ])
    result, output = run_script(tmp_path, jsonl, extra_args=["--since-last-compact"])
    assert result.returncode == 0
    assert "Old stuff" not in output
    assert "Old response" not in output
    assert "New stuff" in output
    assert "New response" in output


@pytest.mark.xfail(reason="impl pending T2", strict=False)
def test_e_flag_absent_byte_stable(tmp_path):
    """Case e: without --since-last-compact, output is byte-equal to a baseline run."""
    jsonl = "\n".join([
        make_user_record("Hello", uuid="u1", timestamp="2024-01-01T00:00:00.000Z"),
        make_compact_summary_record(uuid="compact1", timestamp="2024-01-01T00:01:00.000Z"),
        make_user_record("World", uuid="u2", timestamp="2024-01-01T00:02:00.000Z"),
        make_assistant_record("Done", uuid="a2", timestamp="2024-01-01T00:03:00.000Z"),
    ])

    # Run once without flag to get baseline.
    session_file = tmp_path / "aaaabbbbccccdddd.jsonl"
    session_file.write_text(jsonl, encoding="utf-8")

    def run_no_flag(out_name):
        out = tmp_path / out_name
        cmd = [
            sys.executable, SCRIPT,
            "--agent", "testbot",
            "--session", "aaaabbbbccccdddd",
            "--project-dir", str(tmp_path),
            "--out", str(out),
        ]
        subprocess.run(cmd, capture_output=True, text=True, check=True)
        return out.read_text(encoding="utf-8")

    baseline = run_no_flag("baseline.md")

    # Delete and re-run (identical invocation).
    (tmp_path / "baseline.md").unlink()
    run2 = run_no_flag("run2.md")

    assert baseline == run2, "baseline runs should be byte-identical (sanity check)"

    # Now verify no --since-last-compact doesn't change a thing compared to baseline.
    # (Re-run once more using the existing session file.)
    out3 = tmp_path / "run3.md"
    cmd_no_flag = [
        sys.executable, SCRIPT,
        "--agent", "testbot",
        "--session", "aaaabbbbccccdddd",
        "--project-dir", str(tmp_path),
        "--out", str(out3),
    ]
    subprocess.run(cmd_no_flag, capture_output=True, text=True, check=True)
    run3 = out3.read_text(encoding="utf-8")

    assert run3 == baseline, "flag-absent run should be byte-identical to baseline"
