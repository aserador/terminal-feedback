# Claude Code Focus Handler for Zsh
# Source this file in your .zshrc to enable tab-level focus detection
#
# How it works:
# 1. Enables terminal focus reporting (DECSET 1004)
# 2. When terminal gains focus, checks if there's a pending background reset
# 3. If pending, resets the background to default
#
# Usage: Add to your .zshrc:
#   source ~/.claude/plugins/ghostty-terminal-feedback/shell/claude-focus-handler.zsh

# Only proceed if we're in an interactive shell with a TTY
[[ -o interactive ]] || return
[[ -t 0 ]] || return

# Function to handle focus-in event
_claude_on_focus_in() {
    local tty_name=$(tty 2>/dev/null | sed 's/\/dev\///')
    [[ -z "$tty_name" ]] && return

    local pending_file="/tmp/claude-pending-reset-${tty_name//\//-}"

    if [[ -f "$pending_file" ]]; then
        # Reset background to default
        printf '\033]111\033\\'

        # Clean up the session's focus watcher if still running
        local session_file="${pending_file}.session"
        if [[ -f "$session_file" ]]; then
            local session_id=$(cat "$session_file" 2>/dev/null)
            if [[ -n "$session_id" ]]; then
                local lock_file="/tmp/claude-focus-watcher-${session_id}.lock"
                if [[ -f "$lock_file" ]]; then
                    local watcher_pid=$(cat "$lock_file" 2>/dev/null)
                    [[ -n "$watcher_pid" ]] && kill "$watcher_pid" 2>/dev/null
                    rm -f "$lock_file"
                fi
            fi
            rm -f "$session_file"
        fi
        rm -f "$pending_file"
    fi
}

# Set up key binding for focus-in escape sequence (ESC [ I)
# We bind the sequence so zle can intercept it
function _claude_focus_in_widget() {
    _claude_on_focus_in
}
zle -N _claude_focus_in_widget

# Bind ESC [ I to our widget
# The escape sequence for focus-in is: ESC [ I (0x1b 0x5b 0x49)
bindkey '\e[I' _claude_focus_in_widget

# Also bind focus-out (ESC [ O) to a no-op to prevent it showing as garbage
function _claude_focus_out_widget() {
    # No action needed on focus-out
}
zle -N _claude_focus_out_widget
bindkey '\e[O' _claude_focus_out_widget

# IMPORTANT: Enable focus reporting AFTER setting up bindkeys
# This prevents race condition where focus events arrive before handlers are ready
# Only enable if this is the initial shell load (not a re-source)
if [[ -z "$_CLAUDE_FOCUS_HANDLER_LOADED" ]]; then
    export _CLAUDE_FOCUS_HANDLER_LOADED=1
    printf '\033[?1004h'
fi

# Disable focus reporting when shell exits
_claude_cleanup_focus() {
    printf '\033[?1004l'
}
trap '_claude_cleanup_focus' EXIT
