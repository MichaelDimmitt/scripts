#!/usr/bin/env bash
# Installs the Antigravity CLI status line to ~/.gemini/antigravity-cli/statusline-antigravity.sh
#
# Antigravity CLI runs a copy, not the repo file, so the copy silently falls
# behind every time the script changes here. Re-run this after pulling; it is
# idempotent and reports whether anything actually moved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for the closing hint.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# next_step/next_steps_render: the closing call to action, recorded rather than
# printed so `just install-all` can gather every installer's into one block.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

SRC="${SCRIPT_DIR}/../resources/extras/statusline-antigravity.sh"
DEST_DIR="$HOME/.gemini/antigravity-cli"
DEST="$DEST_DIR/statusline-antigravity.sh"
SETTINGS="$DEST_DIR/settings.json"

echo "==> Installing Antigravity CLI status line"
echo "    src:  $SRC"
echo "    dest: $DEST"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC"
  exit 1
fi

# Report whether this changed anything. "Already current" is the useful answer
# after a pull.
if [[ -f "$DEST" ]] && diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
  echo "==> SKIP: already current"
else
  if [[ -f "$DEST" ]]; then
    echo "==> Updating existing copy"
  else
    echo "==> Creating $DEST_DIR"
    mkdir -p "$DEST_DIR"
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

# Reduces a statusLine command to the script path it runs, so the comparison is
# between paths rather than between spellings.
statusline_target() {
  local word last=""
  # shellcheck disable=SC2086
  for word in $1; do last="$word"; done
  # shellcheck disable=SC2088
  case "$last" in
    "~/"*) printf '%s' "$HOME/${last#\~/}" ;;
    *)     printf '%s' "$last" ;;
  esac
}

echo "==> Checking $SETTINGS"

have_jq=0
command -v jq > /dev/null 2>&1 && have_jq=1

configured_cmd=""
configured_stack=""
target=""

if [[ ! -f "$SETTINGS" ]]; then
  echo "==> Creating $SETTINGS with statusLine config"
  mkdir -p "$DEST_DIR"
  cat > "$SETTINGS" << 'JSON'
{
  "statusLine": {
    "command": "bash ~/.gemini/antigravity-cli/statusline-antigravity.sh",
    "stack_with_default": true
  }
}
JSON
  echo "    OK: created settings.json"
  next_step_note "Restart Antigravity CLI (agy) or run /statusline on to pick up the status line."
elif ! (( have_jq )); then
  if grep -q 'statusline-antigravity.sh' "$SETTINGS"; then
    echo "    OK: settings.json mentions statusline-antigravity.sh (install jq for an exact check)"
  else
    echo "    WARN: jq not installed -- cannot configure settings.json safely"
    next_step_note "Add statusLine block to $SETTINGS, then restart agy."
  fi
else
  configured_cmd="$(jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null)" || configured_cmd=""
  configured_stack="$(jq -r '.statusLine.stack_with_default // empty' "$SETTINGS" 2>/dev/null)" || configured_stack=""
  [[ -n "$configured_cmd" ]] && target="$(statusline_target "$configured_cmd")"

  if [[ "$target" == "$DEST" ]] && [[ "$configured_stack" == "true" ]]; then
    echo "    OK: statusLine is already configured"
  else
    echo "==> Configuring statusLine in $SETTINGS"
    backup="${SETTINGS}.bak"
    cp "$SETTINGS" "$backup"
    if jq --arg cmd "bash ~/.gemini/antigravity-cli/statusline-antigravity.sh" \
          '.statusLine = ((.statusLine // {}) + {"command": $cmd, "stack_with_default": true})' \
          "$SETTINGS" > "${SETTINGS}.tmp" \
       && jq empty "${SETTINGS}.tmp" 2> /dev/null; then
      mv "${SETTINGS}.tmp" "$SETTINGS"
      echo "    OK: updated statusLine (backup: $backup)"
      next_step_note "Restart Antigravity CLI (agy) or run /statusline on to pick up the status line."
    else
      rm -f "${SETTINGS}.tmp"
      echo "    WARN: could not rewrite settings.json -- left unchanged"
      next_step_note "Add statusLine block to $SETTINGS, then restart agy."
    fi
  fi
fi

echo ""
echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} An updated script takes effect on the next render."
next_steps_render
