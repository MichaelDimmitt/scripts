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
| `tell/tell_claude_skills.sh` | tell | Snapshot Claude Code skill and plugin locations |
| `tell/tell_installed_skills.sh` | tell | List every installed SKILL.md skill (Claude + Cursor) |
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
just tell-ai-tools
just tell-casks
just tell-rcs
just tell-skills
just tell-claude-skills
just tell-installed-skills
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
| [context-monitor.sh](./resources/extras/context-monitor.sh) | Claude Code `Stop` hook that warns when a session nears the autocompact threshold |
| [context-monitor-setup.md](./resources/extras/context-monitor-setup.md) | Setup guide for the context monitor hook — thresholds, tuning, and how to test it |
| [statusline-command.sh](./resources/extras/statusline-command.sh) | Claude Code status line script that mirrors a bash PS1 (cwd, short SHA, branch in cyan) and adds model, context window usage, and rate-limit percentages |
| [statusline-setup.md](./resources/extras/statusline-setup.md) | Setup guide for the status line — includes a no-clone install path using `curl` |
| [statusline-tests/](./resources/extras/statusline-tests) | Fixture-driven test suite for the status line script (`./run-tests.sh`) |
| [stashes.sh](./resources/extras/stashes.sh) | Shell functions `dump_stashes` and `dump_stashes_files` for exporting a range of git stashes to a text file |
| [text-manipulation.sh](./resources/extras/text-manipulation.sh) | Shell utility functions for common text transformations |

Source it from your RC file to keep these alongside the generated aliases:

```sh
source ~/scripts/resources/extras/brew-cask-aliases-additional
```

`generate_cask-aliases.sh` instead copies the file to `~/.brew-cask-aliases-additional`
and sources *that* from `~/.bashrc`. Either path works, but pick one — a home-dir
copy stops tracking the repo the moment this file changes. Re-run
`just generate-cask-aliases` (or `regen-aliases`) after editing it to refresh the copy.

#### What's in `brew-cask-aliases-additional`

| Name | Type | Purpose |
|------|------|---------|
| `cl` | alias | Start a fresh Claude Code session with `--dangerously-skip-permissions` |
| `cx` | alias | Start a Codex session with `--yolo` (approval prompts bypassed) |
| `cresume` | alias | Resume the most recent Claude Code session with `--dangerously-skip-permissions` |
| `cchats` | alias | List previous Claude Code sessions for the current project (newest first) |
| `cresumef <session-id>` | function | Resume a specific Claude Code session by ID (IDs come from `cchats`) with permissions bypass |
| `regen-aliases` | function | Re-run `generate_cask-aliases.sh` and re-source both alias files in the current shell |

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
    "command": "bash /Users/<you>/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
```

`refreshInterval` (seconds) keeps the rate-limit percentages current while the
session sits idle — without it they freeze during long tool calls. See
[statusline-setup.md](./resources/extras/statusline-setup.md#why-refreshinterval).

#### How it compares to the popular status lines

There is a sizeable ecosystem of Claude Code status lines, most of them larger
than this one. The useful ones to know about:

| Project | Language | Notes |
|---------|----------|-------|
| [ccstatusline](https://github.com/sirmalloc/ccstatusline) | TypeScript | The category leader. Dozens of widgets, TUI configurator, Powerline themes. Runs via `npx @latest` per render. |
| [claude-powerline](https://github.com/Owloops/claude-powerline) | TypeScript | Vim-style powerline, installable from the plugin marketplace. Node 18+. |
| [CCometixLine](https://github.com/Haleclipse/CCometixLine) | Rust | Compiled binary — the fastest render in the field. Multiple themes. |
| [claude-statusline-powerline](https://github.com/spences10/claude-statusline-powerline) | TypeScript | Superscript git symbols, tuned for Victor Mono. |
| [ccusage statusline](https://ccusage.com/guide/statusline) | TypeScript | Cost-focused: session / daily / block spend, burn rate. Own pricing engine. |
| [kcchien/claude-code-statusline](https://github.com/kcchien/claude-code-statusline) | Bash | Closest peer to this one — single `jq` call, gradient context bar, git status. |
| [awesome-claude-statusline](https://github.com/jakreymyers/awesome-claude-statusline) | Bash | Git Flow branch icons, ahead/behind sync status. |

Feature comparison against this script:

| | This script | ccstatusline | ccusage | kcchien |
|---|---|---|---|---|
| Context window % | ✓ | ✓ | ✓ | ✓ |
| 5h / 7d rate limits | ✓ | ✓ | ✗ | ✓ |
| Session cost | ✓ | ✓ | ✓ | ✓ |
| **Per-command cost** | **✓** | ✗ | ✗ | ✗ |
| Git SHA + branch | ✓ | ✓ | ✗ | ✓ |
| Width-aware path collapsing | ✓ | ✓ | ✗ | ✓ |
| No runtime dependency beyond `jq` | ✓ | ✗ | ✗ | ✓ |
| No network at render time | ✓ | ✗ | ✗ | ✓ |
| Git dirty / staged / ahead-behind | ✗ | ✓ | ✗ | ✓ |
| Per-model weekly limits | ✗ | ✓ | ✗ | ✗ |
| Burn rate, block timers | ✗ | ✓ | ✓ | ✗ |
| Lines added/removed, session duration | ✗ | ✓ | ✗ | ✓ |
| Reasoning effort indicator | ✗ | ✓ | ✓ | ✗ |
| Powerline / Nerd Font theming | ✗ | ✓ | ✗ | ✓ |
| TUI configuration | ✗ | ✓ | ✗ | ✓ |

The tradeoff is deliberate. [A survey of the
ecosystem](https://yigitkonur.com/research/claude-code-statuslines-compared)
concluded that these tools are no longer differentiated by whether they can show
model, context, git, and cost — everything does — but by *how they install, what
data they trust, and whether they do network or transcript work at render time*.
This script reads only the official stdin payload, forks two processes (`jq` and
`git`), and degrades every field independently rather than failing the whole bar.
The per-command cost segment is the one feature none of the popular ones have:
the payload carries only a cumulative total, so this-command cost has to be
inferred from turn boundaries.

Planned additions are tracked in [plan2.md](./plan2.md).

### Claude Code context monitor

A `Stop` hook that warns you as a session approaches autocompact, so you can
wrap up deliberately instead of being compacted mid-task. See
[context-monitor-setup.md](./resources/extras/context-monitor-setup.md) for
thresholds and tuning.

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

### `tell/tell_claude_skills.sh`
Snapshots all Claude Code skill and plugin locations to a dated file (`~/claude-skills-<hostname>-<YYYYMMDD>.txt`). Covers user skills (`~/.claude/skills`), installed plugins (`~/.claude/plugins`), nested plugin skill directories, and project-scoped skill directories under `~/.claude/projects`.

```sh
bash tell/tell_claude_skills.sh
```

---

### `tell/tell_installed_skills.sh`
Lists the name of every `SKILL.md`-based skill installed on the machine, grouped by source: Claude marketplace plugins, Claude global skills (`~/.claude/skills`), project-local `.claude/skills` directories, Cursor skills (`~/.cursor/skills`), and project-local `.cursor/skills` directories. Prints to stdout — use `tell_claude_skills.sh` instead when you want a dated file on disk.

```sh
bash tell/tell_installed_skills.sh
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
