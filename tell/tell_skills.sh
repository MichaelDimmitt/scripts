#!/bin/bash
# ============================================================
#  Skills Directory Inspector
#  Reports on git-cloned skill repos under ~/skills
#  If ~/skills does not exist, offers to clone anthropics/skills
# ============================================================

SKILLS_DIR="$HOME/skills"
ANTHROPIC_SKILLS_REPO="https://github.com/anthropics/skills"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

report_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")

    print_header "$repo_name"

    if ! git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
        echo -e "  ${YELLOW}⚠  Not a git repository${NC}"
        return
    fi

    # Remote + branch
    local remote_url branch last_commit last_date
    remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "no remote")
    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
    last_commit=$(git -C "$repo_path" log -1 --format="%s" 2>/dev/null)
    last_date=$(git -C "$repo_path" log -1 --format="%ar" 2>/dev/null)

    echo -e "  ${CYAN}Remote:${NC}  $remote_url"
    echo -e "  ${CYAN}Branch:${NC}  $branch"
    echo -e "  ${CYAN}Last commit:${NC}  $last_commit ${YELLOW}($last_date)${NC}"

    # Up to date check
    git -C "$repo_path" fetch origin --quiet 2>/dev/null
    local local_sha remote_sha
    local_sha=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null)
    remote_sha=$(git -C "$repo_path" rev-parse "origin/$branch" 2>/dev/null)

    if [[ "$local_sha" == "$remote_sha" ]]; then
        echo -e "  ${GREEN}✔ Up to date${NC}"
    else
        local behind
        behind=$(git -C "$repo_path" rev-list --count HEAD.."origin/$branch" 2>/dev/null)
        echo -e "  ${YELLOW}⚠  $behind commit(s) behind origin/$branch${NC}"
    fi

    # List skills (top-level dirs and .md files, excluding .git)
    echo ""
    echo -e "  ${BOLD}Skills available:${NC}"
    while IFS= read -r item; do
        if [[ -d "$repo_path/$item" ]]; then
            echo -e "    ${GREEN}▸${NC} $item/"
        else
            echo -e "    ${GREEN}▸${NC} $item"
        fi
    done < <(ls "$repo_path" | grep -v '^\.git$')
}

# ── Main ────────────────────────────────────────────────────

if [[ ! -d "$SKILLS_DIR" ]]; then
    echo ""
    echo -e "${YELLOW}⚠  ~/skills does not exist.${NC}"
    echo ""
    printf "Would you like to clone anthropics/skills into ~/skills? [y/N] "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS])
            echo ""
            echo -e "${CYAN}Cloning $ANTHROPIC_SKILLS_REPO ...${NC}"
            if git clone "$ANTHROPIC_SKILLS_REPO" "$SKILLS_DIR"; then
                echo -e "${GREEN}✔ Cloned successfully.${NC}"
                echo ""
                report_repo "$SKILLS_DIR"
            else
                echo -e "${RED}✘ Clone failed. Check your network connection and try again.${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "  Skipping. To add manually: git clone $ANTHROPIC_SKILLS_REPO ~/skills"
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
    echo -e "${YELLOW}⚠  ~/skills exists but contains no git repositories.${NC}"
    echo -e "  Add repos manually or run: git clone $ANTHROPIC_SKILLS_REPO ~/skills/anthropic"
fi

echo ""
