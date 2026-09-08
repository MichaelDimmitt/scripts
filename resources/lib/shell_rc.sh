# shellcheck shell=bash
# Decides which RC file an installer should edit, and warns about the one way
# that file can still go unread. Source it from any script that writes aliases,
# shell functions, or PATH entries into the user's shell config.
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=resources/lib/shell_rc.sh
#   source "${SCRIPT_DIR}/../resources/lib/shell_rc.sh"
#
# Sets two variables:
#
#   SHELL_NAME  basename of $SHELL, e.g. "zsh"
#   SHELL_RC    absolute path to that shell's interactive RC, or "" if this
#               repo has nothing sensible to write for it
#
# The interactive RC, not the login profile: aliases and shell functions are an
# interactive-shell feature, and under bash that means .bashrc specifically.
# Bash reads .bashrc only for interactive non-login shells, so a login shell
# (Terminal.app opens one) picks them up only if .bash_profile sources .bashrc
# -- which is what shell_rc_warn_login_profile checks, rather than assuming.
#
# Hardcoding ~/.bashrc instead is the bug this file exists to prevent: it
# silently does nothing under zsh, the macOS default since Catalina, and the
# installer still prints a cheerful "Done".

# Consumed by the sourcing script, never by this file.
# shellcheck disable=SC2034
SHELL_NAME=$(basename "${SHELL:-bash}")

case "$SHELL_NAME" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  *)
    # Every other shell either uses a syntax this repo's snippets are not
    # written in (fish, csh) or has no obvious interactive RC. Empty means
    # "say so and skip" -- never write a source line into a file that will
    # never run it.
    SHELL_RC=""
    ;;
esac

# Warns when ~/.bash_profile exists but does not source ~/.bashrc, i.e. when
# what we just wrote to .bashrc will not reach a login shell. Call it after
# editing $SHELL_RC, passing what the user would otherwise not see.
#
#   shell_rc_warn_login_profile "these aliases"
#
# A no-op under any shell but bash, so it is safe to call unconditionally.
shell_rc_warn_login_profile() {
  local what="${1:-this}"

  [[ "$SHELL_NAME" == "bash" && -f "$HOME/.bash_profile" ]] || return 0
  grep -qE '(\.|source).*\.bashrc' "$HOME/.bash_profile" && return 0

  echo "    WARN: ~/.bash_profile does not source ~/.bashrc"
  echo "          Login shells will not see $what. Add to ~/.bash_profile:"
  echo "            . \"\$HOME/.bashrc\""
}
