#!/bin/bash
# UserPromptSubmit: user just typed a new prompt — clear any leftover
# completion/attention bg and reset to idle. Falls back to process-tree
# TTY discovery if the registered TTY is stale (e.g. session was resumed
# in a different tab).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
hook_bootstrap "$SCRIPT_DIR"

SESSION_ID=$(json_field "$HOOK_INPUT" session_id)

if [[ -z "$SESSION_ID" ]]; then
    log user-prompt "missing session_id"
    echo '{"suppressOutput":true}'
    exit 0
fi

resolve_tty "$SESSION_ID"
TTY_NAME="$RESOLVED_TTY_NAME"
TTY_PATH="$RESOLVED_TTY_PATH"

log user-prompt "fired session=$SESSION_ID tty=$TTY_NAME cmux=$(in_cmux && echo 1 || echo 0)"

state_write "$TTY_NAME" "working"

if in_cmux; then
    cmux_clear_color
else
    reset_bg "$TTY_PATH"
    clear_pending_reset "$TTY_NAME"
fi

echo '{"suppressOutput":true}'
