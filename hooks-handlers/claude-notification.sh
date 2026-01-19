#!/bin/bash
# Called when Claude sends a notification (needs permission, idle, etc.)
# The Notification hook provides message and notification_type directly

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$PLUGIN_ROOT/config.sh"
[[ -f "$PLUGIN_ROOT/config.local.sh" ]] && source "$PLUGIN_ROOT/config.local.sh"

# Read hook input JSON from stdin
INPUT=$(cat)

echo "$(date): [notification] Hook fired" >> "$LOG_FILE"

# Extract fields from JSON
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
MESSAGE=$(echo "$INPUT" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
NOTIFICATION_TYPE=$(echo "$INPUT" | grep -o '"notification_type":"[^"]*"' | cut -d'"' -f4)

# Check if we have the necessary info
if [ -z "$SESSION_ID" ]; then
    echo "$(date): [notification] Missing session_id" >> "$LOG_FILE"
    exit 0
fi

# Get session location info (TTY, tab name)
LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"

TTY_PATH=""
TTY_NAME=""
TAB_NAME="Claude"

if [ -f "$LOCATION_FILE" ]; then
    source "$LOCATION_FILE"
    TAB_NAME="${TAB_NAME:-Claude}"
fi

echo "$(date): [notification] TTY_PATH=$TTY_PATH TAB_NAME=$TAB_NAME TYPE=$NOTIFICATION_TYPE" >> "$LOG_FILE"

# Change terminal background using OSC 11 escape sequence
if [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\033]11;%s\033\\' "$ATTENTION_BG" > "$TTY_PATH"
    echo "$(date): [notification] Changed background to $ATTENTION_BG on $TTY_PATH" >> "$LOG_FILE"
else
    echo "$(date): [notification] Cannot write to TTY: $TTY_PATH" >> "$LOG_FILE"
fi

# Build notification title based on type
TITLE="Claude Code - $TAB_NAME"

# Emit bell for dock bounce
if [ "$DISABLE_BELL" != "true" ] && [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\a' > "$TTY_PATH"
fi

# Send macOS notification
if [ "$DISABLE_NOTIFICATIONS" != "true" ] && [ -x "$TERMINAL_NOTIFIER" ]; then
    NOTIFIER_ARGS=(
        -title "$TITLE"
        -message "$MESSAGE"
        -sound default
        -activate "$TERMINAL_BUNDLE_ID"
    )

    # Add ignoreDnD flag unless user wants to respect DND
    if [ "$RESPECT_DND" != "true" ]; then
        NOTIFIER_ARGS+=(-ignoreDnD)
    fi

    "$TERMINAL_NOTIFIER" "${NOTIFIER_ARGS[@]}"
    echo "$(date): [notification] Notification sent: $MESSAGE" >> "$LOG_FILE"
fi

# Create pending reset marker for shell-based focus detection
# The shell's focus handler will detect this and reset when the tab is actually focused
if [ -n "$TTY_NAME" ]; then
    PENDING_FILE="/tmp/claude-pending-reset-${TTY_NAME//\//-}"
    touch "$PENDING_FILE"
    echo "$SESSION_ID" > "${PENDING_FILE}.session"
    echo "$(date): [notification] Created pending reset marker: $PENDING_FILE" >> "$LOG_FILE"
fi

# Note: We rely solely on the shell's focus handler (claude-focus-handler.zsh)
# which uses DECSET 1004 for terminal-level focus detection.
