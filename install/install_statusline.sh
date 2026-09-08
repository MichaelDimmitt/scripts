#!/usr/bin/env bash
# Installs the Claude Code status line to ~/.claude/statusline-command.sh
#
# Claude Code runs a *copy*, not the repo file, so the copy silently falls
# behind every time the script changes here -- which is exactly how an installed
# bar ends up two features stale with nothing reporting it. Re-run this after
# pulling; it is idempotent and tells you whether anything actually moved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for the closing hint -- see install_aliases.sh for the rationale.
# The shared library guards on stdout being a tty so piped output stays plain.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# next_step/next_steps_render: the closing call to action, recorded rather than
# printed so `just install-all` can gather every installer's into one block.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

SRC="${SCRIPT_DIR}/../resources/extras/statusline-command.sh"
DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

echo "==> Installing Claude Code status line"
echo "    src:  $SRC"
echo "    dest: $DEST"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC"
  exit 1
fi

# Report whether this changed anything. "Already current" is the useful answer
# after a pull -- it is the check that was missing when the bar went stale.
if [[ -f "$DEST" ]] && diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
  echo "==> SKIP: already current"
else
  if [[ -f "$DEST" ]]; then
    echo "==> Updating existing copy"
  else
    echo "==> Creating ~/.claude"
    mkdir -p "$HOME/.claude"
    echo "==> Copying status line"
  fi
  cp "$SRC" "$DEST"
  # Without the executable bit the status line silently does not appear.
  chmod +x "$DEST"

  echo "==> Verifying copy"
  if diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
    echo "    OK: files match"
  else
    echo "    WARN: files differ after copy!"
  fi
fi

# Copying the script is only half the install: the bar does not render at all
# unless settings.json points at it.
#
# This check used to be a literal grep for $DEST, and it was wrong in both
# directions. It called `bash ~/.claude/statusline-command.sh` a miss -- the
# tilde form is the same install, spelled portably -- so a correct setup was
# warned at on every run, and a warning you have learned to ignore is precisely
# how a copy goes stale unnoticed. And when the pointer genuinely was wrong it
# said only "some other script", when by far the likeliest other script is *this
# one*, at $HOME/statusline-command.sh, where installs predating ~/.claude put
# it. That is a migration, not a mystery, so it is now named and repaired.

# Reduces a statusLine command to the script path it runs, so the comparison is
# between paths rather than between spellings. The value is a shell line
# ("bash ~/.claude/statusline-command.sh"), and the script is its last word in
# every form this installer has ever written.
statusline_target() {
  local word last=""
  # Unquoted on purpose: word-splitting is the parse. Globbing cannot bite --
  # the words are a command name and a path, and an unmatched glob would pass
  # through unchanged anyway.
  # shellcheck disable=SC2086
  for word in $1; do last="$word"; done
  # ~ is expanded by the shell that runs the command, so it must be expanded
  # here too or the comparison fails on a correct setting.
  # The tilde here is data being matched, not a path being written, so its not
  # expanding is the point.
  # shellcheck disable=SC2088
  case "$last" in
    "~/"*) printf '%s' "$HOME/${last#\~/}" ;;
    *)     printf '%s' "$last" ;;
  esac
}

# True when the path names a copy of this status line rather than some unrelated
# script: same filename, and either already gone or still recognisable as ours.
# Both halves matter -- the name alone would let this rewrite a setting pointing
# at someone else's file, and requiring the content would refuse to repair a
# pointer whose target has already been deleted.
is_our_statusline() {
  [[ "$(basename "$1")" == "statusline-command.sh" ]] || return 1
  [[ ! -e "$1" ]] && return 0
  grep -q 'Claude Code status line' "$1" 2>/dev/null
}

echo "==> Checking $SETTINGS"

# jq reads the setting as JSON rather than by grep. It is a hard requirement of
# the status line itself, but this installer can run on a machine that has not
# got it yet, so its absence degrades the check instead of failing the install.
have_jq=0
command -v jq > /dev/null 2>&1 && have_jq=1

configured=""
target=""

if [[ ! -f "$SETTINGS" ]]; then
  echo "    WARN: no settings.json -- the status line will not render until you add:"
  echo "          \"statusLine\": { \"type\": \"command\", \"command\": \"bash $DEST\", \"refreshInterval\": 30 }"
  next_step_note "Add a statusLine block to $SETTINGS pointing at $DEST, then restart Claude Code."
elif ! grep -q 'statusLine' "$SETTINGS"; then
  echo "    WARN: no statusLine block -- add:"
  echo "          \"statusLine\": { \"type\": \"command\", \"command\": \"bash $DEST\", \"refreshInterval\": 30 }"
  next_step_note "Add a statusLine block to $SETTINGS pointing at $DEST, then restart Claude Code."
