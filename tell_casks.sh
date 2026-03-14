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
