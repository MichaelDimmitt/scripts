#!/usr/bin/env bash
# End-to-end check that an install actually produces working aliases.
#
#   just check-install          # or: bash check/check_install.sh
#
# Everything else in this repo is checked statically: shellcheck reads the
# scripts, check_conventions.sh reads their shape, and tell_aliases.sh greps
# the RC files for a source line. None of that can tell you an alias *works* --
# only that a line exists somewhere. This runs the installers for real and then
# asks a fresh shell whether the aliases came out the other side.
#
# WHY A SEPARATE SHELL: an installer runs as a child process and can never
# change the alias table of the shell that launched it. Liveness is only
# observable from a shell started *after* the install, which is what makes this
# a second invocation rather than an assertion inside install_all.sh.
#
# The `-i` matters as much as the second process: aliases are not expanded in
# non-interactive shells, so `zsh -c 'type cchats'` reports "not found" on a
# perfectly good install. Every probe here is `-ic`.
#
# This is the check that would have caught the hardcoded ~/.bashrc bug on its
# own: under zsh the install reported success while every alias came back dead.
#
# Not part of `just lint` -- lint is static and fast, and this runs three
# installers per shell. Run it before merging anything that touches install/.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

ALIAS_SRC="${REPO_ROOT}/resources/extras/brew-cask-aliases-additional"

pass=0
fail=0

# Everything runs inside one throwaway root, removed on exit. No test ever sees
# the real $HOME: HOME, and GIT_CONFIG_GLOBAL with it, are redirected in here.
# That second one is not optional -- install_checkout_release.sh runs
# `git config --global`, which would otherwise edit the user's real ~/.gitconfig
# just for running the tests.
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/check-install.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

ok() {
  pass=$((pass + 1))
  echo "    ${GREEN}ok${RESET}   $1"
}

no() {
  fail=$((fail + 1))
  echo "    ${RED}FAIL${RESET} $1"
  [[ -n "${2:-}" ]] && echo "         $2"
  return 0
}

# Builds a throwaway HOME that is already "correct" everywhere the installers
# only report rather than fix. settings.json is pre-pointed at the status line
# so install_statusline.sh reaches its OK branch -- which is what lets the
# re-run assert silence below mean "nothing changed" rather than "the one
# branch that always warns warned again".
make_home() {
  local h="$1"
  mkdir -p "$h/.claude"
  cat > "$h/.claude/settings.json" <<JSON
{
  "statusLine": {
    "type": "command",
    "command": "bash ${h}/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
JSON
}

run_install() {
  local h="$1" shell_path="$2"
  ( HOME="$h" SHELL="$shell_path" GIT_CONFIG_GLOBAL="$h/.gitconfig" \
      bash "${REPO_ROOT}/install/install_all.sh" ) 2>&1
}

# Asks a fresh interactive shell what a name resolves to. Prints nothing and
# returns non-zero when the name is not defined at all.
probe() {
  local shell_path="$1" h="$2" name="$3"
  HOME="$h" "$shell_path" -ic "type $name" 2>/dev/null
}

# The names to probe come from the alias file itself, parsed the same way
# tell_aliases.sh parses it -- both `alias x=` and bare `name() {` functions,
# since cresumef and regen-aliases are functions and omitting them would let
# half the file go untested. Reading the file rather than hardcoding a list is
# what keeps this check honest as aliases are added.
alias_names() {
  awk '
    /^[[:space:]]*alias [A-Za-z0-9_-]+=/ { n = $2; sub(/=.*/, "", n); print n; next }
    /^[A-Za-z0-9_-]+\(\)[[:space:]]*\{/  { n = $0; sub(/\(\).*/, "", n); print n; next }
  ' "$1"
}

check_shell() {
  local shell_path="$1"
  local name rc h out names n

  name="$(basename "$shell_path")"

  echo ""
  echo "${BLUE}==>${RESET} ${BOLD}${name}${RESET} ($shell_path)"

  if [[ ! -x "$shell_path" ]]; then
    echo "    ${YELLOW}skip${RESET} not installed"
    return 0
  fi

  h="$TMPROOT/$name"
  make_home "$h"

  case "$name" in
    zsh)  rc="$h/.zshrc" ;;
    bash) rc="$h/.bashrc" ;;
    *)    no "$name" "no RC mapping for this shell"; return 0 ;;
  esac

  out="$(run_install "$h" "$shell_path")"

  if [[ -f "$rc" ]]; then
    ok "install wrote $(basename "$rc")"
  else
    no "install wrote $(basename "$rc")" "no RC file created -- the install had no effect on this shell"
  fi

  if grep -qxF 'source ~/.brew-cask-aliases-additional' "$rc" 2>/dev/null; then
    ok "RC sources the alias file exactly once"
  else
    no "RC sources the alias file exactly once" "line missing from $rc"
  fi

  # The actual point of this script: are the aliases live in a new shell?
  names="$(alias_names "$ALIAS_SRC")"
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    if probe "$shell_path" "$h" "$n" > /dev/null; then
      ok "$n is defined"
    else
      no "$n is defined" "not found in a fresh '$name -ic' after install"
    fi
  done <<< "$names"

  # install_checkout_release.sh installs a git() wrapper and a PATH entry, and
  # both are only real once the RC has been read. `type git` always succeeds --
  # the binary exists -- so this asserts on the *kind* of thing it resolves to.
  if probe "$shell_path" "$h" git | grep -q 'function'; then
    ok "git() wrapper is a shell function"
  else
    no "git() wrapper is a shell function" "git still resolves to the plain binary"
  fi

  if HOME="$h" "$shell_path" -ic 'command -v latest_release' > /dev/null 2>&1; then
    ok "latest_release is on PATH"
  else
    no "latest_release is on PATH" "the .local/bin PATH entry never took effect"
  fi

  # The property the whole next_steps design exists to produce: a run that
  # changes nothing says so and asks for nothing.
  out="$(run_install "$h" "$shell_path")"
  if echo "$out" | grep -q 'Nothing to do'; then
    ok "re-run is a no-op"
  else
    no "re-run is a no-op" "second run still reported work to do"
  fi
}

# ---------------------------------------------------------------------------

echo "${BLUE}==>${RESET} ${BOLD}End-to-end install check${RESET}"
echo "    sandbox: $TMPROOT"

if [[ ! -f "$ALIAS_SRC" ]]; then
  echo "ERROR: alias source not found: $ALIAS_SRC" >&2
  exit 2
fi

check_shell /bin/zsh
check_shell /bin/bash

# An unsupported shell must be told, not guessed at. The bug this guards is the
# tempting fallback: writing bash syntax into ~/.bashrc for a fish user, which
# reports success and does nothing.
echo ""
echo "${BLUE}==>${RESET} ${BOLD}fish${RESET} (unsupported shell)"
h="$TMPROOT/fish"
make_home "$h"
run_install "$h" /usr/local/bin/fish > /dev/null
if [[ -f "$h/.zshrc" || -f "$h/.bashrc" ]]; then
  no "no RC written for an unsupported shell" "installers wrote a file fish will never read"
else
  ok "no RC written for an unsupported shell"
fi

echo ""
if (( fail > 0 )); then
  echo "${RED}==>${RESET} ${BOLD}${pass} passed, ${fail} failed.${RESET}"
  exit 1
fi

echo "${GREEN}==>${RESET} ${BOLD}${pass} passed.${RESET}"
