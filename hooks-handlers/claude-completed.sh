#!/bin/bash
# Called when Claude stops after completing work
# Changes terminal background color and sends notification
# Only triggers if Claude finished without needing input

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$PLUGIN_ROOT/config.sh"
[[ -f "$PLUGIN_ROOT/config.local.sh" ]] && source "$PLUGIN_ROOT/config.local.sh"

# Read hook input JSON from stdin
INPUT=$(cat)

echo "$(date): [completed] Hook fired" >> "$LOG_FILE"

# Extract session_id and transcript_path from JSON
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
TRANSCRIPT_PATH=$(echo "$INPUT" | grep -o '"transcript_path":"[^"]*"' | cut -d'"' -f4)

# Check if we have the necessary info
if [ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT_PATH" ]; then
    echo "$(date): [completed] Missing session_id or transcript_path" >> "$LOG_FILE"
    exit 0
fi

# Check if Claude needs input - if so, let the other hook handle it
NEEDS_INPUT=false

if [ -f "$TRANSCRIPT_PATH" ]; then
    # Get the last assistant message
    LAST_ASSISTANT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)

    # Check if it contains AskUserQuestion tool use
    if echo "$LAST_ASSISTANT" | grep -q '"name":"AskUserQuestion"'; then
        NEEDS_INPUT=true
    # Check if it's waiting for permission (tool use that requires approval)
    elif echo "$LAST_ASSISTANT" | grep -q '"type":"tool_use"'; then
        NEEDS_INPUT=true
    # Check if the text content ends with a question
    elif echo "$LAST_ASSISTANT" | grep -qE '\?["\s]*$'; then
        NEEDS_INPUT=true
    fi
fi

# If Claude needs input, skip - the other hook handles that
if [ "$NEEDS_INPUT" = "true" ]; then
    echo "$(date): [completed] Needs input, skipping completed notification" >> "$LOG_FILE"
    exit 0
fi

echo "$(date): [completed] Claude completed work, sending notification" >> "$LOG_FILE"

# Get session location info (TTY, tab name)
LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"

TTY_PATH=""
TTY_NAME=""
TAB_NAME="Claude"

if [ -f "$LOCATION_FILE" ]; then
    source "$LOCATION_FILE"
    TAB_NAME="${TAB_NAME:-Claude}"
fi

echo "$(date): [completed] TTY_PATH=$TTY_PATH TAB_NAME=$TAB_NAME" >> "$LOG_FILE"

# Stop any running flasher
if [ -n "$TTY_NAME" ]; then
    WORKING_MARKER="/tmp/claude-working-${TTY_NAME//\//-}"
    FLASHER_PID_FILE="/tmp/claude-flasher-${TTY_NAME//\//-}.pid"

    # Remove marker to stop flasher loop
    rm -f "$WORKING_MARKER"

    # Kill flasher process
    if [ -f "$FLASHER_PID_FILE" ]; then
        FLASHER_PID=$(cat "$FLASHER_PID_FILE" 2>/dev/null)
        if [ -n "$FLASHER_PID" ]; then
            kill "$FLASHER_PID" 2>/dev/null
        fi
        rm -f "$FLASHER_PID_FILE"
    fi
fi

# Change terminal background using OSC 11 escape sequence
# Write directly to the TTY device
if [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\033]11;%s\033\\' "$COMPLETED_BG" > "$TTY_PATH"
    echo "$(date): [completed] Changed background to $COMPLETED_BG on $TTY_PATH" >> "$LOG_FILE"
else
    echo "$(date): [completed] Cannot write to TTY: $TTY_PATH" >> "$LOG_FILE"
fi

# Emit bell for dock bounce (write to TTY if available)
if [ "$DISABLE_BELL" != "true" ] && [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\a' > "$TTY_PATH"
fi

# Send macOS notification
if [ "$DISABLE_NOTIFICATIONS" != "true" ] && [ -x "$TERMINAL_NOTIFIER" ]; then
    NOTIFIER_ARGS=(
        -title "Claude Code - $TAB_NAME"
        -message "Task completed"
        -sound default
        -activate "$TERMINAL_BUNDLE_ID"
    )

    # Add ignoreDnD flag unless user wants to respect DND
    if [ "$RESPECT_DND" != "true" ]; then
        NOTIFIER_ARGS+=(-ignoreDnD)
    fi

    "$TERMINAL_NOTIFIER" "${NOTIFIER_ARGS[@]}"
    echo "$(date): [completed] Notification sent for $TAB_NAME" >> "$LOG_FILE"
fi

# Create pending reset marker for shell-based focus detection
# The shell's focus handler will detect this and reset when the tab is actually focused
if [ -n "$TTY_NAME" ]; then
    PENDING_FILE="/tmp/claude-pending-reset-${TTY_NAME//\//-}"
    touch "$PENDING_FILE"
    echo "$SESSION_ID" > "${PENDING_FILE}.session"
    echo "$(date): [completed] Created pending reset marker: $PENDING_FILE" >> "$LOG_FILE"
fi

# Note: We rely solely on the shell's focus handler (claude-focus-handler.zsh)
# which uses DECSET 1004 for terminal-level focus detection.
