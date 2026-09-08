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

# SHELL_RC, for the closing hint -- the same file the installers below write to.
# shellcheck source=resources/lib/shell_rc.sh
source "${SCRIPT_DIR}/../resources/lib/shell_rc.sh"

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

# Each installer prints its own "run this to load it" hint, and by the end
# those have scrolled well up the screen. Repeat the one action that covers all
# of them so the last thing on screen is still the thing to do.
#
# Which RC to name comes from resources/lib/shell_rc.sh, the same decision the
# installers themselves make, so this hint always points at the file they wrote.

echo ""
echo "${BLUE}==>${RESET} ${BOLD}Ran ${ran} installer(s).${RESET}"

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "    ${BOLD}${RED}${#failed[@]} failed:${RESET} ${failed[*]}"
  echo "    Re-run the failing one on its own to see its output in isolation."
  exit 1
fi

echo "    All steps reported success, but ${BOLD}this shell${RESET} has not picked them up yet."

if [[ -n "$SHELL_RC" ]]; then
  echo "    ${BOLD}${RED}Run this to load them now:${RESET}"
  echo ""
  echo "      ${BOLD}${CYAN}source ${SHELL_RC}${RESET}"
  echo ""
fi

echo "    (Or just open a new terminal. A settings.json change needs a Claude Code restart.)"
