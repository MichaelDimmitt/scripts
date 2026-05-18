# scripts

## Dependency check

At the start of every session, check whether `just` is installed by running `which just`.

If it is not found:
- Tell the user that this project uses `just` as its command runner
- Ask if they want to install it
- If yes, install it using the appropriate method for their OS:
  - macOS: `brew install just`
  - Linux (Debian/Ubuntu): `curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin`
  - Windows: `winget install Casey.Just`
- After installing, confirm with `just --list` to show available commands
