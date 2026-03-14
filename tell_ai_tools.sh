#!/bin/bash
# ============================================================
#  SaaS AI Tools Detector for macOS
#  Based on: github.com/MichaelDimmitt/319c8176034c999907b0c957cf71159a
#  Scans for Web Interfaces, AI IDEs, CLI Agents, SDKs & Extensions
#
#  Requires: resources/mappings/ai_tools_launch.txt (lookup file) relative to this script
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_FILE="${SCRIPT_DIR}/resources/mappings/ai_tools_launch.txt"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

found_count=0
not_found_count=0
found_items=()

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_found() {
    local name="$1"
    local detail="$2"
    echo -e "  ${GREEN}✔ ${BOLD}$name${NC}  ${detail}"
    found_items+=("$name")
    ((found_count++))
}

check_not_found() {
    local name="$1"
    echo -e "  ${RED}✘${NC} $name"
    ((not_found_count++))
}

# ----------------------------------------------------------
#  1. Web Interfaces (macOS desktop apps)
#     Ref: claude.ai, ChatGPT, Gemini, Grok
# ----------------------------------------------------------
print_header "Web Interfaces (Desktop Apps)"

declare -a web_apps=(
    "Claude:claude.ai (Anthropic)"
    "ChatGPT:ChatGPT (OpenAI)"
    "Google Gemini:Gemini (Google)"
    "Gemini:Gemini (Google)"
    "Grok:Grok (xAI)"
)

seen_gemini=0
for entry in "${web_apps[@]}"; do
    app_name="${entry%%:*}"
    display_name="${entry##*:}"
    if [[ "$display_name" == *"Gemini"* ]]; then
        [[ $seen_gemini -eq 1 ]] && continue
    fi
    if ls /Applications/"${app_name}"*.app &>/dev/null || \
       ls ~/Applications/"${app_name}"*.app &>/dev/null || \
       ls /Applications/*/"${app_name}"*.app &>/dev/null; then
        version=$(mdls -name kMDItemVersion /Applications/"${app_name}"*.app 2>/dev/null | awk -F'"' '{print $2}')
        [[ -z "$version" || "$version" == "(null)" ]] && version=""
        [[ "$display_name" == *"Gemini"* ]] && seen_gemini=1
        check_found "$display_name" "${version:+v$version}"
    else
        if [[ "$display_name" == *"Gemini"* ]]; then
            [[ $seen_gemini -eq 0 ]] && { seen_gemini=1; check_not_found "$display_name"; }
        else
            check_not_found "$display_name"
        fi
    fi
done

# ----------------------------------------------------------
#  2. AI-Powered IDEs (macOS apps)
#     Ref: Cursor, Windsurf, Zed
# ----------------------------------------------------------
print_header "AI-Powered IDEs"

declare -a ide_apps=(
    "Cursor:Cursor"
    "Windsurf:Windsurf"
    "Zed:Zed"
)

for entry in "${ide_apps[@]}"; do
    app_name="${entry%%:*}"
    display_name="${entry##*:}"
    if ls /Applications/"${app_name}"*.app &>/dev/null || \
       ls ~/Applications/"${app_name}"*.app &>/dev/null || \
       ls /Applications/*/"${app_name}"*.app &>/dev/null; then
        version=$(mdls -name kMDItemVersion /Applications/"${app_name}"*.app 2>/dev/null | awk -F'"' '{print $2}')
        [[ -z "$version" || "$version" == "(null)" ]] && version=""
        check_found "$display_name" "${version:+v$version}"
    else
        check_not_found "$display_name"
    fi
done

# ----------------------------------------------------------
#  3. CLI / Terminal Agents
#     Ref: Claude Code, Cursor CLI, GitHub Copilot CLI,
#          Gemini CLI, Codex CLI, OpenCode, Aider
# ----------------------------------------------------------
print_header "CLI / Terminal Agents"

declare -a cli_tools=(
    "claude:Claude Code (Anthropic)"
    "agent:Cursor CLI"
    "github-copilot-cli:GitHub Copilot CLI"
    "gh:GitHub CLI (Copilot extension)"
    "gemini:Gemini CLI (Google)"
    "codex:Codex CLI (OpenAI)"
    "opencode:OpenCode"
    "aider:Aider"
)

for entry in "${cli_tools[@]}"; do
    cmd="${entry%%:*}"
    display_name="${entry##*:}"
    if command -v "$cmd" &>/dev/null; then
        version=$($cmd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)
        check_found "$display_name" "${version:+v$version}"
    else
        check_not_found "$display_name"
    fi
done

# Special check: gh copilot extension
if command -v gh &>/dev/null; then
    if gh extension list 2>/dev/null | grep -qi copilot; then
        check_found "GitHub Copilot (gh extension)" ""
    fi
fi

# ----------------------------------------------------------
#  4. VS Code / IDE Extensions
#     Ref: GitHub Copilot (IDE), Cline
# ----------------------------------------------------------
print_header "VS Code / IDE Extensions"

declare -a vscode_extensions=(
    "github.copilot:GitHub Copilot"
    "github.copilot-chat:GitHub Copilot Chat"
    "saoudrizwan.claude-dev:Cline"
)

code_cmd=""
if command -v code &>/dev/null; then
    code_cmd="code"
elif command -v code-insiders &>/dev/null; then
    code_cmd="code-insiders"
fi

if [[ -n "$code_cmd" ]]; then
    ext_list=$($code_cmd --list-extensions 2>/dev/null)
    for entry in "${vscode_extensions[@]}"; do
        ext_id="${entry%%:*}"
        display_name="${entry##*:}"
        if echo "$ext_list" | grep -qi "$ext_id"; then
            check_found "$display_name" ""
        else
            check_not_found "$display_name"
        fi
    done
