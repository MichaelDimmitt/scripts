# Plan: follow-ups from the 2026-08-28 repo audit

Findings surfaced while reconciling the diverged `master`, adopting the two
untracked root scripts, and auditing the README against what is actually on
disk — plus one (P2) that surfaced as a live hook failure caused by that work.
Each item below was verified against the repo or the machine — none are
speculative. Ordered by whether the thing is *wrong* versus merely *untidy*.

---

## P1 — `tell_skills.sh` reports zero of the 87 real skills

**Verified.** `~/skills` contains 87 `SKILL.md` files. The report lists 8
entries: `AGENTS.md`, `CLAUDE.md`, `LICENSE`, `mise.toml`, `plugins/`,
`PRD.md`, `README.md`, `test/`.

Cause is `tell/tell_skills.sh:71`:

```sh
done < <(ls "$repo_path" | grep -v '^\.git$')
```

It lists the repo's top-level directory entries under a heading that says
"Skills available". Nothing about that line looks for a skill. In the current
`~/skills` layout the real skills are nested — `plugins/<group>/<lang>/skills/<name>/SKILL.md` —
so a flat `ls` cannot reach them at any depth.

**Recommendation.** Replace the `ls` with a `SKILL.md` search, the same shape
`tell_installed_skills.sh` already uses:

```sh
find "$repo_path" -name SKILL.md -not -path '*/.git/*' \
  | while read -r f; do basename "$(dirname "$f")"; done | sort -u
```

Worth doing because the script currently answers its own headline question
wrongly, and does so confidently — the failure looks like a populated list, not
an error. That is the kind of output you stop double-checking after a while.

**Effort:** ~15 minutes, including a check against a repo with a flat layout so
the fix does not simply trade one wrong assumption for another.

---

## P2 — Nothing checks the live config that points into this repo

**Found the hard way.** Moving `context-monitor.sh` from the repo root to
`resources/extras/` broke the Stop hook immediately:

```
Stop hook error: bash: /Users/michaeldimmitt/scripts/context-monitor.sh:
No such file or directory
```

`~/.claude/settings.json` referenced the old path. The move checked that nothing
*inside* the repo referenced the script; it did not check outside it. For a hook
script, the config that installs it is the one referrer guaranteed to exist.
Fixed by repointing the hook, with a timestamped `settings.json.bak-*` alongside.

The wider problem is that `resources/extras/` now holds two scripts wired into
live Claude Code config, by two different and equally unenforced mechanisms:

| Script | How settings.json reaches it | Failure mode |
| --- | --- | --- |
| `context-monitor.sh` | `~/scripts/resources/extras/context-monitor.sh` — into the repo | breaks loudly when the file moves |
| `statusline-command.sh` | `~/statusline-command.sh` — a home-dir copy | never breaks; silently goes stale |

Both are correct right now (the statusline copy is byte-identical to the repo's).
That is luck, not a guarantee — the loud one just proved it can break, and the
quiet one is the case `statusline-setup.md` already warns about.

**Recommendation**, cheapest first:

- Grep `~/.claude/settings.json` before relocating anything under
  `resources/extras/`. One line in ARCHITECTURE.md next to the folder
  description is enough to make that a habit rather than a memory.
- Optionally add a `just check-wiring` target that resolves every
  `~/scripts/...` path in `settings.json` and diffs any home-dir copies against
  their repo originals. That catches both failure modes in one command, and is
  the only thing here that would have caught this before the hook fired.

**Effort:** 2 minutes for the note; ~20 for the check target.

---

## P3 — `skill.json` is an orphan that would misfire if loaded

**Verified.** Not referenced by README, the docs, or the justfile. It defines a
`PreToolUse` gatekeeper on `Edit|Write` that rejects edits violating Temporal
API and MUI v5 rules, and instructs the agent to read the
`temporal-api-standard` or `mui-react-generator` skills.

Neither skill exists — 0 matches across `~/.claude` and `~/skills`.

So if this config were ever active, it would block edits and then point the
agent at documentation that cannot be found. It also does not describe this
repo: there is no React, TypeScript, or MUI here, only shell.

**Recommendation.** Decide which of these it is:

- **Leftover from another project** → delete it.
- **A template you keep for reference** → move to `resources/docs/` or
  `resources/extras/` and say what it is for in a comment or README line.
- **Actually intended to be live** → the two skills need to exist first.

Left alone, it is a tripwire: unreferenced config at repo root reads as load-bearing
to anyone (or any agent) that finds it later.

**Effort:** 2 minutes once you decide.

---

## P4 — `context-monitor.sh` can read a subagent's context as your own

**Verified as latent, not currently biting.** The script sums the usage block of
the last `"type":"assistant"` line in the transcript. Transcript lines carry an
`isSidechain` flag; sidechain lines are subagent turns and carry the subagent's
token counts, which are unrelated to the main session's context.

The current session has 113 assistant lines and 0 sidechains, so last-line and
last-main-line agree exactly (91,215 tokens). A session that ends a turn with
subagent activity would not agree.

**Recommendation.** One condition in the line filter — skip lines where
`isSidechain` is true. This is independent of the threshold question below: it
is about reading the right number at all, not about where the bar sits.

**Effort:** ~10 minutes.

---

## P5 — Executable bits are split roughly down the middle

**Verified.** Of 12 scripts, 5 are `755` and 7 are `644`. No pattern —
`tell_skills.sh` and `tell_claude_skills.sh` are executable, `tell_casks.sh` and
`tell_rcs.sh` are not.

Harmless today because every documented invocation is `bash path/to/script.sh`
or a `just` target that does the same. It only bites if someone runs one
directly, which the statusline already proved is easy to hit — hence the
`chmod +x` note in the README.

**Recommendation.** Pick one and apply it repo-wide. `chmod +x` on all of them
is the smaller surprise, and matches the shebangs every script already has. Add
a line to ARCHITECTURE.md's naming conventions so the answer is written down.

**Effort:** 5 minutes.

---

## Considered and deliberately not doing

### Hardening the context-monitor thresholds

`MAX_TOKENS=200000` is inferred rather than measured — the transcript carries
`model: claude-opus-5` but no window size field. `AUTOCOMPACT_AT=167000` is a
guess with nothing in the payload to confirm it.

**Decision: leave as is.** The cost of the guess being wrong is a desktop
notification firing somewhat early or late, and the statusline already shows
`ctx` continuously with colour coding — it is the better instrument, always on
screen. Adding a confidence gate or a tolerance band would be engineering a
precision the tool does not need.

**Revisit if** you ever start treating "it hasn't warned me yet" as permission
to begin something long. At that point the number is load-bearing and needs a
bar under it.

The comment mismatch that made the constants *look* more precise than they are
(comments said 78%/90%, measured against the 167k estimate; the script prints
65%/75%, measured against `MAX_TOKENS`) is already fixed in `37a6eb4`.

### `brew-cask-aliases-additional` living at two paths

README sources it from the repo; `generate_cask-aliases.sh` copies it to
`~/.brew-cask-aliases-additional`, which is what `~/.bashrc:104` actually
sources. Both files exist and are currently byte-identical.

**Decision: documented rather than changed.** Consolidating means either
rewriting the generator or editing your `.bashrc`, and the failure mode — the
home copy going stale — is now called out in the README next to the
`regen-aliases` instruction that fixes it.

---

## Suggested order

P2's one-line note first — it costs nothing and the failure it prevents has
already happened once. Then P3, a two-minute decision and the only remaining
item that could mislead a future reader or agent. Then P1, a real wrong answer
being reported confidently. P4 and P5 are cleanup whenever convenient.
