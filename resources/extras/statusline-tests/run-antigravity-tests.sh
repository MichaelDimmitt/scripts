#!/usr/bin/env bash
# Render statusline-antigravity.sh against test payloads and assert invariants.
#
#   ./run-antigravity-tests.sh                            # test ../statusline-antigravity.sh
#   ./run-antigravity-tests.sh ~/statusline-antigravity.sh # test a specific copy
#   VERBOSE=1 ./run-antigravity-tests.sh                  # also print each rendered line
#
# Exits non-zero if any assertion fails. Requires jq.

set -u

here=$(cd "$(dirname "$0")" && pwd)
script=${1:-$here/../statusline-antigravity.sh}
tmpdir=${TMPDIR:-/tmp}/statusline-antigravity-tests.$$

ESC=$(printf '\033')
pass=0
fail=0

cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

if [ ! -f "$script" ]; then
  printf 'no such script: %s\n' "$script" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required to run these tests\n' >&2
  exit 2
fi

strip_ansi() { sed "s/${ESC}\[[0-9;]*m//g"; }

render_json() { # $1 = json string -> plain status line
  printf '%s' "$1" | bash "$script" 2>/dev/null | strip_ansi
}

render_env_json() { # $1 = env vars, $2 = json string
  eval "$1 printf '%s' \"\$2\"" | bash "$script" 2>/dev/null | strip_ansi
}

ok() { pass=$((pass + 1)); [ -n "${VERBOSE:-}" ] && printf '  ok    %s\n' "$1"; return 0; }
no() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; printf '        got: [%s]\n' "$2"; }

want() { # name, haystack, needle
  case "$2" in
    *"$3"*) ok "$1" ;;
    *) no "$1 (expected to contain '$3')" "$2" ;;
  esac
}

dont() { # name, haystack, needle
  case "$2" in
    *"$3"*) no "$1 (expected NOT to contain '$3')" "$2" ;;
    *) ok "$1" ;;
  esac
}

pct_sane() { # name, haystack
  local bad=""
  local p
  for p in $(printf '%s\n' "$2" | grep -Eo '[0-9]+%' | tr -d '%'); do
    if [ "$p" -gt 100 ]; then bad=$p; fi
  done
  if [ -n "$bad" ]; then
    no "$1 (rendered ${bad}% > 100)" "$2"
  else
    ok "$1"
  fi
}

case_header() {
  printf '%s\n' "$1"
  if [ -n "${VERBOSE:-}" ]; then printf '        [%s]\n' "$2"; fi
}

mkdir -p "$tmpdir"

# --- Test Cases -------------------------------------------------------------

# 1. Full Antigravity payload
payload_full='{
  "workspace": {"current_dir": "/Users/test/project"},
  "vcs": {"branch": "feat/agy", "dirty": false},
  "model": {"display_name": "Gemini 3.8 Flash", "effort": "high"},
  "context": {"input_tokens": 16384, "total_tokens": 1048576},
  "quota": {
    "gemini-weekly": {"remaining_fraction": 0.9378, "reset_in_seconds": 560580}
  },
  "cost": {"total_usd": 0.045, "subagent_usd": 0.012},
  "subagents": [
    {"role": "researcher", "agent_state": "running"},
    {"role": "tester", "agent_state": "active"}
  ]
}'
out=$(render_json "$payload_full")
case_header "full payload" "$out"
want "shows dir"              "$out" "dir: /Users/test/project"
want "shows vcs branch"       "$out" "(feat/agy)"
want "shows model"            "$out" "model: Gemini 3.8 Flash"
want "shows effort"           "$out" "(high)"
want "shows context tokens"   "$out" "ctx 16k/1049k"
want "shows context percent"  "$out" "(1%)"
want "shows weekly quota"     "$out" "weekly 6%"
want "shows quota countdown"  "$out" "(6d11h)"
want "shows 2 subagents"      "$out" "[2 agents]"
want "shows total cost"       "$out" "\$0.04"
want "shows subagent cost"    "$out" "(sub:\$0.01)"
pct_sane "percentages sane"   "$out"

