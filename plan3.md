# Plan: know what we installed, and be able to leave

Three ideas raised on 2026-09-08 — an install log, a changeset doc, an uninstall
script — which on inspection are **one system with a strict dependency order**.
Uninstall can only remove what something recorded. Changesets are what produce
the list of paths we have abandoned. The log is the substrate under both.

This plan proposes the whole thing for evaluation. Nothing here is built yet.

---

## The problem, stated exactly

This repo writes **eleven** things into `$HOME`, across four installers, and has
no record of any of them. Two more are already orphaned.

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

Plus ephemeral state at `$TMPDIR/claude-statusline/<session_id>`, and the two
**ghosts** — paths a past version wrote and no current version maintains:

| Ghost | Where | Currently handled by |
|-------|-------|----------------------|
| pre-`~/.claude` status line | `~/statusline-command.sh` | `install_statusline.sh` migration (as of `fefa2ce`) |
| `git()` block in the *other* shell's RC | `~/.bashrc` under zsh, or vice versa | a bespoke `if` block, `install_checkout_release.sh:130` |

**The shape of the problem is the split in the Owner column.** Four files are
ours and safe to delete. Eight are edits *inside* files the user owns, where the
only correct removal is surgical — and where deleting the file would be
catastrophic and is exactly what a naive uninstaller does.

**And the ghost list grows.** It is already two. Each one currently costs a
hand-written detection block that exists only because someone remembered to
write it. That does not scale, and a missed one is invisible forever.

---

## A — The install log

**What.** An append-only TSV, written by every installer through a shared
library, recording each thing placed on the machine.

```
resources/lib/install_log.sh        # log_installed, log_path, log_history
```

```
2026-09-08T14:22:07Z  install_statusline  file  /Users/me/.claude/statusline-command.sh  sha256:9f3c2a1b4d5e  fefa2ce
2026-09-08T14:22:07Z  install_aliases     line  /Users/me/.zshrc                          sha256:1a2b3c4d5e6f  4ffa324
2026-09-08T14:22:08Z  install_checkout    key   ~/.gitconfig#alias.checkout-release       sha256:7e8f9a0b1c2d  4ffa324
```

Six columns: **timestamp · installer · kind · path · hash · repo sha**.

Four `kind`s, because removal differs per kind and nothing else about the row
tells you how to undo it:

| kind | Meaning | How uninstall reverses it |
|------|---------|---------------------------|
| `file` | a file we created | delete, if the hash still matches |
| `line` | one line appended to their file | remove that line, by content |
| `block` | a multi-line block in their file | remove those lines, by content |
| `key` | a key inside their config | unset that key, if the value still matches |

### Append-only is the load-bearing decision

The original framing was "one entry per installer, the last time it was
touched." That version cannot work, and the reason is worth stating precisely:

> v1 writes `~/statusline-command.sh` and logs it. v2 stops writing that path and
> logs `~/.claude/statusline-command.sh` instead. Under last-entry-wins, the
> record of the old path is **overwritten at the exact moment it becomes a
> ghost.**

Append-only inverts that. v1's line stays in the file, so uninstall on that
machine finds both paths without anyone having remembered anything. **Future
ghosts become self-recording** — which is the single most valuable property in
this plan, and it costs one design decision rather than one `if` block per ghost
forever.

Readers get both views: `log_path` for the current state of a path (last entry
wins), `log_history` for everything ever written.

### The hash is not optional either

If we abandon `~/.brew-cask-aliases` and the user later writes their own file
there, uninstall must not delete it. Recording the content hash at write time
means removal is conditional on the file still being what we left. Anything that
drifted gets **reported, not touched**. With one static path you could hand-wave
this; with a set that grows, you cannot.

`shasum -a 256`, truncated to 12 hex chars. Present on macOS by default; note in
the code that Linux may need `sha256sum` and handle both.

### Where it lives

**Recommended: `~/.local/state/scripts/installed.tsv`.**

- XDG-correct: this is *state*, not config, and not something the user edits.
- A directory we own outright, so uninstall can remove it wholesale rather than
  surgically — the log is the one thing that must be able to delete itself.
- The repo already writes `~/.local/bin`, so the tree is not new.

The alternative, `~/.scripts-installed`, matches the existing
`~/.brew-cask-aliases*` dotfile idiom but adds a fifth dotfile of ours to a home
directory and gives the log no directory of its own. **Open for your call.**

### Not telemetry

Worth saying plainly in the file header, because "log" invites the assumption:
it is written locally, read locally, never transmitted, and removed by
`just uninstall`. Nothing in this repo makes a network call and this does not
change that.

**Effort:** ~90 min — the library, plus wiring four installers.

---

## B — Enforce the log in `check_conventions.sh`

