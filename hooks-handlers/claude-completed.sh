#!/bin/bash
# Stop: Claude finished its turn.
#
# Goes green ONLY if the state machine doesn't already say "attention" — if
# Notification fired during this turn (permission prompt, idle, AskUserQuestion),
# the brown bg is intentional and Stop should leave it alone. This replaces
# the prior transcript-scanning heuristic which only caught AskUserQuestion
# and missed permission/idle notifications.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
hook_bootstrap "$SCRIPT_DIR"

SESSION_ID=$(json_field "$HOOK_INPUT" session_id)

if [[ -z "$SESSION_ID" ]]; then
    log completed "missing session_id"
    echo '{"suppressOutput":true}'
    exit 0
fi

resolve_tty "$SESSION_ID"
TTY_NAME="$RESOLVED_TTY_NAME"
TTY_PATH="$RESOLVED_TTY_PATH"
TAB_NAME="$RESOLVED_TAB_NAME"

CURRENT_STATE=$(state_read "$TTY_NAME")
log completed "fired session=$SESSION_ID tty=$TTY_NAME state=$CURRENT_STATE cmux=$(in_cmux && echo 1 || echo 0)"

# If we're already in attention state, Notification owns the screen.
# Don't overwrite the brown waiting indicator with green completed.
if [[ "$CURRENT_STATE" == "attention" ]]; then
    log completed "skip — current state is attention"
    echo '{"suppressOutput":true}'
    exit 0
fi

state_write "$TTY_NAME" "completed"

if in_cmux; then
    cmux_set_color "$CMUX_COMPLETED_COLOR"
    [[ "$USE_CMUX_NOTIFY" == "true" ]] && cmux_notify "Claude Code - $TAB_NAME" "Task completed"
    log completed "cmux set-color=$CMUX_COMPLETED_COLOR"
else
    set_bg_color "$TTY_PATH" "$COMPLETED_BG"
    ring_bell "$TTY_PATH"
    send_notification "Claude Code - $TAB_NAME" "Task completed"
    mark_pending_reset "$TTY_NAME" "$SESSION_ID"
    log completed "set bg=$COMPLETED_BG on $TTY_PATH"
fi

echo '{"suppressOutput":true}'
