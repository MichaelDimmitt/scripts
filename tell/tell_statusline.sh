#!/usr/bin/env bash
# Explains the status line, one segment per line.
#
# The bar in resources/extras/statusline-command.sh packs seven kinds of
# information into a single row of terse labels. This is the legend for it:
# each label, then what the number next to it actually means, in one sentence.
#
# Read-only. It describes the format, not your current session -- the live
# numbers are already on screen, and what a glance is missing is what they mean.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# Label and explanation are kept in one string and split on the first colon, so
# the two stay together as they are edited and the column width is set in one
# place below rather than baked into every line.
segments=(
  "dir:the directory this session is working in, shortened to ~ or ... when the bar runs out of room"
  "(sha):the short commit sha HEAD points at"
  "(branch):the branch you are on, or 'detached' when HEAD points at no branch"
  "model:the model answering you, with its effort level in brackets when it has one"
  "ctx:tokens used out of the context window, and that as a percentage -- at 100% the conversation gets compacted"
  "5h:percentage of the 5-hour usage limit reached so far, and in brackets how long until that window resets"
  "7d:percentage of the 7-day usage limit reached so far, and in brackets how long until that window resets"
  "+\$:what the command you just ran cost"
  "\$:what this session has cost in total"
)

echo "The status line, left to right"
echo ""

for segment in "${segments[@]}"; do
  printf '  %s%-8s%s %s\n' "$CYAN" "${segment%%:*}" "$RESET" "${segment#*:}"
done

echo ""
echo "A segment is left out when its number is unavailable: no git repo drops the"
echo "sha and branch, a session under a cent drops the costs, and an account with"
echo "no rate limits reported drops 5h and 7d."
echo ""
echo "${CYAN}Colour${RESET} on a percentage is how close it is to its cap:"
printf '  %s%-6s%s  %s\n' "$GREEN" "green" "$RESET" "under 70%"
printf '  %s%-6s%s  %s\n' "$YELLOW" "yellow" "$RESET" "70-89%"
printf '  %s%-6s%s  %s\n' "$RED" "red" "$RESET" "90% and over"
echo ""
echo "Source: resources/extras/statusline-command.sh"
echo "Install it with: just install-statusline"

exit 0