**What.** Extend the installer contract: every `install/install_*.sh` (and
`generate_cask-aliases.sh`, which joined the contract in `4ffa324`) must source
`install_log.sh` and call `log_installed`.

**Why it lands immediately after A, not later.** This is the exact lesson
`check_conventions.sh` already exists to encode, in its own words:

> the installer contract is voluntary in the worst way ... An author who writes
> `echo "source ~/.zshrc"` instead gets no error, no lint failure, and no block

A log with one installer quietly not calling it is worse than no log, because
uninstall then reports a clean sweep while leaving files behind. The contract
has to be mechanical from the start. The rule is three `grep -q` checks in the
existing loop.

**Effort:** ~20 min.

---

## C — `just tell-install-log`

**What.** `tell/tell_install_log.sh` — what this repo has put on this machine,
when, from which commit, and whether it is still current.

This is the payoff of the original idea: staleness at a glance. Note that a
timestamp alone cannot answer it — for the four files we copy, `diff SRC DEST`
already answers exactly, which is what `install_statusline.sh`'s
`SKIP: already current` branch does. What the log uniquely buys is the **eight
rows that have nothing to diff against**: an RC line or a settings key is either
present-and-matching, drifted, or gone, and only a recorded hash can tell those
apart.

```
$ just tell-install-log

Installed from this repo                       last write   state
  ~/.claude/statusline-command.sh              2026-09-08   current
  ~/.zshrc  source ~/.brew-cask-aliases        2026-08-14   current
  ~/.zshrc  git() wrapper                      2026-08-14   DRIFTED (edited since)
  ~/.local/bin/latest_release                  2026-08-14   STALE (repo is newer)

Installed at 3b9c535 — master is 12 commits ahead, 2 of them touched install/
  Run: just install-all
```

**Why it precedes uninstall in the order.** It is read-only. It forces the log
to answer real questions before anything bets a deletion on the answers, and any
gap in what A records shows up here harmlessly instead of as a file uninstall
silently skipped.

**Effort:** ~45 min.

---

## D — `just uninstall`

**What.** `uninstall/uninstall_all.sh`. A new verb directory, consistent with the
naming rules in the README, which will need a row for it.

**Dry-run by default.** `just uninstall` prints what it would do; `just uninstall
--apply` does it. This is the repo's existing posture — `install_statusline.sh`
reports rather than edits, and only crossed that line for one key, under guards —
and the destructive script is the last place to abandon it.

### Rules

1. **Never delete a file we do not own.** RC files, `settings.json`, `.gitconfig`
   are edited surgically or not at all.
2. **Never delete a containing directory.** `~/.local/bin` may hold the user's
   own binaries; `~/.claude` belongs to Claude Code, not to us.
3. **Hash-gate every removal.** Drifted content is reported and left. "We changed
   your file after you did" is a worse outcome than an orphan.
4. **Read the full history, not the current state** — that is what collects the
   ghosts.
5. **Remove the log last**, and its state directory with it.

### One generic uninstaller, not one per installer

Tempting to mirror `install/` with `uninstall_statusline.sh` and friends. That
would re-create precisely the problem the log exists to kill: per-installer
knowledge, hand-maintained, drifting out of sync with what the installers
actually write. The log makes removal **data-driven** — the uninstaller needs to
know how to reverse four `kind`s, and nothing whatsoever about the status line.

**Effort:** ~2 hrs. The one genuinely complex piece.

---

## E — The graveyard

**What.** `resources/graveyard.tsv` — paths written before the log existed, in
the same `kind`/`path` shape, read by uninstall alongside the log.

Seeded with exactly the two known ghosts. **This list is closed.** Once A ships,
every future ghost self-records, so the graveyard only ever covers the pre-log
era. Without that bound it would be the bespoke `if` blocks again with extra
steps.

Ships with D.

**Effort:** ~15 min.

---

## F — The round-trip test

**What.** In `check_install.sh`:

> install into a throwaway `$HOME`, uninstall, assert `$HOME` is **byte-identical**
> to before.

**This is the assertion that makes the whole system trustworthy**, and the reason
D and F must land in the same commit. It validates A transitively: if the log is
missing anything, the leftover shows up as a diff. It validates D directly: if
uninstall removes a line it did not write, the RC file differs.

Three cases:

| Case | Asserts |
|------|---------|
| install → uninstall | `$HOME` byte-identical to before install |
| uninstall on a virgin `$HOME` | no-op, no errors, touches nothing |
| uninstall with a drifted file | file survives, drift is reported |

The harness for this already exists — `make_home`, `run_install`, `TMPROOT`.

Note the honest limit: a byte-identical `$HOME` proves we removed what we added,
not that we added everything we should have. Only B proves that.

