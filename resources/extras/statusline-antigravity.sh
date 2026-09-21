#!/usr/bin/env bash
# Google Antigravity / Gemini CLI (`agy`) status line.
#
# Renders: directory, git branch/sha, model, context-window usage,
# active subagents count, and total session cost (with subagent cost when non-zero).
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

# --- Parse ------------------------------------------------------------------
# One jq invocation for every field. agy cancels an in-flight status line
# when a new update arrives, so a script that forks a process per field
# risks being killed before it prints.
#
# Contract: 13 lines, in order, empty when unavailable:
#   cwd, vcs_branch, vcs_dirty, vcs_sha, model, effort,
#   ctx_used_k, ctx_size_k, ctx_pct, agent_count, cost, subagent_cost, terminal_width
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

  ((.context.input_tokens // .context_window.current_usage.input_tokens // 0) | finite // 0) as $tok
  | ((.context.total_tokens // .context.context_window_size // .context_window.context_window_size // 0) | finite // 0) as $size
  | ($tok > 0 and $size > 0) as $ctx_ok
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
      (active_subagents | if . > 0 then tostring else "" end),
      (.cost.total_usd // .cost.total_cost_usd | finite | if . == null then "" else tostring end),
      (.cost.subagent_usd | finite | if . == null then "" else tostring end),
      (.terminal_width | finite | if . == null then "" else tostring end)
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
agent_count=""
cost=""
subagent_cost=""
json_cols=""

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
      10) agent_count=$value ;;
      11) cost=$value ;;
      12) subagent_cost=$value ;;
      13) json_cols=$value ;;
    esac
  done < <(printf '%s' "$input" | jq -r "$jq_program" 2>/dev/null)
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
    add_segment "  ${CYAN}\$${RESET}${cost_fmt}${sub_seg}" "  \$${cost_fmt}${sub_plain}"
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
