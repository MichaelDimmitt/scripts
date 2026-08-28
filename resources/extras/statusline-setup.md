# Claude Code Status Line Setup

> Use the `statusline-setup` agent to configure my statusLine from `~/scripts/resources/extras/statusline-command.sh`.

> **Note:** After cloning, make the script executable or the statusline will silently not appear:
> ```sh
> chmod +x ~/scripts/resources/extras/statusline-command.sh
> ```

---

## What it shows

```
dir: ~/scripts  (a770942a5) (master)  model: Opus  ctx 16k/200k (8%)  5h 23%  7d 41%  +$0.04  $0.01
```

| Segment | Source | Notes |
| --- | --- | --- |
| `dir:` | `workspace.current_dir` | `$HOME` collapses to `~`; shortens or drops to fit the terminal |
| `(sha) (branch)` | `git` | `(no git)` outside a repo, `(detached)` on a detached HEAD |
| `model:` | `model.display_name` | omitted when absent |
| `ctx` | `context_window` | omitted until the first API call, and after `/compact` |
| `5h` / `7d` | `rate_limits` | Pro/Max only; each window may appear independently |
| `+$` | derived | what the command you just ran cost; hidden below a cent |
| `$` | `cost.total_cost_usd` | session total; client-side estimate, hidden at `$0.00` |

Usage percentages are colour-coded: green below 70%, yellow 70–89%, red 90%+.
They are **floored**, never rounded, so 99.6% shows as `99%` rather than a
limit-reached-looking `100%`.

### The two cost figures

Both are estimates Claude Code computes locally from token counts at standard
API list rates. On a Pro or Max plan nothing is billed against them — usage is
included in the subscription, so they are an API-equivalent valuation rather
than a bill. The `5h` and `7d` segments are what actually constrains you.

`$` is the session total and resets on `/clear`, not on `/compact`. `+$` is the
share the most recent command added, and is **derived, not reported**: the
payload carries no marker for where one command ends and the next begins, so the
script infers it — a total that grew since the last render means a command is
still running, a total that held steady means it finished. Two consequences
worth knowing:

- It needs `refreshInterval` set. Without idle renders the total only ever
  moves, so every command reads as one unbroken turn.
- A command that goes quiet for longer than `refreshInterval` mid-flight — a
  slow test run between two API calls — is counted as two commands.

State lives in `$TMPDIR/claude-statusline/<session_id>`, one file per session.
Set `CLAUDE_STATUSLINE_STATE_DIR` to move it. Delete a file and that session
simply re-baselines on its next render.

## Without cloning the repo (paste to claude)

> First get the status line that you need:
> ```sh
> curl -o ~/statusline-command.sh https://raw.githubusercontent.com/MichaelDimmitt/scripts/master/resources/extras/statusline-command.sh
> chmod +x ~/statusline-command.sh
> ```
> Next:
> Use the `statusline-setup` agent to configure my statusLine from `~/statusline-command.sh`.

> **A standalone copy does not update when the repo does.** Re-run the `curl`
> above (or `cp` from a clone) after pulling changes, or fixes stay in the repo
> and never reach your bar.

## Settings

However you install it, the `statusLine` block in `~/.claude/settings.json`
ends up looking like this:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/statusline-command.sh",
  "refreshInterval": 30
}
```

### Why `refreshInterval`

Status line updates are event-driven — a new assistant message, `/compact`, a
permission-mode change. Those triggers **go quiet while the session is idle**,
for example while waiting on a long tool call or on background subagents.
Without a timer the `5h` / `7d` percentages silently freeze during exactly the
long waits where you most want them current. `refreshInterval` is in seconds
(minimum `1`); `30` keeps the quota numbers honest without re-running the script
constantly.

## Running the tests

The script is covered by fixture-driven tests that need no Claude Code session:

```sh
cd ~/scripts/resources/extras/statusline-tests
./run-tests.sh                            # test the repo copy
./run-tests.sh ~/statusline-command.sh    # test your installed standalone copy
VERBOSE=1 ./run-tests.sh                  # also print each rendered line
```

Fixtures cover the free tier (no `rate_limits`), a null `current_usage` before
the first API call, a missing `context_window_size`, non-git directories, narrow
terminals, a missing `jq`, and the upstream bug where `used_percentage` carries
the `resets_at` epoch instead of a percentage.

## Requirements

- `jq` — recent macOS ships `/usr/bin/jq`; otherwise `brew install jq`. Without
  it the bar degrades to directory and git info rather than disappearing.
- `bash` 3.2 or newer (macOS system bash is fine).

Script source: https://github.com/MichaelDimmitt/scripts/blob/master/resources/extras/statusline-command.sh
