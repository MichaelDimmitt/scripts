#!/bin/bash

shell=$(basename "$SHELL")

case "$shell" in
  zsh)
    echo "Shell: zsh"
    echo "RC files:"
    echo "  ~/.zshrc       (interactive shells)"
    echo "  ~/.zprofile    (login shells)"
    echo "  ~/.zshenv      (all shells)"
    echo "  ~/.zlogin      (login shells, after .zshrc)"
    echo "  ~/.zlogout     (login shell cleanup)"
    ;;
  bash)
    echo "Shell: bash"
    echo "RC files:"
    echo "  ~/.bashrc      (interactive non-login shells)"
    echo "  ~/.bash_profile (login shells)"
    echo "  ~/.profile     (login shells, fallback)"
    echo "  ~/.bash_logout (login shell cleanup)"
    ;;
  fish)
    echo "Shell: fish"
    echo "RC files:"
    echo "  ~/.config/fish/config.fish"
    ;;
  ksh)
    echo "Shell: ksh"
    echo "RC files:"
    echo "  ~/.kshrc"
    echo "  ~/.profile"
    ;;
  tcsh|csh)
    echo "Shell: $shell"
    echo "RC files:"
    echo "  ~/.cshrc"
    echo "  ~/.tcshrc"
    echo "  ~/.login"
    echo "  ~/.logout"
    ;;
  *)
    echo "Shell: $shell (unknown)"
    echo "Try: ~/.profile"
    ;;
esac

echo ""
echo "Existing files:"
for f in ~/.zshrc ~/.zprofile ~/.zshenv ~/.bashrc ~/.bash_profile ~/.profile ~/.config/fish/config.fish; do
  [ -f "$f" ] && echo "  $f"
done

# The loop's last [ -f ] test decides the exit status, so a missing final
# candidate (commonly the fish config) would report failure on a good run.
exit 0
