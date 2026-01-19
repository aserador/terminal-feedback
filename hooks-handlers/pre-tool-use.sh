#!/bin/bash
# Called before Claude executes a tool (Bash, Edit, Write, Read, etc.)
# Sets the terminal background to "working" color

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$PLUGIN_ROOT/config.sh"
[[ -f "$PLUGIN_ROOT/config.local.sh" ]] && source "$PLUGIN_ROOT/config.local.sh"

# Read hook input JSON from stdin
INPUT=$(cat)

# Extract session_id and tool_name from JSON
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)

# Skip for certain tools that don't indicate "real work"
# (Read is passive, TodoWrite is internal)
case "$TOOL_NAME" in
    Read|TodoWrite|Glob|Grep)
        exit 0
        ;;
esac

# Get session location info (TTY)
LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"

TTY_PATH=""

if [ -f "$LOCATION_FILE" ]; then
    source "$LOCATION_FILE"
fi

# Change terminal background to working color
if [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\033]11;%s\033\\' "$WORKING_BG" > "$TTY_PATH"
    echo "$(date): [pre-tool-use] Set working background for $TOOL_NAME on $TTY_PATH" >> "$LOG_FILE"
fi
