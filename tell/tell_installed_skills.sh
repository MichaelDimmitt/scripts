#!/usr/bin/env bash
# find-skill: list all SKILL.md-based skills across Claude and Cursor installs

print_skills() {
  local label="$1"; shift
  local skills=()
  for path in "$@"; do
    while IFS= read -r f; do
      skill=$(basename "$(dirname "$f")")
      skills+=("$skill")
    done < <(find "$path" -name "SKILL.md" 2>/dev/null)
  done
  if [ ${#skills[@]} -gt 0 ]; then
    echo ""
    echo "── $label"
    printf '   %s\n' "${skills[@]}" | sort -u
  fi
}

echo "=== Installed Skills ==="

# 1. Claude marketplace plugins
print_skills "Claude marketplace (~/.claude/plugins)" \
  "$HOME/.claude/plugins/marketplaces"

# 2. Claude global skills (non-plugin)
[ -d "$HOME/.claude/skills" ] && \
  print_skills "Claude global (~/.claude/skills)" "$HOME/.claude/skills"

# 3. Project-local .claude/ skills under home dir
project_skills=()
while IFS= read -r f; do
  skill=$(basename "$(dirname "$f")")
  proj=$(echo "$f" | sed "s|$HOME/||" | cut -d'/' -f1-2)
  project_skills+=("$skill  ($proj)")
done < <(find "$HOME" -maxdepth 5 -path '*/.claude/skills/*/SKILL.md' \
         -not -path "$HOME/.claude/*" 2>/dev/null)
if [ ${#project_skills[@]} -gt 0 ]; then
  echo ""
  echo "── Project-local Claude skills"
  printf '   %s\n' "${project_skills[@]}" | sort -u
fi

# 4. Cursor skills
print_skills "Cursor (~/.cursor/skills, ~/.cursor/skills-cursor)" \
  "$HOME/.cursor/skills" "$HOME/.cursor/skills-cursor"

# 5. Project-local .cursor/ skills under home dir
cursor_project_skills=()
while IFS= read -r f; do
  skill=$(basename "$(dirname "$f")")
  proj=$(echo "$f" | sed "s|$HOME/||" | cut -d'/' -f1-2)
  cursor_project_skills+=("$skill  ($proj)")
done < <(find "$HOME" -maxdepth 5 -path '*/.cursor/skills/*/SKILL.md' \
         -not -path "$HOME/.cursor/*" 2>/dev/null)
if [ ${#cursor_project_skills[@]} -gt 0 ]; then
  echo ""
  echo "── Project-local Cursor skills"
  printf '   %s\n' "${cursor_project_skills[@]}" | sort -u
fi

echo ""
