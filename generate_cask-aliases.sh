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
