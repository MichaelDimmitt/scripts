#!/usr/bin/env bash
# Lists installed Homebrew casks, split by whether they ship a CLI binary
# Useful for deciding which casks need an `open -a` alias generated for them

echo "=== Casks WITH binaries ==="
echo ""
for cask in $(brew list --cask); do
  bins=$(brew list --cask "$cask" 2>/dev/null | grep -E '/bin/|/sbin/')
  if [ -n "$bins" ]; then
    echo "$cask:"
    echo "$bins"
    echo ""
  fi
done

echo "=== Casks WITHOUT binaries ==="
echo ""
for cask in $(brew list --cask); do
  bins=$(brew list --cask "$cask" 2>/dev/null | grep -E '/bin/|/sbin/')
  if [ -z "$bins" ]; then
    echo "  $cask"
  fi
done
