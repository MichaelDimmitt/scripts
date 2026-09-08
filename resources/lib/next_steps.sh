# shellcheck shell=bash
# Collects the "now do this yourself" actions an installer cannot perform for
# the user, and prints them once, at the end, in one block.
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=resources/lib/next_steps.sh
#   source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"
#
#   next_step "source $SHELL_RC"                   # a line to copy and paste
#   next_step_note "Restart Claude Code to ..."    # an action with no command
#   next_steps_render                              # at the end of the script
#
# Record a step at the moment the change is made, inside the branch that made
# it -- not unconditionally at the end. That is the whole point: a re-run that
# changes nothing then has nothing to report, and says so, instead of printing
# a source line the user does not need.
#
# WHY A FILE: each installer runs as its own `bash install/foo.sh` child, so
# install_all.sh cannot read a variable they set. NEXT_STEPS_FILE is the shared
# scratch file, and whoever creates it renders it:
#
#   unset  -> this script is running standalone. It makes the file, and
#             next_steps_render prints what it collected.
#   set    -> install_all.sh exported it. This script appends and renders
#             nothing; the parent prints the combined block at the end.
#
# So an installer makes the same three calls either way and never asks which
# mode it is in.
#
# The alternative was marker lines on stdout (NEXT_STEP: ...) for the parent to
# filter. Rejected: the parent has to strip them back out of a live, coloured
# stream, and each script's output then depends on who is reading it.

# Set by the sourcing script's own colour import; referenced here only when a
# caller has already sourced colours.sh, hence the :- defaults below.
# shellcheck disable=SC2034

# True when this process created the file, i.e. nobody above us is collecting.
NEXT_STEPS_OWNER=0

if [[ -z "${NEXT_STEPS_FILE:-}" ]]; then
  NEXT_STEPS_FILE="$(mktemp "${TMPDIR:-/tmp}/next-steps.XXXXXX")"
  NEXT_STEPS_OWNER=1
  # Own the cleanup as well as the rendering. Without this a script that dies
  # between mktemp and render leaves the file behind.
  trap 'rm -f "$NEXT_STEPS_FILE"' EXIT
fi

# Records a command for the user to run. Written to the file as `cmd<TAB>text`
# so the renderer can tell a paste-able line from prose.
next_step() {
  printf 'cmd\t%s\n' "$1" >> "$NEXT_STEPS_FILE"
}

# Records an action with no single command behind it ("restart Claude Code").
next_step_note() {
  printf 'note\t%s\n' "$1" >> "$NEXT_STEPS_FILE"
}

# Records a parenthetical that is not itself an action -- "(or open a new
# terminal)". Rendered plain, so the eye still lands on the command above it.
#
# Only the process that will render records one: an aside is a closing line for
# a whole block, so a child installer's would land mid-block under install_all,
# ahead of steps recorded after it. The parent supplies its own closer.
next_step_aside() {
  [[ "$NEXT_STEPS_OWNER" == "1" ]] || return 0
  printf 'aside\t%s\n' "$1" >> "$NEXT_STEPS_FILE"
}

# Size of the file when this script started, so next_steps_pending can answer
# "did *I* record anything" rather than "has anyone". Under install_all.sh the
# file already holds the earlier installers' steps; a script asking whether it
# has anything to say must not count those.
NEXT_STEPS_START=$(wc -c < "$NEXT_STEPS_FILE")

# True when this script has recorded something. Guard a trailing aside with it
# -- "(or open a new terminal)" is only meaningful next to an actual step, and
# a run that changed nothing should print no block at all.
#
# Use `if next_steps_pending; then ...; fi`, not `next_steps_pending && ...`:
# under `set -e` a failing && list at top level exits the script.
next_steps_pending() {
  local now
  now=$(wc -c < "$NEXT_STEPS_FILE")
  (( now > NEXT_STEPS_START ))
}

# Prints the collected steps, deduplicated, in the order first recorded.
#
# A no-op unless this process owns the file: under install_all.sh the child
# installers stay quiet so the parent can print one block for the whole run.
# Also a no-op when nothing was recorded -- an install that changed nothing
# needs no call to action, and saying so by staying silent is the point.
next_steps_render() {
  [[ "$NEXT_STEPS_OWNER" == "1" ]] || return 0
  [[ -s "$NEXT_STEPS_FILE" ]] || return 0

  local kind text
  local prev=""

  echo ""
  echo "${BLUE:-}==>${RESET:-} ${BOLD:-}Next steps${RESET:-}"

  # `awk '!seen[$0]++'` deduplicates on the whole `kind<TAB>text` line while
  # keeping first-seen order: install_checkout_release.sh and
  # install_aliases.sh both want the RC sourced, and the user should be told
  # once, in the order the run produced.
  while IFS=$'\t' read -r kind text; do
    # Blank lines around a run of commands, but not between them: consecutive
    # source lines read as one block to paste, and the surrounding prose stays
    # visually separate from the thing to copy.
    if [[ "$kind" != "$prev" ]]; then
      echo ""
    fi
    prev="$kind"

    case "$kind" in
      cmd)   echo "      ${BOLD:-}${CYAN:-}${text}${RESET:-}" ;;
      note)  echo "    ${BOLD:-}${RED:-}${text}${RESET:-}" ;;
      *)     echo "    ${text}" ;;
    esac
  done < <(awk '!seen[$0]++' "$NEXT_STEPS_FILE")

  echo ""
}
