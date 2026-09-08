#!/usr/bin/env bash
# Skeleton for a new install/*.sh. Copy it to install/install_<noun>.sh, make
# it executable, and replace everything marked REPLACE.
#
#   cp resources/templates/install_template.sh install/install_foo.sh
#   chmod +x install/install_foo.sh
#
# This file is not executable itself and lives outside install/, so it is a
# thing to copy rather than a thing to run -- check/check_conventions.sh skips
# resources/templates/ for exactly that reason. The relative paths below are
# written for its destination (install/), not for where it currently sits.
#
# The shape here is the installer contract from resources/docs/ARCHITECTURE.md
# made concrete: source the shared libs, record next steps inside the branch
# that made the change, render once at the end. Delete the parts you do not
# need -- an installer that never touches shell config does not need
# shell_rc.sh -- but keep next_steps.sh, which is not optional.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colour variables, blanked when stdout is not a tty so redirected output stays
# plain text. Source this instead of declaring BOLD/RESET yourself.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# SHELL_NAME / SHELL_RC: which config file an alias or shell function has to
# land in to take effect. Drop this source line if you write no shell config.
# Never hardcode ~/.bashrc -- that is the bug this library replaces.
# shellcheck source=resources/lib/shell_rc.sh
source "${SCRIPT_DIR}/../resources/lib/shell_rc.sh"

# next_step / next_steps_render: the closing call to action, recorded rather
# than printed so `just install-all` gathers every installer's into one block.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

# REPLACE: what this installer copies, and where it lands.
SRC="${SCRIPT_DIR}/../resources/extras/REPLACE-me"
DEST="$HOME/.REPLACE-me"

echo "==> Installing REPLACE"
echo "    src:  $SRC"
echo "    dest: $DEST"

# Fail loudly on a missing source file rather than creating an empty DEST.
if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC"
  exit 1
fi

# The idempotence branch, and the reason next_step is called where it is.
#
# "Already current" is a real answer worth printing -- it is what tells you a
# re-run after a pull had nothing to do. Because the next_step call sits in the
# else branch rather than after the if, that run also records nothing, so the
# script closes silently instead of asking for a source that changes nothing.
if [[ -f "$DEST" ]] && diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
  echo "==> SKIP: already current"
else
  cp "$SRC" "$DEST"
  echo "==> Copied"
  # Only the branch that changed something records the action it created.
  next_step "source $DEST"
fi

# An empty SHELL_RC means a shell this repo has no snippet syntax for (fish,
# csh). Say so and skip the edit -- never fall back to a default file.
if [[ -z "$SHELL_RC" ]]; then
  echo "==> WARN: unsupported shell '$SHELL_NAME' -- not editing any RC file"
  next_step_note "Nothing sources $DEST under $SHELL_NAME -- add it to your shell's config."
  next_steps_render
  exit 0
fi

# REPLACE: the line this installer needs in the user's RC. Written with a
# literal ~ so it stays valid if $HOME ever moves.
LINE="source ~/.REPLACE-me"

if [[ -f "$SHELL_RC" ]] && grep -qF "$LINE" "$SHELL_RC"; then
  echo "    SKIP: already sourced in $SHELL_RC"
else
  printf '%s\n' "$LINE" >> "$SHELL_RC"
  echo "    Added to $SHELL_RC: $LINE"
  next_step "source $SHELL_RC"
fi

# Under bash a login shell reads .bash_profile, not .bashrc, so what was just
# written reaches a Terminal.app window only via that chain. A no-op elsewhere.
shell_rc_warn_login_profile "this"

# The install landed on disk, but this script is a child process and cannot
# change the parent shell. next_steps_pending answers "did *this* run record
# anything", which is what decides between the two closing lines -- and the
# aside is only meaningful next to an actual step.
echo ""
if next_steps_pending; then
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Installed, but ${BOLD}this shell${RESET} has not picked it up yet."
  next_step_aside "(Or just open a new terminal.)"
else
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Already current -- nothing to do."
fi

# Always last. Under install_all.sh this is a no-op and the parent renders the
# combined block instead; standalone, it prints what this run collected.
next_steps_render
