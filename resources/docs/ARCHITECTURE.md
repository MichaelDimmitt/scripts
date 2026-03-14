# Script OS Architecture

## Philosophy

This repo is an operating system for shell automation. Structure is intentionally designed to scale — conventions are established upfront so the project can grow without painful reorganization.

## Folder Structure

```
scripts/
├── tell_*.sh              # Scripts that display or report information
├── generate_*.sh          # Scripts that produce or create output
├── resources/
│   ├── mappings/          # Key→value lookup tables (pipe-delimited)
│   ├── templates/         # (future) reusable output templates
│   ├── lists/             # (future) static enumeration files
│   └── schemas/           # (future) validation or format definitions
├── README.md
└── ARCHITECTURE.md
```

## Naming Conventions

### Scripts
- Pattern: `verb_noun.sh`
- Case: snake_case
- Verbs: `tell` (display/report), `generate` (produce/create)

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

1. Pick a verb that describes what it does (`tell`, `generate`, etc.)
2. Name it `verb_noun.sh` in snake_case
3. If it needs a lookup table, add it to `resources/mappings/`
4. Reference the lookup file relative to `$SCRIPT_DIR`

## Adding a New Resource

| Type | Folder | Format |
|------|--------|--------|
| Key→value lookup | `resources/mappings/` | `NAME \| VALUE` (pipe-delimited) |
| Reusable text blocks | `resources/templates/` | Plain text or heredoc-ready |
| Static lists | `resources/lists/` | One item per line |
