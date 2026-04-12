# "Team" vs "Have someone" — coordination surface distinction

When Duong says **"have a team on this"** or **"team"**, use `TeamCreate` — agents share a task list, communicate via SendMessage, coordinate as a group.

When Duong says **"have someone do this"**, use `Agent` tool with `run_in_background: true` — single agent, independent task, reports back when done.

Never spawn independent background agents when Duong asks for a team. Never create a full team for a single-agent task.

Also: never reassign a team member to a different task mid-flight without first checking if another agent is available. The team roster has depth — use it.