else
  if (( have_jq )); then
    configured="$(jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null)" || configured=""
  fi
  [[ -n "$configured" ]] && target="$(statusline_target "$configured")"

  if [[ -z "$target" ]]; then
    # No jq, or a statusLine block with no command in it. Fall back to the old
    # literal match, widened to the tilde form, and say which question was
    # actually answered -- "the file mentions the path" is not "the setting
    # points at it", and the report should not pretend otherwise.
    # Same as above: a literal tilde is what appears in the file being searched.
    # shellcheck disable=SC2088
    if grep -q "$DEST" "$SETTINGS" || grep -q '~/.claude/statusline-command.sh' "$SETTINGS"; then
      echo "    OK: settings.json mentions $DEST (install jq for an exact check)"
    else
      echo "    WARN: statusLine does not appear to point at $DEST"
      next_step_note "Point statusLine at $DEST in $SETTINGS, then restart Claude Code."
    fi
  elif [[ "$target" == "$DEST" ]]; then
    echo "    OK: statusLine points here"
  elif is_our_statusline "$target"; then
    # The migration. Editing settings.json is a line this installer otherwise
    # does not cross -- the file is hand-maintained and holds unrelated config --
    # so the edit is as narrow as the problem: one key, set with jq so the rest
    # of the document is preserved verbatim, only when the path it currently
    # holds is a copy of this same script, and never without a backup first.
    #
    # Reporting instead was the alternative, and it is what the previous version
    # did. It does not work across machines: the whole point of an installer is
    # that a second machine needs one command, and "now hand-edit this JSON" is
    # not one command.
    echo "==> Migrating: statusLine points at an older copy"
    echo "    was:  $target"
    echo "    now:  $DEST"

    if (( have_jq )); then
      backup="${SETTINGS}.bak"
      cp "$SETTINGS" "$backup"
      if jq --arg cmd "bash $DEST" '.statusLine.command = $cmd' "$SETTINGS" > "${SETTINGS}.tmp" \
         && jq empty "${SETTINGS}.tmp" 2> /dev/null; then
        mv "${SETTINGS}.tmp" "$SETTINGS"
        echo "    OK: repointed (backup: $backup)"
        next_step_note "Restart Claude Code to pick up the repointed status line."
      else
        # jq failed or produced something that is not JSON. Leave the original
        # in place: a settings.json this script half-wrote is a worse outcome
        # than one it did not touch.
        rm -f "${SETTINGS}.tmp"
        echo "    WARN: could not rewrite settings.json -- left unchanged"
        next_step_note "Point statusLine at $DEST in $SETTINGS, then restart Claude Code."
      fi
    else
      echo "    WARN: jq not installed -- cannot rewrite settings.json safely"
      next_step_note "Point statusLine at $DEST in $SETTINGS, then restart Claude Code."
    fi

    # The old copy is now orphaned. Removing it is the user's call, not this
    # script's: it is a file outside anything this installer created, and an
    # installer that deletes from $HOME on its own is a different kind of tool.
    if [[ -e "$target" ]]; then
      echo "    NOTE: the old copy is now unused"
      next_step "rm $target"
    fi
  else
    # A statusLine pointing at something that is not this script at all. Left
    # alone -- the user is running a different bar on purpose, and this install
    # genuinely had no effect on what renders.
    echo "    WARN: statusLine runs a different script: $target"
    echo "          This install changed nothing about what renders."
    next_step_note "Point statusLine at $DEST in $SETTINGS, then restart Claude Code."
  fi

  # Checked whenever a statusLine block exists, rather than only on the path
  # that got everything else right: a stale pointer and a missing refresh
  # interval are independent problems, and fixing the first should not be what
  # finally reveals the second.
  if ! grep -q 'refreshInterval' "$SETTINGS"; then
    # Without idle renders the per-command cost segment cannot find turn
    # boundaries and the rate-limit numbers freeze mid-command.
    echo "    WARN: no refreshInterval -- usage numbers will freeze during long calls"
    echo "          Add \"refreshInterval\": 30 to the statusLine block."
    next_step_note "Add \"refreshInterval\": 30 to the statusLine block in $SETTINGS."
  fi
fi

# Unlike the alias installers there is no command to copy: the script is picked
# up on the next render by itself. The restart line used to print on every run,
# including the one where settings.json was already correct and there was
# nothing to restart for. It is now recorded by the branches above that
# actually found something to fix, so the OK path closes silently.
echo ""
echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} An updated script takes effect on the next render."
next_steps_render
