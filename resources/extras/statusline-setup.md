# Claude Code Status Line Setup

> Use the `statusline-setup` agent to configure my statusLine from `~/scripts/resources/extras/statusline-command.sh`.

> **Note:** After cloning, make the script executable or the statusline will silently not appear:
> ```sh
> chmod +x ~/scripts/resources/extras/statusline-command.sh
> ```

---

## What it shows

```
dir: ~/scripts  (a770942a5) (master)  model: Opus  ctx 16k/200k (8%)  5h 23%  7d 41%  $0.01
```

| Segment | Source | Notes |
| --- | --- | --- |
| `dir:` | `workspace.current_dir` | `$HOME` collapses to `~`; shortens or drops to fit the terminal |
| `(sha) (branch)` | `git` | `(no git)` outside a repo, `(detached)` on a detached HEAD |
| `model:` | `model.display_name` | omitted when absent |
| `ctx` | `context_window` | omitted until the first API call, and after `/compact` |
| `5h` / `7d` | `rate_limits` | Pro/Max only; each window may appear independently |
| `$` | `cost.total_cost_usd` | client-side estimate; hidden at `$0.00` |

Usage percentages are colour-coded: green below 70%, yellow 70–89%, red 90%+.
They are **floored**, never rounded, so 99.6% shows as `99%` rather than a
limit-reached-looking `100%`.

## Without cloning the repo (paste to claude)

> First get the status line that you need:
> ```sh
> curl -o ~/statusline-command.sh https://raw.githubusercontent.com/MichaelDimmitt/scripts/master/resources/extras/statusline-command.sh
> chmod +x ~/statusline-command.sh
> ```
> Next
> Use the `statusline-setup` agent to configure my statusLine from `~/scripts/resources/extras/statusline-command.sh`, with `refreshInterval` set to 30.

**A standalone copy does not update when the repo does.** Re-run the `curl`
above after pulling changes, or fixes stay in the repo and never reach your bar.

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
