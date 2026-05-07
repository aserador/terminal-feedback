#!/bin/bash
# Shared library for terminal-feedback hook handlers.
# Source this from every handler. Provides:
#   - jq-based JSON field extraction (replaces fragile grep parsing)
#   - TTY discovery with process-tree fallback
#   - Per-TTY state machine (idle / working / attention / completed)
#   - OSC 11/111 emission to a TTY device
#   - terminal-notifier wrapper
#   - Logging helper
#
# Why this exists: previous handlers each reimplemented JSON parsing and
# TTY lookup, with subtle differences (e.g. only claude-completed.sh had a
# process-tree fallback). Centralizing eliminates the inconsistencies.

# State file lives per TTY so concurrent Claude sessions in different
# terminals don't fight. Possible values: idle, working, attention, completed.
_state_file_for_tty() {
    local tty_name="$1"
    [[ -z "$tty_name" ]] && return 1
    echo "/tmp/claude-state-${tty_name//\//-}"
}

state_read() {
    local tty_name="$1"
    local f
    f=$(_state_file_for_tty "$tty_name") || return 1
    [[ -f "$f" ]] && cat "$f" || echo "idle"
}

state_write() {
    local tty_name="$1"
    local new_state="$2"
    local f
    f=$(_state_file_for_tty "$tty_name") || return 1
    printf '%s' "$new_state" > "$f"
}

state_clear() {
    local tty_name="$1"
    local f
    f=$(_state_file_for_tty "$tty_name") || return 1
    rm -f "$f"
}

# Extract a top-level field from hook input JSON. Uses jq when available
# and falls back to grep (only for the simple session_id case where jq
# is genuinely unavailable on the system — should be rare).
json_field() {
    local input="$1"
    local field="$2"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$input" | jq -r --arg k "$field" '.[$k] // empty' 2>/dev/null
    else
        # Fallback: handles simple unescaped values only.
        printf '%s' "$input" | grep -oE "\"$field\"\\s*:\\s*\"[^\"]*\"" | sed -E 's/.*"([^"]*)"$/\1/'
    fi
}

# Walk up the process tree to find the controlling TTY of an ancestor
# (the Claude CLI process owns a TTY; hook subprocesses do not).
# Honor CLAUDE_HOOKS_FORCE_TTY_NAME for deterministic testing.
discover_tty() {
    if [[ -n "${CLAUDE_HOOKS_FORCE_TTY_NAME:-}" ]]; then
        echo "$CLAUDE_HOOKS_FORCE_TTY_NAME"
        return 0
    fi
    local pid=$$
    while [[ "$pid" != "1" && -n "$pid" ]]; do
        local tty
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [[ -n "$tty" && "$tty" != "??" ]]; then
            echo "$tty"
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

# Look up TTY for a session, preferring the registered location file
# but falling back to process-tree discovery so resumed/forked sessions
# still land on the right terminal. Honors test overrides
# (CLAUDE_HOOKS_FORCE_TTY_NAME / CLAUDE_HOOKS_FORCE_TTY_PATH).
resolve_tty() {
    local session_id="$1"
    local location_file="$HOME/.claude/session-locations/$session_id"
    local tty_name="" tty_path="" tab_name="Claude" cwd=""

    if [[ -n "${CLAUDE_HOOKS_FORCE_TTY_NAME:-}" ]]; then
        RESOLVED_TTY_NAME="$CLAUDE_HOOKS_FORCE_TTY_NAME"
        RESOLVED_TTY_PATH="${CLAUDE_HOOKS_FORCE_TTY_PATH:-/dev/$CLAUDE_HOOKS_FORCE_TTY_NAME}"
        RESOLVED_TAB_NAME="${CLAUDE_HOOKS_FORCE_TAB_NAME:-test}"
        RESOLVED_CWD=""
        return 0
    fi

    if [[ -f "$location_file" ]]; then
        # shellcheck disable=SC1090
        source "$location_file"
        tab_name="${TAB_NAME:-Claude}"
        tty_name="${TTY_NAME:-}"
        tty_path="${TTY_PATH:-}"
        cwd="${CWD:-}"
    fi

    # Fallback if location file missing or its TTY is no longer writable
    # (terminal closed, session resumed in a new tab, etc.)
    if [[ -z "$tty_path" || ! -w "$tty_path" ]]; then
        tty_name=$(discover_tty)
        if [[ -n "$tty_name" ]]; then
            tty_path="/dev/$tty_name"
        fi
    fi

    # Export for caller
    RESOLVED_TTY_NAME="$tty_name"
    RESOLVED_TTY_PATH="$tty_path"
    RESOLVED_TAB_NAME="$tab_name"
    RESOLVED_CWD="$cwd"
}

# Set terminal background via OSC 11. Color is hex, e.g. "#1a3d2a".
set_bg_color() {
    local tty_path="$1"
    local color="$2"
    [[ -z "$tty_path" || ! -w "$tty_path" ]] && return 1
    printf '\033]11;%s\033\\' "$color" > "$tty_path"
}

# Reset terminal background to default via OSC 111.
reset_bg() {
    local tty_path="$1"
    [[ -z "$tty_path" || ! -w "$tty_path" ]] && return 1
    printf '\033]111\033\\' > "$tty_path"
}

# Emit terminal bell for dock bounce / OS attention attractor.
ring_bell() {
    local tty_path="$1"
    [[ "$DISABLE_BELL" == "true" ]] && return 0
    [[ -z "$tty_path" || ! -w "$tty_path" ]] && return 1
    printf '\a' > "$tty_path"
}

# Send macOS notification via terminal-notifier. Activates terminal on click.
send_notification() {
    local title="$1"
    local message="$2"
    [[ "$DISABLE_NOTIFICATIONS" == "true" ]] && return 0
    [[ ! -x "$TERMINAL_NOTIFIER" ]] && return 1

    local args=(
        -title "$title"
        -message "$message"
        -sound default
        -execute "osascript -e 'tell application id \"$TERMINAL_BUNDLE_ID\" to activate'"
    )
    [[ "$RESPECT_DND" != "true" ]] && args+=(-ignoreDnD)

    "$TERMINAL_NOTIFIER" "${args[@]}" >/dev/null 2>&1
}

# Mark this TTY as having a pending reset, so the shell focus handler
# (claude-focus-handler.zsh) can clear the bg next time the user focuses
# the tab. Tied to a session_id so the focus handler can also kill any
# per-session watcher.
mark_pending_reset() {
    local tty_name="$1"
    local session_id="$2"
    [[ -z "$tty_name" ]] && return 1
    local pending="/tmp/claude-pending-reset-${tty_name//\//-}"
    touch "$pending"
    [[ -n "$session_id" ]] && echo "$session_id" > "${pending}.session"
}

clear_pending_reset() {
    local tty_name="$1"
    [[ -z "$tty_name" ]] && return 1
    local pending="/tmp/claude-pending-reset-${tty_name//\//-}"
    rm -f "$pending" "${pending}.session"
}

log() {
    local tag="$1"; shift
    echo "$(date): [$tag] $*" >> "$LOG_FILE"
}

# Standard handler bootstrap: load config + read stdin into INPUT.
hook_bootstrap() {
    local script_dir="$1"
    local plugin_root
    plugin_root="$(dirname "$script_dir")"
    # shellcheck disable=SC1091
    source "$plugin_root/config.sh"
    [[ -f "$plugin_root/config.local.sh" ]] && source "$plugin_root/config.local.sh"
    HOOK_INPUT=$(cat)
}