**Effort:** ~45 min, and it will find bugs in D.

---

## G — `CHANGESET.md`

**What.** A doc, not a runner. Timestamped entries, newest first, each answering
three questions in this order:

```markdown
## 2026-09-08 — status line moved to ~/.claude

**Affected?** `grep statusLine ~/.claude/settings.json` names a path outside
`~/.claude`, or `~/statusline-command.sh` exists.
**Clean environments can skip this entirely.**

**Fix.** `just install-statusline` — repoints settings.json automatically as of
fefa2ce, keeps a .bak, and names the orphaned copy.
```

**The detector is the product, not the fix.** Most readers are clean, and a
changeset that cannot tell you whether it applies to you is a doc that goes
unread. "Affected?" comes first for that reason.

Seeded with the two known migrations. Independent of everything else here — it
can land at any point, and should land early while the status line one is fresh.

**Effort:** ~20 min.

---

## H — Migration runner — deferred

A `migrations/` directory of `detect()`/`fix()` pairs, auto-run by
`install_all.sh`, recorded in the log so each fires once.

**Not yet.** There are two migrations, and both are already handled — one inline,
one by a note. One migration does not need machinery; it needs a paragraph, which
is G. Revisit when a third appears, at which point the log is already there to
record what has been applied.

There is also a distinction to preserve when this does get built, and it is the
reason the statusline repair should *not* move into `migrations/` when it does:

- a **standing correctness check** — "is settings.json still pointing here?" —
  must keep running forever, and belongs in the installer
- a **one-time repair** — "rename this file" — should fire once and never again,
  and belongs in a migration

Only the second kind belongs in `migrations/`. Conflating them is how installers
accrete historical repairs that can never fire on any living machine.

---

## Order

Dependency-forced for the most part; where there was a choice, the cheap and
read-only work goes first, and the one irreversible piece goes last behind a test
that can prove it.

**Status.** Kept current as each step lands, but treat it as a summary, not the
source of truth — `prompt3.md` derives the next step by probing the repo, and the
repo wins if these ever disagree.

| # | Step | Depends on | Effort | State | Commit |
|---|------|-----------|--------|-------|--------|
| 1 | **A** — install log library, wired into 4 installers | — | ~90 min | next — **blocked on open decision 1** | — |
| 2 | **B** — enforce it in `check_conventions.sh` | A | ~20 min | not started | — |
| 3 | **G** — `CHANGESET.md` | — | ~20 min | not started — **unblocked, can go first** | — |
| 4 | **C** — `just tell-install-log` | A, B | ~45 min | not started | — |
| 5 | **D + E + F** — uninstall, graveyard, round-trip test | A, B, C | ~3 hrs | not started | — |
| — | **H** — migration runner | — | — | deferred | — |

Why each step sits where it does:

- **A** is the substrate; nothing else works without it.
- **B** follows immediately because a voluntary log rots on the first installer
  that forgets to call it.
- **G** is independent of all of it — land it while the statusline migration is
  still fresh in someone's memory.
- **C** uses the log read-only, so any gap in what A records surfaces harmlessly.
- **D+E+F** is the only step that deletes anything, and goes last, behind a test
  that can prove it.

Steps 1–4 are additive and reversible. Step 5 is the only one that deletes
anything, and it is sequenced last on purpose: by then the log has been proven
readable by C and complete by B.

**G is unblocked and can be done at any time** — including first, if you want
something to look at before committing to the rest.

---

## Open decisions

1. **Log location** — `~/.local/state/scripts/installed.tsv` (recommended) or
   `~/.scripts-installed`.
2. **Does `just uninstall` remove the generated `~/.brew-cask-aliases`?** It is
   ours by row 6, but it is also derived from *their* installed casks and may be
   something they now rely on. Recommend: yes, remove it, but name it explicitly
   in the dry-run rather than burying it in a list.
3. **Does uninstall offer `--keep-config`?** Removing the aliases file but
   leaving the RC line produces a broken shell on next login. Recommend: no such
   flag — partial uninstalls are how you get a machine in a state nothing can
   reason about.

## Explicitly not doing

- **Per-installer uninstall scripts.** See D — re-creates the hand-maintained
  per-installer knowledge the log exists to remove.
- **A remote or shared log.** Per-machine is correct: the whole question is what
  is on *this* machine.
- **Recording every read.** The log records writes. An installer that changed
  nothing writes nothing, exactly as `next_steps.sh` prints nothing.
- **Migration runner (H)** until there is a third migration.

## Verification

Per step: `just lint` and `just check-install`, which is where the new assertions
land. Step 5 additionally must show the round-trip test failing when a log entry
is deliberately removed — a test that cannot fail is not a test, which is how the
tilde assertion in `fefa2ce` was caught passing under its own bug.
