#!/bin/bash
# Snapshots all Claude Code skill and plugin locations to a dated file
# Useful for auditing what skills/plugins are installed across user, plugin, and project scopes

{
    echo "=== User skills (~/.claude/skills) ==="
    ls ~/.claude/skills 2>/dev/null || echo "(none)"
    echo

    echo "=== Plugins (~/.claude/plugins) ==="
    ls ~/.claude/plugins 2>/dev/null || echo "(none)"
    echo

    echo "=== Plugin skills (nested) ==="
    find ~/.claude/plugins -type d -name skills 2>/dev/null
    echo

    echo "=== Project skills ==="
    find ~/.claude/projects -maxdepth 4 -type d -name skills 2>/dev/null
} > ~/claude-skills-$(hostname)-$(date +%Y%m%d).txt

echo "Wrote: ~/claude-skills-$(hostname)-$(date +%Y%m%d).txt"
