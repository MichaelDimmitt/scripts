# scripts

A collection of shell scripts for inspecting and reporting on the local macOS environment.

## Scripts

### `tell_ai_tools.sh`
Scans your machine for installed SaaS AI tools and reports what it finds, grouped by category:
- Web interface desktop apps (Claude, ChatGPT, Gemini, Grok)
- AI-powered IDEs (Cursor, Windsurf, Zed)
- CLI / terminal agents (Claude Code, Aider, Codex, Gemini CLI, etc.)
- VS Code extensions (GitHub Copilot, Cline)
- Python SDKs (Anthropic, OpenAI, LangChain, Google GenAI)
- Node.js SDKs (Anthropic JS, OpenAI JS, LangChain JS)

Prints a summary with found/not-found counts, and for installed tools shows how to launch each one using `resources/mappings/ai_tools_launch.txt`.

```sh
bash tell_ai_tools.sh
```

---

### `tell_casks.sh`
Lists all installed Homebrew casks split into two groups: casks that expose a binary in `/bin/` or `/sbin/`, and casks that do not. Useful for auditing what CLI tools your casks provide.

```sh
bash tell_casks.sh
```

---

### `tell_rcs.sh`
Detects your current shell and prints the relevant RC/profile files for it (e.g. `~/.zshrc`, `~/.zprofile`). Also lists which of those files actually exist on disk.

```sh
bash tell_rcs.sh
```

---

### `generate_cask-aliases.sh`
Generates shell aliases for every installed Homebrew cask (e.g. `alias notion="open -a 'Notion'"`), writes them to `~/.brew-cask-aliases`, and sources that file from `~/.bashrc`. Run once after installing or removing casks.

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
| `generate_cask-aliases.sh` | generate | Create shell aliases for casks |

### Rules

- Use a verb prefix that describes what the script does (`tell`, `generate`)
- Separate words with underscores (snake_case)
- Use the `.sh` extension for all shell scripts

---

## Project Structure

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full folder structure and conventions.
