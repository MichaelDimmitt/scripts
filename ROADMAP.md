# ROADMAP — the outstanding work, and how to pick it up

One document, replacing `plan.md`, `plan2.md`, `plan3.md`, `prompt.md` and
`prompt3.md`. It carries three areas of work at different stages, and the
executor prompt for all of them.

**Open items keep their full design. Finished items are compressed to one line
and a sha** — the reasoning behind them lives in the commit and the PR, and
repeating it here only makes the live work harder to find. See
[Done](#done) for what that covers.

---

# How to work on this

You are likely picking this up with **no memory of previous sessions**. This
section is re-read from scratch each time. Everything you need is here or in the
files it names.

Do **one step**, verify it, commit it, stop. Do not batch steps.

## 1. Work out which step is next

Do not assume, and do not trust the [status table](#status) — §5 obliges every
session to leave it current, but a session can crash between the code landing and
the doc catching up, and that gap is exactly when you are reading. Derive the
step from the repo. **The first probe that comes back "not done" in your chosen
area is your step.**

```sh
cd /Users/michaeldimmitt/scripts

# ---- Area 1: repo audit follow-ups ----
grep -c 'SKILL.md' tell/tell_skills.sh        # P1 — 0 means open
grep -c 'check-wiring' justfile               # P2 — 0 means open
ls skill.json 2>/dev/null                     # P3 — existing means open
grep -c 'subagent' resources/extras/context-monitor.sh   # P4 — 0 means open

# ---- Area 2: status line ----
grep -c 'build_rest' resources/extras/statusline-command.sh   # step 5 — 0 means open

# ---- Area 3: install log, changeset, uninstall ----
# A — done when the lib exists AND all four writers call it. Four, not three:
# generate_cask-aliases.sh joined the installer contract in 4ffa324 and writes
# two of the twelve artifacts. install_all.sh is the aggregator and writes none.
ls resources/lib/install_log.sh 2>/dev/null
grep -l 'log_installed' install/install_*.sh generate/generate_cask-aliases.sh | wc -l
grep -c 'install_log' check/check_conventions.sh   # B
ls CHANGESET.md 2>/dev/null                        # G
ls tell/tell_install_log.sh 2>/dev/null            # C
# D+E+F. Do NOT probe for "byte-identical": the tilde assertion added in fefa2ce
# already uses that phrase and would read as done.
ls uninstall/uninstall_all.sh resources/graveyard.tsv 2>/dev/null
grep -c 'uninstall' check/check_install.sh
```

Also check `git log --oneline -8`, which tells you what landed and in what order.

**Two steps are blocked on the user and are not yours to decide:**

- **Area 2 step 4** is not code. It is "does the countdown earn its columns?",
  a judgment only daily use can answer. If step 5 is unbuilt, **stop and ask**.
  The answer may be "delete the countdowns instead" — a real outcome this plan
  anticipates. Do not infer it from elapsed time.
- **Area 3 step A** needs the log location settled ([open decision 1](#open-decisions)).
  If this doc records no answer, **stop and ask**, and offer G meanwhile — it is
  independent of everything and needs no decisions. Do not pick a path yourself:
  it lands on every user's machine and is painful to change later.

If everything in an area is done, say so, run the verification below once to
confirm green, and stop.

## 2. Read before you edit

- **This document's section for your step.** The sketches are illustrative, not
  literal. Read the actual code first; if a sketch conflicts with what is on
  disk, the code wins and you flag the discrepancy.
- `resources/docs/ARCHITECTURE.md` — "The installer contract".
- `resources/lib/next_steps.sh` — read it **whole** before writing any new shared
  library. It is the model: a lib every installer calls, whose contract
  `check_conventions.sh` enforces. Its header explains why it is a file rather
  than a variable, and that reasoning generalises.
- `install/install_statusline.sh` — the one installer that edits a file the user
  owns, and the guards it needed to be allowed to.
- `resources/extras/statusline-command.sh` — for Area 2, read it **whole**. It is
  ~345 densely commented lines and the comments encode design constraints that
  are easy to violate accidentally.

## 3. Constraints that are not negotiable

Violating one silently is worse than not doing the step.

**Everywhere:**

- **No network. No new dependencies.** `jq`, `git`, `shasum` — all already
  present.
- **Match the surrounding comment density.** This repo explains *why*, not
  *what*. A bare edit with no rationale is out of place here.

**Area 2, the status line:**

- **No new forked processes on the render path.** Currently exactly two, `jq` and
  `git`. A `date` inside the *test harness* is fine; that is not the render path.
- **Every field degrades to empty.** No `set -e`, no `set -u`. A missing or
  malformed field drops its own segment and leaves the rest of the bar intact.
- **Absent optional data must render byte-identically to today.** This is the
  strongest regression signal available — assert it.

**Area 3, the log and uninstaller:**

- **The log is append-only.** Never rewrite, compact, sort, or deduplicate the
  file on disk. The design rests on old entries surviving after the path they
  name is abandoned — that is what makes future ghosts self-recording.
  Deduplicate on *read* if you need to.
- **A failed log write must never fail an install.** The log is a side effect,
  not a precondition. A read-only `$HOME` or a full disk degrades to no log entry
  and a working install. An installer that aborts because it could not journal
  itself is worse than one with no log.
- **Never delete a file we do not own.** Eight of the twelve artifacts are edits
  *inside* the user's files. Those are reverted line-by-line or key-by-key, or
  not at all. Deleting one of those files is the catastrophic failure mode.
- **Never delete a containing directory.** `~/.local/bin` may hold the user's own
  binaries; `~/.claude` belongs to Claude Code.
- **Never delete `~/.claude/settings.json.bak`.** Ours by authorship, but it is
  the user's escape hatch from the migration that wrote it — the one deliberate
  exception to "we own it, we remove it". Do not tidy it away as an
  inconsistency.
- **Hash-gate every removal.** Drifted content is reported and left alone.
  "We changed your file after you did" is worse than leaving an orphan.
- **Uninstall is dry-run by default.** `--apply` acts.

## 4. Verify — all of these, every time

```sh
just lint                                       # conventions, then shellcheck
just check-install                              # end-to-end, throwaway $HOME
./resources/extras/statusline-tests/run-tests.sh
```

1. **All green.** At the time of writing: `check-install` 33 passed, statusline
   75 passed.
2. **New assertions actually added.** A step that changes installer behaviour
   without adding a `check_install.sh` case is not done.
3. **Mutation-test anything you assert.** Reintroduce the bug your new check
   describes and confirm the check fails. Not ceremony: in `fefa2ce` the first
   draft of an assertion passed with its own bug restored, and only mutation
   testing caught it. A test that cannot fail is not a test.
4. **Never run an installer against your real `$HOME`.** Use
   `HOME=$(mktemp -d) bash install/install_foo.sh`. `check_install.sh` shows the
   pattern, including `GIT_CONFIG_GLOBAL`, without which
   `install_checkout_release.sh` edits the real `~/.gitconfig`.
5. **Width check, Area 2 only.** The suite cannot catch a width regression, the
   likeliest way these changes go wrong:

```sh
COLUMNS=60  bash resources/extras/statusline-command.sh \
  < resources/extras/statusline-tests/fixtures/full.json; echo
COLUMNS=100 bash resources/extras/statusline-command.sh \
  < resources/extras/statusline-tests/fixtures/full.json; echo
```

Confirm the line does not exceed the width, and that the path — not the usage
numbers — is what gave way.

Report failures with the actual output. Never report a step done that is not.

### A caution about `sed -i` on this file

A `sed -i '' 's|...|...|'` whose replacement text contains unescaped `|`
characters — likely here, since the probes above are pipelines — silently
reparses its own delimiter. One did exactly that while this document was being
written: it corrupted 58 lines and created a garbage file named after the
fragment it could not parse, and `git add -A` committed both. Prefer a Python or
heredoc rewrite, and read back what you edited before staging it.

## 5. Update this document — part of the step, not an afterthought

Do it **before** committing, so it lands in the same commit as the code. A plan
updated in a later commit is a plan that was wrong in between.

1. **The [status table](#status).** Mark your step done and record its sha. If
   you added, split, or dropped a step, change the rows. Then move the item's
   design into [Done](#done) as a single line — that compression is what keeps
   this document about the work that remains.
2. **Any claim your step proved wrong.** Not just field names: sketches that did
   not survive contact with the code, effort estimates off by more than a factor
   of two, edge cases that turned out impossible or turned out to be the only
   case. Correct the text in place and say so in the commit body. This document
   has been wrong before — see [Corrections](#corrections).
3. **Decisions the step resolved.** If [Open decisions](#open-decisions) had it
   and you settled it, write down what you chose and why, then remove it from
   that list. The next session has no memory and will otherwise re-litigate it,
   possibly differently.

Prefer rewriting a claim over appending a note to it — but keep the original
reasoning visible when the *mistake itself* is instructive, marked as corrected
and dated.

**This does not make the table authoritative about progress.** §1 still derives
the next step by probing the repo, and the repo wins on any disagreement.

## 6. Commit and stop

One commit per step, Conventional Commits (`git log --oneline -10` for examples).
End with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Commit only — **do not push and do not open a PR** unless asked.

**Expect a squash merge.** It replaces the sha you committed under, so a sha
written into this document is correct only until it lands. `plan2.md` carried a
scar from exactly this, and PR #20 repeated it. When you record a step's commit
in the status table, record the **squashed** sha from `master`, not the one from
your branch.

Then **stop**. Do not start the next step. Report: which step you completed;
test results as counts, not "all passed", including which mutations proved your
new assertions can fail; what you changed in this document and why — if the
answer is "only the status table", say so explicitly, because it means you found
nothing contradicting the code, which is a finding, not a blank; and what the
next step is and whether it is blocked on the user.

---

# Status

A summary, not the source of truth. Probe the repo (§1); it wins.

| Area | # | Step | State | Commit |
|------|---|------|-------|--------|
| 1 | P1 | `tell_skills.sh` finds no skills | open | — |
| 1 | P2 | nothing checks live config pointing into the repo | **partly done** — see note | — |
| 1 | P3 | `skill.json` is an orphan | open — **decision** | — |
| 1 | P4 | `context-monitor.sh` reads a subagent's context as yours | open | — |
| 2 | 4 | live with the countdowns — do they earn their columns? | **ask the user** | — |
| 2 | 5 | three-tier width ladder | gated on step 4 | — |
| 3 | A | install log library | blocked on [decision 1](#open-decisions) | — |
| 3 | B | enforce the log in `check_conventions.sh` | after A | — |
| 3 | G | `CHANGESET.md` | **unblocked, can go first** | — |
| 3 | C | `just tell-install-log` | after A, B | — |
| 3 | D+E+F | uninstall, graveyard, round-trip test | after A, B, C | — |
| 3 | H | migration runner | deferred | — |

**Cheapest unblocked work right now:** Area 3 G (~20 min), then Area 1 P3 (a
two-minute decision) and P1 (~15 min).

---

# Area 1 — Repo audit follow-ups

From the 2026-08-28 audit, taken while reconciling a diverged `master` and
auditing the README against what was on disk. Every item was verified against
the repo or the machine; none are speculative. P5 (executable bits) is
[done](#done).

## P1 — `tell_skills.sh` reports zero of the 87 real skills

**Verified.** `~/skills` holds 87 `SKILL.md` files. The report lists 8 entries:
`AGENTS.md`, `CLAUDE.md`, `LICENSE`, `mise.toml`, `plugins/`, `PRD.md`,
`README.md`, `test/`.

The cause is a flat `ls` under a heading that says "Skills available" — nothing
about it looks for a skill, and the real skills are nested at
`plugins/<group>/<lang>/skills/<name>/SKILL.md`, which a flat `ls` cannot reach
at any depth.

**Fix.** Replace the `ls` with a `SKILL.md` search, the shape
`tell_installed_skills.sh` already uses:

```sh
find "$repo_path" -name SKILL.md -not -path '*/.git/*' \
  | while read -r f; do basename "$(dirname "$f")"; done | sort -u
```

Worth doing because the script answers its own headline question wrongly and
does so confidently — the failure looks like a populated list, not an error,
which is the kind of output you stop double-checking.

**Effort:** ~15 min, including a check against a flat-layout repo so the fix does
not trade one wrong assumption for another.

## P2 — Nothing checks the live config that points into this repo

**Found the hard way.** Moving `context-monitor.sh` into `resources/extras/`
broke the Stop hook immediately, because `~/.claude/settings.json` referenced the
old path. The move checked that nothing *inside* the repo referenced the script;
it did not check outside it. For a hook script, the config that installs it is
the one referrer guaranteed to exist.

Two scripts are wired into live Claude Code config by two unenforced mechanisms:

| Script | How settings.json reaches it | Failure mode |
| --- | --- | --- |
| `context-monitor.sh` | a path into the repo | breaks loudly when the file moves |
| `statusline-command.sh` | a home-dir copy | never breaks; silently goes stale |

**Partly resolved, and the original was wrong about it.** This plan used to
claim "both are correct right now (the statusline copy is byte-identical to the
repo's)". That was false by 2026-09-08: the installed copy was from Aug 28 and
was missing two merged features. The quiet failure mode had already fired and
nothing reported it. PR #20 fixed the statusline half — the installer now
resolves the configured command to a path, migrates a pointer aimed at an older
copy, and `check_install.sh` covers all of it.

**What remains** is the `context-monitor.sh` half and the general check:

- One line in ARCHITECTURE.md next to the folder description: grep
  `~/.claude/settings.json` before relocating anything under `resources/extras/`.
  Makes it a habit rather than a memory. **2 minutes.**
- A `just check-wiring` target that resolves every `~/scripts/...` path in
  `settings.json` and diffs any home-dir copies against their repo originals.
  **~20 min.**

**Note, surfaced by converging these documents:** `check-wiring` and Area 3's
[C](#c--just-tell-install-log) are the same idea at different scopes — "what on
this machine points at this repo, and is it current?". Build C and P2's check
target becomes a subset of it. Recommend folding P2 into C rather than building
both.

## P3 — `skill.json` is an orphan that would misfire if loaded

**Verified, and still present.** Not referenced by the README, the docs, or the
justfile. It defines a `PreToolUse` gatekeeper on `Edit|Write` rejecting edits
that violate Temporal API and MUI v5 rules, and points the agent at
`temporal-api-standard` or `mui-react-generator` skills. Neither skill exists —
0 matches across `~/.claude` and `~/skills`. It also does not describe this repo:
no React, no TypeScript, no MUI, only shell.

If it were ever loaded it would block edits and then point at documentation that
cannot be found.

**This is a decision, not a task.** Delete it, or document what it is for and
where the skills it names are meant to come from. Two minutes either way, and the
only remaining item that could actively mislead a future reader or agent.

## P4 — `context-monitor.sh` can read a subagent's context as your own

**Verified as latent, not currently biting.** The script sums the usage block of
the last `"type":"assistant"` line in the transcript. Transcript lines carry an
`isSidechain` flag; sidechain lines are subagent turns, carrying token counts
unrelated to the main session's context.

At the time of the audit the session had 113 assistant lines and 0 sidechains, so
last-line and last-main-line agreed exactly. A session ending a turn with subagent
activity would not agree.

**Fix.** One condition in the line filter — skip lines where `isSidechain` is
true. Independent of any threshold question: this is about reading the right
number at all, not about where the bar sits.

**Effort:** ~10 min.

---

# Area 2 — Status line

Steps 1–3 are [done](#done). What is left is a judgment call and the change that
depends on it.

## Step 4 — Live with it. Do the countdowns earn their columns?

**Not code. Ask the user.** The fixtures can tell you a countdown renders
correctly; only daily use tells you whether it is worth its width.

**This became answerable only on 2026-09-08.** Until PR #20 the installed status
line was the Aug 28 copy, which predated the countdown entirely — so the question
had never actually been put to the test, no matter how much time had passed.
Elapsed time since is what counts now, not elapsed time since the feature merged.

A real outcome is "delete them instead", which deletes step 5 rather than
building it.

## Step 5 — Three-tier width ladder

**Gated on step 4.** The only non-additive change in this area.

The countdowns cost ~15 columns on `full.json` (94 vs 79 at `COLUMNS=60`).

**The bar already overran a narrow terminal before they existed** — once the path
is gone, `rest_str` has nothing left to yield and prints whole. The countdowns
made a pre-existing overrun ~15 columns worse rather than creating it. So the
ladder is a fix, not a refinement, **and it has value even if step 4 says the
countdowns are noise.** Weigh that in step 4: the question is not only "are they
useful" but "useful enough to pay the ladder for".

Drop order:

```
percentages  >  path  >  countdowns
```

**Reasoning, for whoever picks this up.** The script header states the usage
numbers are why the bar exists, and a countdown is not a usage number — it
qualifies one. `5h 82%` without a countdown still answers the question;
`5h (1h23m)` without the percentage does not. So countdowns cannot outrank the
percentages. But they must not outrank the path either, because the two fail
differently under the same pressure: a narrow terminal usually means a split
pane, and a split pane usually means several — which is when `dir:` stops being
decoration and becomes how you tell panes apart. Losing a countdown costs a
refinement recoverable by widening for a second. Drop `7d` before `5h`; the
weekly window is the one you rarely act on within a session.

Today `budget` is computed once against a fixed `plain_rest`. Three tiers means
building a *candidate* and retrying:

```sh
# widest first; take the first that fits
for variant in full no_7d_rem no_rem; do
  build_rest "$variant"
  [ $((cols - 5 - ${#plain_rest})) -ge "${#cwd}" ] && break
done
```

Real complexity in the one section that is currently simple arithmetic — not
worth paying before the feature has earned it.

**Effort:** ~30 min. Ships as its own PR. **Merge it without squashing** if the
helper/feature/deflake split is worth reading in `git log`; PR #6 was squashed
and that split now survives only in its description.

---

# Area 3 — Know what we installed, and be able to leave

Three ideas — an install log, a changeset doc, an uninstaller — which are **one
system with a strict dependency order**. Uninstall can only remove what something
recorded. Changesets produce the list of paths we have abandoned. The log is the
substrate under both. **Nothing here is built.**

## The problem, stated exactly

This repo writes **twelve** things into `$HOME` across four writers and has no
record of any of them.

| # | What | Where | Owner | Written by |
|---|------|-------|-------|------------|
| 1 | status line script | `~/.claude/statusline-command.sh` | **us** | `install_statusline.sh` |
| 2 | `statusLine.command` key | `~/.claude/settings.json` | *them* | `install_statusline.sh` (migration only) |
| 3 | settings backup | `~/.claude/settings.json.bak` | **us** | `install_statusline.sh` (migration only) |
| 4 | hand-maintained aliases | `~/.brew-cask-aliases-additional` | **us** | `install_aliases.sh` |
| 5 | `source ~/.brew-cask-aliases-additional` | `~/.zshrc` \| `.bashrc` | *them* | `install_aliases.sh` |
| 6 | generated cask aliases | `~/.brew-cask-aliases` | **us** | `generate_cask-aliases.sh` |
| 7 | `source ~/.brew-cask-aliases` | `~/.zshrc` \| `.bashrc` | *them* | `generate_cask-aliases.sh` |
| 8 | `latest_release` | `~/.local/bin/latest_release` | **us** | `install_checkout_release.sh` |
| 9 | `export PATH="$HOME/.local/bin:$PATH"` | `~/.zshrc` \| `.bashrc` | *them* | `install_checkout_release.sh` |
| 10 | `# no AI was used to install this` | `~/.zshrc` \| `.bashrc` | *them* | `install_checkout_release.sh` |
| 11 | `git()` wrapper block | `~/.zshrc` \| `.bashrc` | *them* | `install_checkout_release.sh` |
| 12 | `alias.checkout-release` | `~/.gitconfig` | *them* | `install_checkout_release.sh` |

Plus ephemeral state at `$TMPDIR/claude-statusline/<session_id>`, and two
**ghosts** — paths a past version wrote and no current version maintains:

| Ghost | Where | Currently handled by |
|-------|-------|----------------------|
| pre-`~/.claude` status line | `~/statusline-command.sh` | `install_statusline.sh` migration, `fefa2ce` |
| `git()` block in the *other* shell's RC | `~/.bashrc` under zsh, or vice versa | a bespoke `if` block, `install_checkout_release.sh:130` |

**The shape of the problem is the Owner column.** Four files are ours and safe to
delete. Eight are edits *inside* files the user owns, where the only correct
removal is surgical — and where deleting the file is exactly what a naive
uninstaller does.

**And the ghost list grows.** It is already two, each costing a hand-written
detection block that exists only because someone remembered to write it. That
does not scale, and a missed one is invisible forever.

## A — The install log

An append-only TSV in `resources/lib/install_log.sh`
(`log_installed`, `log_path`, `log_history`), recording each thing placed on the
machine. Six columns: **timestamp · installer · kind · path · hash · repo sha**.

```
2026-09-08T14:22:07Z  install_statusline  file  /Users/me/.claude/statusline-command.sh  sha256:9f3c2a1b4d5e  fefa2ce
2026-09-08T14:22:07Z  install_aliases     line  /Users/me/.zshrc                          sha256:1a2b3c4d5e6f  4ffa324
```

Four `kind`s, because removal differs per kind and nothing else in the row tells
you how to undo it:

| kind | Meaning | How uninstall reverses it |
|------|---------|---------------------------|
| `file` | a file we created | delete, if the hash still matches |
| `line` | one line appended to their file | remove that line, by content |
| `block` | a multi-line block in their file | remove those lines, by content |
| `key` | a key inside their config | unset it, if the value still matches |

### Append-only is the load-bearing decision

The idea started as "one entry per installer, the last time it was touched."
That cannot work:

> v1 writes `~/statusline-command.sh` and logs it. v2 stops writing that path and
> logs `~/.claude/statusline-command.sh` instead. Under last-entry-wins, the
> record of the old path is **overwritten at the exact moment it becomes a
> ghost.**

Append-only inverts it. v1's line survives, so uninstall finds both paths without
anyone having remembered anything. **Future ghosts become self-recording** — the
single most valuable property here, and it costs one design decision rather than
one `if` block per ghost forever.

### The hash is not optional either

If we abandon `~/.brew-cask-aliases` and the user later writes their own file
there, uninstall must not delete it. Recording the hash at write time makes
removal conditional on the file still being what we left; anything drifted is
**reported, not touched**. With one static path you could hand-wave this; with a
set that grows, you cannot.

`shasum -a 256` truncated to 12 hex chars; handle `sha256sum` for Linux.

### Where it lives — **[open decision 1](#open-decisions)**

**Recommended: `~/.local/state/scripts/installed.tsv`.** XDG-correct (this is
state, not config); a directory we own outright, so uninstall can remove it
wholesale — the log is the one thing that must be able to delete itself; and the
repo already writes `~/.local/bin`, so the tree is not new.

The alternative, `~/.scripts-installed`, matches the `~/.brew-cask-aliases*`
dotfile idiom but adds a fifth dotfile of ours and gives the log no directory.

### Not telemetry

Say so plainly in the file header, because "log" invites the assumption. Written
locally, read locally, never transmitted, removed by `just uninstall`.

**Effort:** ~90 min including wiring four writers.

## B — Enforce the log in `check_conventions.sh`

Every `install/install_*.sh` and `generate_cask-aliases.sh` must source
`install_log.sh` and call `log_installed`. Three `grep -q` checks in the existing
loop.

**Immediately after A, not later.** This is the lesson `check_conventions.sh`
already exists to encode: the installer contract is voluntary in the worst way,
and an author who skips it gets no error and no lint failure. A log with one
installer quietly not calling it is worse than no log, because uninstall then
reports a clean sweep while leaving files behind.

**Effort:** ~20 min.

## C — `just tell-install-log`

`tell/tell_install_log.sh` — what this repo has put on this machine, when, from
which commit, and whether it is current.

A timestamp alone cannot answer staleness: for the four files we copy,
`diff SRC DEST` already answers exactly. What the log uniquely buys is the
**eight rows with nothing to diff against** — an RC line or a settings key is
present-and-matching, drifted, or gone, and only a recorded hash separates those.

```
Installed from this repo                       last write   state
  ~/.claude/statusline-command.sh              2026-09-08   current
  ~/.zshrc  source ~/.brew-cask-aliases        2026-08-14   current
  ~/.zshrc  git() wrapper                      2026-08-14   DRIFTED (edited since)
  ~/.local/bin/latest_release                  2026-08-14   STALE (repo is newer)

Installed at 3b9c535 — master is 12 commits ahead, 2 of them touched install/
```

**Before uninstall, deliberately.** It is read-only, so any gap in what A records
shows up harmlessly here instead of as a file uninstall silently skipped. See
also [P2](#p2--nothing-checks-the-live-config-that-points-into-this-repo), which
this should absorb.

**Effort:** ~45 min.

## D — `just uninstall`

`uninstall/uninstall_all.sh`. A new verb directory; the README naming rules need
a row for it. Dry-run by default, `--apply` to act.

Rules: never delete a file we do not own; never delete a containing directory;
hash-gate every removal; read the **full history**, not the current state, since
that is what collects the ghosts; remove the log last. See
[§3 constraints](#3-constraints-that-are-not-negotiable).

**One generic uninstaller, not one per installer.** Mirroring `install/` would
re-create exactly the per-installer, hand-maintained knowledge the log exists to
kill. The log makes removal data-driven: the uninstaller needs to know how to
reverse four `kind`s and nothing whatsoever about the status line.

**Effort:** ~2 hrs. The one genuinely complex piece.

## E — The graveyard

`resources/graveyard.tsv` — paths written before the log existed, same
`kind`/`path` shape, read alongside the log. Seeded with the two known ghosts.
**This list is closed**: once A ships every future ghost self-records, so it only
ever covers the pre-log era. Without that bound it is the bespoke `if` blocks
again with extra steps. Ships with D. **~15 min.**

## F — The round-trip test

In `check_install.sh`: **install into a throwaway `$HOME`, uninstall, assert
`$HOME` is byte-identical to before.**

**This is what makes the system trustworthy**, and why D and F land in one
commit. It validates A transitively — a missing log entry shows up as a leftover
diff — and D directly. Three cases: the round trip; uninstall on a virgin `$HOME`
is a no-op; uninstall with a drifted file leaves it and reports.

Honest limit: byte-identical proves we removed what we added, not that we added
everything we should have. Only B proves that.

**Effort:** ~45 min, and it will find bugs in D.

## G — `CHANGESET.md`

A doc, not a runner. Timestamped entries, newest first, each answering three
things in this order:

```markdown
## 2026-09-08 — status line moved to ~/.claude

**Affected?** `grep statusLine ~/.claude/settings.json` names a path outside
`~/.claude`, or `~/statusline-command.sh` exists.
**Clean environments can skip this entirely.**

**Fix.** `just install-statusline` — repoints settings.json automatically as of
fefa2ce, keeps a .bak, and names the orphaned copy.
```

**The detector is the product, not the fix.** Most readers are clean, and a
changeset that cannot tell you whether it applies is a doc that goes unread —
hence "Affected?" first. Seed with the two known migrations.

**Unblocked, independent of everything. ~20 min.**

## H — Migration runner — deferred

A `migrations/` directory of `detect()`/`fix()` pairs, auto-run by
`install_all.sh`, recorded in the log so each fires once. **Not yet** — there are
two migrations and both are handled, one inline and one by a note. One migration
does not need machinery; it needs a paragraph, which is G.

When it is built, preserve this distinction — it is why the statusline repair
should *not* move into `migrations/`:

- a **standing correctness check** ("is settings.json still pointing here?") must
  keep running forever, and belongs in the installer
- a **one-time repair** ("rename this file") should fire once and never again

Conflating them is how installers accrete historical repairs that can never fire
on any living machine.

---

# Open decisions

1. **Where the log lives** — `~/.local/state/scripts/installed.tsv`
   (recommended) or `~/.scripts-installed`. **Blocks Area 3 A.**
2. **Does `just uninstall` remove the generated `~/.brew-cask-aliases`?** Ours by
   row 6, but derived from *their* installed casks and possibly relied on.
   Recommend: yes, but name it explicitly in the dry-run rather than burying it.
3. **Does uninstall offer `--keep-config`?** Removing the aliases file while
   leaving the RC line produces a broken shell on next login. Recommend: no —
   partial uninstalls produce a machine nothing can reason about.
4. **Is the uninstaller wanted at all**, or is the plan for it enough? It is ~3
   of Area 3's ~6 hours and all of its risk, and it runs perhaps once ever.
5. **Does anyone besides the author clone this repo?** `statusline-setup.md`
   publishes a `curl` from GitHub. If it is one person's machines, the graveyard
   and changeset work is largely ceremony; if not, it is the point.

---

# Explicitly not doing

**Status line** (from the comparison against popular status lines):

- **Burn rate ($/hr), block timers** — the per-command cost segment already
  answers "am I spending too fast" better, and stacking both spends width on a
  bar that has to fight for it.
- **Lines added/removed, session duration** — low signal; duration is largely
  implied by cost.
- **Powerline / Nerd Font theming, TUI config** — this is what makes ccstatusline
  a product. Adding it here produces a worse version of one and costs the
  property that makes this script worth keeping: you can re-read it in six
  months.
- **Git dirty indicator** — the most-requested missing field, but the only
  candidate that breaks the one-`git`-process discipline. Worth deciding on its
  own merits, not bundled in behind changes that cost nothing.

**Install log and uninstall:**

- **Per-installer uninstall scripts** — re-creates the hand-maintained knowledge
  the log exists to remove.
- **A remote or shared log** — per-machine is correct; the question is what is on
  *this* machine.
- **Recording every read** — the log records writes. An installer that changed
  nothing writes nothing, exactly as `next_steps.sh` prints nothing.

---

# Done

Compressed deliberately. The reasoning lives in the commit and its PR.

| Area | Item | Landed |
|------|------|--------|
| 1 | P5 — executable bits, now enforced by `check_conventions.sh` | `4ec4bdf` (#15) |
| 2 | P2 — reasoning effort indicator next to the model name | `3262d05` (#4) |
| 2 | P0 — `render_rel` test helper, so fixtures cannot go stale | `309675c` (#6) |
| 2 | P1 — rate-limit reset countdown | `309675c` (#6) |
| 3 | — | nothing built |
| — | statusline installer: tilde form, pre-`~/.claude` migration, 10 new checks | `fefa2ce` (#20) |
| — | `just tell-statusline` — the status line legend | `fa97f2c` (#19) |

`render_rel` and the countdown share a sha: PR #6 was squash-merged, collapsing
three commits. The per-step shas this table used to carry, `65d9615` and
`128bff9`, no longer exist on `master` — do not go looking for them.

---

# Corrections

Kept because the mistakes are instructive.

- **2026-09-08 — "both are correct right now".** Area 1 P2 claimed the installed
  status line was byte-identical to the repo's. It was two merged features
  behind, and had been for weeks. The quiet failure mode described in that very
  item had already fired, unnoticed, while the item asserted it had not. A plan
  that verifies a claim once and then keeps asserting it is a plan that goes
  stale in exactly the way it warns about.
- **2026-09-08 — a probe that reported itself done.** The first version of the
  Area 3 D+E+F probe grepped `check_install.sh` for "byte-identical", a phrase
  `fefa2ce` had already introduced for an unrelated assertion. It would have sent
  the next agent straight past the uninstaller. Probes need running before they
  are trusted, against the tree the next reader will see.
- **2026-08-28 — `effort.level` placed under `model`.** It is top-level in the
  status line payload. Verified against the schema, not assumed, only after the
  first version was written from memory.
