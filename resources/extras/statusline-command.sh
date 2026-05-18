#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')

if [ -z "$cwd" ]; then
  cwd="$(pwd)"
fi

# Git info (skip optional locks to avoid contention)
sha="no git"
branch="detected"
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null | cut -c -9)
  branch=$(git -C "$cwd" branch 2>/dev/null | grep "^\*" | cut -c 3-)
  [ -z "$sha" ] && sha="no git"
  [ -z "$branch" ] && branch="detected"
fi

# ANSI cyan color (matches \e[1;36m from original PS1)
CYAN="\033[1;36m"
RESET="\033[0m"

# --- Context window usage ---
# Build "ctx <used>k/<max>k (<pct>%)" only when there has been at least one API call.
# Strategy:
#   1. Use pre-calculated .context_window.used_percentage if non-null.
#   2. Otherwise compute from current_usage (input + cache_read + cache_creation) / context_window_size.
#   3. Silently skip when current_usage is null (no messages yet).
ctx_str=""
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
# Sum the three token buckets that occupy context; null current_usage yields 0.
input_tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens          // 0) +
  (.context_window.current_usage.cache_read_input_tokens   // 0) +
  (.context_window.current_usage.cache_creation_input_tokens // 0)
')
# used_percentage: prefer the pre-calculated field; compute as fallback.
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$used_pct" ] || [ "$used_pct" = "null" ]; then
  # Compute ourselves; only proceed when we have a real ctx_size and token data.
  if [ "$ctx_size" -gt 0 ] && [ "$input_tokens" -gt 0 ] 2>/dev/null; then
    used_pct=$(echo "$input_tokens $ctx_size" | awk '{printf "%.2f", ($1/$2)*100}')
  fi
fi
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ] && [ "$input_tokens" -gt 0 ] 2>/dev/null; then
  # Convert raw token counts to "Nk" shorthand (round to nearest whole k)
  used_k=$(echo "$input_tokens $ctx_size" | awk '{printf "%dk/%dk", ($1+500)/1000, ($2+500)/1000}')
  used_pct_int=$(printf "%.0f" "$used_pct")
  ctx_str=$(printf "  \033[1;36mctx\033[0m %s (%s%%)" "$used_k" "$used_pct_int")
fi

# --- Rate-limit usage (show both windows simultaneously) ---
rate_str=""
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$five_pct" ] && [ -n "$week_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  week_int=$(printf "%.0f" "$week_pct")
  rate_str=$(printf "  \033[1;36m5h\033[0m %s%%  \033[1;36m7d\033[0m %s%%" "$five_int" "$week_int")
elif [ -n "$five_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  rate_str=$(printf "  \033[1;36m5h\033[0m %s%%" "$five_int")
elif [ -n "$week_pct" ]; then
  week_int=$(printf "%.0f" "$week_pct")
  rate_str=$(printf "  \033[1;36m7d\033[0m %s%%" "$week_int")
fi

if [ -n "$model" ]; then
  printf "dir: %s  (%b%s%b) (%b%s%b)  model: %s%b%b" \
    "$cwd" \
    "$CYAN" "$sha" "$RESET" \
    "$CYAN" "$branch" "$RESET" \
    "$model" \
    "$ctx_str" \
    "$rate_str"
else
  printf "dir: %s  (%b%s%b) (%b%s%b)%b%b" \
    "$cwd" \
    "$CYAN" "$sha" "$RESET" \
    "$CYAN" "$branch" "$RESET" \
    "$ctx_str" \
    "$rate_str"
fi
