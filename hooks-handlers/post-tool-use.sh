#!/bin/bash
# Called after a tool completes execution
# Resets terminal background to default since Claude is now working again

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$PLUGIN_ROOT/config.sh"
[[ -f "$PLUGIN_ROOT/config.local.sh" ]] && source "$PLUGIN_ROOT/config.local.sh"

# Read hook input JSON from stdin
INPUT=$(cat)

echo "$(date): [post-tool-use] Hook fired" >> "$LOG_FILE"

# Extract session_id from JSON
SESSION_ID=$(echo "$INPUT" | grep -oE '"session_id"\s*:\s*"[^"]*"' | cut -d'"' -f4)

if [ -z "$SESSION_ID" ]; then
    echo "$(date): [post-tool-use] Missing session_id" >> "$LOG_FILE"
    exit 0
fi

# Get session location info (TTY)
LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"

TTY_PATH=""
TTY_NAME=""

if [ -f "$LOCATION_FILE" ]; then
    source "$LOCATION_FILE"
fi

echo "$(date): [post-tool-use] TTY_PATH=$TTY_PATH TTY_NAME=$TTY_NAME" >> "$LOG_FILE"

# Reset terminal background to default using OSC 111
if [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\033]111\033\\' > "$TTY_PATH"
    echo "$(date): [post-tool-use] Reset background to default on $TTY_PATH" >> "$LOG_FILE"
else
    echo "$(date): [post-tool-use] Cannot write to TTY: $TTY_PATH" >> "$LOG_FILE"
fi

# Clean up any pending reset markers
if [ -n "$TTY_NAME" ]; then
    PENDING_FILE="/tmp/claude-pending-reset-${TTY_NAME//\//-}"
    if [ -f "$PENDING_FILE" ]; then
        rm -f "$PENDING_FILE"
        rm -f "${PENDING_FILE}.session"
        echo "$(date): [post-tool-use] Cleaned up pending reset marker" >> "$LOG_FILE"
    fi
fi

exit 0
