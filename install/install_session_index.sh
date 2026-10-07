#!/usr/bin/env bash
# Installs the session-index skill to ~/.claude/skills/session-index/
#
# Claude Code loads skills from ~/.claude/skills, so it runs a *copy* rather
# than the repo file -- the same staleness trap as the status line. Re-run this
# after pulling; it is idempotent and reports whether anything actually moved.
#
# This was a SessionStart hook in an earlier revision. It is a skill now: the
# hook ran unprompted in every project on every start, spending tokens without
# being asked, and could only index a session on the *following* start because a
# session's own transcript is still empty when SessionStart fires. Nothing here
# touches settings.json -- a skill needs no hook wiring.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for terminal output.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# next_step/next_steps_render: the closing call to action, recorded rather than
# printed so `just install-all` can gather every installer's into one block.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

SRC="${SCRIPT_DIR}/../resources/extras/skills/session-index"
DEST="$HOME/.claude/skills/session-index"

echo "==> Installing session-index skill"
echo "    src:  $SRC"
echo "    dest: $DEST"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: source directory not found: $SRC"
  exit 1
fi

# The skill is a python3 script that shells out to `claude -p` for each summary.
# Without python3 it cannot run at all; without the CLI it writes nothing. Say
# either at install time rather than at use time.
echo "==> Checking dependencies"
if ! command -v python3 > /dev/null 2>&1; then
  echo "ERROR: python3 not found -- the skill cannot run"
  exit 1
fi
echo "    OK: python3 $(python3 --version 2>&1 | awk '{print $2}')"
if ! command -v claude > /dev/null 2>&1; then
  echo "    ${YELLOW}WARN${RESET}: \`claude\` not on PATH -- summaries will fail"
else
  echo "    OK: claude CLI found"
fi

CHANGED=0
mkdir -p "$DEST"
for f in SKILL.md session_index.py; do
  if [[ -f "$DEST/$f" ]] && diff -q "$SRC/$f" "$DEST/$f" > /dev/null 2>&1; then
    echo "    SKIP: $f already current"
  else
    cp "$SRC/$f" "$DEST/$f"
    echo "    Copied $f"
    CHANGED=1
  fi
done
chmod +x "$DEST/session_index.py"

if [[ "$CHANGED" -eq 0 ]]; then
  echo "==> Nothing moved -- install already current"
else
  # Recorded here, in the branch that actually copied something: a re-run that
  # changed nothing has no call to action and should print none. Claude Code
  # reads skills at startup, so a fresh copy is not live until it restarts.
  next_step_note "Restart Claude Code to pick up the session-index skill, then ask it to index this project's past sessions."
  next_step "python3 $DEST/session_index.py --dry-run"
fi

# An earlier revision installed this as a SessionStart hook. Leaving that in
# place would keep indexing every project unprompted, so flag the leftovers
# rather than silently coexisting with them.
echo "==> Checking for leftovers from the old hook install"
LEFTOVER=0
if [[ -f "$HOME/.claude/hooks/session_index.py" ]]; then
  echo "    ${YELLOW}WARN${RESET}: old hook still at ~/.claude/hooks/session_index.py -- delete it"
  LEFTOVER=1
fi
if [[ -f "$HOME/.claude/settings.json" ]] && grep -q 'session_index.py' "$HOME/.claude/settings.json"; then
  echo "    ${YELLOW}WARN${RESET}: settings.json still has a SessionStart entry -- remove it"
  LEFTOVER=1
fi
if [[ -f "$HOME/.claude/.session-index-installed" ]]; then
  echo "    Removing obsolete cutoff marker (the skill has no backfill guard)"
  rm -f "$HOME/.claude/.session-index-installed"
fi
[[ "$LEFTOVER" -eq 0 ]] && echo "    OK: no hook leftovers"

echo ""
if next_steps_pending; then
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Installed the session-index skill."
else
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Already current -- nothing to do."
fi

next_steps_render
