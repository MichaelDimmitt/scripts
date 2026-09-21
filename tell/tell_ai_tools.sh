#!/bin/bash
# ============================================================
#  SaaS AI Tools Detector for macOS
#  Based on: github.com/MichaelDimmitt/319c8176034c999907b0c957cf71159a
#  Scans for Web Interfaces, AI IDEs, CLI Agents, SDKs & Extensions
#
#  Requires: resources/mappings/ai_tools_launch.txt (lookup file) relative to this script
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_FILE="${SCRIPT_DIR}/../resources/mappings/ai_tools_launch.txt"

# Colours come from the shared library, which blanks them when stdout is not a
# tty -- piping this script used to write raw escape codes.
# shellcheck source=resources/lib/colours.sh
source "${SCRIPT_DIR}/../resources/lib/colours.sh"

found_count=0
not_found_count=0
found_items=()

print_header() {
    echo ""
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BOLD}${CYAN}  $1${RESET}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# The optional trailing $note is a standing fact about the tool itself -- a
# deprecation, a licensing restriction -- as distinct from $detail, which
# reports what this machine happens to have. Both branches print it: "installed
# but no longer served" and "gone, and not worth reaching for" are each worth
# saying, and a note that appeared only on a hit would be missed by exactly the
# reader deciding whether to install.
check_found() {
    local name="$1"
    local detail="$2"
    local note="$3"
    echo "  ${GREEN}✔ ${BOLD}$name${RESET}  ${detail}${note:+  ${YELLOW}${note}${RESET}}"
    found_items+=("$name")
    ((found_count++))
}

check_not_found() {
    local name="$1"
    local note="$2"
    echo "  ${RED}✘${RESET} $name${note:+  ${note}}"
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
#     Ref: Antigravity, Cursor, Windsurf, Zed
#
#  Antigravity ships as a desktop app (Homebrew cask `antigravity`, artifact
#  /Applications/Antigravity.app) separately from its CLI, which section 3
#  detects. Having one installed says nothing about the other, so they are two
#  independent checks rather than one.
# ----------------------------------------------------------
print_header "AI-Powered IDEs"

declare -a ide_apps=(
    "Antigravity:Antigravity"
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
#          Antigravity CLI, Gemini CLI, Codex CLI, OpenCode, Aider
#
#  Google retired the Gemini CLI on 18 June 2026 and replaced it with the
#  Antigravity CLI (`agy`). The Gemini CLI stays on this list rather than being
#  deleted, because the retirement was by tier, not outright: Gemini Code Assist
#  Standard/Enterprise seats and paid Gemini Agent Platform API keys are still
#  served, while AI Pro, AI Ultra and free individual accounts are not. A
#  detector that dropped the row would report nothing on the enterprise machines
#  where it is still the right tool -- so it is annotated, not removed.
#  Ref: developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
# ----------------------------------------------------------
print_header "CLI / Terminal Agents"

# Entries are CMD:DISPLAY_NAME, with an optional |NOTE appended. DISPLAY_NAME is
# grepped against the launch lookup file further down, so the note has to sit
# outside it. The separator is `|` rather than a third `:` so that the existing
# two-field entries keep parsing unchanged -- a third colon would make
# ${entry##*:} return the note instead of the name for annotated rows only,
# which is the kind of split behaviour that goes unnoticed.
declare -a cli_tools=(
    "claude:Claude Code (Anthropic)"
    "agent:Cursor CLI"
    "github-copilot-cli:GitHub Copilot CLI"
    "gh:GitHub CLI (Copilot extension)"
    "agy:Antigravity CLI (Google)"
    "gemini:Gemini CLI (Google)|retired 18 Jun 2026 — enterprise seats only; see agy"
    "codex:Codex CLI (OpenAI)"
    "opencode:OpenCode"
    "aider:Aider"
)

for entry in "${cli_tools[@]}"; do
    cmd="${entry%%:*}"
    rest="${entry#*:}"
    # Without a |NOTE, ${rest%%|*} is the whole display name and the guard below
    # leaves $note empty -- no separate no-note branch needed.
    display_name="${rest%%|*}"
    note=""
    [[ "$rest" == *"|"* ]] && note="${rest#*|}"
    if command -v "$cmd" &>/dev/null; then
        version=$($cmd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+[0-9.]*' | head -1)
        check_found "$display_name" "${version:+v$version}" "$note"
    else
        check_not_found "$display_name" "$note"
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
    echo "  ${YELLOW}⚠  VS Code CLI not found — skipping extension check${RESET}"
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
    echo "  ${YELLOW}⚠  pip not found — skipping Python SDK check${RESET}"
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
    echo "  ${YELLOW}⚠  npm not found — skipping Node SDK check${RESET}"
fi

# ----------------------------------------------------------
#  Summary
# ----------------------------------------------------------
total=$((found_count + not_found_count))
echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${BOLD}  SUMMARY${RESET}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "  ${GREEN}✔ Found:${RESET}     ${BOLD}$found_count${RESET} SaaS AI tools"
echo "  ${RED}✘ Not found:${RESET} $not_found_count items checked"
echo "  ${CYAN}Total scanned:${RESET} $total"
echo ""

if [[ $found_count -eq 0 ]]; then
    echo "  ${YELLOW}No SaaS AI tools detected. You're living off the grid! 🏕️${RESET}"
elif [[ $found_count -le 5 ]]; then
    echo "  ${GREEN}A few SaaS AI tools on board — nice and tidy. 👍${RESET}"
elif [[ $found_count -le 10 ]]; then
    echo "  ${GREEN}Solid SaaS AI toolkit! You're well-equipped. 🚀${RESET}"
else
    echo "  ${GREEN}You're a SaaS AI power user! Impressive collection. 🤖${RESET}"
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
    echo "  ${YELLOW}⚠  Lookup file not found: ${LAUNCH_FILE}${RESET}"
    echo "  ${YELLOW}   Place ai_tools_launch.txt in resources/mappings/ next to this script.${RESET}"
    echo ""
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BOLD}  INSTALLED SAAS AI TOOLS${RESET}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    for item in "${found_items[@]}"; do
        echo "  ${GREEN}✔${RESET} ${item}"
    done
    echo ""
    exit 0
fi

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${BOLD}  INSTALLED TOOLS & HOW TO OPEN${RESET}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

for tool_name in "${found_items[@]}"; do
    # grep the lookup file for a line starting with this tool name
    # use fixed-string match on the portion before the pipe
    match=$(grep -v '^#' "$LAUNCH_FILE" | grep -F "$tool_name" | head -1)

    if [[ -n "$match" ]]; then
        # split on first pipe: left = name (ignored, we have it), right = command
        launch_cmd="${match#*| }"
        # trim leading whitespace from command
        launch_cmd="${launch_cmd#"${launch_cmd%%[![:space:]]*}"}"
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET} ${YELLOW}→${RESET}  %s\n" "$tool_name" "$launch_cmd"
    else
        # tool found but no launch entry in lookup file
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET} ${RED}(no launch command in lookup file)${RESET}\n" "$tool_name"
    fi
done

echo ""
echo "  ${CYAN}Lookup file:${RESET} ${LAUNCH_FILE}"
echo "  ${CYAN}Edit it to add or change launch commands.${RESET}"
echo ""