# 2. Single subagent (singular form)
payload_single_agent='{
  "workspace": {"current_dir": "/Users/test/project"},
  "vcs": {"branch": "main", "dirty": false},
  "model": {"display_name": "Gemini 3.8 Pro"},
  "subagents": [
    {"role": "orchestrator", "agent_state": "running"}
  ]
}'
out=$(render_json "$payload_single_agent")
case_header "single subagent" "$out"
want "shows singular agent"   "$out" "[1 agent]"
dont "not plural"             "$out" "[1 agents]"

# 3. No subagents
payload_no_agents='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Gemini 3.8 Flash"},
  "subagents": []
}'
out=$(render_json "$payload_no_agents")
case_header "no subagents" "$out"
dont "omits subagents segment" "$out" "agent"

# 4. Completed subagents only (should be filtered out)
payload_completed_agents='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Gemini 3.8 Flash"},
  "subagents": [
    {"role": "researcher", "agent_state": "completed"},
    {"role": "writer", "status": "done"}
  ]
}'
out=$(render_json "$payload_completed_agents")
case_header "completed subagents" "$out"
dont "omits completed subagents" "$out" "agent"

# 5. Dirty git branch
payload_dirty_git='{
  "workspace": {"current_dir": "/Users/test/project"},
  "vcs": {"branch": "main", "dirty": true},
  "model": {"display_name": "Gemini 3.8 Flash"}
}'
out=$(render_json "$payload_dirty_git")
case_header "dirty git branch" "$out"
want "shows dirty asterisk"   "$out" "(main*)"

# 6. Zero cost
payload_zero_cost='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Gemini 3.8 Flash"},
  "cost": {"total_usd": 0.00}
}'
out=$(render_json "$payload_zero_cost")
case_header "zero cost" "$out"
dont "omits zero cost"        "$out" "\$"

# 7. Git fallback when .vcs is omitted
payload_git_fallback='{
  "workspace": {"current_dir": "'"$here"'"},
  "model": {"display_name": "Gemini 3.8 Flash"}
}'
out=$(render_json "$payload_git_fallback")
case_header "git fallback" "$out"
want "still detects git branch" "$out" "("

# 8. Non-git directory
nongit=$tmpdir/nongit
mkdir -p "$nongit"
payload_nongit='{
  "workspace": {"current_dir": "'"$nongit"'"},
  "model": {"display_name": "Gemini 3.8 Flash"}
}'
out=$(render_json "$payload_nongit")
case_header "non-git directory" "$out"
want "reports no git"         "$out" "no git"

# 9. Narrow terminal width budgeting (COLUMNS=50)
payload_narrow='{
  "workspace": {"current_dir": "/Very/Long/Path/To/A/Workspace/Directory"},
  "vcs": {"branch": "very-long-feature-branch-name-123456", "dirty": false},
  "model": {"display_name": "Gemini 3.8 Flash"}
}'
out=$(COLUMNS=50 render_json "$payload_narrow")
case_header "narrow terminal width" "$out"
dont "drops long dir path to preserve right metrics" "$out" "dir: /Very/Long/Path"
want "preserves git branch"   "$out" "very-long-feature-branch"

# 10. Payload terminal_width field
out=$(render_json '{"workspace": {"current_dir": "/Long/Path/Workspace"}, "terminal_width": 40, "model": {"display_name": "Flash"}}')
case_header "payload terminal_width" "$out"
dont "drops dir when payload terminal_width is tight" "$out" "dir: /Long"

# 11. Missing jq: degrades gracefully
sandbox=$tmpdir/nojq-bin
mkdir -p "$sandbox"
if git_bin=$(command -v git); then ln -sf "$git_bin" "$sandbox/git"; fi
out=$(PATH="$sandbox" /bin/bash "$script" <<< "$payload_full" 2>/dev/null | strip_ansi)
case_header "jq unavailable" "$out"
want "still shows dir"        "$out" "dir:"
if [ -n "$out" ]; then ok "produces output"; else no "produces output" "$out"; fi

