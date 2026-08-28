#!/usr/bin/env bash
# Render statusline-command.sh against fixture payloads and assert invariants.
#
#   ./run-tests.sh                     # test ../statusline-command.sh
#   ./run-tests.sh ~/statusline-command.sh   # test a specific copy
#   VERBOSE=1 ./run-tests.sh           # also print each rendered line
#
# Exits non-zero if any assertion fails. Requires jq (same as the script).

set -u

here=$(cd "$(dirname "$0")" && pwd)
script=${1:-$here/../statusline-command.sh}
fixtures=$here/fixtures
tmpdir=${TMPDIR:-/tmp}/statusline-tests.$$

# The per-command cost segment remembers the previous render on disk. Point that
# state at the throwaway dir so a test run neither reads a real session's history
# nor leaves anything behind for the next run to trip over.
export CLAUDE_STATUSLINE_STATE_DIR=$tmpdir/state

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

# --- helpers ----------------------------------------------------------------

strip_ansi() { sed "s/${ESC}\[[0-9;]*m//g"; }

render() { # $1 = payload file -> plain (ANSI-stripped) status line
  bash "$script" < "$1" 2>/dev/null | strip_ansi
}

# A fixture holding an absolute future `resets_at` does not fail when it goes
# stale -- it passes wrongly, asserting past-timestamp behaviour under a name
# that says the opposite. So rate-limit fixtures store `resets_in`, seconds from
# now, and this converts it to the absolute epoch the script expects, at render
# time. Negative values are the point too: -60 is always "a minute ago".
#
# The `date` fork is fine here -- the no-forks rule covers the render path, and
# this is the harness. Only fixtures that carry `resets_in` need this; the rest
# keep using render(), and that containment is deliberate.
render_rel() { # $1 = payload file -> plain (ANSI-stripped) status line
  jq --argjson now "$(date +%s)" \
    '(.rate_limits[]? | select(.resets_in != null))
     |= (.resets_at = $now + .resets_in | del(.resets_in))' "$1" \
  | bash "$script" 2>/dev/null | strip_ansi
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

# No rendered percentage may exceed 100 — catches the leaked-epoch class of bug
# wherever it appears, not just in the fixture that reproduces it.
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

# --- cases ------------------------------------------------------------------

mkdir -p "$tmpdir"

out=$(render "$fixtures/full.json")
case_header "full payload" "$out"
want "shows model"            "$out" "model: Opus"
want "shows effort level"     "$out" "model: Opus (high)"
want "shows context tokens"   "$out" "ctx 16k/200k"
want "shows context percent"  "$out" "(8%)"
want "shows 5h floored"       "$out" "5h 23%"
want "shows 7d floored"       "$out" "7d 41%"
want "shows session cost"     "$out" "\$0.01"
pct_sane "percentages sane"   "$out"

out=$(render "$fixtures/no-ratelimits.json")
case_header "free tier (no rate_limits)" "$out"
dont "omits 5h"               "$out" "5h"
dont "omits 7d"               "$out" "7d"
want "still shows context"    "$out" "ctx"
want "shows cost"             "$out" "\$0.50"

out=$(render "$fixtures/null-usage.json")
case_header "null current_usage (pre-first-call / post-compact)" "$out"
dont "omits context segment"  "$out" "ctx"
dont "omits zero cost"        "$out" "\$"
want "still shows dir"        "$out" "dir:"

out=$(render "$fixtures/leaked-epoch.json")
case_header "leaked epoch in used_percentage (upstream #52326)" "$out"
dont "drops the epoch value"  "$out" "1785312000"
dont "drops the bad 5h window" "$out" "5h"
want "keeps the good 7d window" "$out" "7d 41%"
pct_sane "percentages sane"   "$out"

out=$(render "$fixtures/missing-ctx-size.json")
case_header "context_window_size absent" "$out"
dont "no divide-by-zero denominator" "$out" "/0k"
want "still shows 5h"         "$out" "5h 10%"

out=$(render "$fixtures/five-only.json")
case_header "only five_hour present" "$out"
want "shows 5h at zero"       "$out" "5h 0%"
dont "omits 7d"               "$out" "7d"
want "handles 1M context"     "$out" "/1000k"

out=$(render "$fixtures/high-usage.json")
case_header "near-limit values" "$out"
want "floors 99.6 to 99"      "$out" "5h 99%"
dont "never rounds up to 100" "$out" "5h 100%"
want "shows 7d"               "$out" "7d 72%"
want "shows ctx percent"      "$out" "(91%)"
want "shows larger cost"      "$out" "\$12.35"
pct_sane "percentages sane"   "$out"

out=$(render "$fixtures/no-model.json")
case_header "no model block" "$out"
dont "omits model label"      "$out" "model:"
# The fixture carries an effort level with nothing to attach it to; without a
# model name there must be no parenthetical left floating on the bar.
dont "no orphaned effort"     "$out" "(high)"
want "still shows 5h"         "$out" "5h 60%"

# A model without the effort parameter omits the field, and the segment must
# come out byte-identical to what it was before effort existed.
out=$(render "$fixtures/no-effort.json")
case_header "model without an effort level" "$out"
want "shows the bare model"   "$out" "model: Haiku 4.5  "
dont "no empty parenthetical" "$out" "()"
want "still shows 5h"         "$out" "5h 15%"

# render_rel's own self-check. The countdown itself does not exist yet, so this
# asserts only the conversion: a relative fixture must reach the script as a
# normal payload and render exactly as its absolute twin does. Without this the
# helper is untested until the fixtures that depend on it arrive.
jq '.rate_limits.five_hour |= (.resets_in = 3600 | del(.resets_at))' \
  "$fixtures/full.json" > "$tmpdir/relative.json"
out=$(render_rel "$tmpdir/relative.json")
case_header "render_rel converts resets_in to an epoch" "$out"
want "renders the whole line"  "$out" "5h 23%"
dont "no resets_in leaks out"  "$out" "3600"
if [ "$out" = "$(render "$fixtures/full.json")" ]; then
  ok "matches the absolute-epoch render"
else
  no "matches the absolute-epoch render" "$out"
fi

# Non-git directory: the branch field must not leak a placeholder.
mkdir -p "$tmpdir/plain"
sed "s#__DIR__#$tmpdir/plain#" > "$tmpdir/non-git.json" <<'JSON'
{
  "cwd": "__DIR__",
  "model": { "display_name": "Opus" },
  "workspace": { "current_dir": "__DIR__" }
}
JSON
out=$(render "$tmpdir/non-git.json")
case_header "non-git directory" "$out"
dont "no 'detected' placeholder" "$out" "detected"
want "reports no git"         "$out" "no git"

# jq unavailable: the bar must degrade to directory and git info, not vanish.
# PATH is sandboxed to a directory holding only git, so jq cannot be found.
# (Note: recent macOS ships /usr/bin/jq, so simply dropping homebrew from PATH
# is not enough to exercise this path.)
sandbox=$tmpdir/nojq-bin
mkdir -p "$sandbox"
if git_bin=$(command -v git); then ln -sf "$git_bin" "$sandbox/git"; fi
out=$(cd "$here" && PATH="$sandbox" /bin/bash "$script" < "$fixtures/full.json" 2>/dev/null | strip_ansi)
case_header "jq unavailable" "$out"
want "still prints a directory" "$out" "dir:"
dont "omits usage segments"   "$out" "5h"
if [ -n "$out" ]; then ok "produces output"; else no "produces output" "$out"; fi

# Narrow terminal: the whole line must fit inside COLUMNS.
out=$(COLUMNS=60 bash "$script" < "$fixtures/no-model.json" 2>/dev/null | strip_ansi)
case_header "narrow terminal (COLUMNS=60)" "$out"
if [ "${#out}" -le 60 ]; then
  ok "fits in 60 columns (${#out})"
else
  no "exceeds 60 columns (${#out})" "$out"
fi
want "keeps the usage segments" "$out" "5h 60%"

# Per-command cost. The segment is inferred from how the session total moves
# between renders, so each assertion below is about a *sequence* of renders, not
# a single payload -- hence a helper rather than a fixture file.
turn() { # session id, session total -> plain rendered line
  jq --arg s "$1" --argjson c "$2" \
    '.session_id = $s | .cost.total_cost_usd = $c' \
    "$fixtures/full.json" > "$tmpdir/turn.json"
  render "$tmpdir/turn.json"
}

out=$(turn turn-a 0.05)
case_header "per-command cost: first render" "$out"
dont "adopts a baseline, claims nothing" "$out" "+\$"
want "still shows the total"  "$out" "\$0.05"

out=$(turn turn-a 0.10)
case_header "per-command cost: total rose" "$out"
want "reports what the command cost" "$out" "+\$0.05"
want "sits to the left of the total" "$out" "+\$0.05  \$0.10"

out=$(turn turn-a 0.10)
case_header "per-command cost: idle render" "$out"
want "holds the last command's cost" "$out" "+\$0.05"

out=$(turn turn-a 0.13)
case_header "per-command cost: next command" "$out"
want "measures from the idle total" "$out" "+\$0.03"

out=$(turn turn-a 0.16)
case_header "per-command cost: same command continues" "$out"
want "accumulates rather than resets" "$out" "+\$0.06"

# A tool-heavy command can add a fraction of a cent. "+$0.00" is noise.
out=$(turn turn-b 0.50)
out=$(turn turn-b 0.503)
case_header "per-command cost: sub-cent command" "$out"
dont "hides a sub-cent command" "$out" "+\$0.00"

# Resuming an old session shows a large total on the very first render; that
# history belongs to no single command and must not be attributed to one.
out=$(turn turn-c 12.34)
case_header "per-command cost: resumed session" "$out"
dont "does not claim the backlog" "$out" "+\$"
want "still shows the total"  "$out" "\$12.34"

# No session_id: nothing to key state by. Degrade to the total alone.
jq 'del(.session_id)' "$fixtures/full.json" > "$tmpdir/no-session.json"
out=$(render "$tmpdir/no-session.json")
case_header "per-command cost: no session_id" "$out"
dont "omits the per-command segment" "$out" "+\$"
want "renders everything else"  "$out" "5h 23%"

# --- summary ----------------------------------------------------------------

printf '\n%s: %d passed, %d failed\n' "$(basename "$script")" "$pass" "$fail"
[ "$fail" -eq 0 ]
