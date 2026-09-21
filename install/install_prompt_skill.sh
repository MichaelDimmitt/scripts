#!/usr/bin/env bash
# Installs the /prompt skill to Claude Code and Antigravity CLI
#
# Copies resources/extras/skills/prompt/SKILL.md to:
#   - ~/.claude/skills/prompt/SKILL.md
#   - ~/.gemini/antigravity-cli/skills/prompt/SKILL.md
#   - ~/.gemini/config/skills/prompt/SKILL.md
#
# Re-run after pulling; it is idempotent and reports whether anything moved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Formatting for terminal output.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

# next_step/next_steps_render: the closing call to action, recorded rather than
# printed so `just install-all` can gather every installer's into one block.
# shellcheck source=resources/lib/next_steps.sh
source "${SCRIPT_DIR}/../resources/lib/next_steps.sh"

SRC="${SCRIPT_DIR}/../resources/extras/skills/prompt/SKILL.md"

echo "==> Installing /prompt skill"
echo "    src: $SRC"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source file not found: $SRC" >&2
  exit 1
fi

DEST_DIRS=(
  "$HOME/.claude/skills/prompt"
  "$HOME/.gemini/antigravity-cli/skills/prompt"
  "$HOME/.gemini/config/skills/prompt"
)

changed=0

for dest_dir in "${DEST_DIRS[@]}"; do
  dest_file="$dest_dir/SKILL.md"
  echo "==> Checking $dest_file"

  if [[ -f "$dest_file" ]] && diff -q "$SRC" "$dest_file" > /dev/null 2>&1; then
    echo "    SKIP: already current ($dest_file)"
  else
    if [[ -f "$dest_file" ]]; then
      echo "    Updating existing copy"
      backup="${dest_file}.bak"
      cp "$dest_file" "$backup"
      echo "    Created backup: $backup"
    else
      echo "    Creating directory $dest_dir"
      mkdir -p "$dest_dir"
      echo "    Copying skill definition"
    fi
    cp "$SRC" "$dest_file"
    chmod 644 "$dest_file"

    if diff -q "$SRC" "$dest_file" > /dev/null 2>&1; then
      echo "    OK: installed $dest_file"
      changed=1
    else
      echo "    WARN: files differ after copy to $dest_file!"
    fi
  fi
done

if (( changed == 1 )); then
  next_step_note "Skill installed. Use /prompt in Claude Code or Antigravity CLI to generate agent handoff prompts."
fi

echo ""
if next_steps_pending; then
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Installed /prompt skill across Claude Code and Antigravity CLI."
else
  echo "${BLUE}==>${RESET} ${BOLD}Done.${RESET} Already current -- nothing to do."
fi

next_steps_render
