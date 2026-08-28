# Prompt: execute the next step of plan2.md

You are picking up an in-progress plan with **no memory of previous sessions**.
This file is re-read from scratch each time, after a context reset. Everything
you need is here or in the files it names.

Do **one step**, verify it, commit it, stop. Do not batch steps.

---

## 1. Work out which step is next

Do not assume. Do not trust this file to have been updated. Determine it from the
repo, in this order — the first unchecked probe is your step:

```sh
cd /Users/michaeldimmitt/scripts

# Step 1 (P2, effort indicator) — done if this matches:
grep -c 'effort' resources/extras/statusline-command.sh

# Step 2 (P0, render_rel helper) — done if this matches:
grep -c 'render_rel' resources/extras/statusline-tests/run-tests.sh

# Step 3 (P1, reset countdown) — done if this matches:
grep -c 'remaining' resources/extras/statusline-command.sh

# Step 5 (three-tier width ladder) — done if this matches:
grep -c 'build_rest' resources/extras/statusline-command.sh
```

A count of `0` means not done. Also check `git log --oneline -8` for
`feat(statusline)` / `test(statusline)` commits, which tell you what landed and
in what order.

**Step 4 is not code.** It is "live with it for a few days" — a human judgment
call about whether the countdown earns its columns. If steps 1–3 are done and
step 5 is not, **stop and ask the user** whether the countdowns have proved
useful. Do not decide this yourself, do not infer it from elapsed time, and do
not skip to step 5. Their answer may be "delete them instead" — that is a real
outcome the plan anticipates.

If every step is done: say so, run the test suite once to confirm green, and stop.

---

## 2. Read before you edit

- `plan2.md` — the step's own section has the implementation sketch, edge cases,
  and test list. **The sketches are illustrative, not literal.** Read the actual
  code before applying them; if a sketch conflicts with what is on disk, the code
  wins and you flag the discrepancy.
- `resources/extras/statusline-command.sh` — read it **whole** before editing. It
  is ~290 lines and densely commented, and the comments encode design constraints
  that are easy to violate accidentally.
- `resources/extras/statusline-tests/run-tests.sh` and `fixtures/`.

### Constraints that are not negotiable

These are the reason the script is worth keeping. Violating one silently is worse
than not doing the step:

- **No new forked processes on the render path.** Currently exactly two: `jq` and
  `git`. Steps 1 and 3 are jq-side only and must stay that way. (`date` inside the
  *test harness* is fine — that is not the render path.)
- **No network calls. No new dependencies.** `jq` and `git` only.
- **Every field degrades to empty.** No `set -e`, no `set -u`. A missing or
  malformed field drops its own segment and leaves the rest of the bar intact.
  Never let one absent field take down the line.
- **Absent optional data must render byte-identically to today.** This is the
  strongest regression signal available — assert it.
- **Match the surrounding comment density.** This script explains *why*, not
  *what*. A bare edit with no rationale is out of place here. Explain any
  non-obvious choice the way the neighbouring code does.

---

## 3. Do the step

Follow the plan section. If you hit something the plan did not anticipate:

- **A wrong factual claim in the plan** (field name, type, bash builtin
  availability) — verify against
  https://code.claude.com/docs/en/statusline or the actual shell, fix the plan
  text as part of your commit, and say so. The plan has been wrong before: it
  originally placed `effort.level` under `model`, and that was corrected.
- **A design decision the plan left open** — stop and ask. Do not invent one.
- **A step that turns out bigger than its stated effort** — finish it anyway if
  it is genuinely one step; split it and ask if it is really two.

---

## 4. Verify — all three, every time

```sh
./resources/extras/statusline-tests/run-tests.sh
```

1. **Suite green.** Every fixture, not just the new ones.
2. **New fixtures actually added** per the step's test list in `plan2.md`. A step
   is not done without them.
3. **Width check.** The suite cannot catch a width regression, which is the most
   likely way these changes go wrong. Render manually at a narrow width:

```sh
COLUMNS=60 bash resources/extras/statusline-command.sh \
  < resources/extras/statusline-tests/fixtures/full.json; echo
COLUMNS=100 bash resources/extras/statusline-command.sh \
  < resources/extras/statusline-tests/fixtures/full.json; echo
```

Confirm the line does not exceed the width and that the path — not the usage
numbers — is what gave way.

Report failures with the actual output. Never report a step done that is not.

---

## 5. Commit and stop

One commit per step, matching the repo's Conventional Commits style
(`git log --oneline -10` for examples):

```
feat(statusline): show reasoning effort next to the model name
test(statusline): convert rate-limit fixtures to relative resets_in
```

End with a `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` trailer.
Commit only — **do not push**, and do not open a PR, unless the user asks.

Then **stop**. Do not start the next step. Report:

- which step you completed
- test results (counts, not "all passed")
- anything you changed in `plan2.md` and why
- what the next step is, and whether it is blocked on the user

---

## Reference — the five steps

Full detail in `plan2.md`; this is orientation only.

| # | Step | Where | Effort |
|---|------|-------|--------|
| 1 | **P2** — reasoning effort indicator | `statusline-command.sh` (jq contract + `model_seg`) | ~15 min |
| 2 | **P0** — `render_rel` test helper | `run-tests.sh` | ~10 min |
| 3 | **P1** — rate-limit reset countdown | `statusline-command.sh` (jq contract + segments) | ~45 min |
| 4 | **Live with it** — does the countdown earn its columns? | — **human call, ask the user** | days |
| 5 | **Three-tier width ladder** | `statusline-command.sh` (fitting logic) | ~30 min |

Step 5 is the only non-additive change in the plan and is **gated on step 4**. It
may end in deleting the countdowns rather than building the ladder.