else
    echo -e "  ${YELLOW}⚠  VS Code CLI not found — skipping extension check${NC}"
fi

# ----------------------------------------------------------
#  5. SaaS Provider SDKs (Python)
# ----------------------------------------------------------
print_header "SaaS Provider SDKs (Python)"

declare -a py_packages=(
    "openai:OpenAI Python SDK"
    "anthropic:Anthropic Python SDK"
    "google-generativeai:Google Generative AI SDK"
    "langchain:LangChain"
)

pip_list=""
if command -v pip3 &>/dev/null; then
    pip_list=$(pip3 list 2>/dev/null)
elif command -v pip &>/dev/null; then
    pip_list=$(pip list 2>/dev/null)
fi

if [[ -n "$pip_list" ]]; then
    for entry in "${py_packages[@]}"; do
        pkg="${entry%%:*}"
        display_name="${entry##*:}"
        match=$(echo "$pip_list" | grep -i "^${pkg} " 2>/dev/null)
        if [[ -n "$match" ]]; then
            version=$(echo "$match" | awk '{print $2}')
            check_found "$display_name" "${version:+v$version}"
        else
            check_not_found "$display_name"
        fi
    done
else
    echo -e "  ${YELLOW}⚠  pip not found — skipping Python SDK check${NC}"
fi

# ----------------------------------------------------------
#  6. SaaS Provider SDKs (Node.js global)
# ----------------------------------------------------------
print_header "SaaS Provider SDKs (Node.js)"

declare -a npm_packages=(
    "@anthropic-ai/sdk:Anthropic JS SDK"
    "openai:OpenAI JS SDK"
    "langchain:LangChain JS"
)

npm_global_list=""
if command -v npm &>/dev/null; then
    npm_global_list=$(npm list -g --depth=0 2>/dev/null)
fi

if [[ -n "$npm_global_list" ]]; then
    for entry in "${npm_packages[@]}"; do
        pkg="${entry%%:*}"
        display_name="${entry##*:}"
        if echo "$npm_global_list" | grep -q "$pkg@"; then
            version=$(echo "$npm_global_list" | grep "$pkg@" | grep -oE '@[0-9]+\.[0-9]+[0-9.]*' | tail -1 | tr -d '@')
            check_found "$display_name" "${version:+v$version}"
        else
            check_not_found "$display_name"
        fi
    done
else
    echo -e "  ${YELLOW}⚠  npm not found — skipping Node SDK check${NC}"
fi

# ----------------------------------------------------------
#  Summary
# ----------------------------------------------------------
total=$((found_count + not_found_count))
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  SUMMARY${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✔ Found:${NC}     ${BOLD}$found_count${NC} SaaS AI tools"
echo -e "  ${RED}✘ Not found:${NC} $not_found_count items checked"
echo -e "  ${CYAN}Total scanned:${NC} $total"
echo ""

if [[ $found_count -eq 0 ]]; then
    echo -e "  ${YELLOW}No SaaS AI tools detected. You're living off the grid! 🏕️${NC}"
elif [[ $found_count -le 5 ]]; then
    echo -e "  ${GREEN}A few SaaS AI tools on board — nice and tidy. 👍${NC}"
elif [[ $found_count -le 10 ]]; then
    echo -e "  ${GREEN}Solid SaaS AI toolkit! You're well-equipped. 🚀${NC}"
else
    echo -e "  ${GREEN}You're a SaaS AI power user! Impressive collection. 🤖${NC}"
fi
echo ""

# ----------------------------------------------------------
#  Merge: grep found tools against the lookup file
#  Shows each installed tool + how to open it
# ----------------------------------------------------------
if [[ ${#found_items[@]} -eq 0 ]]; then
    exit 0
fi

if [[ ! -f "$LAUNCH_FILE" ]]; then
    echo -e "  ${YELLOW}⚠  Lookup file not found: ${LAUNCH_FILE}${NC}"
    echo -e "  ${YELLOW}   Place ai_tools_launch.txt in resources/mappings/ next to this script.${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  INSTALLED SAAS AI TOOLS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for item in "${found_items[@]}"; do
        echo -e "  ${GREEN}✔${NC} ${item}"
    done
    echo ""
    exit 0
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  INSTALLED TOOLS & HOW TO OPEN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for tool_name in "${found_items[@]}"; do
    # grep the lookup file for a line starting with this tool name
    # use fixed-string match on the portion before the pipe
    match=$(grep -v '^#' "$LAUNCH_FILE" | grep -F "$tool_name" | head -1)

    if [[ -n "$match" ]]; then
        # split on first pipe: left = name (ignored, we have it), right = command
        launch_cmd="${match#*| }"
        # trim leading whitespace from command
        launch_cmd="${launch_cmd#"${launch_cmd%%[![:space:]]*}"}"
        printf "  ${GREEN}✔${NC} ${BOLD}%-34s${NC} ${YELLOW}→${NC}  %s\n" "$tool_name" "$launch_cmd"
    else
        # tool found but no launch entry in lookup file
        printf "  ${GREEN}✔${NC} ${BOLD}%-34s${NC} ${RED}(no launch command in lookup file)${NC}\n" "$tool_name"
    fi
done

echo ""
echo -e "  ${CYAN}Lookup file:${NC} ${LAUNCH_FILE}"
echo -e "  ${CYAN}Edit it to add or change launch commands.${NC}"
echo ""
