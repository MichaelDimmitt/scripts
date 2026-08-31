#!/usr/bin/env bash
# Installs latest_release and wires up git checkout release* intercept

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for the closing hint -- see install_aliases.sh for the rationale.
# The shared library guards on stdout being a tty so piped output stays plain.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

echo "==> Creating ~/.local/bin"
mkdir -p ~/.local/bin

if ! grep -q '\.local/bin' ~/.bashrc; then
  echo "==> Adding ~/.local/bin to PATH in ~/.bashrc"
  echo '# no AI was used to install this' >> ~/.bashrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
  echo "==> SKIP: ~/.bashrc already contains .local/bin PATH entry"
fi

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

echo "==> Setting git alias checkout-release"
git config --global alias.checkout-release '!latest_release'
echo "    $(git config --global --get alias.checkout-release)"

GIT_FUNC='git() {
  if [[ "$1" == "checkout" && ( "$2" == "release" || "$2" == "release/" ) ]]; then
    latest_release
  else
    command git "$@"
  fi
}'

if grep -q 'latest_release' ~/.bashrc; then
  echo "==> Replacing existing git() shell function in ~/.bashrc"
  # Remove the old function block and write the current one in its place
  awk '
    /^git\(\)/ { skip=1; next }
    skip && /^\}/ { skip=0; next }
    skip { next }
    { print }
  ' ~/.bashrc > ~/.bashrc.tmp && mv ~/.bashrc.tmp ~/.bashrc
  echo "$GIT_FUNC" >> ~/.bashrc
  echo "    OK: git() function replaced"
else
  echo "==> Adding git() shell function to ~/.bashrc"
  printf '\n%s\n' "$GIT_FUNC" >> ~/.bashrc
fi

# Same child-process caveat as install_aliases.sh: the PATH entry and git()
# function land in ~/.bashrc, but this shell already read its RC, so nothing
# changes here until the user re-sources it.
echo ""
echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Installed, but ${BOLD}this shell${RESET} has not picked it up yet."
echo "    ${BOLD}${RED}Run this to load it now:${RESET}"
echo ""
echo "      ${BOLD}${CYAN}source ~/.bashrc${RESET}"
echo ""
echo "    (Or just open a new terminal.)"
