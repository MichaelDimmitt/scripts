#!/usr/bin/env bash
# Verifies the repo's own conventions -- the ones a reviewer would otherwise
# have to catch by eye. Run it with `just check-conventions`, or as the first
# half of `just lint`.
#
# It exists because the installer contract is voluntary in the worst way:
# install_all.sh discovers installers by glob and exports NEXT_STEPS_FILE to
# them, so a new install_foo.sh is wired in automatically -- but only *joins*
# the shared "Next steps" block if it sources next_steps.sh and calls the
# functions. An author who writes `echo "source ~/.zshrc"` instead gets no
# error, no lint failure, and no block: just the scattered per-script hints
# that next_steps.sh was written to replace, creeping back one script at a
# time. Documentation cannot catch that. This can.
#
# See "The installer contract" in resources/docs/ARCHITECTURE.md for the rules
# themselves; this file is only their enforcement.

# Deliberately not `set -e`: the point is to report *every* violation in one
# pass, so an author fixes them together rather than rediscovering the next one
# on each re-run.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# Every path below is written repo-relative, so violations print as the paths
# an author would type rather than as absolute paths from wherever they ran it.
cd "$REPO_ROOT" || exit 1

violations=0

# Records one violation: the file, then the rule it broke on its own line.
# Two lines rather than one because the rule text carries the fix, and a
# wrapped single line buries the filename in the middle of it.
report() {
  violations=$((violations + 1))
  echo "  ${RED}FAIL${RESET} ${BOLD}$1${RESET}"
  echo "       $2"
}

section() {
  echo ""
  echo "${BLUE}==>${RESET} ${BOLD}$1${RESET}"
}

# ---------------------------------------------------------------------------
# The installer contract
# ---------------------------------------------------------------------------

section "Installer contract (install/*.sh)"

# An echo or printf whose text hands the user a `source ~/...` or `source $...`
# line -- the hand-rolled call to action that next_step() replaces.
#
# Anchored on echo/printf at the start of the line so it does not fire on the
# correct usage: `next_step "source $SHELL_RC"` is the API, and passing that
# exact string is the whole point of it.
HINT_RE='^[[:space:]]*(echo|printf)([[:space:]]|$).*source[[:space:]]+\\?"?[~$]'

for script in install/install_*.sh; do
  name="$(basename "$script")"

  # The aggregator renders the block the others contribute to; it is exempt
  # from contributing to one. Same skip, and same reason, as its own glob loop.
  [[ "$name" == "install_all.sh" ]] && continue

  grep -q 'lib/next_steps\.sh' "$script" ||
    report "$script" "does not source resources/lib/next_steps.sh"

  grep -q 'next_steps_render' "$script" ||
    report "$script" "never calls next_steps_render -- anything it records is dropped"

  while IFS= read -r hit; do
    report "$script:${hit%%:*}" "prints its own call to action; record it with next_step instead"
  done < <(grep -nE "$HINT_RE" "$script")
done

# ---------------------------------------------------------------------------
# Shebang <-> executable bit
# ---------------------------------------------------------------------------

section "Shebangs and executable bits"

# Tracked files only: git ls-files skips .git, editor scratch, and anything
# untracked, so a work-in-progress file cannot fail someone else's lint run.
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "  ${YELLOW}SKIP${RESET} not a git work tree -- cannot enumerate tracked files"
else
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue

    # resources/templates/ is the deliberate exception: a template carries the
    # shebang the copy will need, but is not itself a thing to run.
    [[ "$f" == resources/templates/* ]] && continue

    shebang=0
    [[ "$(head -c 2 "$f" 2>/dev/null)" == '#!' ]] && shebang=1
    executable=0
    [[ -x "$f" ]] && executable=1

    if (( shebang == 1 && executable == 0 )); then
      report "$f" "has a shebang but is not executable -- chmod +x it, or drop the shebang"
    elif (( shebang == 0 && executable == 1 )); then
      report "$f" "is executable but has no shebang -- the kernel has nothing to run it with"
    fi
  done < <(git ls-files)
fi

# ---------------------------------------------------------------------------
# Shared libraries
# ---------------------------------------------------------------------------

section "Shared libraries (resources/lib/*.sh)"

for lib in resources/lib/*.sh; do
  [[ -x "$lib" ]] &&
    report "$lib" "is executable -- libs under resources/lib are sourced, not run"

  [[ "$(head -c 2 "$lib" 2>/dev/null)" == '#!' ]] &&
    report "$lib" "has a shebang -- a sourced file runs in the caller's shell, not its own"

  grep -q '^# shellcheck shell=bash' "$lib" ||
    report "$lib" "missing '# shellcheck shell=bash' -- shellcheck cannot infer the shell without a shebang"
done

# ---------------------------------------------------------------------------

echo ""
if (( violations > 0 )); then
  echo "${RED}==>${RESET} ${BOLD}${violations} violation(s).${RESET} See 'The installer contract' in resources/docs/ARCHITECTURE.md."
  exit 1
fi

echo "${GREEN}==>${RESET} ${BOLD}All conventions pass.${RESET}"
