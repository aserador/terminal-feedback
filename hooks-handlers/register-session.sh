#!/bin/bash
# SessionStart: capture the controlling TTY for this Claude Code session
# so other handlers can target the right terminal. Fires for every source
# (startup, resume, clear, compact) so a /resume in a different tab refreshes
# the mapping.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
hook_bootstrap "$SCRIPT_DIR"

SESSION_ID=$(json_field "$HOOK_INPUT" session_id)
SOURCE=$(json_field "$HOOK_INPUT" source)
CWD=$(json_field "$HOOK_INPUT" cwd)

if [[ -z "$SESSION_ID" ]]; then
    log session "missing session_id, exiting"
    echo '{"suppressOutput":true}'
    exit 0
fi

mkdir -p "$HOME/.claude/session-locations"
LOCATION_FILE="$HOME/.claude/session-locations/$SESSION_ID"

TTY_NAME=$(discover_tty)
TTY_PATH="${CLAUDE_HOOKS_FORCE_TTY_PATH:-/dev/$TTY_NAME}"
TAB_NAME=$(basename "$CWD" 2>/dev/null || echo "claude")

cat > "$LOCATION_FILE" << EOF
TTY_NAME="$TTY_NAME"
TTY_PATH="$TTY_PATH"
TAB_NAME="$TAB_NAME"
CWD="$CWD"
REGISTERED_AT="$(date)"
EOF

# Fresh session = idle background. Clear any stale state from a prior
# session that happened to land on this same TTY.
state_write "$TTY_NAME" "idle"
clear_pending_reset "$TTY_NAME"

log session "registered $SESSION_ID source=$SOURCE tty=$TTY_NAME tab=$TAB_NAME"

echo '{"suppressOutput":true}'
