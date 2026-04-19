# orianna-fact-check.sh picks report by alphabetical order, not mtime

**Date:** 2026-04-19
**Session:** plan promotion for usage-dashboard-subagent-task-attribution

## Lesson

`orianna-fact-check.sh` uses a shell glob loop to find the "latest" report for a plan:

```bash
for f in "$REPORT_DIR"/${PLAN_BASENAME}-[0-9]*.md; do
  [ -f "$f" ] && latest_report="$f"
done
```

This iterates in filename (alphabetical) order and keeps overwriting `latest_report`. It ends on the alphabetically last file — NOT the most recently written one.

If Orianna writes a new clean report (e.g. `...-T00-00-00Z.md`) that sorts before a stale report with a real timestamp (e.g. `...-T04-10-25Z.md`), the script reads the stale one and exits 1 even though the real run was clean.

## Symptoms

- `plan-promote.sh` halts with "fact-check returned non-zero exit (1)".
- The printed block findings are from the old run, not the new one.
- Orianna's own stdout says "0 block findings / exit 0" but the gate still blocks.

## Workaround

Delete the stale report from `assessments/plan-fact-checks/` and re-run `plan-promote.sh`. The glob then picks only the new clean report.

## Fix (for Heimerdinger/Orianna track)

Replace the glob loop in `orianna-fact-check.sh` with an mtime-based sort:

```bash
latest_report=$(ls -t "$REPORT_DIR"/${PLAN_BASENAME}-[0-9]*.md 2>/dev/null | head -1)
```

`ls -t` sorts by modification time descending; `head -1` picks the newest file regardless of filename.
