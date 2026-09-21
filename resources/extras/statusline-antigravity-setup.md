# Google Antigravity CLI Status Line Setup

> Dedicated status line for Google Antigravity / Gemini CLI (`agy`).

> **Note:** After cloning, make the script executable or the statusline will silently not appear:
> ```sh
> chmod +x ~/scripts/resources/extras/statusline-antigravity.sh
> ```

---

## What it shows

```
dir: ~/scripts  (feat/antigravity-statusline*)  model: Gemini 3.8 Flash (high)  ctx 16k/1049k (1%)  [2 agents]  $0.05 (sub:$0.02)
```

| Segment | Source | Notes |
| --- | --- | --- |
| `dir:` | `.workspace.current_dir` / `.cwd` | `$HOME` collapses to `~`; shortens (`...`) or drops to fit terminal width |
| `(branch)` | `.vcs.branch`, `.vcs.dirty` | `*` suffix when dirty; falls back to commit SHA + branch via local git; `(no git)` outside a repo |
| `model:` | `.model.display_name` | model name, with effort level in parentheses when available (e.g. `high`, `medium`, `low`) |
| `ctx` | `.context.input_tokens` / `.context.total_tokens` | token usage out of total context window, plus usage percentage; omitted when unavailable |
| `[agents]` | `.subagents` | count of active / running background subagents; omitted when zero |
| `$` | `.cost.total_usd` | total session cost, with optional `(sub:$...)` subagent cost breakdown; omitted when $0.00 |

Usage percentages are colour-coded: green below 70%, yellow 70–89%, red 90%+.
They are **floored**, never rounded, so 99.6% shows as `99%` rather than a limit-reached `100%`.

---

## Installation

### From a clone (recommended)

Run the installer via `just`:

```sh
just install-statusline-antigravity
```

This:
1. Copies `resources/extras/statusline-antigravity.sh` to `~/.gemini/antigravity-cli/statusline-antigravity.sh`
2. Sets executable permissions (`chmod +x`)
3. Configures `~/.gemini/antigravity-cli/settings.json` (creating a backup at `settings.json.bak` if modified)
4. Checks idempotency: reports `SKIP: already current` if unchanged

### Without cloning the repo (standalone copy)

Download the script directly using `curl`:

```sh
mkdir -p ~/.gemini/antigravity-cli
curl -fsSL -o ~/.gemini/antigravity-cli/statusline-antigravity.sh https://raw.githubusercontent.com/MichaelDimmitt/scripts/master/resources/extras/statusline-antigravity.sh
chmod +x ~/.gemini/antigravity-cli/statusline-antigravity.sh
```

Then configure `settings.json` or use the `/statusline` TUI command as shown below.

---

## Settings Configuration

### Via `~/.gemini/antigravity-cli/settings.json`

Add or update the `statusLine` block in your `settings.json`:

```json
{
  "statusLine": {
    "command": "bash ~/.gemini/antigravity-cli/statusline-antigravity.sh",
    "stack_with_default": true
  }
}
```

- `command`: shell invocation to render the status line
- `stack_with_default`: when `true`, displays the custom status line alongside the built-in default status bar

### Via the `agy` Interactive TUI

Antigravity CLI provides native slash commands to configure the status line:

```
/statusline bash ~/.gemini/antigravity-cli/statusline-antigravity.sh
/statusline on
```

Available slash command options:
- `/statusline <command>`: Configure a custom shell command to render the statusline
- `/statusline on` (or `enable`): Enable the statusline
- `/statusline off` (or `disable`): Disable the statusline
- `/statusline delete`: Delete the custom command and revert to built-in default
- `/statusline help`: Show slash command help

---

## Testing

You can test the status line directly by feeding sample JSON on stdin:

```sh
jq -n '{
  workspace: {current_dir: "/Users/you/project"},
  vcs: {branch: "main", dirty: false},
  model: {display_name: "Gemini 3.8 Flash", effort: "high"},
  context: {input_tokens: 15000, total_tokens: 1000000},
  cost: {total_usd: 0.04, subagent_usd: 0.01},
  subagents: [{role: "researcher", agent_state: "running"}]
}' | ~/.gemini/antigravity-cli/statusline-antigravity.sh
```

---

## Requirements

- `jq` — for JSON parsing (`brew install jq`)
- `bash` 3.2 or newer (macOS default bash or newer)
- Git (optional, for branch/SHA fallback)
