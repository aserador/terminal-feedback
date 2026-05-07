#!/bin/bash
# SessionEnd: clean up per-session and per-TTY scratch files so a new
# session on the same TTY starts from a clean slate.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
hook_bootstrap "$SCRIPT_DIR"

SESSION_ID=$(json_field "$HOOK_INPUT" session_id)
REASON=$(json_field "$HOOK_INPUT" reason)

if [[ -z "$SESSION_ID" ]]; then
    log session-end "missing session_id"
    echo '{"suppressOutput":true}'
    exit 0
fi

resolve_tty "$SESSION_ID"
TTY_NAME="$RESOLVED_TTY_NAME"
TTY_PATH="$RESOLVED_TTY_PATH"

log session-end "fired session=$SESSION_ID tty=$TTY_NAME reason=$REASON"

# Best-effort: leave the bg as-is (user may want to see the final color),
# but clear our internal state files.
state_clear "$TTY_NAME"
clear_pending_reset "$TTY_NAME"
rm -f "$HOME/.claude/session-locations/$SESSION_ID"

echo '{"suppressOutput":true}'
