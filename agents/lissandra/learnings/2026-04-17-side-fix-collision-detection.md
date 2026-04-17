When a PR touches a file that another agent recently fixed, the two fixes may use divergent approaches even if they solve the same bug. Don't just flag a conflict — describe the semantic difference between the two approaches so the implementer knows which direction to align with.

In PR #128, Jayce's `read` loop workaround and Shen's version-check-and-abort approach to bash 3.2 compatibility are not equivalent: one silently patches around bash 3.2 limitations, the other requires the user to install bash 4+. The correct fix depends on team policy (Shen's was already merged and is authoritative).

Pattern: when reviewing any file touched by both a pending PR and a recent main commit, show both approaches in the review comment and identify which is authoritative.
