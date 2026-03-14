# scripts

> An operating system for shell automation on macOS. A growing collection of focused scripts for inspecting, reporting on, and generating configuration for your local environment.

---

## Scripts

### `tell_ai_tools.sh`
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
bash tell_ai_tools.sh
```

---

### `tell_casks.sh`
Lists all installed Homebrew casks split into two groups: casks that expose a binary in `/bin/` or `/sbin/`, and those that don't. Useful for auditing what CLI tools your GUI apps quietly ship.

```sh
bash tell_casks.sh
```

---

### `tell_rcs.sh`
Detects your current shell and prints the relevant RC and profile files for it (e.g. `~/.zshrc`, `~/.zprofile`). Also shows which of those files actually exist on disk.

```sh
bash tell_rcs.sh
```

---

### `tell_skills.sh`
Reports on git-cloned skill repos under `~/skills`. Shows remote URL, current branch, last commit, whether the repo is up to date vs origin, and a list of available skills. Handles both a single repo at `~/skills/` and a directory of multiple repos.

If `~/skills` doesn't exist, prompts you to clone [anthropics/skills](https://github.com/anthropics/skills) automatically.

```sh
bash tell_skills.sh
```

---

### `generate_cask-aliases.sh`
Generates shell aliases for every installed Homebrew cask (e.g. `alias notion="open -a 'Notion'"`), writes them to `~/.brew-cask-aliases`, and sources that file from `~/.bashrc`. Re-run whenever you install or remove casks.

```sh
bash generate_cask-aliases.sh
```

---

## File Naming Convention

Files follow a `verb_noun.sh` pattern in **snake_case**:

- `tell_*` — scripts that display or report information
- `generate_*` — scripts that produce or create output

### Examples

| File | Verb | Purpose |
|------|------|---------|
| `tell_ai_tools.sh` | tell | Report installed SaaS AI tools |
| `tell_casks.sh` | tell | Report installed Homebrew casks |
| `tell_rcs.sh` | tell | Report shell RC files |
| `tell_skills.sh` | tell | Report cloned skill repos under ~/skills |
| `generate_cask-aliases.sh` | generate | Create shell aliases for casks |

### Rules

- Use a verb prefix that describes what the script does (`tell`, `generate`)
- Separate words with underscores (snake_case)
- Use the `.sh` extension for all shell scripts

---

## Docs

| File | Purpose |
|------|---------|
| [ARCHITECTURE.md](./resources/docs/ARCHITECTURE.md) | Folder structure, naming conventions, how to add scripts and resources |
| [AGENT_GUIDE.md](./resources/docs/AGENT_GUIDE.md) | Tips for agents navigating this repo and `~/skills` efficiently |
| [SKILLS_APPROACH.md](./resources/docs/SKILLS_APPROACH.md) | Pros/cons of plugin vs direct `~/skills` reference for Claude skills |
