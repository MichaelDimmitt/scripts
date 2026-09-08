#!/usr/bin/env bash
# Writes an `open -a` shell alias for every installed Homebrew cask to
# ~/.brew-cask-aliases, sources that file from your shell's interactive RC, and
# delegates the hand-maintained companion file to install_aliases.sh.
#
# Run it whenever you install or remove a cask. It is idempotent: a run that
# finds nothing to change says so and asks you to source nothing.
#
# This is the one script the shared-library work passed over -- it kept its own
# ~/.bashrc write and its own closing hint after every installer moved to
# shell_rc.sh and next_steps.sh. It is also the only generate/ script that
# writes shell config, and the only one that calls an installer, so it plays
# the same aggregator role install_all.sh does: it exports NEXT_STEPS_FILE
# before delegating, and renders one closing block for the whole run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for the closing hint -- see install_aliases.sh for the rationale.
# The shared library guards on stdout being a tty so piped output stays plain.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# SHELL_NAME / SHELL_RC: which config file the source line has to land in to
# take effect. This script hardcoded ~/.bashrc, which under zsh -- the macOS
# default since Catalina -- wrote to a file the user's shell never reads and
# then printed a cheerful "Done".
# shellcheck source=resources/lib/shell_rc.sh
source "${SCRIPT_DIR}/../resources/lib/shell_rc.sh"

# next_step/next_steps_render: the closing call to action, recorded rather than
# printed. This script used to print its own block *after* running
# install_aliases.sh, which printed one too, so a single run closed with two
# "Next steps" blocks saying overlapping things.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

usage() {
  cat <<'USAGE'
Usage: generate_cask-aliases.sh

Writes an `open -a` shell alias for every installed Homebrew cask to
~/.brew-cask-aliases, sources it from your shell's interactive RC, and runs
install_aliases.sh for the hand-maintained companion file.

Takes no options. Re-run it after installing or removing a cask.
USAGE
}

