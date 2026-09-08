#!/usr/bin/env bash
# Installs latest_release and wires up git checkout release* intercept

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for the closing hint -- see install_aliases.sh for the rationale.
# The shared library guards on stdout being a tty so piped output stays plain.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# SHELL_NAME / SHELL_RC: which config file the PATH entry and the git() wrapper
# have to land in to take effect. This script used to hardcode ~/.bashrc, which
# under zsh -- the macOS default -- wrote to a file the user's shell never
# reads and then reported success.
# shellcheck source=resources/lib/shell_rc.sh
source "${SCRIPT_DIR}/../resources/lib/shell_rc.sh"

# next_step/next_steps_render: the closing call to action, recorded rather than
# printed so `just install-all` can gather every installer's into one block.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

# Announce the target before touching anything, so an unexpected shell shows up
# as a line to read rather than as an edit to the wrong file.
echo "==> Shell: $SHELL_NAME -> ${SHELL_RC:-(no RC this script can write)}"

echo "==> Creating ~/.local/bin"
mkdir -p ~/.local/bin

SRC="${SCRIPT_DIR}/../bin/latest_release"
DEST="$HOME/.local/bin/latest_release"

echo "==> Copying latest_release"
echo "    src:  $SRC"
echo "    dest: $DEST"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC"
  exit 1
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"

echo "==> Verifying copy"
if diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
  echo "    OK: files match"
else
  echo "    WARN: files differ after copy!"
fi

# The git alias is stored in ~/.gitconfig, not a shell RC, so it works under
# every shell -- including the ones we bail out on below.
echo "==> Setting git alias checkout-release"
git config --global alias.checkout-release '!latest_release'
echo "    $(git config --global --get alias.checkout-release)"

# Single quotes on purpose: $1/$2/$@ are the wrapper's own arguments at call
# time in the user's shell, so they must land in the RC file verbatim.
# shellcheck disable=SC2016
GIT_FUNC='git() {
  if [[ "$1" == "checkout" && ( "$2" == "release" || "$2" == "release/" ) ]]; then
    latest_release
  else
    command git "$@"
  fi
}'

# Everything above is shell-agnostic; everything below writes bash/zsh syntax
# into an interactive RC. For any other shell, print what to add by hand rather
# than writing a function body that shell cannot parse.
if [[ -z "$SHELL_RC" ]]; then
  echo "==> WARN: unsupported shell '$SHELL_NAME' -- not editing any RC file"
  echo "    latest_release is installed and 'git checkout-release' works already."
  echo "    For the bare 'git checkout release' intercept, add to your shell's config:"
  echo "      - \$HOME/.local/bin on PATH"
  echo "      - a git wrapper calling latest_release for 'checkout release'"
  next_step_note "Add ~/.local/bin to PATH in your shell's config by hand."
  next_steps_render
  exit 0
fi

# Whether to tell the user to re-source is decided by comparing the RC before
# and after, not by which branch ran. The git() block below is rewritten on
# every run, but with identical content -- a per-branch next_step there would
# ask for a reload that changes nothing. A checksum rather than a temp copy:
# taking one would mean an EXIT trap, which would replace the one next_steps.sh
# installs to clean up its own file.
rc_checksum() {
  if [[ -f "$SHELL_RC" ]]; then
    cksum < "$SHELL_RC"
  else
    echo "absent"
  fi
}
rc_before="$(rc_checksum)"

if [[ -f "$SHELL_RC" ]] && grep -q '\.local/bin' "$SHELL_RC"; then
  echo "==> SKIP: $SHELL_RC already contains .local/bin PATH entry"
else
  echo "==> Adding ~/.local/bin to PATH in $SHELL_RC"
  echo '# no AI was used to install this' >> "$SHELL_RC"
  # Single quotes again, same reason: $HOME and $PATH must reach the RC file
  # unexpanded so they resolve in the user's shell, not in this one.
  # shellcheck disable=SC2016
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
fi

if [[ -f "$SHELL_RC" ]] && grep -q 'latest_release' "$SHELL_RC"; then
  echo "==> Replacing existing git() shell function in $SHELL_RC"
  # Remove the old function block and write the current one in its place
  awk '
    /^git\(\)/ { skip=1; next }
    skip && /^\}/ { skip=0; next }
    skip { next }
    { print }
  ' "$SHELL_RC" > "$SHELL_RC.tmp" && mv "$SHELL_RC.tmp" "$SHELL_RC"
  echo "$GIT_FUNC" >> "$SHELL_RC"
  echo "    OK: git() function replaced"
else
  echo "==> Adding git() shell function to $SHELL_RC"
  printf '\n%s\n' "$GIT_FUNC" >> "$SHELL_RC"
fi

if [[ "$(rc_checksum)" != "$rc_before" ]]; then
  next_step "source $SHELL_RC"
fi

# A zsh user who ran the version of this script that hardcoded ~/.bashrc still
# has that copy sitting there. It is inert under zsh but live under bash, where
# it will shadow this one with whatever the old function said. Point at it
# rather than editing a file the user did not ask us to touch.
case "$SHELL_NAME" in
  zsh)  OTHER_RC="$HOME/.bashrc" ;;
  bash) OTHER_RC="$HOME/.zshrc" ;;
  *)    OTHER_RC="" ;;
esac

if [[ -n "$OTHER_RC" && -f "$OTHER_RC" ]] && grep -q 'latest_release' "$OTHER_RC"; then
  echo "==> NOTE: $OTHER_RC also has a latest_release git() function"
  echo "    Left from an earlier install that assumed ~/.bashrc. Harmless under"
  echo "    $SHELL_NAME, but delete the git() block there to avoid a stale copy."
  next_step_note "Delete the stale git() block from $OTHER_RC."
fi

# Under bash a login shell reads .bash_profile, not .bashrc, so a function
# written to .bashrc reaches a Terminal.app window only via that chain.
shell_rc_warn_login_profile "the git() wrapper"

# Same child-process caveat as install_aliases.sh: the PATH entry and git()
# function land in the RC file, but this shell already read its RC, so nothing
# changes here until the user re-sources it. The command itself was recorded
# where the write happened, so a re-run that changed nothing stays quiet here.
echo ""
if next_steps_pending; then
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Installed, but ${BOLD}this shell${RESET} has not picked it up yet."
  next_step_aside "(Or just open a new terminal.)"
else
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Already current -- nothing to do."
fi
next_steps_render
