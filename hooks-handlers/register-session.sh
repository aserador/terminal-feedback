#!/bin/bash
# Called when Claude Code session starts
# Captures the TTY for this terminal session

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
source "$PLUGIN_ROOT/config.sh"
[[ -f "$PLUGIN_ROOT/config.local.sh" ]] && source "$PLUGIN_ROOT/config.local.sh"

# Read hook input JSON from stdin
INPUT=$(cat)

# Get session_id from hook input
SESSION_ID=$(echo "$INPUT" | grep -oE '"session_id"\s*:\s*"[^"]*"' | cut -d'"' -f4)

if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Create location file directory
mkdir -p "$HOME/.claude/session-locations"

LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"

# Find the TTY by walking up the process tree
# The Claude CLI process has the TTY, but hook subprocesses don't
find_tty() {
    local CURRENT_PID=$$
    while [ "$CURRENT_PID" != "1" ] && [ -n "$CURRENT_PID" ]; do
        local TTY=$(ps -o tty= -p $CURRENT_PID 2>/dev/null | tr -d ' ')
        if [ -n "$TTY" ] && [ "$TTY" != "??" ]; then
            echo "$TTY"
            return 0
        fi
        CURRENT_PID=$(ps -o ppid= -p $CURRENT_PID 2>/dev/null | tr -d ' ')
    done
    echo ""
}

TTY_NAME=$(find_tty)

# Get the working directory from the hook input for tab identification
CWD=$(echo "$INPUT" | grep -oE '"cwd"\s*:\s*"[^"]*"' | cut -d'"' -f4)
TAB_NAME=$(basename "$CWD" 2>/dev/null || echo "claude")

# Write session info
cat > "$LOCATION_FILE" << EOF
TTY_NAME="$TTY_NAME"
TTY_PATH="/dev/$TTY_NAME"
TAB_NAME="$TAB_NAME"
CWD="$CWD"
REGISTERED_AT="$(date)"
EOF

echo "$(date): [session] Registered session $SESSION_ID (TTY: $TTY_NAME, Tab: $TAB_NAME)" >> "$LOG_FILE"