# Argument handling exists because this script had none: it ignored $@ entirely
# and performed a full install whatever it was passed. Someone running it with
# --help to find out what it did had their real ~/.brew-cask-aliases and
# ~/.bashrc rewritten by way of an answer.
if (( $# > 0 )); then
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

if ! command -v brew > /dev/null 2>&1; then
  echo "ERROR: brew not found -- this script enumerates Homebrew casks." >&2
  exit 1
fi

DEST="$HOME/.brew-cask-aliases"
TMP="${DEST}.tmp"

echo "==> Scanning Homebrew casks"

# Generate into a temp file and move it into place. The old form redirected
# straight into DEST, truncating it before `brew list` had produced a line --
# so an interrupted or failing scan left the user with no aliases at all.
#
# No EXIT trap to clean TMP up: next_steps.sh installs one for its own scratch
# file and a second would replace it, the same constraint install_checkout_
# release.sh works around. A leftover .tmp is inert and the next run rewrites it.
#
# Skip any cask whose name already resolves to an executable on PATH —
# those casks ship their own CLI (e.g. `cursor`, `code`) that accepts paths
# and args, and an `open -a` alias would shadow it and break `cursor .` etc.
brew list --cask | while read -r cask; do
  # Check for a real executable on PATH (ignore aliases/functions from this shell).
  if env PATH="$PATH" type -P "$cask" >/dev/null 2>&1; then
    continue
  fi
  # `|| true` because plenty of casks ship no .app at all -- fonts, drivers,
  # QuickLook plugins -- and grep exits non-zero when it matches nothing. That
  # is the normal case for those, not a failure, but under `set -o pipefail` it
  # would abort the whole scan on the first one. The `-n` test below is what
  # actually decides whether a cask gets an alias.
  app=$(brew list --cask "$cask" 2>/dev/null | grep -m1 '\.app$' | xargs -I{} basename "{}" .app || true)
  if [ -n "$app" ]; then
    echo "alias $cask=\"open -a '$app'\""
  fi
done > "$TMP"

# Only a changed file needs sourcing. On the SKIP path this shell's aliases
# already match what is on disk, so there is nothing for the user to do.
if [[ -f "$DEST" ]] && diff -q "$TMP" "$DEST" > /dev/null 2>&1; then
  echo "==> SKIP: cask aliases already current"
  rm -f "$TMP"
else
  mv "$TMP" "$DEST"
  # `|| true` because grep exits non-zero on zero matches, which under `set -e`
  # would abort a run whose only fault is that you have no casks installed.
  count=$(grep -c '^alias ' "$DEST" || true)
  echo "==> Wrote ${count} cask alias(es) to $DEST"
  next_step "source $DEST"
fi

# The line this script needs in the RC. Written with a literal ~ to match what
# install_aliases.sh writes beside it and to stay valid if $HOME ever moves.
LINE="source ~/.brew-cask-aliases"

# See resources/lib/shell_rc.sh for why this is the interactive RC and not the
# login profile. An empty SHELL_RC means a shell this repo's snippets are not
# written for; leave its config alone and hand the line to the user.
if [[ -z "$SHELL_RC" ]]; then
  echo "==> WARN: unsupported shell '$SHELL_NAME' -- not editing any RC file"
  next_step_note "Nothing sources $DEST under $SHELL_NAME -- add it to your shell's config."
else
  echo "==> Wiring up $SHELL_RC (shell: $SHELL_NAME)"

  # Whole-line matching (-x) throughout, and this is the reason: the bare
  # string `source ~/.brew-cask-aliases` is a *prefix* of the -additional line
  # install_aliases.sh manages, so an unanchored match hits both. The previous
  # `sed -i '' '/source ~\/.brew-cask-aliases/d'` deleted both lines and relied
  # on install_aliases.sh running afterwards to restore the -additional one --
  # so any failure in between silently cost the user that line. Anchoring means
  # each script now owns exactly its own line.
  if [[ -f "$SHELL_RC" ]] && grep -qxF "$LINE" "$SHELL_RC"; then
    count=$(grep -cxF "$LINE" "$SHELL_RC" || true)
    if (( count > 1 )); then
      echo "    Found ${count} duplicate source lines -- collapsing to one"
      grep -vxF "$LINE" "$SHELL_RC" > "$SHELL_RC.tmp" && mv "$SHELL_RC.tmp" "$SHELL_RC"
      printf '%s\n' "$LINE" >> "$SHELL_RC"
      next_step "source $SHELL_RC"
    else
      echo "    SKIP: already sourced"
    fi
  else
    printf '%s\n' "$LINE" >> "$SHELL_RC"
    echo "    Added: $LINE"
    next_step "source $SHELL_RC"
  fi
fi

# The hand-maintained aliases are installed by their own script rather than
# copied here. Exporting NEXT_STEPS_FILE first is what puts it in "record, do
# not print" mode -- the same handoff install_all.sh performs -- so this run
# ends with one combined block instead of the installer's followed by ours.
export NEXT_STEPS_FILE

# Not allowed to abort this script: the cask aliases are already written and
# the RC already edited, so the steps recorded above still need printing
# whatever happens here. Same reasoning as install_all.sh's missing `set -e`.
# Banner the delegated run, the same way install_all.sh does. Without it the
# installer's own "Done." lands directly above this script's, reading as the
# same message printed twice rather than as one nested run inside another.
echo ""
echo "${BLUE}==============================================================${RESET}"
echo "${BLUE}==>${RESET} ${BOLD}install_aliases.sh${RESET}"
echo "${BLUE}==============================================================${RESET}"

if ! bash "${SCRIPT_DIR}/../install/install_aliases.sh"; then
  echo ""
  echo "${RED}==> WARN:${RESET} install_aliases.sh failed -- ${DEST}-additional may be stale."
  echo "    Re-run it on its own to see its output in isolation."
fi

# install_aliases.sh calls shell_rc_warn_login_profile for this same RC file
# and always runs, so calling it here too would print the warning twice.

# The aliases are on disk, but this script is a child process and cannot touch
# the parent shell's alias table. Until the user sources them, the old
# definitions are still live -- which reads as "the run did nothing".
echo ""
if next_steps_pending; then
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Aliases written, but ${BOLD}this shell${RESET} still has the old copies."
  next_step_aside "(Or just open a new terminal.)"
else
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Aliases were already current -- nothing to do."
fi

next_steps_render