# 12. Session state: context accumulation across tool calls
session_tmp=$tmpdir/agy-state-test
export AGY_STATUSLINE_STATE_DIR=$session_tmp
turn1='{"conversation_id": "test-conv-1", "context": {"input_tokens": 4096, "total_tokens": 1048576}, "cost": {"total_usd": 0.02}}'
turn2_tool='{"conversation_id": "test-conv-1", "context": {"input_tokens": 3072, "total_tokens": 1048576}, "cost": {"total_usd": 0.04}}'
out1=$(render_json "$turn1")
out2=$(render_json "$turn2_tool")
case_header "accumulated context during tool call" "$out2"
want "turn 1 shows 4k"       "$out1" "ctx 4k/1049k"
want "turn 2 preserves 4k"    "$out2" "ctx 4k/1049k"
dont "turn 2 does not drop"   "$out2" "ctx 3k/1049k"
want "turn 2 shows turn cost delta" "$out2" "+\$0.02"
want "turn 2 shows total cost"      "$out2" "\$0.04"

# 13. Session reset on new conversation_id (/clear)
turn_new_conv='{"conversation_id": "test-conv-2", "context": {"input_tokens": 1024, "total_tokens": 1048576}, "cost": {"total_usd": 0.01}}'
out3=$(render_json "$turn_new_conv")
case_header "session reset on new conversation (/clear)" "$out3"
want "new session resets context" "$out3" "ctx 1k/1049k"
dont "does not carry over 4k"     "$out3" "ctx 4k/1049k"

# 14. Quota with explicit used_percentage and short countdown
payload_quota_used='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Gemini 3.8 Flash"},
  "quota": {
    "weekly": {"used_percentage": 25, "reset_in_seconds": 7200}
  }
}'
out=$(render_json "$payload_quota_used")
case_header "quota with used_percentage and hours countdown" "$out"
want "shows weekly 25%"       "$out" "weekly 25%"
want "shows 2h countdown"     "$out" "(2h0m)"

# 15. Quota absent or empty (omits segment)
payload_no_quota='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Gemini 3.8 Flash"},
  "quota": {}
}'
out=$(render_json "$payload_no_quota")
case_header "empty quota" "$out"
dont "omits quota segment"    "$out" "weekly"
dont "omits generic quota"    "$out" "quota"

# 16. Dual Gemini quotas (gemini-5h + gemini-weekly alongside unused 3p-5h)
payload_gemini_dual='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Gemini 3.8 Flash (High)", "effort": "high"},
  "quota": {
    "3p-5h": {"remaining_fraction": 1, "reset_in_seconds": 17924},
    "3p-weekly": {"remaining_fraction": 1, "reset_in_seconds": 604724},
    "gemini-5h": {"remaining_fraction": 0.55271, "reset_in_seconds": 13151},
    "gemini-weekly": {"remaining_fraction": 0.9241483, "reset_in_seconds": 599951}
  }
}'
out=$(COLUMNS=200 render_json "$payload_gemini_dual")
case_header "dual gemini quota" "$out"
want "shows 5h quota"         "$out" "5h 44%"
want "shows 5h countdown"     "$out" "(3h39m)"
want "shows weekly quota"     "$out" "weekly 7%"
want "shows weekly countdown" "$out" "(6d22h)"
dont "does not show 3p-5h"    "$out" "3p-5h"

# 17. 3p model quota selection
payload_3p_model='{
  "workspace": {"current_dir": "/Users/test/project"},
  "model": {"display_name": "Claude 3.7 Sonnet"},
  "quota": {
    "3p-5h": {"remaining_fraction": 0.8, "reset_in_seconds": 7200},
    "3p-weekly": {"remaining_fraction": 0.9, "reset_in_seconds": 86400}
  }
}'
out=$(COLUMNS=200 render_json "$payload_3p_model")
case_header "3p model quota" "$out"
want "shows 3p-5h label"      "$out" "3p-5h 20%"
want "shows 3p-5h countdown"  "$out" "(2h0m)"
want "shows 3p-weekly label"  "$out" "3p-weekly 10%"
want "shows 3p-weekly countdown" "$out" "(1d0h)"

printf '\nstatusline-antigravity.sh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1


