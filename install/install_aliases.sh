#!/usr/bin/env bash
# Installs the hand-maintained shell aliases (cl, cx, cresume, cresumef,
# cchats, regen-aliases) from resources/extras/brew-cask-aliases-additional.
#
# Split out of generate_cask-aliases.sh, which does this as a footnote to
# enumerating every Homebrew cask. Editing an alias should not require a full
# `brew list --cask` scan, and this needs no brew at all.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for the closing hint. The copy-paste line is the one piece of
# output the user must act on, so it gets bold + colour rather than blending
# into the log above it. The shared library guards on stdout being a tty, so
# piping or redirecting this script yields plain text, not escape codes.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# SHELL_NAME / SHELL_RC: which config file these aliases have to land in to
# take effect. Shared with the other installers so they all agree on it.
# shellcheck source=resources/lib/shell_rc.sh
source "${SCRIPT_DIR}/../resources/lib/shell_rc.sh"

# next_step/next_steps_render: the closing call to action. Recorded rather than
# printed directly, so `just install-all` can gather every installer's actions
# into one block instead of leaving them scattered up the scrollback.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

SRC="${SCRIPT_DIR}/../resources/extras/brew-cask-aliases-additional"
DEST="$HOME/.brew-cask-aliases-additional"

echo "==> Installing shell aliases"
echo "    src:  $SRC"
echo "    dest: $DEST"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC"
  exit 1
fi

if [[ -f "$DEST" ]] && diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
  echo "==> SKIP: aliases already current"
else
  cp "$SRC" "$DEST"
  echo "==> Copied aliases"
  if diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
    echo "    OK: files match"
  else
    echo "    WARN: files differ after copy!"
  fi
  # Only a changed file needs sourcing. On the SKIP path this shell's aliases
  # already match what is on disk, so there is nothing for the user to do.
  next_step "source $DEST"
fi

# See resources/lib/shell_rc.sh for why this is the interactive RC and not the
# login profile. An empty SHELL_RC means the shell is one this repo's snippets
# are not written for; leave its config alone and hand the line to the user.
if [[ -z "$SHELL_RC" ]]; then
  echo "==> WARN: unsupported shell '$SHELL_NAME' -- not editing any RC file"
  echo "    Nothing will load these automatically; source them yourself."
  # Self-contained wording: the copy above may already have recorded the source
  # line, and the renderer keeps first-seen order, so a note that reads as a
  # caption ("source this:") would end up orphaned below its own command.
  next_step_note "Nothing sources $DEST under $SHELL_NAME -- add it to your shell's config."
  next_steps_render
  exit 0
fi

RC="$SHELL_RC"
echo "==> Wiring up $RC (shell: $SHELL_NAME)"
# Written with a literal ~ rather than the expanded path, to match the line the
# generate script writes beside it and to stay valid if $HOME ever moves.
LINE="source ~/.brew-cask-aliases-additional"

# Rewrite rather than append. The generate script appends this line with no
# dedupe, so every run leaves another copy behind; strip any existing lines
# first so re-running converges instead of accumulating.
if [[ -f "$RC" ]] && grep -qF "$LINE" "$RC"; then
  count=$(grep -cF "$LINE" "$RC")
  if [[ "$count" -gt 1 ]]; then
    echo "    Found $count duplicate source lines -- collapsing to one"
    grep -vF "$LINE" "$RC" > "$RC.tmp" && mv "$RC.tmp" "$RC"
    printf '%s\n' "$LINE" >> "$RC"
  else
    echo "    SKIP: already sourced"
  fi
else
  printf '%s\n' "$LINE" >> "$RC"
  echo "    Added: $LINE"
  next_step "source $RC"
fi

# Under bash a login shell reads .bash_profile, not .bashrc, so aliases written
# to .bashrc reach a Terminal.app window only via that chain.
shell_rc_warn_login_profile "these aliases"

# The aliases are installed, but this script is a child process -- it cannot
# touch the parent shell's alias table. Until the user sources the file (or
# opens a new shell) `alias cchats` still reports the old definition, which
# reads as "the install did nothing". Say so, then hand the actual command to
# the aggregator so it lands in one place with every other installer's.
echo ""
if next_steps_pending; then
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Aliases are installed, but ${BOLD}this shell${RESET} still has the old copy."
  next_step_aside "(Or just open a new terminal.)"
else
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Aliases were already current -- nothing to do."
fi
next_steps_render
