#!/usr/bin/env bash
# Claude Code status line.
#
# Renders: directory, git sha/branch, model, context-window usage, 5h/7d
# rate-limit usage, and session cost. Reads the session JSON that Claude Code
# pipes on stdin. Schema and behaviour: https://code.claude.com/docs/en/statusline
#
# Tests: resources/extras/statusline-tests/run-tests.sh
#
# No `set -e`/`set -u` on purpose: a status line that aborts prints nothing,
# and a blank bar is worse than a partial one. Every field degrades to empty.
#
# LC_ALL=C pins float formatting to a dot decimal separator; under a
# comma-decimal locale printf "%.2f" emits "1,23" and the cost segment breaks.
export LC_ALL=C

# Slurp stdin without forking cat. `read -d ''` reads to NUL, i.e. to EOF here,
# and returns non-zero at EOF while still assigning, so the || is expected.
IFS= read -r -d '' input || true

# --- Colours ----------------------------------------------------------------
# $'' produces real escape bytes, so every printf below uses %s. (%b would also
# re-interpret backslashes appearing in paths.)
CYAN=$'\033[1;36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# --- Parse ------------------------------------------------------------------
# One jq invocation for every field. Claude Code cancels an in-flight status
# line when a new update arrives, so a script that forks a process per field
# risks being killed before it prints. jq also does all the arithmetic, keeping
# bash away from float formatting entirely.
#
# Contract: 8 lines, in order, empty when unavailable:
#   cwd, model, cost, ctx_used_k, ctx_size_k, ctx_pct, five_pct, week_pct
jq_program='
  def finite:
    if type == "number" and (isnan | not) and (isinfinite | not)
    then . else null end;

  # A used_percentage is 0-100. Anything else is not a percentage: upstream bug
  # #52326 can leave the resets_at epoch in this field, and rendering that would
  # blow the bar apart. Values a hair over 100 are rounding artefacts, so clamp.
  def pct:
    finite
    | if . == null or . < 0 or . > 101 then null
      elif . > 100 then 100
      else . end;

  # Floor, never round: 99.6% must not display as a limit-reached 100%.
  def show: if . == null then "" else (floor | tostring) end;

  (.context_window.current_usage // {}) as $u
  | (($u.input_tokens // 0)
     + ($u.cache_read_input_tokens // 0)
     + ($u.cache_creation_input_tokens // 0)) as $tok
  | (.context_window.context_window_size | finite // 0) as $size
  # Both a token count and a window size are required; without the size there is
  # no denominator and the whole context segment is omitted rather than shown
  # against a zero.
  | ($tok > 0 and $size > 0) as $ctx_ok
  | [
      (.workspace.current_dir // .cwd // ""),
      (.model.display_name // ""),
      (.cost.total_cost_usd | finite | if . == null then "" else tostring end),
      (if $ctx_ok then (($tok + 500) / 1000 | floor | tostring) else "" end),
      (if $ctx_ok then (($size + 500) / 1000 | floor | tostring) else "" end),
      (if $ctx_ok
       then ((.context_window.used_percentage | pct) // ($tok * 100 / $size)) | show
       else "" end),
      (.rate_limits.five_hour.used_percentage | pct | show),
      (.rate_limits.seven_day.used_percentage | pct | show)
    ]
  | .[]
'

cwd=""
model=""
cost=""
ctx_used_k=""
ctx_size_k=""
ctx_pct=""
five_pct=""
week_pct=""

# Without jq the bar degrades to directory and git info instead of vanishing.
if command -v jq >/dev/null 2>&1; then
  field=0
  while IFS= read -r value; do
    field=$((field + 1))
    case $field in
      1) cwd=$value ;;
      2) model=$value ;;
      3) cost=$value ;;
      4) ctx_used_k=$value ;;
      5) ctx_size_k=$value ;;
      6) ctx_pct=$value ;;
      7) five_pct=$value ;;
      8) week_pct=$value ;;
    esac
  done < <(printf '%s' "$input" | jq -r "$jq_program" 2>/dev/null)
fi

[ -z "$cwd" ] && cwd=$(pwd)

# --- Git --------------------------------------------------------------------
# One process for both values: `rev-parse HEAD --abbrev-ref HEAD` prints the sha
# and then the branch (or "HEAD" when detached). --no-optional-locks stops git
# taking index.lock, which would contend with the user's own git commands.
sha="no git"
branch="no git"
if git_out=$(git -C "$cwd" --no-optional-locks rev-parse HEAD --abbrev-ref HEAD 2>/dev/null); then
  sha=${git_out%%$'\n'*}
  branch=${git_out##*$'\n'}
  sha=${sha:0:9}
  [ "$branch" = "HEAD" ] && branch="detached"
fi

# --- Segments ---------------------------------------------------------------
# Each segment is built twice: once with colour for display, once plain so the
# line can be measured against the terminal width without counting escape bytes.
tail_str=""
plain_tail=""
_colour=""

add_segment() { # $1 = coloured, $2 = plain
  tail_str="$tail_str$1"
  plain_tail="$plain_tail$2"
}

# Colour-code usage so a number near the cap reads differently at a glance.
# Every value reaching here is an integer, so numeric comparison is safe.
pct_colour() {
  if [ "$1" -ge 90 ]; then
    _colour=$RED
  elif [ "$1" -ge 70 ]; then
    _colour=$YELLOW
  else
    _colour=$GREEN
  fi
}

if [ -n "$ctx_pct" ]; then
  pct_colour "$ctx_pct"
  add_segment \
    "  ${CYAN}ctx${RESET} ${ctx_used_k}k/${ctx_size_k}k (${_colour}${ctx_pct}%${RESET})" \
    "  ctx ${ctx_used_k}k/${ctx_size_k}k (${ctx_pct}%)"
fi

if [ -n "$five_pct" ]; then
  pct_colour "$five_pct"
  add_segment "  ${CYAN}5h${RESET} ${_colour}${five_pct}%${RESET}" "  5h ${five_pct}%"
fi

if [ -n "$week_pct" ]; then
  pct_colour "$week_pct"
  add_segment "  ${CYAN}7d${RESET} ${_colour}${week_pct}%${RESET}" "  7d ${week_pct}%"
fi

if [ -n "$cost" ]; then
  cost_fmt=$(printf '%.2f' "$cost" 2>/dev/null)
  if [ -n "$cost_fmt" ] && [ "$cost_fmt" != "0.00" ]; then
    add_segment "  ${CYAN}\$${RESET}${cost_fmt}" "  \$${cost_fmt}"
  fi
fi

model_seg=""
[ -n "$model" ] && model_seg="  model: $model"

# --- Fit to the terminal ----------------------------------------------------
# Claude Code captures stdout, so tput cannot see the terminal; it exports
# COLUMNS instead (v2.1.153+). When COLUMNS is unset, print at full width.
#
# The usage numbers are the reason this bar exists, so the path yields space
# first: it collapses to ~, then to a "..."-prefixed tail, then disappears
# entirely rather than pushing the percentages off-screen.
case "$cwd" in
  "$HOME") cwd="~" ;;
  "$HOME"/*) cwd="~${cwd#"$HOME"}" ;;
esac

rest_str="  (${CYAN}${sha}${RESET}) (${CYAN}${branch}${RESET})${model_seg}${tail_str}"
plain_rest="  (${sha}) (${branch})${model_seg}${plain_tail}"

cols=${COLUMNS:-0}
case $cols in
  '' | *[!0-9]*) cols=0 ;;
esac

head_str="dir: $cwd"
if [ "$cols" -gt 0 ]; then
  budget=$((cols - 5 - ${#plain_rest})) # 5 = len("dir: ")
  if [ "$budget" -lt "${#cwd}" ]; then
    if [ "$budget" -ge 8 ]; then
      keep=$((budget - 3))
      offset=$((${#cwd} - keep))
      head_str="dir: ...${cwd:$offset}"
    else
      head_str=""
    fi
  fi
fi

line="${head_str}${rest_str}"
[ -z "$head_str" ] && line=${line#  } # no path: drop its leading separator

printf '%s' "$line"
