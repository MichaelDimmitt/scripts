# Claude Code Context Monitor Setup

A `Stop` hook that warns you as a session approaches the autocompact threshold,
so you can wrap up or start fresh on your own terms instead of being compacted
mid-task.

---

## What it does

After each assistant turn it reads the session transcript, sums the most recent
`usage` block (`input` + `cache_creation` + `cache_read` + `output`), and warns
at two levels:

| Level | Threshold | Behaviour |
| --- | --- | --- |
| ⚠️ Warning | 130,000 tokens (65%) | macOS notification (`Glass`) + a line in the transcript |
| 🚨 Critical | 150,000 tokens (75%) | macOS notification (`Sosumi`) + a stronger message |

Below the warning threshold it prints nothing and exits `0`.

Both messages report how many tokens remain before autocompact fires at
~167,000.

## Install

```sh
chmod +x ~/scripts/resources/extras/context-monitor.sh
```

Then add the hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/scripts/resources/extras/context-monitor.sh"
          }
        ]
      }
    ]
  }
}
```

Restart Claude Code, or run `/hooks` to confirm it registered.

## Tuning

The thresholds are plain variables at the top of the script:

```sh
WARN_THRESHOLD=130000
CRIT_THRESHOLD=150000
MAX_TOKENS=200000
AUTOCOMPACT_AT=167000
```

`MAX_TOKENS` and `AUTOCOMPACT_AT` assume a 200k context window. On a model or
setting with a different window, scale all four together — the percentages in
the warnings are derived from `MAX_TOKENS`, so leaving it stale makes the
reported percentage wrong even when the raw token count is right.

## Requirements

- `python3` — used to parse the hook payload and the transcript's JSON lines.
- `osascript` (macOS) for the desktop notification. On other platforms the
  notification is skipped silently and the text warning still prints.

## Testing it without a long session

Feed it a transcript path directly:

```sh
printf '{"transcript_path":"%s"}' \
  "$(ls -t ~/.claude/projects/*/*.jsonl | head -1)" \
  | bash ~/scripts/resources/extras/context-monitor.sh
```

Silence means the session is below `WARN_THRESHOLD`. Lower `WARN_THRESHOLD` to
a small number to confirm the warning path fires.
