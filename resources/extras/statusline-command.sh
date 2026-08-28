#!/usr/bin/env bash
# Claude Code status line.
#
# Renders: directory, git sha/branch, model, context-window usage, 5h/7d
# rate-limit usage with time until each window resets, and cost (this command,
# then the session total). Reads the session JSON that Claude Code pipes on stdin.
# Schema and behaviour: https://code.claude.com/docs/en/statusline
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

# --- Per-command cost state -------------------------------------------------
# The payload carries only a cumulative session total; nothing in it marks where
# one command ends and the next begins. The boundary is inferred instead: a
# total that grew since the last render means a command is still in flight, a
# total that held steady means it finished, so the next rise starts a new one.
# That inference needs idle renders to happen at all, which is what
# `refreshInterval` buys — without it the bar only updates when the total moves
# and every command looks like one unbroken turn.
#
# State lives in TMPDIR so the OS reaps it; each session keeps its own file, and
# `/clear` issues a new session_id and so starts from zero on its own.
state_dir=${CLAUDE_STATUSLINE_STATE_DIR:-${TMPDIR:-/tmp}/claude-statusline}
state=""
state_file=""

# session_id is matched in bash rather than read from jq: the state has to be in
# hand *before* jq runs, since jq is what does the floating-point subtraction.
# [[ =~ ]] is a builtin, so this costs no process. The character class doubles as
# the sanitiser -- only a UUID-shaped id can reach the path below. The payload is
# pretty-printed in the fixtures and compact in the wild, hence the [[:space:]].
session_id=""
session_re='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]+)"'
if [[ $input =~ $session_re ]]; then
  session_id=${BASH_REMATCH[1]}
fi
if [ -n "$session_id" ]; then
  state_file=$state_dir/$session_id
  [ -r "$state_file" ] && IFS= read -r state < "$state_file"
fi

# --- Parse ------------------------------------------------------------------
# One jq invocation for every field. Claude Code cancels an in-flight status
# line when a new update arrives, so a script that forks a process per field
# risks being killed before it prints. jq also does all the arithmetic, keeping
# bash away from float formatting entirely.
#
# Contract: 13 lines, in order, empty when unavailable:
#   cwd, model, effort, cost, ctx_used_k, ctx_size_k, ctx_pct, five_pct,
#   five_rem, week_pct, week_rem, cmd_cost, new_state
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

  # A resets_at epoch rendered as time-from-now. Two units, never three: "2d4h",
  # "1h23m", "47m". A third unit is more precision than a glanceable bar carries,
  # and the segment has to survive the width budget.
  #
  # A timestamp at or before now yields null, not a negative duration. Claude Code
  # drops a window once its resets_at passes, so a stale payload is the realistic
  # way to get one, and the honest render is no countdown rather than "-3m".
  def remaining($now):
    finite
    | if . == null or . <= $now then null
      else (. - $now) as $s
      | if $s >= 86400 then "\($s / 86400 | floor)d\($s % 86400 / 3600 | floor)h"
        elif $s >= 3600 then "\($s / 3600 | floor)h\($s % 3600 / 60 | floor)m"
        else "\($s / 60 | floor)m" end
      end;

  # "Now" comes from jq rather than bash: $EPOCHSECONDS needs bash 5, and stock
  # macOS ships 3.2, where the countdown would have silently never rendered. jq
  # already runs, so its `now` costs no extra process and needs no version floor.
  (now | floor) as $n

  # The previous render left "total base active" here, empty on the first render.
  # Guard every field: a truncated state file must not take the bar down.
  | ($state | split(" ")) as $s
  | ($s[0] | tonumber? // null) as $prev
  | ($s[1] | tonumber? // 0) as $base
  | ($s[2] | tonumber? // 0) as $act
  | (.cost.total_cost_usd | finite) as $total
  # First sight of a session adopts the total as the baseline rather than
  # claiming it as one command: a resumed session would otherwise report its
  # entire history as the cost of the next thing you type. A total that went
  # *down* is not something the schema produces, so treat it as a fresh start.
  | (if $total == null then null
     elif $prev == null or $total < $prev then {b: $total, a: 0}
     elif $total > $prev then {b: (if $act == 1 then $base else $prev end), a: 1}
     else {b: $base, a: 0} end) as $turn

  | (.context_window.current_usage // {}) as $u
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
      # Top-level, not under .model -- and absent entirely for models without
      # the effort parameter. Passed through verbatim: it is a display string,
      # never branched on, so a level added upstream shows rather than breaks.
      (.effort.level // ""),
      (.cost.total_cost_usd | finite | if . == null then "" else tostring end),
      (if $ctx_ok then (($tok + 500) / 1000 | floor | tostring) else "" end),
      (if $ctx_ok then (($size + 500) / 1000 | floor | tostring) else "" end),
      (if $ctx_ok
       then ((.context_window.used_percentage | pct) // ($tok * 100 / $size)) | show
       else "" end),
      (.rate_limits.five_hour.used_percentage | pct | show),
      # Each window is independently optional, and so is its resets_at within a
      # window that is present: a percentage with no timestamp renders alone.
      (.rate_limits.five_hour.resets_at | remaining($n) // ""),
      (.rate_limits.seven_day.used_percentage | pct | show),
      (.rate_limits.seven_day.resets_at | remaining($n) // ""),
      (if $turn == null then "" else ($total - $turn.b | tostring) end),
      (if $turn == null then $state
       else "\($total) \($turn.b) \($turn.a)" end)
    ]
  | .[]
'

cwd=""
model=""
effort=""
cost=""
ctx_used_k=""
ctx_size_k=""
ctx_pct=""
five_pct=""
five_rem=""
week_pct=""
week_rem=""
cmd_cost=""
new_state=""

# Without jq the bar degrades to directory and git info instead of vanishing.
if command -v jq >/dev/null 2>&1; then
  field=0
  while IFS= read -r value; do
    field=$((field + 1))
    case $field in
      1) cwd=$value ;;
      2) model=$value ;;
      3) effort=$value ;;
      4) cost=$value ;;
      5) ctx_used_k=$value ;;
      6) ctx_size_k=$value ;;
      7) ctx_pct=$value ;;
      8) five_pct=$value ;;
      9) five_rem=$value ;;
      10) week_pct=$value ;;
      11) week_rem=$value ;;
      12) cmd_cost=$value ;;
      13) new_state=$value ;;
    esac
  done < <(printf '%s' "$input" | jq -r --arg state "$state" "$jq_program" 2>/dev/null)
