# Run this once (or whenever you install/remove a cask)
# Skip any cask whose name already resolves to an executable on PATH —
# those casks ship their own CLI (e.g. `cursor`, `code`) that accepts paths
# and args, and an `open -a` alias would shadow it and break `cursor .` etc.
brew list --cask | while read cask; do
  # Check for a real executable on PATH (ignore aliases/functions from this shell).
  if env PATH="$PATH" type -P "$cask" >/dev/null 2>&1; then
    continue
  fi
  app=$(brew list --cask "$cask" 2>/dev/null | grep -m1 '\.app$' | xargs -I{} basename "{}" .app)
  if [ -n "$app" ]; then
    echo "alias $cask=\"open -a '$app'\""
  fi
done > ~/.brew-cask-aliases

# Note the pattern here also matches the -additional line, so this deletes both
# and the generated one is re-added immediately below.
sed -i '' '/source ~\/.brew-cask-aliases/d' ~/.bashrc
echo 'source ~/.brew-cask-aliases' >> ~/.bashrc

# The hand-maintained aliases are installed by their own script rather than
# copied here. That one detects the shell's RC file instead of assuming
# ~/.bashrc, and de-duplicates its source line -- this script used to append it
# unguarded, so every run left another copy behind.
bash "$(dirname "$0")/../install/install_aliases.sh"

echo ""
echo "Aliases written. To activate in the CURRENT shell, run:"
echo "  source ~/.brew-cask-aliases"
echo "  source ~/.brew-cask-aliases-additional"
