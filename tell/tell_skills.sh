#!/bin/bash
# ============================================================
#  Skills Directory Inspector
#  Reports on git-cloned skill repos under ~/skills
#  If ~/skills does not exist, offers to clone anthropics/skills
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/skills"
ANTHROPIC_SKILLS_REPO="https://github.com/anthropics/skills"

# Colours come from the shared library, which blanks them when stdout is not a
# tty -- `just tell-skills > notes.txt` used to write raw escape codes.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

print_header() {
    echo ""
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BOLD}${CYAN}  $1${RESET}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

report_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")

    print_header "$repo_name"

    if ! git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
        echo "  ${YELLOW}⚠  Not a git repository${RESET}"
        return
    fi

    # Remote + branch
    local remote_url branch last_commit last_date
    remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "no remote")
    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
    last_commit=$(git -C "$repo_path" log -1 --format="%s" 2>/dev/null)
    last_date=$(git -C "$repo_path" log -1 --format="%ar" 2>/dev/null)

    echo "  ${CYAN}Remote:${RESET}  $remote_url"
    echo "  ${CYAN}Branch:${RESET}  $branch"
    echo "  ${CYAN}Last commit:${RESET}  $last_commit ${YELLOW}($last_date)${RESET}"

    # Up to date check
    git -C "$repo_path" fetch origin --quiet 2>/dev/null
    local local_sha remote_sha
    local_sha=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null)
    remote_sha=$(git -C "$repo_path" rev-parse "origin/$branch" 2>/dev/null)

    if [[ "$local_sha" == "$remote_sha" ]]; then
        echo "  ${GREEN}✔ Up to date${RESET}"
    else
        local behind
        behind=$(git -C "$repo_path" rev-list --count HEAD.."origin/$branch" 2>/dev/null)
        echo "  ${YELLOW}⚠  $behind commit(s) behind origin/$branch${RESET}"
    fi

    # List skills (top-level dirs and .md files, excluding .git)
    echo ""
    echo "  ${BOLD}Skills available:${RESET}"
    while IFS= read -r item; do
        if [[ -d "$repo_path/$item" ]]; then
            echo "    ${GREEN}▸${RESET} $item/"
        else
            echo "    ${GREEN}▸${RESET} $item"
        fi
    done < <(ls "$repo_path" | grep -v '^\.git$')
}

# ── Main ────────────────────────────────────────────────────

if [[ ! -d "$SKILLS_DIR" ]]; then
    echo ""
    echo "${YELLOW}⚠  ~/skills does not exist.${RESET}"
    echo ""
    printf "Would you like to clone anthropics/skills into ~/skills? [y/N] "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS])
            echo ""
            echo "${CYAN}Cloning $ANTHROPIC_SKILLS_REPO ...${RESET}"
            if git clone "$ANTHROPIC_SKILLS_REPO" "$SKILLS_DIR"; then
                echo "${GREEN}✔ Cloned successfully.${RESET}"
                echo ""
                report_repo "$SKILLS_DIR"
            else
                echo "${RED}✘ Clone failed. Check your network connection and try again.${RESET}"
                exit 1
            fi
            ;;
        *)
            echo "  Skipping. To add manually: git clone $ANTHROPIC_SKILLS_REPO ~/skills"
            echo ""
            exit 0
            ;;
    esac
    exit 0
fi

# ~/skills exists — check if it's a single repo or a directory of repos
repo_count=0
for entry in "$SKILLS_DIR"/*/; do
    [[ -d "$entry/.git" ]] && ((repo_count++))
done

if git -C "$SKILLS_DIR" rev-parse --git-dir &>/dev/null; then
    # Single repo at root
    report_repo "$SKILLS_DIR"
elif [[ $repo_count -gt 0 ]]; then
    # Directory of repos
    print_header "Skills Directory  —  $repo_count repo(s) found"
    for entry in "$SKILLS_DIR"/*/; do
        [[ -d "$entry/.git" ]] && report_repo "$entry"
    done
else
    echo ""
    echo "${YELLOW}⚠  ~/skills exists but contains no git repositories.${RESET}"
    echo "  Add repos manually or run: git clone $ANTHROPIC_SKILLS_REPO ~/skills/anthropic"
fi

echo ""
