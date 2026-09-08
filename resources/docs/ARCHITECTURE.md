# Script OS Architecture

## Philosophy

This repo is an operating system for shell automation. Structure is intentionally designed to scale — conventions are established upfront so the project can grow without painful reorganization.

## Folder Structure

```
scripts/
├── .github/workflows/     # CI. Present but disabled -- see checks.yml
├── tell/                  # Scripts that display or report information
│   └── tell_*.sh
├── generate/              # Scripts that produce or create output
│   └── generate_*.sh
├── install/               # Scripts that set up tooling or wire up shell integrations
│   └── install_*.sh
├── check/                 # Scripts that verify the repo's own conventions
│   └── check_*.sh
├── bin/                   # Standalone executables (no verb prefix)
│   └── latest_release
├── resources/
│   ├── docs/              # Architecture and agent guide documents
│   ├── extras/            # Hand-maintained snippets to source from RC files,
│   │                      #   plus Claude Code integrations (statusline, hooks)
│   ├── lib/               # Shell libraries the repo's own scripts source
│   ├── mappings/          # Key→value lookup tables (pipe-delimited)
│   ├── templates/         # Skeletons to copy when adding a script
│   │   └── install_template.sh
│   ├── lists/             # (future) static enumeration files
│   └── schemas/           # (future) validation or format definitions
└── README.md
```

## Naming Conventions

### Scripts
- Pattern: `verb_noun.sh`
- Case: snake_case
- Verbs: `tell` (display/report), `generate` (produce/create), `install` (set up tooling/shell integrations), `check` (verify the repo's own conventions)

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
3. Place it in the folder matching its verb (e.g. `tell/tell_foo.sh`).
   For an installer, start from the skeleton rather than a blank file:
   `cp resources/templates/install_template.sh install/install_foo.sh`
4. Reference resource files via `${SCRIPT_DIR}/../resources/...`
5. Source a shared library for anything one of them already owns. See
   **Shared Libraries** above for what each sets and the `SCRIPT_DIR` form to
   source it with.

   | If the script | Source | Rather than |
   |---|---|---|
   | colours its output | `resources/lib/colours.sh` | declaring `BOLD`/`RESET` itself |
   | writes to the user's shell config | `resources/lib/shell_rc.sh` | naming `~/.bashrc` directly |
   | ends with a call to action | `resources/lib/next_steps.sh` | `echo`ing the hint itself |

6. If it needs a lookup table, add it to `resources/mappings/`
7. Add a section for it in README.md under Scripts
8. Run `just lint` -- it runs `check/check_conventions.sh` over the rules below
   before shellcheck, so a script that opts out of a shared library fails here
   rather than at review

### The installer contract

Everything under `install/` is also bound by the following. It is a contract
rather than a suggestion because opting out is silent: an installer that prints
its own hint still works, it just quietly returns the repo to the scattered
call-to-actions that `next_steps.sh` exists to collect.

Every `install/*.sh` must:

1. source `resources/lib/next_steps.sh`
2. record what the user still has to do with `next_step` / `next_step_note`
   **inside the branch that made the change**, never unconditionally at the end
3. end with `next_steps_render`
4. never `echo` a "source this" call to action of its own -- that is the line
   step 2 replaces

`install/install_statusline.sh` is the worked example of step 2: four of its
five `settings.json` branches record a step and the `OK` branch records none,
so an install that found nothing to fix closes silently. Recording at the end
instead would ask for a Claude Code restart on every run, including the run
where nothing changed to restart for.

Where "did anything change" spans several branches rather than one, compare the
file before and after -- `install_checkout_release.sh` checksums the RC -- and
record once against that.

`install_all.sh` is exempt from all four: it is the aggregator that renders the
combined block, not an installer.

`resources/templates/install_template.sh` is the contract as runnable code: it
sources all three libraries, records a step in the branch that copied the file
and none in the `SKIP: already current` branch beside it, and closes with
`next_steps_render`. Copying it is the shortest path to a compliant installer.
It keeps a shebang -- the copy needs one -- but stays non-executable, which is
why the shebang/exec-bit rule below skips `resources/templates/`.

`check/check_conventions.sh` enforces every rule above, plus two the whole repo
is held to: a file has a shebang if and only if it is executable, and
`resources/lib/*.sh` are non-executable, shebang-free, and carry
`# shellcheck shell=bash`. It reports every violation in one pass and exits
non-zero, so `just lint` fails on a contract breach the way it fails on a
shellcheck finding.

`check/check_install.sh` is the end-to-end counterpart, and deliberately not
part of `just lint`: it runs the installers for real against a throwaway
`$HOME`, then asks a fresh `zsh -ic` / `bash -ic` whether the aliases and
functions actually came out the other side. Liveness cannot be asserted any
other way -- an installer is a child process and can never change the alias
table of the shell that launched it -- and aliases do not expand in a
non-interactive shell, so the `-i` is load-bearing. It is what catches a
hardcoded RC path: the install reports success while every alias comes back
dead under the shell it did not write to.

## Adding a New Resource

| Type | Folder | Format |
|------|--------|--------|
| Key→value lookup | `resources/mappings/` | `NAME \| VALUE` (pipe-delimited) |
| Sourced shell library | `resources/lib/` | `*.sh`, no shebang, `# shellcheck shell=bash` |
| Reusable text blocks | `resources/templates/` | Plain text or heredoc-ready |
| Script skeleton | `resources/templates/` | `*.sh`, shebang, non-executable |
| Static lists | `resources/lists/` | One item per line |
