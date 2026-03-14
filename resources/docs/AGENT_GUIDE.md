# Agent Guide

Tips for agents working in this repo and the broader `~/skills` ecosystem. Written to save time and avoid unnecessary file reads.

---

## Navigating ~/skills efficiently

### Step 1 — Read the index first, not the skills

Before opening any `SKILL.md`, read the marketplace index:

```
~/skills/.claude-plugin/marketplace.json
```

This single file lists all 17 skills grouped into 3 plugin categories with their folder paths. Reading it tells you which skill folder to target without touching any skill content.

**Categories in marketplace.json:**
| Plugin | Skills |
|--------|--------|
| `document-skills` | xlsx, docx, pptx, pdf |
| `example-skills` | algorithmic-art, brand-guidelines, canvas-design, doc-coauthoring, frontend-design, internal-comms, mcp-builder, skill-creator, slack-gif-creator, theme-factory, web-artifacts-builder, webapp-testing |
| `claude-api` | claude-api |

### Step 2 — Read frontmatter only, not the full SKILL.md

Each `SKILL.md` has a `description` field in its YAML frontmatter that includes explicit trigger logic (`TRIGGER when` / `DO NOT TRIGGER when`). You can match on description alone — reading the full instruction body is only necessary when executing the skill.

```
~/skills/skills/<name>/SKILL.md   ← frontmatter = fast match; body = execution details
```

### Step 3 — Know which skills have supporting files

Most skills are just `SKILL.md + LICENSE.txt`. The following have additional resources worth knowing about:

| Skill | Extra files |
|-------|-------------|
| `pdf` | `reference.md`, `forms.md`, `scripts/` (8 Python utilities) |
| `pptx` | `editing.md`, `pptxgenjs.md`, `scripts/` |
| `docx` | `scripts/` (comment.py, templates) |
| `xlsx` | `scripts/` (schemas, validators) |
| `claude-api` | `python/`, `typescript/`, `java/`, `go/`, `php/`, `ruby/`, `csharp/`, `curl/` |
| `internal-comms` | `examples/` (4 templates) |
| `theme-factory` | `themes/` (10 pre-built themes) |
| `algorithmic-art` | `templates/` (generator_template.js, viewer.html) |
| `skill-creator` | `agents/`, `references/`, `scripts/`, `eval-viewer/` |
| `mcp-builder` | `reference/`, `scripts/` |
| `webapp-testing` | `scripts/`, `examples/` |
| `web-artifacts-builder` | `scripts/` (init-artifact.sh, bundle-artifact.sh) |

---

## Navigating this scripts repo efficiently

### The lookup for this repo lives at:

```
resources/mappings/ai_tools_launch.txt    ← tool name → launch command
```

### File discovery shortcuts

- All scripts are at the repo root — no nesting, no subdirectories to recurse
- Script purpose is encoded in the filename: `tell_` = read-only report, `generate_` = produces output
- The only resource files live under `resources/mappings/` (more subfolders may be added per ARCHITECTURE.md)

### What to read and in what order

| Goal | Read |
|------|------|
| Understand the project | `README.md` |
| Understand folder/naming conventions | `ARCHITECTURE.md` |
| Find a script | `ls *.sh` — names are self-describing |
| Find a mapping/lookup file | `ls resources/mappings/` |
| Understand navigation tips | This file (`AGENT_GUIDE.md`) |

---

## General tips

- **Prefer frontmatter over full file reads.** Both SKILL.md files and scripts embed their purpose in the first few lines. Read those before reading the body.
- **Check for a manifest before globbing.** `marketplace.json` and `resources/mappings/` exist specifically so agents don't have to discover structure by walking the tree.
- **Folder names are meaningful.** In both this repo and `~/skills`, the folder/file name is the skill/script name — trust it before reading content.
- **When ~/skills grows**, each new repo cloned into `~/skills/` should have its own `.claude-plugin/marketplace.json` or equivalent index. Run `tell_skills.sh` to see what's installed and whether repos are up to date.
