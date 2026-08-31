#!/usr/bin/env bash
# Run this once (or whenever you install/remove a cask)

# Formatting for the closing hint -- see install_aliases.sh for the rationale.
# Guarded on stdout being a tty so piped output stays plain text.
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; BLUE=$'\033[34m'; CYAN=$'\033[36m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=''; BLUE=''; CYAN=''; RED=''; RESET=''
fi

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

# install_aliases.sh above printed its own hint covering the -additional file
# only. This run also regenerated ~/.brew-cask-aliases, so both need sourcing;
# state the full pair here rather than leaving the user to combine two hints.
echo ""
echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Aliases written, but ${BOLD}this shell${RESET} still has the old copies."
echo "    ${BOLD}${RED}Run these to load them now:${RESET}"
echo ""
echo "      ${BOLD}${CYAN}source ~/.brew-cask-aliases${RESET}"
echo "      ${BOLD}${CYAN}source ~/.brew-cask-aliases-additional${RESET}"
echo ""
echo "    (Or just open a new terminal.)"
