# scripts

> An operating system for shell automation on macOS. A growing collection of focused scripts for inspecting, reporting on, and generating configuration for your local environment.

---

## File Naming Convention

Files follow a `verb_noun.sh` pattern in **snake_case**, grouped into folders by verb:

- `tell/` — scripts that display or report information
- `generate/` — scripts that produce or create output
- `install/` — scripts that set up tooling or wire up shell integrations
- `bin/` — standalone executables (no verb prefix)

### Examples

| File | Verb | Purpose |
|------|------|---------|
| `tell/tell_ai_tools.sh` | tell | Report installed SaaS AI tools |
| `tell/tell_casks.sh` | tell | Report installed Homebrew casks |
| `tell/tell_rcs.sh` | tell | Report shell RC files |
| `tell/tell_skills.sh` | tell | Report cloned skill repos under ~/skills |
| `generate/generate_cask-aliases.sh` | generate | Create shell aliases for casks |
| `install/install_checkout_release.sh` | install | Wire up latest_release without running the full generate script |
| `bin/latest_release` | — | Checkout the highest versioned release branch |

### Rules

- Use a verb prefix that describes what the script does (`tell`, `generate`, `install`)
- Separate words with underscores (snake_case)
- Use the `.sh` extension for all shell scripts
- Place the script in the folder matching its verb

## Usage

Requires [`just`](https://github.com/casey/just): `brew install just`

```sh
just                        # list all commands
just tell-casks
just tell-ai-tools
just generate-cask-aliases
just install-checkout-release
```

---

## Docs

| File | Purpose |
|------|---------|
| [ARCHITECTURE.md](./resources/docs/ARCHITECTURE.md) | Folder structure, naming conventions, how to add scripts and resources |
| [AGENT_GUIDE.md](./resources/docs/AGENT_GUIDE.md) | Tips for agents navigating this repo and `~/skills` efficiently |
| [SKILLS_APPROACH.md](./resources/docs/SKILLS_APPROACH.md) | Pros/cons of plugin vs direct `~/skills` reference for Claude skills |

## Extras

Hand-maintained additions that layer on top of generated output.

| File | Purpose |
|------|---------|
| [brew-cask-aliases-additional](./resources/extras/brew-cask-aliases-additional) | Extra shell aliases to source alongside `~/.brew-cask-aliases` |
| [statusline-command.sh](./resources/extras/statusline-command.sh) | Claude Code status line script that mirrors a bash PS1 (cwd, short SHA, branch in cyan) and adds model, context window usage, and rate-limit percentages |
| [statusline-setup.md](./resources/extras/statusline-setup.md) | Setup guide for the status line — includes a no-clone install path using `curl` |
| [stashes.sh](./resources/extras/stashes.sh) | Shell functions `dump_stashes` and `dump_stashes_files` for exporting a range of git stashes to a text file |
| [text-manipulation.sh](./resources/extras/text-manipulation.sh) | Shell utility functions for common text transformations |

Source it from your RC file to keep these alongside the generated aliases:

```sh
source ~/scripts/resources/extras/brew-cask-aliases-additional
```

### Claude Code status line

See [statusline-setup.md](./resources/extras/statusline-setup.md) for the full setup guide, including a no-clone install path.

To install the status line on a new machine, tell Claude:

> Use the `statusline-setup` agent to configure my statusLine from `~/scripts/resources/extras/statusline-command.sh`.

> **Note:** After cloning, make the script executable or the statusline will silently not appear:
> ```sh
> chmod +x ~/scripts/resources/extras/statusline-command.sh
> ```

Or do it manually:

```sh
cp ~/scripts/resources/extras/statusline-command.sh ~/.claude/statusline-command.sh
```

Then add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /Users/<you>/.claude/statusline-command.sh"
  }
}
```

---

## Scripts

### `tell/tell_ai_tools.sh`
Scans your machine for installed SaaS AI tools and reports what it finds, grouped by category. Prints a summary with found/not-found counts, then for every installed tool shows the command to launch it.

**Detects:**
- Web interface desktop apps — Claude, ChatGPT, Gemini, Grok
- AI-powered IDEs — Cursor, Windsurf, Zed
- CLI / terminal agents — Claude Code, Aider, Codex, Gemini CLI, OpenCode, GitHub Copilot CLI
- VS Code extensions — GitHub Copilot, Cline
- Python SDKs — Anthropic, OpenAI, LangChain, Google GenAI
- Node.js SDKs — Anthropic JS, OpenAI JS, LangChain JS

**Requires:** `resources/mappings/ai_tools_launch.txt` (included)

```sh
bash tell/tell_ai_tools.sh
```

---

### `tell/tell_casks.sh`
Lists all installed Homebrew casks split into two groups: casks that expose a binary in `/bin/` or `/sbin/`, and those that don't. Useful for auditing what CLI tools your GUI apps quietly ship.

```sh
bash tell/tell_casks.sh
```

---

### `tell/tell_rcs.sh`
Detects your current shell and prints the relevant RC and profile files for it (e.g. `~/.zshrc`, `~/.zprofile`). Also shows which of those files actually exist on disk.

```sh
bash tell/tell_rcs.sh
```

---

### `tell/tell_skills.sh`
Reports on git-cloned skill repos under `~/skills`. Shows remote URL, current branch, last commit, whether the repo is up to date vs origin, and a list of available skills. Handles both a single repo at `~/skills/` and a directory of multiple repos.

If `~/skills` doesn't exist, prompts you to clone [anthropics/skills](https://github.com/anthropics/skills) automatically.

```sh
bash tell/tell_skills.sh
```

---

### `install/install_checkout_release.sh`
Minimal installer that wires up `latest_release` without running the full `generate_cask-aliases.sh`. Copies `bin/latest_release` to `~/.local/bin`, adds it to `PATH` in `~/.bashrc`, registers the `git checkout-release` alias, and installs the `git checkout release` / `git checkout release/` shell function intercept. Use this when you only want the release-checkout tooling on a new machine.

```sh
bash install/install_checkout_release.sh
source ~/.bashrc
```

---

### `generate/generate_cask-aliases.sh`
Generates shell aliases for every installed Homebrew cask (e.g. `alias notion="open -a 'Notion'"`), writes them to `~/.brew-cask-aliases`, and sources that file from `~/.bashrc`. Re-run whenever you install or remove casks, or on a fresh clone.

```sh
bash generate/generate_cask-aliases.sh
```

---

### `bin/latest_release`
Checks out the highest versioned `release/X.Y.Z` branch in the current repo. Fetches all remotes, filters to branches matching the `release/#.##.##` pattern, version-sorts them, and checks out the latest. Branches with non-version suffixes (e.g. `release/vite-config-updates`) are ignored.

**Three ways to invoke:**

```sh
latest_release                # direct (after install)
git checkout-release          # git alias
git checkout release          # shell function intercept (also matches release/; release/X.Y.Z passes through to git)
```

**Install on a new machine:**

```sh
# clone the repo, then:
bash install/install_checkout_release.sh
source ~/.bashrc
```

---
