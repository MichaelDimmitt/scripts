#!/usr/bin/env bash
# Explains the Antigravity CLI status line, one segment per line.
#
# The bar in resources/extras/statusline-antigravity.sh packs seven kinds of
# information into a single row of terse labels. This is the legend for it:
# each label, then what the number next to it actually means, in one sentence.
#
# Read-only. It describes the format, not your current session.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

segments=(
  "dir:the directory this session is working in, shortened to ~ or ... when the bar runs out of room"
  "(branch):the git branch you are on, marked with * when dirty (or commit sha + branch fallback)"
  "model:the model answering you, with its effort level in brackets when it has one"
  "ctx:tokens used out of the context window, and that as a percentage (accumulated across turns)"
  "weekly:percentage of model quota limit used so far, and in brackets time until reset"
  "[agents]:count of active background subagents currently running"
  "+\$:what the command you just ran cost (delta since last turn)"
  "\$:what this session has cost in total, with subagent cost in brackets when non-zero"
)

echo "The Antigravity status line, left to right"
echo ""

for segment in "${segments[@]}"; do
  printf '  %s%-10s%s %s\n' "$CYAN" "${segment%%:*}" "$RESET" "${segment#*:}"
done

echo ""
echo "A segment is left out when its data is unavailable: no git repo drops the"
echo "branch, an account with no quota reported drops weekly, a session under a"
echo "cent drops the costs, and an idle session with no subagents drops [agents]."
echo ""
echo "${CYAN}Colour${RESET} on a percentage is how close it is to its cap:"
printf '  %s%-6s%s  %s\n' "$GREEN" "green" "$RESET" "under 70%"
printf '  %s%-6s%s  %s\n' "$YELLOW" "yellow" "$RESET" "70-89%"
printf '  %s%-6s%s  %s\n' "$RED" "red" "$RESET" "90% and over"
echo ""
echo "Source: resources/extras/statusline-antigravity.sh"
echo "Install it with: just install-statusline-antigravity"

exit 0
