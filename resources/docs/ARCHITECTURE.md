# Script OS Architecture

## Philosophy

This repo is an operating system for shell automation. Structure is intentionally designed to scale — conventions are established upfront so the project can grow without painful reorganization.

## Folder Structure

```
scripts/
├── tell/                  # Scripts that display or report information
│   └── tell_*.sh
├── generate/              # Scripts that produce or create output
│   └── generate_*.sh
├── install/               # Scripts that set up tooling or wire up shell integrations
│   └── install_*.sh
├── bin/                   # Standalone executables (no verb prefix)
│   └── latest_release
├── resources/
│   ├── docs/              # Architecture and agent guide documents
│   ├── extras/            # Hand-maintained shell snippets to source from RC files
│   ├── mappings/          # Key→value lookup tables (pipe-delimited)
│   ├── templates/         # (future) reusable output templates
│   ├── lists/             # (future) static enumeration files
│   └── schemas/           # (future) validation or format definitions
└── README.md
```

## Naming Conventions

### Scripts
- Pattern: `verb_noun.sh`
- Case: snake_case
- Verbs: `tell` (display/report), `generate` (produce/create), `install` (set up tooling/shell integrations)

### Resource files
- Mapping files: descriptive noun, `.txt`, pipe-delimited (`NAME | VALUE`)
- One entry per line, `#` for comments

### Folders
- Lowercase, singular nouns

## Comment Style

Order comments mechanic-first, use-case second:

```sh
# What it does / how it works
# When to use it
```

Leading with the functional description lets a skimmer get the "what" immediately, with context following as a second line.

## Adding a New Script

1. Pick a verb that describes what it does (`tell`, `generate`, `install`, etc.)
2. Name it `verb_noun.sh` in snake_case
3. Place it in the folder matching its verb (e.g. `tell/tell_foo.sh`)
4. Reference resource files via `${SCRIPT_DIR}/../resources/...`
5. If it needs a lookup table, add it to `resources/mappings/`
6. Add a section for it in README.md under Scripts

## Adding a New Resource

| Type | Folder | Format |
|------|--------|--------|
| Key→value lookup | `resources/mappings/` | `NAME \| VALUE` (pipe-delimited) |
| Reusable text blocks | `resources/templates/` | Plain text or heredoc-ready |
| Static lists | `resources/lists/` | One item per line |
