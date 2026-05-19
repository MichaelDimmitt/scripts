#!/usr/bin/env bash
# Installs latest_release and wires up git checkout release* intercept

set -euo pipefail

echo "==> Creating ~/.local/bin"
mkdir -p ~/.local/bin

if ! grep -q '\.local/bin' ~/.bashrc; then
  echo "==> Adding ~/.local/bin to PATH in ~/.bashrc"
  echo '# no AI was used to install this' >> ~/.bashrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
else
  echo "==> SKIP: ~/.bashrc already contains .local/bin PATH entry"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

echo ""
echo "==> Done. Run 'source ~/.bashrc' to apply changes."
