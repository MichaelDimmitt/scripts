#!/usr/bin/env bash
# Installs latest_release and wires up git checkout release* intercept

mkdir -p ~/.local/bin
if ! grep -q '\.local/bin' ~/.bashrc; then
  echo '# no AI was used to install this' >> ~/.bashrc
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

cp latest_release ~/.local/bin/latest_release
chmod +x ~/.local/bin/latest_release

git config --global alias.checkout-release '!latest_release'

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
