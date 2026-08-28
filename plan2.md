# Plan: two additions to the status line

Follow-up to the 2026-08-28 comparison of `resources/extras/statusline-command.sh`
against the popular Claude Code status lines (see the comparison tables in the
[README](./README.md#how-it-compares-to-the-popular-status-lines)). That review
produced six candidate features across three tiers. This plan covers the two in
Tier 1 — the ones that add information without changing the script's cost profile
— plus the test-harness change one of them depends on.

Both are **jq-side only**. Neither forks a process, neither touches the network,
and neither changes the render path. That is the whole reason they sort above the
rest: the git dirty indicator (Tier 2) was the next most useful field but is the
only candidate that breaks the one-`git`-process discipline, so it is deliberately
not here.

Field names below were verified against the
[status line schema](https://code.claude.com/docs/en/statusline), not assumed.

---

## P0 — `render_rel` test helper (prerequisite for P1)

**What.** Let rate-limit fixtures store `resets_in` (seconds from now) instead of
an absolute `resets_at`, and have the runner convert it at render time.

**Why this is not optional.** A fixture with a fixed future epoch does not break
when it goes stale — it *passes wrongly*. A file named `resets-future.json` whose
timestamp has quietly drifted into the past starts asserting the past-timestamp
behaviour under a name that says the opposite. That is the same failure class as
P1 in [plan.md](./plan.md): output that looks populated rather than erroring, the
kind you stop double-checking. Cheaper to prevent than to discover.

### Implementation

Leave `render()` alone and add a sibling to
`resources/extras/statusline-tests/run-tests.sh`:

```sh
# Fixtures store resets_at as seconds-from-now so they cannot go stale;
# convert to absolute epoch at render time.
render_rel() { # $1 = payload file -> plain (ANSI-stripped) status line
  jq --argjson now "$(date +%s)" \
    '(.rate_limits[]? | select(.resets_in != null))
     |= (.resets_at = $now + .resets_in | del(.resets_in))' "$1" \
  | bash "$script" 2>/dev/null | strip_ansi
}
```

Only the new rate-limit fixtures use `resets_in`. The existing eight stay
byte-identical and keep using `render()` — that containment is the point. The one
`date` fork lives in the harness, where forks do not matter.

**Effort:** ~10 minutes.

---

## P1 — Rate-limit reset countdown

**What.** Append a remaining-time hint to the existing usage segments:

```
5h 82% (1h23m)      7d 44% (2d4h)
```

**Why this one first.** `5h 82%` tells you how much you have spent but not
whether to keep going. Eighty-two percent with twelve minutes left on the window
and eighty-two percent with four hours left call for opposite decisions, and the
bar currently cannot distinguish them. It is the largest information gain
available for the smallest change.

**Schema.** `rate_limits.five_hour.resets_at` and `rate_limits.seven_day.resets_at`,
both **Unix epoch seconds**. Confirmed in the docs field table.

### Implementation

Two extra fields on the existing jq program — the contract grows from 11 lines to
13. Get "now" from **jq's own `now` builtin**, floored to seconds:

```jq
(now | floor) as $n
```

**Corrected 2026-08-28.** This section previously said to read bash's
`$EPOCHSECONDS` and pass it in with `--argjson`, mirroring `$state`. That does
not work on this machine and would have shipped a feature that never renders —
see the bash 3.2 note under Edge cases. `now` costs no extra process (jq already
runs), needs no bash version floor, and removes the degradation path entirely
rather than guarding it. Verified: `jq 'now|floor'` returns the same epoch as
`date +%s`, and works inside a `def`.

A `remaining` filter alongside the existing `pct` and `show` helpers:

```jq
def remaining($now):
  finite
  | if . == null or . <= $now then null
    else (. - $now) as $s
    | if $s >= 86400 then "\($s / 86400 | floor)d\($s % 86400 / 3600 | floor)h"
      elif $s >= 3600 then "\($s / 3600 | floor)h\($s % 3600 / 60 | floor)m"
      else "\($s / 60 | floor)m" end
    end;
```

Two units, never three: `2d4h`, `1h23m`, `47m`. Three units is more precision than
a glanceable bar can carry, and the segment has to stay short enough to survive
the width budget.

Rendering slots into `add_segment` next to the existing percentage, guarded so an
absent countdown leaves today's output byte-identical:

```sh
five_rem_seg=""
[ -n "$five_rem" ] && five_rem_seg=" (${five_rem})"
```

### Edge cases

- **`resets_at` in the past.** Returns null rather than a negative duration. This
  matters more than it looks: the docs state Claude Code *drops a window once its
  `resets_at` passes*, so a stale payload is the realistic path to a past
  timestamp, and the honest render is no countdown at all.
- **`resets_at` absent, `used_percentage` present.** Show the percentage alone.
  Each window is independently optional per the schema.
- **bash 3.2** (stock macOS) — **resolved by using jq's `now`; no longer an edge
  case.** Recorded because the original framing was wrong in a way worth not
  repeating. This section used to call bash 3.2 an edge case handled by guarding
  `${EPOCHSECONDS:-}` and passing `0`, on the reasoning that `remaining` would
  then return null for every window and degrade to exactly today's output — which
  is true, and which the script's "every field degrades to empty" header endorses.
  But on this machine `/bin/bash` **and** the bash on `PATH` are both
  3.2.57, so there is no bash 5 anywhere: that "degraded" path was the *only*
  path. The countdown would have landed green, passed its whole suite, and
  displayed nothing — and step 4 asks a human whether the countdowns earn their
  columns, a judgment impossible to make about something that never renders.
  Correct degradation of a field nobody can see is not degradation, it is a
  no-op wearing its costume. Hence `now`.
- **Interaction with the `pct` clamp.** The clamp exists because upstream bug
  \#52326 can leak the `resets_at` epoch into `used_percentage`. This change reads
  the field the clamp was written to defend against, so **keep the clamp** — it
  guards the percentage, not the countdown, and the bug it documents is still live.

### Width

Adds roughly 8–9 columns per window, ~17 total. **Measured after landing:** 15
columns on `full.json` with both countdowns (94 vs 79 at `COLUMNS=60`).

**Measured, and it sharpens step 5.** The bar already overran a narrow terminal
before this change: at `COLUMNS=60`, `full.json` rendered 79 columns, because once
the path is gone `rest_str` has nothing left to yield and is printed whole. The
countdowns take that to 94. This is not a regression — same behaviour, more of it
— but it means the ladder in step 5 is not a refinement, it is the fix for a
pre-existing overrun that the countdowns make ~15 columns worse. Worth weighing in
step 4: the question is not only "are the countdowns useful" but "useful enough to
pay the ladder for", and the ladder has value even if the answer is no.

**Land P1 with the countdowns load-bearing** — i.e. inside `rest_str`, where the
path degrades first, exactly as everything right of `dir:` does today. No change
to the fitting logic in this step.

**Then, only if the countdowns prove useful in daily use** (see P3), move them to
their own tier. The eventual drop order should be:

```
percentages  >  path  >  countdowns
```

Reasoning, for whoever picks this up: the script header states the usage numbers
are why the bar exists, and a countdown is not a usage number — it qualifies one.
`5h 82%` without a countdown still answers the question; `5h (1h23m)` without the
percentage does not. So countdowns cannot outrank the percentages. But they should
not outrank the path either, because the two fail differently under the same
pressure: a narrow terminal usually means a split pane, and a split pane usually
means several — which is when `dir:` stops being decoration and becomes how you
tell panes apart. Losing a countdown costs a refinement recoverable by widening
for a second. Drop 7d before 5h; the weekly window is the one you rarely act on
within a session.

This is deferred because it is the only part of this plan that is not additive.
Today `budget` is computed once against a fixed `plain_rest`; three tiers means
building a *candidate* line and retrying:

```sh
# widest first; take the first that fits
for variant in full no_7d_rem no_rem; do
  build_rest "$variant"
  [ $((cols - 5 - ${#plain_rest})) -ge "${#cwd}" ] && break
done
```

That is real complexity in the one section that is currently simple arithmetic —
not worth paying before the feature has earned it. If the countdowns turn out to
be noise, this step is deleted rather than built.

### Tests

Extend `resources/extras/statusline-tests/`:

- **Corrected 2026-08-28.** This list said "`full.json` — add `resets_at` to both
  windows; assert both countdowns render." Both windows already *had* `resets_at`,
  and both epochs are fixed dates now ~15 months past, so they render no countdown
  — the assertion would have failed, and "adding" the field was a no-op. Worse,
  had they been future epochs when written they would have been the exact stale-
  fixture trap P0 exists to prevent. So the positive assertions live in a new
  relative fixture instead, and `full.json` is untouched: it is the shared base for
  the cost-sequence, no-jq and no-session cases, and switching it to `resets_in`
  would drag `render_rel` into six call sites for no gain.
- New `resets-relative.json` — both windows future via `resets_in`; assert
  `5h 23% (1h23m)` and `7d 41% (2d4h)`, covering both the h/m and d/h branches.
- New `resets-past.json` — `resets_in` negative; assert percentage renders and
  no countdown, no negative number, no stray `()`.
- New `resets-imminent.json` — `resets_in` of a few seconds. This is the boundary
  where "expires between renders" lives, and the only case that exercises the
  transition the `remaining` filter guards. **Resolved:** under a minute renders
  `(0m)`, not nothing. The plan left this open; `0m` is the honest reading, since
  the window has not reset yet and dropping the countdown would claim it had.
- New `resets-missing.json` — `used_percentage` without `resets_at`; assert the
  segment matches today's output exactly.
- `five-only.json`, `no-ratelimits.json` — assert unchanged (regression guard).
  Note `five-only.json`'s epoch is also past, so "unchanged" means "renders no
  countdown" — which is what makes it a usable guard.
- `leaked-epoch.json` — assert the clamp still suppresses the bogus percentage,
  **and** that reading `resets_at` for the countdown does not put the leaked epoch
  back on the bar by the other door.

**One existing case had to change.** `render_rel`'s self-check compared its output
against `render "$fixtures/full.json"`. That equality held only while `resets_at`
changed nothing about the output; with the countdown it compares "a future
countdown" against "a past epoch's absent one" and fails. It now builds an
absolute twin from the same offset, which is what the case was always meant to
isolate — the conversion, not the feature.

These fixtures depend on a `render_rel` helper in the runner — build that first
(P0 below), so they are written against it the first time.

**Effort:** ~45 minutes including fixtures.

---

## P2 — Reasoning effort indicator

**What.** `model: Opus 5 (high)`

**Why.** Effort level materially changes both cost and latency, which is what the
two numbers already on the bar measure. When a `+$0.42` command lands, whether the
session was on `high` or `max` is the first thing that explains it. It is also the
cheapest item in the whole comparison — one field, one array slot, no new logic.

**Schema — one correction worth flagging.** The field is **`effort.level`,
top-level in the payload — not nested under `model`**. Values: `low`, `medium`,
`high`, `xhigh`, `max`. It is **absent when the current model does not support the
effort parameter**, so it is optional, not guaranteed. Also per the docs:
`ultracode` is not a distinct level and reports as `xhigh`, and the field reflects
mid-session `/effort` changes — so it can legitimately differ between two renders
in one session. Nothing to handle there; just do not cache it.

### Implementation

One more line on the jq contract:

```jq
(.effort.level // "")
```

and at render:

```sh
model_seg=""
if [ -n "$model" ]; then
  model_seg="  model: $model"
  [ -n "$effort" ] && model_seg="$model_seg ($effort)"
fi
```

Deliberately plain: no colour and no abbreviation. The existing colour vocabulary
is green/yellow/red for *approaching a limit*, and effort is not a limit —
colouring it would overload a signal that currently means one thing.

### Edge cases

- **`effort` absent** (model without the parameter) — renders exactly as today.
- **`model` absent but `effort` present** — no `model:` segment, so no orphaned
  `(high)` floating on the bar. The nesting above handles this.
- **Unexpected value.** Rendered as-is. It is a display string, never compared or
  branched on, so a new level added upstream degrades to showing it verbatim
  rather than breaking.

### Width

~7 columns. Same path-first degradation.

### Tests

- `full.json` — add `effort.level`; assert `(high)` renders after the model name.
- `no-model.json` — add an `effort` block with no model; assert no orphaned
  parenthetical.
- New `no-effort.json` — model present, `effort` absent; assert byte-identical to
  today's model segment.

**Effort:** ~15 minutes.

---

## Order

Numbered by priority above; execute in this order, which is not the same thing.
The principle: land the cheap parts first, and sequence the one genuinely complex
piece last and behind a real usage signal.

**Status.** Kept current as each step lands, but treat it as a summary, not the
source of truth — `prompt.md` derives the next step by probing the repo, and the
repo wins if these ever disagree. Steps are not PRs; see
[How this ships](#how-this-ships) for where the review boundaries fall.

| # | Step | State | Commit |
|---|------|-------|--------|
| 1 | P2 — effort indicator | done | `3262d05` |
| 2 | P0 — `render_rel` helper | done | `65d9615` |
| 3 | P1 — reset countdown | done | `128bff9` |
| 4 | Live with it — human call | next — **ask the user** | — |
| 5 | Three-tier width ladder | gated on 4 | — |

1. **P2 — effort indicator** (~15 min). Despite being second on value. It touches
   the jq contract and the `model_seg` construction — the same two sites P1
   touches, but in their simplest form. Landing it first means the contract has
   already grown by one optional field, and the tests already cover one, before P1
   adds duration arithmetic.
2. **P0 — `render_rel` helper** (~10 min). Before P1's fixtures exist, so they are
   written against it rather than retrofitted.
3. **P1 — reset countdown** (~45 min), countdowns load-bearing in the existing
   width ladder. No fitting-logic changes. Landed as specified; the sketches for
   `remaining`, the jq contract and `five_rem_seg` all survived contact with the
   code unchanged. Only the test list needed correcting — see P1's Tests section.
4. **Live with it for a few days.** The fixtures cannot tell you whether a
   countdown is worth its columns; only using it can.
5. **Three-tier drop order** — the `percentages > path > countdowns` ladder in
   P1's width section. Only if step 4 says the countdowns earned it. This is the
   sole non-additive change in the plan, and deferring it means it either gets
   built with evidence or gets deleted.

All of this lands before any Tier 2 work. Git dirty state is the most-requested
missing field, but it costs a second `git` process against an explicit design
constraint — worth deciding on its own merits, not bundled in behind changes that
cost nothing.

## How this ships

**One PR per user-visible feature.** That is what this repo already does: PRs #3,
#4 and #5 each landed a single status-line feature with its script change, its
fixtures and its tests together, as one reviewable unit. Scaffolding and docs went
in direct — `f4f2be0` (this plan) and `3fd4e7e` (`plan.md`) carry no PR number.

So the steps in the table above do **not** map one-to-one onto PRs:

| Steps | Ships as |
|-------|----------|
| 1 (P2, effort) | its own PR — merged as #4 |
| 2 + 3 (`render_rel` + countdown) | **one PR**, opened at the end of step 3 |
| 5 (width ladder) | its own PR, if step 4 says build it |

**Why 2 and 3 travel together.** Step 2 landed a test helper whose only caller
today is its own self-check, plus a correction to how step 3 gets the time. On its
own that PR reads as "a helper for a feature that does not exist yet" — there is
nothing to review, because the question a reviewer cares about (does the countdown
work, is it worth its columns) is not in the diff. Alongside P1 the same commits
read as one coherent change: helper, fix, feature. Holding them also avoids a
rebase, since step 3 will touch `render_rel`'s neighbourhood when it adds the
countdown fixtures.

Keep them as separate *commits* either way — the split is worth reading in
`git log`; it is only the review boundary that is wrong.

**Per `prompt.md`, no session opens a PR on its own.** Steps get committed, not
pushed. Opening the PR is a human call, and for the step-2+3 bundle the moment is
after step 3 is green — not before.

## Explicitly not doing

From the comparison, ranked and rejected:

- **Burn rate ($/hr), block timers** — ccusage's answer to "am I spending too
  fast." The per-command cost segment already answers that better, and stacking
  both spends width on a bar that has to fight for it.
- **Lines added/removed, session duration** — low signal; duration is largely
  implied by cost.
- **Powerline / Nerd Font theming, TUI config** — this is what makes ccstatusline
  a product. Adding it here produces a worse version of one, and costs the
  property that makes this script worth keeping: you can re-read it in six months.

## Verification

After each item:

```sh
./resources/extras/statusline-tests/run-tests.sh
```

And render against a live session at a few terminal widths — the fixtures cannot
catch a width regression, which is the most likely way either of these goes wrong
in practice. That gap is also what step 4 of the order is for: the suite can tell
you the countdown renders correctly, but not whether it is worth its columns.
