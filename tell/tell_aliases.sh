#!/usr/bin/env bash
# Reports the shell aliases this project installs: what the repo defines
# (resources/extras/brew-cask-aliases-additional) and whether the copy in
# $HOME is present, current, and actually sourced from your shell RC.
#
# Read-only counterpart to install_aliases.sh -- run it before or after an
# install to see what you have without changing anything.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/../resources/extras/brew-cask-aliases-additional"
DEST="$HOME/.brew-cask-aliases-additional"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC"
  exit 1
fi

echo "Aliases defined in this repo"
echo "  source: $SRC"
echo ""

# Pair each definition with the comment block directly above it, so the list
# explains what each alias is for rather than just naming it. Both `alias x=`
# and plain `name() {` shell functions count -- cresumef and regen-aliases are
# functions, and leaving them out would under-report what gets installed.
awk '
  /^#/ { desc = desc (desc ? " " : "") substr($0, 3); next }
  /^[[:space:]]*alias [A-Za-z0-9_-]+=/ {
    name = $2; sub(/=.*/, "", name)
    printf "  %-16s %s\n", name, desc; desc = ""; next
  }
  /^[A-Za-z0-9_-]+\(\)[[:space:]]*\{/ {
    name = $0; sub(/\(\).*/, "", name)
    printf "  %-16s %s\n", name "()", desc; desc = ""; next
  }
  /^[[:space:]]*$/ { desc = "" }
' "$SRC"

echo ""
echo "Installed copy"
if [[ ! -f "$DEST" ]]; then
  echo "  $DEST -- NOT INSTALLED"
  echo "  Run: just install-aliases"
elif diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
  echo "  $DEST -- installed, up to date"
else
  echo "  $DEST -- installed, DIFFERS from repo"
  echo "  Run: just install-aliases"
fi

echo ""
echo "Sourced from"
LINE="source ~/.brew-cask-aliases-additional"
found=0
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  [[ -f "$rc" ]] || continue
  # grep -c prints its count and still exits 1 on zero matches, so guard the
  # exit status rather than substituting a second "0" onto the output.
  count=$(grep -cF "$LINE" "$rc" 2>/dev/null) || count=0
  if [[ "$count" -gt 0 ]]; then
    found=1
    if [[ "$count" -gt 1 ]]; then
      echo "  $rc ($count duplicate lines)"
    else
      echo "  $rc"
    fi
  fi
done
[[ "$found" -eq 0 ]] && echo "  (no RC file sources it)"

exit 0
