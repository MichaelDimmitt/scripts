# scripts

A collection of shell scripts for inspecting and reporting on the local macOS environment.

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
