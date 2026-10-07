---
name: session-index
description: Summarize past Claude Code sessions in a project into a SESSIONS.md index — an append-only table of one-line session summaries plus a paragraph describing the project. Use when the user asks to index sessions, summarize past chats/sessions, catch up on what a project has been about, or asks "what have I been doing in this repo".
---

# Session Index

Builds and maintains `SESSIONS.md` in a project: an append-only table of
one-line summaries of past Claude Code sessions, plus a short paragraph
describing what the project is and where the work has been heading.

Reads the session transcripts Claude Code already keeps in
`~/.claude/projects/<slugged-path>/*.jsonl`.

## When to invoke

- "index the sessions here" / "summarize my past sessions"
- "what have I been working on in this repo"
- Returning to a project after time away and wanting the history in one place

Do **not** run this unprompted. It costs one `claude -p` call per unindexed
session, and the user should be choosing to spend that.

## How to run

Always start with a dry run so the user knows the cost before anything is spent:

```sh
python3 ~/.claude/skills/session-index/session_index.py --dry-run
```

That prints how many sessions are unindexed. Report the count, then run:

```sh
python3 ~/.claude/skills/session-index/session_index.py
```

Useful flags:

| Flag | Effect |
| --- | --- |
| `--project DIR` | Index a different project (default: cwd) |
| `--limit N` | Only the N most recent unindexed sessions |
| `--dry-run` | List what would be summarized, spend nothing |
| `--resummarize UUID` | Redo one session (the only override of write-once) |

**If the dry run reports more than ~20 sessions, tell the user the count and
confirm before proceeding**, or suggest `--limit`. A project with a long history
can be dozens of sequential Haiku calls.

## Rules the script enforces

| Rule | Behaviour |
| --- | --- |
| Write-once | A UUID already in the table is never re-summarized |
| Additive | Rows are never removed, including rows with no local transcript |
| Synthesis on change | The paragraph regenerates only when rows were added |

The additive rule is what makes this safe across machines. The script keys off
*rows in the file*, never *files on disk*, so a `SESSIONS.md` synced through git
keeps rows written on another computer even though those transcripts do not
exist locally. Session UUIDs are unique, so two machines produce disjoint rows
and git merges them as an ordinary append.

`SESSIONS.md` is added to `.git/info/exclude` on write — a local-only ignore, so
it cannot be committed by accident and the repo's tracked `.gitignore` stays
clean. If the user wants it committed and shared across machines, remove that
line from `.git/info/exclude`.

## Cost

One `claude -p` call per new session plus one for the paragraph, on
`claude-haiku-4-5`. Input is capped at ~6k characters of the user's own messages
— not the raw transcript, which can be megabytes.

## A note on summary quality

Transcript text is piped into `claude -p`, so the model can mistake the user's
last message for a live instruction and *answer* it instead of describing the
session. Early versions produced exactly that: a "summary" that was a fabricated
permission request. The transcript is now fenced in
`<<<ARCHIVED_TRANSCRIPT ... >>>` with the task repeated *after* the data.

Skim the rows it writes. If any read as replies rather than labels, the fencing
needs strengthening — and `--resummarize UUID` redoes a single bad row.

## History

This began as a global `SessionStart` hook that indexed every project
automatically. That was the wrong shape: it ran unprompted on every session
start in every directory, spending tokens without being asked, and it could only
ever index a session on the *following* start (a session's own transcript is
still empty when `SessionStart` fires). As a skill it runs when asked, sees
complete transcripts including the current session, and backfill is just a
normal request rather than a hazard to guard against.