fi

# Persist before rendering: a bar that gets cancelled mid-print has still
# advanced the turn state, so the next render measures from the right place.
if [ -n "$state_file" ] && [ -n "$new_state" ]; then
  if [ -d "$state_dir" ] || mkdir -p "$state_dir" 2>/dev/null; then
    printf '%s\n' "$new_state" > "$state_file" 2>/dev/null
  fi
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

# A percentage says how much of the window is spent; the countdown says how long
# you have to spend the rest. 82% with twelve minutes left and 82% with four
# hours left call for opposite decisions, and the number alone cannot tell them
# apart. Left uncoloured -- the colour here means "approaching a limit", which is
# the percentage's job; a countdown qualifies that number rather than restating
# it. Built as its own string so an absent one leaves the segment byte-identical
# to what it was before countdowns existed.
five_rem_seg=""
[ -n "$five_rem" ] && five_rem_seg=" (${five_rem})"
week_rem_seg=""
[ -n "$week_rem" ] && week_rem_seg=" (${week_rem})"

if [ -n "$five_pct" ]; then
  pct_colour "$five_pct"
  add_segment \
    "  ${CYAN}5h${RESET} ${_colour}${five_pct}%${RESET}${five_rem_seg}" \
    "  5h ${five_pct}%${five_rem_seg}"
fi

if [ -n "$week_pct" ]; then
  pct_colour "$week_pct"
  add_segment \
    "  ${CYAN}7d${RESET} ${_colour}${week_pct}%${RESET}${week_rem_seg}" \
    "  7d ${week_pct}%${week_rem_seg}"
fi

# `printf -v` rather than $(printf ...): command substitution forks a subshell
# even around a builtin, and this runs on every render.
if [ -n "$cost" ]; then
  cost_fmt=""
  printf -v cost_fmt '%.2f' "$cost" 2>/dev/null
  if [ -n "$cost_fmt" ] && [ "$cost_fmt" != "0.00" ]; then
    # This command's share sits to the left of the running total. Both are
    # dropped below a cent: "+$0.00" is noise, not information.
    cmd_seg=""
    cmd_plain=""
    if [ -n "$cmd_cost" ]; then
      cmd_fmt=""
      printf -v cmd_fmt '%.2f' "$cmd_cost" 2>/dev/null
      if [ -n "$cmd_fmt" ] && [ "$cmd_fmt" != "0.00" ]; then
        cmd_seg="  ${CYAN}+\$${RESET}${cmd_fmt}"
        cmd_plain="  +\$${cmd_fmt}"
      fi
    fi
    add_segment "${cmd_seg}  ${CYAN}\$${RESET}${cost_fmt}" "${cmd_plain}  \$${cost_fmt}"
  fi
fi

# Effort hangs off the model name rather than standing alone: without a model to
# qualify, a bare "(high)" says nothing. Left uncoloured on purpose -- the
# green/yellow/red vocabulary here means "approaching a limit", and effort is not
# a limit, so colouring it would overload a signal that currently means one thing.
model_seg=""
if [ -n "$model" ]; then
  model_seg="  model: $model"
  [ -n "$effort" ] && model_seg="$model_seg ($effort)"
fi

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
