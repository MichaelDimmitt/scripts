# Script OS Architecture

## Philosophy

This repo is an operating system for shell automation. Structure is intentionally designed to scale — conventions are established upfront so the project can grow without painful reorganization.

## Folder Structure

```
scripts/
├── tell/                  # Scripts that display or report information
│   └── tell_*.sh
├── generate/              # Scripts that produce or create output
│   └── generate_*.sh
├── install/               # Scripts that set up tooling or wire up shell integrations
│   └── install_*.sh
├── bin/                   # Standalone executables (no verb prefix)
│   └── latest_release
├── resources/
│   ├── docs/              # Architecture and agent guide documents
│   ├── extras/            # Hand-maintained snippets to source from RC files,
│   │                      #   plus Claude Code integrations (statusline, hooks)
│   ├── lib/               # Shell libraries the repo's own scripts source
│   ├── mappings/          # Key→value lookup tables (pipe-delimited)
│   ├── templates/         # (future) reusable output templates
│   ├── lists/             # (future) static enumeration files
│   └── schemas/           # (future) validation or format definitions
└── README.md
```

## Naming Conventions

### Scripts
- Pattern: `verb_noun.sh`
- Case: snake_case
- Verbs: `tell` (display/report), `generate` (produce/create), `install` (set up tooling/shell integrations)

### Resource files
- Mapping files: descriptive noun, `.txt`, pipe-delimited (`NAME | VALUE`)
- One entry per line, `#` for comments

### Folders
- Lowercase, singular nouns

## Shared Libraries

`resources/lib/` holds shell files that other scripts `source` rather than
execute. They are not runnable scripts, so they take no `verb_noun` name and no
shebang — a `# shellcheck shell=bash` directive instead, since shellcheck
cannot infer the target shell without one.

Source them via `SCRIPT_DIR`, the same convention as every other resource, so a
script works from any working directory:

```sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"
```

The `source=` directive is written **repo-root relative**, which is where
`shellcheck -x` resolves it from.

### Terminal colour

`resources/lib/colours.sh` is the single definition of every colour variable
the repo uses. Any script that colours its output sources it instead of
declaring its own.

- Reset is named `RESET`.
- Values use ANSI-C quoting (`$'\033[1m'`), so escapes expand at assignment and
  print correctly through plain `echo`. Do not use the `'\033[1m'` + `echo -e`
  form — it emits literal `\033[1m` if the `-e` is ever dropped.
- Every variable is blanked when stdout is not a tty, so redirected output
  (`just tell-skills > notes.txt`) stays plain text.

### Shell RC selection

`resources/lib/shell_rc.sh` is the single answer to "which file do I write an
alias or shell function into". Any installer that edits shell config sources it
instead of naming a file directly.

- `SHELL_NAME` is the basename of `$SHELL`; `SHELL_RC` is that shell's
  interactive RC (`~/.zshrc`, `~/.bashrc`).
- `SHELL_RC` is empty for shells this repo has no snippet syntax for (fish,
  csh). Treat that as "print the manual steps and skip the RC edit" — never
  fall back to a default file.
- `shell_rc_warn_login_profile "<what>"` reports the bash case where
  `~/.bash_profile` does not source `~/.bashrc`, so a login shell never sees
  what was just installed. A no-op under other shells.

Hardcoding `~/.bashrc` is the specific bug this replaces: under zsh, the macOS
default, it edits a file the user's shell never reads and still reports success.

### Next steps

`resources/lib/next_steps.sh` collects the actions an installer cannot perform
for the user — sourcing an RC file, restarting Claude Code — and prints them
once, in one block, at the end.

```sh
next_step "source $SHELL_RC"                  # a line to copy and paste
next_step_note "Restart Claude Code to ..."   # an action with no command
next_step_aside "(Or open a new terminal.)"   # a parenthetical, rendered plain
next_steps_render                             # at the end of the script
```

Record a step **inside the branch that made the change**, never unconditionally
at the end. That is what lets a re-run which changed nothing print nothing.
Where "did anything change" spans several branches, compare the file before and
after (`install_checkout_release.sh` checksums the RC) rather than recording
from each branch.

`NEXT_STEPS_FILE` is the shared scratch file, and whoever creates it renders it:

| `NEXT_STEPS_FILE` | Meaning |
|---|---|
| unset | Running standalone. The lib creates the file; `next_steps_render` prints. |
| set | `install_all.sh` exported it. The script appends and renders nothing; the parent prints the combined block. |

So an installer makes the same calls either way and never asks which mode it is
in. `next_steps_pending` answers "did *this script* record anything", not "has
anyone" — it compares against the file size at source time.

## Comment Style

Order comments mechanic-first, use-case second:

```sh
# What it does / how it works
# When to use it
```

Leading with the functional description lets a skimmer get the "what" immediately, with context following as a second line.

## Adding a New Script

1. Pick a verb that describes what it does (`tell`, `generate`, `install`, etc.)
2. Name it `verb_noun.sh` in snake_case
3. Place it in the folder matching its verb (e.g. `tell/tell_foo.sh`)
4. Reference resource files via `${SCRIPT_DIR}/../resources/...`
5. If it needs a lookup table, add it to `resources/mappings/`
6. Add a section for it in README.md under Scripts

## Adding a New Resource

| Type | Folder | Format |
|------|--------|--------|
| Key→value lookup | `resources/mappings/` | `NAME \| VALUE` (pipe-delimited) |
| Sourced shell library | `resources/lib/` | `*.sh`, no shebang, `# shellcheck shell=bash` |
| Reusable text blocks | `resources/templates/` | Plain text or heredoc-ready |
| Static lists | `resources/lists/` | One item per line |
