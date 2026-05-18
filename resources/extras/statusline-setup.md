# Claude Code Status Line Setup

> Use the `statusline-setup` agent to configure my statusLine from `~/scripts/resources/extras/statusline-command.sh`.

> **Note:** After cloning, make the script executable or the statusline will silently not appear:
> ```sh
> chmod +x ~/scripts/resources/extras/statusline-command.sh
> ```

---

## Without cloning the repo

Download the script directly and place it wherever you'd like:

```sh
curl -o ~/statusline-command.sh https://raw.githubusercontent.com/MichaelDimmitt/scripts/master/resources/extras/statusline-command.sh
chmod +x ~/statusline-command.sh
```

Then add the following to your Claude Code settings (`~/.claude/settings.json`):

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/statusline-command.sh"
}
```

Script source: https://github.com/MichaelDimmitt/scripts/blob/master/resources/extras/statusline-command.sh
