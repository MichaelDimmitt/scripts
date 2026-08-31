# shellcheck shell=bash
# Defines the terminal colour variables every script in this repo shares.
# Source it near the top of any script that colours its output.
#
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=../resources/lib/colours.sh
#   source "${SCRIPT_DIR}/../resources/lib/colours.sh"
#
# Every variable is set to the empty string when stdout is not a tty, the way
# Homebrew's formatter.sh does it: piping or redirecting a script yields plain
# text rather than raw escape codes. That guard is the whole point of the file
# being shared -- it was previously duplicated in four scripts and missing from
# two others, which is how `just tell-skills > notes.txt` ended up with ANSI
# codes in it.
#
# Values use ANSI-C quoting ($'...'), so the escapes are expanded at assignment
# rather than at print time. Print them with plain `echo` -- `echo -e` also
# works, but is not required, and the reverse is not true: a value written as
# '\033[1m' (literal backslash) needs `echo -e` and emits the literal text
# under plain `echo`. One idiom, no per-call-site rule to remember.
#
# The union of every colour the repo uses. A script referencing only some of
# these is fine and expected.
#
# CYAN and RED carry an explicit `0;` intensity prefix. The install/generate
# scripts previously wrote these as `\033[36m` / `\033[31m` and the tell/
# scripts as `\033[0;36m` / `\033[0;31m`. The two render identically -- an
# omitted intensity parameter defaults to 0 -- so unifying on the longer form
# keeps one definition without changing what any terminal draws.

# Every variable here is consumed by the sourcing script, never by this file,
# so shellcheck's unused-variable warning does not apply.
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  BLUE=$'\033[34m'
  CYAN=$'\033[0;36m'
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  YELLOW=$'\033[1;33m'
  RESET=$'\033[0m'
else
  BOLD=''
  BLUE=''
  CYAN=''
  GREEN=''
  RED=''
  YELLOW=''
  RESET=''
fi
