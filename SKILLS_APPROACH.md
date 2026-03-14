# Skills: Plugin vs Direct Reference

Two approaches for working with Claude skills. They are not mutually exclusive.

---

## Option A — `/plugin marketplace add anthropics/skills`

**Pros**
- Skills auto-activate — Claude reads the `TRIGGER when` / `DO NOT TRIGGER when` descriptions and loads the right skill without being told to
- Zero navigation overhead — no need for `AGENT_GUIDE.md`, no file reads, no directory traversal
- Gets updates automatically through the plugin system
- The SKILL.md trigger descriptions were designed for this activation pattern — you're using the system as intended

**Cons**
- Black box — you don't see what's loaded or when, harder to debug false activations
- No customization — can't modify individual skills locally
- Tied to Anthropic's release cadence
- Only works in Claude Code, not other agents or scripts
- Skills activate globally across all projects, not scoped to this repo

---

## Option B — `AGENT_GUIDE.md` + `~/skills` direct

**Pros**
- Full visibility and control — you can read, fork, and modify any skill
- Version pinned via git — you choose when to pull updates
- Extensible — `~/skills` is already structured for multiple repos (awesome lists, partner skills, custom skills)
- Works across any agent or tool, not just Claude Code
- `tell_skills.sh` gives you observability into what's installed and whether it's stale

**Cons**
- Agent has to be told to look at `AGENT_GUIDE.md` — activation is manual, not automatic
- You're re-implementing the trigger logic the plugin system does for free
- More maintenance burden — pull updates yourself, keep `AGENT_GUIDE.md` current
- Higher cognitive overhead per session

---

## Comparison

| | Plugin | AGENT_GUIDE + ~/skills |
|--|--------|------------------------|
| Activation | Automatic | Manual |
| Visibility | Low | High |
| Customization | None | Full |
| Portability | Claude Code only | Any agent |
| Maintenance | Managed | Self-managed |
| Scale (many skill repos) | Harder | Designed for it |

---

## Recommendation

Use both. The plugin approach wins for day-to-day Claude Code use with Anthropic's skills as-is. The `AGENT_GUIDE.md` + `~/skills` approach wins when mixing in third-party skill repos, customizing skills, or building tooling that works outside Claude Code.

Since this repo is designed to grow into a multi-source skill OS (Anthropic + awesome lists + custom), `~/skills` is the managed source of truth you inspect and extend — the plugin handles activation convenience on top of it.
