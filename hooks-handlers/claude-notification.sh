#!/bin/bash
# Notification: Claude needs the user's attention — permission request,
# AskUserQuestion, or idle. Sets brown background and writes
# state=attention so a subsequent Stop hook in the same turn won't
# overwrite it with green.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
hook_bootstrap "$SCRIPT_DIR"

SESSION_ID=$(json_field "$HOOK_INPUT" session_id)
MESSAGE=$(json_field "$HOOK_INPUT" message)
NOTIFICATION_TYPE=$(json_field "$HOOK_INPUT" notification_type)

if [[ -z "$SESSION_ID" ]]; then
    log notification "missing session_id"
    echo '{"suppressOutput":true}'
    exit 0
fi

resolve_tty "$SESSION_ID"
TTY_NAME="$RESOLVED_TTY_NAME"
TTY_PATH="$RESOLVED_TTY_PATH"
TAB_NAME="$RESOLVED_TAB_NAME"

log notification "fired session=$SESSION_ID tty=$TTY_NAME type=$NOTIFICATION_TYPE cmux=$(in_cmux && echo 1 || echo 0)"

state_write "$TTY_NAME" "attention"

if in_cmux; then
    cmux_set_color "$CMUX_ATTENTION_COLOR"
    [[ "$USE_CMUX_NOTIFY" == "true" ]] && cmux_notify "Claude Code - $TAB_NAME" "$MESSAGE"
    log notification "cmux set-color=$CMUX_ATTENTION_COLOR ($MESSAGE)"
else
    set_bg_color "$TTY_PATH" "$ATTENTION_BG"
    ring_bell "$TTY_PATH"
    send_notification "Claude Code - $TAB_NAME" "$MESSAGE"
    mark_pending_reset "$TTY_NAME" "$SESSION_ID"
    log notification "set bg=$ATTENTION_BG on $TTY_PATH ($MESSAGE)"
fi

echo '{"suppressOutput":true}'
