#!/usr/bin/env bash
# Runs every other install_*.sh in this folder, in one pass, and reports which
# steps succeeded. Use it on a fresh machine, or after pulling this repo, when
# you want the whole setup rather than one piece of it.
#
# Discovery is a glob rather than a hand-written list: a new install_foo.sh is
# picked up here the moment it lands, so there is no second place to remember
# to update. Order is whatever the glob yields (alphabetical) -- the installers
# touch different files and none depends on another having run.

# Deliberately not `set -e`: a failing installer should not swallow the ones
# after it. Each step's status is recorded and the failures are reported at the
# end, so `just install-all` on a machine missing one dependency still gets you
# everything else.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# The aggregator. Exporting NEXT_STEPS_FILE before running the installers is
# what puts them in "record, do not print" mode: each appends the actions it
# could not perform for the user, and this script renders the combined,
# deduplicated block once at the end. See resources/lib/next_steps.sh.
#
# shell_rc.sh is no longer sourced here -- the closing hint used to be built
# from SHELL_RC, which meant guessing at what the installers had done. They
# report it now instead.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"
export NEXT_STEPS_FILE

failed=()
ran=0

for script in "${SCRIPT_DIR}"/install_*.sh; do
  name="$(basename "$script")"
  # Skip self -- the glob that finds the installers finds this file too.
  [[ "$name" == "install_all.sh" ]] && continue

  echo ""
  echo "${BLUE}==============================================================${RESET}"
  echo "${BLUE}==>${RESET} ${BOLD}${name}${RESET}"
  echo "${BLUE}==============================================================${RESET}"

  ran=$((ran + 1))
  bash "$script"
  status=$?
  if (( status != 0 )); then
    echo "${RED}==> FAILED:${RESET} $name (exit $status)"
    failed+=("$name")
  fi
done

echo ""
echo "${BLUE}==>${RESET} ${BOLD}Ran ${ran} installer(s).${RESET}"

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "    ${BOLD}${RED}${#failed[@]} failed:${RESET} ${failed[*]}"
  echo "    Re-run the failing one on its own to see its output in isolation."
  # Steps recorded before a failure still render below: an RC file that was
  # already edited still needs sourcing, whatever happened afterwards.
fi

# One block for the whole run, rather than each installer's hint scattered up
# the scrollback. This says what the run actually did -- a re-run that changed
# nothing records nothing and prints nothing, which the old hardcoded
# "source your RC / restart Claude Code" footer could not express.
if next_steps_pending; then
  next_step_aside "(Or just open a new terminal.)"
else
  echo "    Nothing to do -- everything was already up to date."
fi

next_steps_render

if [[ ${#failed[@]} -gt 0 ]]; then
  exit 1
fi
