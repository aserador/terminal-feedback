#!/bin/bash
# Called when user submits a new prompt
# Resets the terminal background color to default

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$PLUGIN_ROOT/config.sh"
[[ -f "$PLUGIN_ROOT/config.local.sh" ]] && source "$PLUGIN_ROOT/config.local.sh"

# Read hook input JSON from stdin
INPUT=$(cat)

# Extract session_id
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

# Get TTY from session location file
if [ -n "$SESSION_ID" ]; then
    LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"
    if [ -f "$LOCATION_FILE" ]; then
        source "$LOCATION_FILE"
    fi

    # Clean up pending reset marker
    if [ -n "$TTY_NAME" ]; then
        PENDING_FILE="/tmp/claude-pending-reset-${TTY_NAME//\//-}"
        rm -f "$PENDING_FILE" "${PENDING_FILE}.session"
    fi
fi

# Reset terminal background using OSC 111 escape sequence
# Write directly to TTY if available
if [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\033]111\033\\' > "$TTY_PATH"
else
    # Fallback: try stdout (works if running in terminal context)
    printf '\033]111\033\\'
fi
