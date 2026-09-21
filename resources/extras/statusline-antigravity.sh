#!/usr/bin/env bash
# Google Antigravity / Gemini CLI (`agy`) status line.
#
# Renders: directory, git branch/sha, model, context-window usage,
# model quota / rate limits, active subagents count, and total session cost (with subagent cost when non-zero).
# Reads the session JSON that agy pipes on stdin.
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

# --- Session state & turn tracking ------------------------------------------
# State lives in TMPDIR so the OS reaps it; each session/conversation keeps its
# own file. A cleared chat (/clear or new conversation_id) resets to zero.
state_dir=${AGY_STATUSLINE_STATE_DIR:-${TMPDIR:-/tmp}/agy-statusline}
state=""
state_file=""

session_id=""
session_re='"(conversation_id|session_id)"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]+)"'
if [[ $input =~ $session_re ]]; then
  session_id=${BASH_REMATCH[2]}
fi
if [ -n "$session_id" ]; then
  state_file=$state_dir/$session_id
  [ -r "$state_file" ] && IFS= read -r state < "$state_file"
fi

# --- Parse ------------------------------------------------------------------
# One jq invocation for every field. agy cancels an in-flight status line
# when a new update arrives, so a script that forks a process per field
# risks being killed before it prints.
#
# Contract: 18 lines, in order, empty when unavailable:
#   cwd, vcs_branch, vcs_dirty, vcs_sha, model, effort,
#   ctx_used_k, ctx_size_k, ctx_pct, quota_label, quota_pct, quota_rem,
#   agent_count, cost, cmd_cost, subagent_cost, terminal_width, new_state
# shellcheck disable=SC2016
jq_program='
  def finite:
    if type == "number" and (isnan | not) and (isinfinite | not)
    then . else null end;

  # A used_percentage is 0-100. Values a hair over 100 are rounding artefacts, so clamp.
  def pct:
    finite
    | if . == null or . < 0 or . > 101 then null
      elif . > 100 then 100
      else . end;

  # Floor, never round: 99.6% must not display as a limit-reached 100%.
  def show: if . == null then "" else (floor | tostring) end;

  def fmt_sec:
    if type == "number" and . > 0 then
      if . >= 86400 then "\(./ 86400 | floor)d\(. % 86400 / 3600 | floor)h"
      elif . >= 3600 then "\(./ 3600 | floor)h\(. % 3600 / 60 | floor)m"
      else "\(./ 60 | floor)m" end
    else null end;

  # Quota extraction: find first bucket or direct quota object
  def extract_quota:
    if (.quota | type) == "object" then
      if .quota.remaining_fraction != null or .quota.used_percentage != null then
        {name: "quota", val: .quota}
      else
        (.quota | to_entries | map(select(.value | type == "object")) | first // null) as $first
        | if $first != null then
            {
              name: (if ($first.key | test("weekly"; "i")) then "weekly"
                     elif ($first.key | test("daily"; "i")) then "daily"
                     else ($first.key | sub("^(gemini|google|agy)[-_]"; "")) end),
              val: $first.value
            }
          else null end
      end
    else null end;

  # Active subagents: count running/active or non-terminated agents
  def active_subagents:
    if (.subagents | type) == "array" then
      ([.subagents[]? | select(
        if type == "object" and .agent_state != null then
          (.agent_state | test("running|active|working|waiting"; "i"))
        elif type == "object" and .status != null then
          (.status | test("running|active|working|waiting"; "i"))
        elif type == "object" and .state != null then
          (.state | test("running|active|working|waiting"; "i"))
        else true end
      )] | length)
    elif (.subagents | type) == "number" then
      .subagents
    else 0 end;

  # The previous render left "total_cost base_cost active_flag accumulated_tokens"
  ($state | split(" ")) as $s
  | ($s[0] | tonumber? // null) as $prev_cost
  | ($s[1] | tonumber? // 0) as $base_cost
  | ($s[2] | tonumber? // 0) as $act_cost
  | ($s[3] | tonumber? // 0) as $prev_tok
  | ((.cost.total_usd // .cost.total_cost_usd) | finite) as $total_cost
  | (if $total_cost == null then null
     elif $prev_cost == null or $total_cost < $prev_cost then {b: $total_cost, a: 0}
     elif $total_cost > $prev_cost then {b: (if $act_cost == 1 then $base_cost else $prev_cost end), a: 1}
     else {b: $base_cost, a: 0} end) as $cost_turn

  | ((.context.total_input_tokens // .context_window.total_input_tokens) | finite) as $reported_total_tok
  | ((.context.input_tokens // .context_window.current_usage.input_tokens // 0) | finite // 0) as $raw_tok
  # Accumulated tokens: if explicit total tokens is reported, use it.
  # Otherwise, keep the high-water mark so intermediate tool steps (e.g. 4k -> 3k)
  # do not artificially drop the conversation context display.
  | (if $reported_total_tok != null and $reported_total_tok > 0 then $reported_total_tok
     elif $raw_tok > $prev_tok then $raw_tok
     else $prev_tok end) as $tok
  | ((.context.total_tokens // .context.context_window_size // .context_window.context_window_size // 0) | finite // 0) as $size
  | ($tok > 0 and $size > 0) as $ctx_ok
  | (if $cost_turn == null then ""
     elif $total_cost != null and ($total_cost - $cost_turn.b) > 0.005 then ($total_cost - $cost_turn.b | tostring)
     else "" end) as $cmd_cost
  | (if $total_cost == null and $tok == 0 then $state
     else "\($total_cost // "null") \($cost_turn.b // "null") \($cost_turn.a // 0) \($tok)" end) as $new_state
  | (. | extract_quota) as $q
  | (if $q != null then
       (if $q.val.used_percentage != null then ($q.val.used_percentage | pct)
        elif $q.val.remaining_fraction != null then (((1 - $q.val.remaining_fraction) * 100) | pct)
        else null end | if . != null then (floor | tostring) else "" end)
     else "" end) as $quota_pct
  | (if $q != null and $quota_pct != "" then
       ($q.name // "quota")
     else "" end) as $quota_label
  | (if $q != null and $quota_pct != "" then
       ($q.val.reset_in_seconds | fmt_sec // "")
     else "" end) as $quota_rem
  | [
      (.workspace.current_dir // .cwd // ""),
      (.vcs.branch // ""),
      (if .vcs.dirty == true then "true" else "" end),
      ((.vcs.sha // "") | if length > 9 then .[:9] else . end),
      (.model.display_name // ""),
      (.model.effort // ""),
      (if $ctx_ok then (($tok + 500) / 1000 | floor | tostring) else "" end),
      (if $ctx_ok then (($size + 500) / 1000 | floor | tostring) else "" end),
      (if $ctx_ok
       then (((.context.used_percentage // .context_window.used_percentage) | pct) // ($tok * 100 / $size)) | show
       else "" end),
      $quota_label,
      $quota_pct,
      $quota_rem,
      (active_subagents | if . > 0 then tostring else "" end),
      (if $total_cost == null then "" else ($total_cost | tostring) end),
      $cmd_cost,
      (.cost.subagent_usd | finite | if . == null then "" else tostring end),
      (.terminal_width | finite | if . == null then "" else tostring end),
      $new_state
    ]
  | .[]
'

cwd=""
vcs_branch=""
vcs_dirty=""
vcs_sha=""
model=""
effort=""
ctx_used_k=""
ctx_size_k=""
ctx_pct=""
quota_label=""
quota_pct=""
quota_rem=""
agent_count=""
cost=""
cmd_cost=""
subagent_cost=""
json_cols=""
new_state=""

# Without jq the bar degrades to directory and git info instead of vanishing.
if command -v jq >/dev/null 2>&1; then
  field=0
  while IFS= read -r value; do
    field=$((field + 1))
    case $field in
      1) cwd=$value ;;
      2) vcs_branch=$value ;;
      3) vcs_dirty=$value ;;
      4) vcs_sha=$value ;;
      5) model=$value ;;
      6) effort=$value ;;
      7) ctx_used_k=$value ;;
      8) ctx_size_k=$value ;;
      9) ctx_pct=$value ;;
      10) quota_label=$value ;;
      11) quota_pct=$value ;;
      12) quota_rem=$value ;;
      13) agent_count=$value ;;
      14) cost=$value ;;
      15) cmd_cost=$value ;;
      16) subagent_cost=$value ;;
      17) json_cols=$value ;;
      18) new_state=$value ;;
    esac
  done < <(printf '%s' "$input" | jq -r --arg state "$state" "$jq_program" 2>/dev/null)
fi

# Persist turn state before rendering so interrupted updates advance baseline
if [ -n "$state_file" ] && [ -n "$new_state" ]; then
  if [ -d "$state_dir" ] || mkdir -p "$state_dir" 2>/dev/null; then
    printf '%s\n' "$new_state" > "$state_file" 2>/dev/null
  fi
fi

[ -z "$cwd" ] && cwd=$(pwd)

# --- Git --------------------------------------------------------------------
# Prefer VCS info reported directly by agy in .vcs (branch + dirty status).
# When missing, fall back to local git rev-parse (sha + branch).
# --no-optional-locks stops git taking index.lock, which would contend with the
# user's own git commands.
sha=""
branch=""

if [ -n "$vcs_branch" ]; then
  branch="$vcs_branch"
  [ "$vcs_dirty" = "true" ] && branch="${branch}*"
  [ -n "$vcs_sha" ] && sha="$vcs_sha"
else
  # Fallback to local git
  if git_out=$(git -C "$cwd" --no-optional-locks rev-parse HEAD --abbrev-ref HEAD 2>/dev/null); then
    sha=${git_out%%$'\n'*}
    branch=${git_out##*$'\n'}
    sha=${sha:0:9}
    [ "$branch" = "HEAD" ] && branch="detached"
  else
    branch="no git"
  fi
fi

git_seg=""
plain_git=""
if [ -n "$sha" ] && [ -n "$branch" ] && [ "$sha" != "no git" ]; then
  git_seg="  (${CYAN}${sha}${RESET}) (${CYAN}${branch}${RESET})"
  plain_git="  (${sha}) (${branch})"
elif [ -n "$branch" ]; then
  git_seg="  (${CYAN}${branch}${RESET})"
  plain_git="  (${branch})"
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

# Context window usage
if [ -n "$ctx_pct" ]; then
  pct_colour "$ctx_pct"
  add_segment \
    "  ${CYAN}ctx${RESET} ${ctx_used_k}k/${ctx_size_k}k (${_colour}${ctx_pct}%${RESET})" \
    "  ctx ${ctx_used_k}k/${ctx_size_k}k (${ctx_pct}%)"
fi

# Model quota / Rate limit usage
if [ -n "$quota_pct" ]; then
  pct_colour "$quota_pct"
  quota_rem_seg=""
  quota_rem_plain=""
  if [ -n "$quota_rem" ]; then
    quota_rem_seg=" (${quota_rem})"
    quota_rem_plain=" (${quota_rem})"
  fi
  quota_name=${quota_label:-quota}
  add_segment \
    "  ${CYAN}${quota_name}${RESET} ${_colour}${quota_pct}%${RESET}${quota_rem_seg}" \
    "  ${quota_name} ${quota_pct}%${quota_rem_plain}"
fi

# Subagents: active/running count
if [ -n "$agent_count" ] && [ "$agent_count" -gt 0 ] 2>/dev/null; then
  agent_label="agents"
  [ "$agent_count" -eq 1 ] && agent_label="agent"
  add_segment \
    "  [${CYAN}${agent_count} ${agent_label}${RESET}]" \
    "  [${agent_count} ${agent_label}]"
fi

# Cost: session total USD and optional subagent USD
# `printf -v` rather than $(printf ...): command substitution forks a subshell
# even around a builtin, and this runs on every render.
if [ -n "$cost" ]; then
  cost_fmt=""
  printf -v cost_fmt '%.2f' "$cost" 2>/dev/null
  if [ -n "$cost_fmt" ] && [ "$cost_fmt" != "0.00" ]; then
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
    sub_seg=""
    sub_plain=""
    if [ -n "$subagent_cost" ]; then
      sub_fmt=""
      printf -v sub_fmt '%.2f' "$subagent_cost" 2>/dev/null
      if [ -n "$sub_fmt" ] && [ "$sub_fmt" != "0.00" ]; then
        sub_seg=" (${CYAN}sub:${RESET}\$${sub_fmt})"
        sub_plain=" (sub:\$${sub_fmt})"
      fi
    fi
    add_segment "${cmd_seg}  ${CYAN}\$${RESET}${cost_fmt}${sub_seg}" "${cmd_plain}  \$${cost_fmt}${sub_plain}"
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
# agy exports COLUMNS or includes terminal_width in the payload.
# When neither is available or > 0, print at full width.
#
# The usage numbers are the reason this bar exists, so the path yields space
# first: it collapses to ~, then to a "..."-prefixed tail, then disappears
# entirely rather than pushing the percentages off-screen.
case "$cwd" in
  "$HOME") cwd="~" ;;
  "$HOME"/*) cwd="~${cwd#"$HOME"}" ;;
esac

rest_str="${git_seg}${model_seg}${tail_str}"
plain_rest="${plain_git}${model_seg}${plain_tail}"

cols=${COLUMNS:-0}
case $cols in
  '' | *[!0-9]*) cols=0 ;;
esac
if [ "$cols" -eq 0 ] && [ -n "$json_cols" ]; then
  case $json_cols in
    '' | *[!0-9]*) cols=0 ;;
    *) cols=$json_cols ;;
  esac
fi

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
