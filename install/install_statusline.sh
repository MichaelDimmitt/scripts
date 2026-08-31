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
# unless settings.json points at it. Checked rather than edited -- settings.json
# is hand-maintained and holds unrelated config, so this reports and leaves the
# editing to a human.
echo "==> Checking $SETTINGS"
if [[ ! -f "$SETTINGS" ]]; then
  echo "    WARN: no settings.json -- the status line will not render until you add:"
  echo "          \"statusLine\": { \"type\": \"command\", \"command\": \"bash $DEST\", \"refreshInterval\": 30 }"
elif ! grep -q 'statusLine' "$SETTINGS"; then
  echo "    WARN: no statusLine block -- add:"
  echo "          \"statusLine\": { \"type\": \"command\", \"command\": \"bash $DEST\", \"refreshInterval\": 30 }"
elif ! grep -q "$DEST" "$SETTINGS"; then
  # A statusLine pointing somewhere else means this install had no effect on
  # what actually renders, which is worth saying loudly.
  echo "    WARN: statusLine does not point at $DEST"
  echo "          Claude Code is running some other script; this install changed nothing."
elif ! grep -q 'refreshInterval' "$SETTINGS"; then
  # Without idle renders the per-command cost segment cannot find turn
  # boundaries and the rate-limit numbers freeze mid-command.
  echo "    WARN: no refreshInterval -- usage numbers will freeze during long calls"
  echo "          Add \"refreshInterval\": 30 to the statusLine block."
else
  echo "    OK: statusLine points here, refreshInterval set"
fi

# Unlike the alias installers there is no command to copy: the script is picked
# up on the next render by itself. Only a settings.json change needs action, so
# the call-to-action highlights the restart rather than a paste-able line.
echo ""
echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} An updated script takes effect on the next render."
echo "    ${BOLD}${RED}A settings.json change needs a Claude Code restart.${RESET}"
