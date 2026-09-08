# Prompt: execute the next step of plan3.md

You are picking up an in-progress plan with **no memory of previous sessions**.
This file is re-read from scratch each time, after a context reset. Everything
you need is here or in the files it names.

Do **one step**, verify it, commit it, stop. Do not batch steps.

The work: this repo writes twelve things into `$HOME` and has no record of any of
them, so it cannot tell you what is stale and cannot uninstall itself. `plan3.md`
proposes a log, a changeset doc, and an uninstaller. You are building one piece.

---

## 0. Find the plan first

`plan3.md` is on `master` as of `fefa2ce` (PR #20). Confirm it before anything
else — if you are on a branch that predates it, you are reading a stale executor.

```sh
cd /Users/michaeldimmitt/scripts
ls plan3.md || git log --all --oneline -- plan3.md
```

Do not re-derive the plan from this file — this file is the executor, `plan3.md`
is the design, and it holds detail this one deliberately omits.

**Branch off `master`, and expect your work to be squash-merged.** That matters
here because both documents cite commits by sha: a squash replaces the sha you
committed under, so any sha you write into the plan is correct only until it
lands. `plan2.md` carries a scar from exactly this. When you record a step's
commit in the status table, record the **squashed** sha from `master` after the
PR merges, not the one from your branch.

---

## 1. Work out which step is next

Do not assume. Do not trust this file or `plan3.md` to have been updated — §5
obliges every session to leave the plan current, but a session can crash or be
interrupted between the code landing and the plan catching up, and that gap is
exactly when you are reading. Determine the step from the repo, in this order —
the first unchecked probe is your step:

```sh
cd /Users/michaeldimmitt/scripts

# Step 1 (A, install log library) — done when the lib exists AND all four
# writers call it. Four, not three: generate_cask-aliases.sh joined the
# installer contract in 4ffa324 and writes two of the twelve artifacts.
# install_all.sh is excluded — it is the aggregator and writes nothing.
ls resources/lib/install_log.sh 2>/dev/null
grep -l 'log_installed' install/install_*.sh generate/generate_cask-aliases.sh | wc -l

# Step 2 (B, enforce it) — done if this matches:
grep -c 'install_log' check/check_conventions.sh

# Step 3 (G, changeset doc) — done if this exists:
ls CHANGESET.md 2>/dev/null

# Step 4 (C, tell-install-log) — done if this exists:
ls tell/tell_install_log.sh 2>/dev/null

# Step 5 (D+E+F, uninstall) — all three, one commit.
# Do NOT probe for "byte-identical": the tilde assertion added in fefa2ce
# already uses that phrase, so it would read as step 5 being done.
ls uninstall/uninstall_all.sh resources/graveyard.tsv 2>/dev/null
grep -c 'uninstall' check/check_install.sh
```

A count of `0` means not done. Also check `git log --oneline -8` for
`feat(log)` / `feat(uninstall)` commits, which tell you what landed and in what
order.

**Step 1 is blocked on a decision that is not yours.** `plan3.md` §Open
decisions #1 asks where the log lives — `~/.local/state/scripts/installed.tsv`
(recommended) or `~/.scripts-installed`. If the plan does not record an answer,
**stop and ask the user**, and offer to do step 3 (G) meanwhile — it is
independent of every other step and needs no decisions. Do not pick a location
yourself: it is a path that ends up on every user's machine and is painful to
change once written.

If every step is done: say so, run `just lint` and `just check-install` once to
confirm green, and stop.

---

## 2. Read before you edit

- `plan3.md` — the step's own section has the rationale, the shape, and the
  constraints. **The sketches are illustrative, not literal.** Read the actual
  code before applying them; if a sketch conflicts with what is on disk, the code
  wins and you flag the discrepancy.
- `resources/docs/ARCHITECTURE.md` — "The installer contract", which is the
  thing you are extending.
- `resources/lib/next_steps.sh` — read it **whole** before writing
  `install_log.sh`. It is the closest existing analogue: a shared library every
  installer calls, whose contract is enforced by `check_conventions.sh`. Its
  header explains why it is a file rather than a variable, and the same reasoning
  applies to you. Match its shape.
- `install/install_statusline.sh` — the one installer that already edits a file
  the user owns, and the guards it needed to be allowed to.

### Constraints that are not negotiable

Violating one silently is worse than not doing the step:

- **The log is append-only.** Never rewrite, compact, sort, or deduplicate the
  file on disk. The whole design rests on old entries surviving after the path
  they name is abandoned — that is what makes future ghosts self-recording.
  Deduplicate on *read* if you need to.
- **A failed log write must never fail an install.** The log is a side effect,
  not a precondition. A read-only `$HOME`, a full disk, or a missing directory
  degrades to no log entry and a working install — the same way every field in
  the status line degrades to empty. An installer that aborts because it could
  not journal itself is a worse tool than one with no log at all.
- **Never delete a file we do not own.** Eight of the twelve artifacts are edits
  *inside* the user's files (`~/.zshrc`, `settings.json`, `.gitconfig`). Those
  are reverted line-by-line or key-by-key, or not at all. Deleting one of those
  files is the catastrophic failure mode of this entire plan.
- **Never delete a containing directory.** `~/.local/bin` may hold the user's own
  binaries. `~/.claude` belongs to Claude Code, not to us.
- **Never delete `~/.claude/settings.json.bak`.** It is row 3 of the inventory
  and it is ours by authorship, but it is the user's escape hatch from the
  migration that wrote it. It is the one deliberate exception to "we own it, we
  remove it" — do not tidy it away as an inconsistency.
- **Hash-gate every removal.** Drifted content is reported and left alone.
  "We changed your file after you did" is worse than leaving an orphan.
- **Uninstall is dry-run by default.** `--apply` acts. This repo reports rather
  than edits; the destructive script is the last place to abandon that.
- **No network. No new dependencies.** `jq`, `git`, `shasum` only — all already
  present. The log is local, never transmitted, and removed by `just uninstall`.
  Say so in the file header; "log" invites the wrong assumption.
- **Match the surrounding comment density.** This repo explains *why*, not
  *what*. A bare edit with no rationale is out of place here.

---

## 3. Do the step

Follow the plan section. If you hit something the plan did not anticipate:

- **A wrong factual claim in the plan** — the artifact inventory, a line number,
  a tool's availability — verify against the actual repo or shell, fix the plan
  text as part of your commit, and say so. The inventory in `plan3.md` was
  compiled by grepping the installers; treat it as a good-faith list, not a
  guarantee, and re-derive it if your step depends on it being complete.
- **A design decision the plan left open** — stop and ask. Do not invent one.
- **A step that turns out bigger than its stated effort** — finish it anyway if
  it is genuinely one step; split it and ask if it is really two. Step 5 is
  already three items in one commit and is the likeliest to want splitting —
  but D and F must not be separated. Uninstall without its round-trip test is
  the dangerous version.

---

## 4. Verify — all of these, every time

```sh
just lint            # check-conventions, then shellcheck every script
just check-install   # end-to-end, throwaway $HOME
```

1. **Both green.** `check-install` was at 33 passed when this plan was written.
2. **New assertions actually added.** A step that changes installer behaviour
   without adding a `check_install.sh` case is not done.
3. **Mutation-test anything you assert.** Reintroduce the bug your new check
   describes and confirm the check fails. This is not optional ceremony: in
   `fefa2ce` the first draft of a new assertion passed with its own bug restored,
   and only mutation testing caught it. A test that cannot fail is not a test.
4. **Never run an installer against your real `$HOME` to test it.** Use a
   throwaway: `HOME=$(mktemp -d) bash install/install_foo.sh`. `check_install.sh`
   does this and shows the pattern, including `GIT_CONFIG_GLOBAL`, without which
   `install_checkout_release.sh` edits the real `~/.gitconfig`.

For step 5 specifically, the round-trip is the assertion that matters: install
into a throwaway `$HOME`, uninstall, assert `$HOME` is byte-identical to before.

Report failures with the actual output. Never report a step done that is not.

### A caution about `sed -i` on these files

Writing this file cost one self-inflicted wound worth passing on. A
`sed -i '' 's|...|...|'` whose *content* contained unescaped `|` characters —
likely here, since every probe above is a pipeline — silently reparsed the
delimiter, corrupted 58 lines of the file it was editing, and left behind a
garbage file named after the fragment it could not parse. `git add -A` then
committed both.

Prefer a Python or heredoc rewrite over `sed -i` for these documents, and read
back what you edited before staging it.

---

## 5. Update the plan — part of the step, not an afterthought

`plan3.md` must leave your session describing the repo as it now is. Do this
**before** committing, so it lands in the same commit as the code — a plan
updated in a later commit is a plan that was wrong in between.

Three things to bring current:

1. **The status table** in the plan's `## Order` section. Mark your step done and
   record its commit sha. If you added, split, or dropped a step, change the rows.
2. **Any claim your step proved wrong.** Especially the twelve-artifact inventory
   — if you find a thirteenth, or find that one of the twelve is not actually
   written any more, correct the table and say so. That inventory is what
   uninstall is built against; a wrong row there becomes a file left behind.
3. **Decisions the step resolved.** The `## Open decisions` section has three.
   When one is settled, write the answer and the reasoning into the plan and
   remove it from that list. The next session has no memory and will otherwise
   re-litigate it, possibly differently.

When you correct something, prefer rewriting the claim over appending a note to
it — but keep the original reasoning visible when the *mistake itself* is
instructive, marked as corrected and dated.

**This does not make the plan authoritative about progress.** Section 1 still
derives the next step by probing the repo, and the repo still wins on any
disagreement.

---

## 6. Commit and stop

One commit per step, matching the repo's Conventional Commits style
(`git log --oneline -10` for examples):

```
feat(log): record what each installer places on the machine
feat(check): make the install log contract enforceable
feat(uninstall): remove what we installed, and nothing else
docs(changeset): record the migrations a dirty machine needs
```

End with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Commit only — **do not push**, and do not open a PR, unless the user asks.

Then **stop**. Do not start the next step. Report:

- which step you completed
- test results (counts, not "all passed"), including which mutations you ran to
  prove the new assertions can fail
- what you changed in `plan3.md` and why — including the status table. If the
  answer is "only the status table", say that explicitly; it means you found
  nothing in the plan that contradicted the code, which is a finding, not a
  blank. Never leave this line out.
- what the next step is, and whether it is blocked on the user

---

## Reference — the steps

Full detail in `plan3.md`; this is orientation only.

| # | Step | Where | Effort |
|---|------|-------|--------|
| 1 | **A** — install log library | `resources/lib/install_log.sh` + 4 writers | ~90 min |
| 2 | **B** — enforce the contract | `check/check_conventions.sh` | ~20 min |
| 3 | **G** — changeset doc | `CHANGESET.md` | ~20 min |
| 4 | **C** — read the log | `tell/tell_install_log.sh` | ~45 min |
| 5 | **D+E+F** — uninstall, graveyard, round-trip | `uninstall/`, `resources/graveyard.tsv`, `check/check_install.sh` | ~3 hrs |
| — | **H** — migration runner | deferred until a third migration exists | — |

Step 5 is the only one that deletes anything. It is sequenced last so that by
the time it runs, the log has been proven readable by step 4 and proven complete
by step 2.

Step 3 is unblocked and depends on nothing. If step 1 is waiting on the user,
do step 3.
