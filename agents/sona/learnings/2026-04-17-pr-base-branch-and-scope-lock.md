# PR base branch checks + team scope locks

Two related lessons from the demo-studio-v3 session.

## Always verify PR base branch before review

When a PR is opened on a topic branch (like `demo-studio-step1`), the branch's actual base may not be `main`. GitHub defaults to `main` as the PR target, which can show the diff as hundreds of files and hundreds of thousands of additions — making review impossible. In our case PR #40 showed 272 files / 170k+ additions; after retargeting to `feat/demo-studio-v3` it was 85 files / 33k additions (mostly deletions of old code, actually net negative).

Before sending a PR to review, run:
```
git merge-base main <branch>
git merge-base <suspected-base> <branch>
```
The one that gives the newer commit is the true base. Set PR base accordingly:
```
gh pr edit <num> --base <correct-base>
```

## Scope locks with agent teams

When Duong gives a scope constraint mid-session ("don't touch services 2-5 going forward"), broadcast it to the team immediately and encode it in agent prompts. When a later instruction seems to contradict ("update demo-factory too"), agents may correctly push back citing the earlier lock — treat this as a feature, not friction. Confirm the reversal is from Duong, relay it, then proceed.

Ekko's pushback on the demo-factory reversal was a good safety check. The flip-flop (revert → re-include) cost maybe 10 min but prevented a wrong move in either direction.

## Meta: don't broadcast structured messages

`SendMessage` with `to: "*"` rejects structured messages like `{"type": "shutdown_request", ...}`. Had to send 10 individual shutdown_request calls. If a broadcast is needed for protocol messages, fan out manually.
