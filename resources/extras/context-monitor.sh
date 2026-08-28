#!/bin/bash
# Stop hook: warns when context approaches the autocompact threshold (~167k tokens)

WARN_THRESHOLD=130000   # 65% of MAX_TOKENS — the % this script prints; ~37k before autocompact
CRIT_THRESHOLD=150000   # 75% of MAX_TOKENS; ~17k before autocompact — final warning
MAX_TOKENS=200000       # assumed context window
AUTOCOMPACT_AT=167000   # estimated

INPUT=$(cat)

TRANSCRIPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    exit 0
fi

TOTAL=$(tac "$TRANSCRIPT" | grep -m 1 '"type":"assistant"' | python3 -c "
import sys, json
try:
    obj = json.loads(sys.stdin.read().strip())
    u = obj.get('message', {}).get('usage', {})
    total = (u.get('input_tokens', 0)
           + u.get('cache_creation_input_tokens', 0)
           + u.get('cache_read_input_tokens', 0)
           + u.get('output_tokens', 0))
    print(total)
except:
    print(0)
" 2>/dev/null)

TOTAL=${TOTAL:-0}

if ! [[ "$TOTAL" =~ ^[0-9]+$ ]]; then
    exit 0
fi

if [ "$TOTAL" -gt "$CRIT_THRESHOLD" ]; then
    PCT=$((TOTAL * 100 / MAX_TOKENS))
    REMAINING=$((AUTOCOMPACT_AT - TOTAL))
    osascript -e "display notification \"${TOTAL} tokens used (${PCT}%) — only ~${REMAINING} tokens until autocompact fires!\" with title \"🚨 Claude Context Critical\" sound name \"Sosumi\"" 2>/dev/null
    echo "🚨 CONTEXT CRITICAL: ${TOTAL}/${MAX_TOKENS} tokens (${PCT}%). Autocompact triggers at ~${AUTOCOMPACT_AT}. Start a new session now."
elif [ "$TOTAL" -gt "$WARN_THRESHOLD" ]; then
    PCT=$((TOTAL * 100 / MAX_TOKENS))
    REMAINING=$((AUTOCOMPACT_AT - TOTAL))
    osascript -e "display notification \"${TOTAL} tokens used (${PCT}%) — ~${REMAINING} tokens until autocompact\" with title \"⚠️ Claude Context Warning\" sound name \"Glass\"" 2>/dev/null
    echo "⚠️  CONTEXT WARNING: ${TOTAL}/${MAX_TOKENS} tokens (${PCT}%). ~${REMAINING} tokens remain before autocompact (~${AUTOCOMPACT_AT})."
fi
