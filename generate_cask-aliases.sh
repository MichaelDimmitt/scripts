# Run this once (or whenever you install/remove a cask)
brew list --cask | while read cask; do
  app=$(brew list --cask "$cask" 2>/dev/null | grep -m1 '\.app$' | xargs -I{} basename "{}" .app)
  if [ -n "$app" ]; then
    echo "alias $cask=\"open -a '$app'\""
  fi
done > ~/.brew-cask-aliases

sed -i '' '/source ~\/.brew-cask-aliases/d' ~/.bashrc
echo 'source ~/.brew-cask-aliases' >> ~/.bashrc
cp resources/extras/brew-cask-aliases-additional ~/.brew-cask-aliases-additional
echo 'source ~/.brew-cask-aliases-additional' >> ~/.bashrc

# Ensure ~/.local/bin exists and is on PATH
mkdir -p ~/.local/bin
if ! grep -q '\.local/bin' ~/.bashrc; then
  echo '# no AI was used to install this' >> ~/.bashrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# Install latest_release script
cp latest_release ~/.local/bin/latest_release
chmod +x ~/.local/bin/latest_release

# Add git alias for checkout-release
git config --global alias.checkout-release '!latest_release'

# Add git() shell function to ~/.bashrc if not already present
if ! grep -q 'latest_release' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'

git() {
  if [[ "$1" == "checkout" && "$2" == release* ]]; then
    latest_release
  else
    command git "$@"
  fi
}
EOF
fi
