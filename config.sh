#!/bin/bash
# Terminal Feedback Plugin Configuration
# Copy this file to config.local.sh to customize (config.local.sh is gitignored)

# =============================================================================
# TERMINAL APPLICATION
# =============================================================================
# The bundle identifier of your terminal app (used for notification activation)
# Common values:
#   - Ghostty:      com.mitchellh.ghostty
#   - iTerm2:       com.googlecode.iterm2
#   - Kitty:        net.kovidgoyal.kitty
#   - Alacritty:    org.alacritty
#   - WezTerm:      com.github.wez.wezterm
#   - Terminal.app: com.apple.Terminal (limited support - no focus detection)
#   - Hyper:        co.zeit.hyper
TERMINAL_BUNDLE_ID="${TERMINAL_BUNDLE_ID:-com.mitchellh.ghostty}"

# =============================================================================
# BACKGROUND COLORS
# =============================================================================
# Colors are specified as hex values
# These work with terminals that support OSC 11 escape sequences

# Color when Claude needs your input (permission, question, idle)
ATTENTION_BG="${ATTENTION_BG:-#3d2a1a}"

# Color when Claude completes a task
COMPLETED_BG="${COMPLETED_BG:-#1a3d2a}"

# =============================================================================
# NOTIFICATIONS
# =============================================================================
# Path to terminal-notifier (install via: brew install terminal-notifier)
TERMINAL_NOTIFIER="${TERMINAL_NOTIFIER:-/opt/homebrew/bin/terminal-notifier}"

# Set to "true" to disable notifications entirely (background colors still work)
DISABLE_NOTIFICATIONS="${DISABLE_NOTIFICATIONS:-false}"

# Set to "true" to disable the bell/dock bounce
DISABLE_BELL="${DISABLE_BELL:-false}"

# Set to "true" to respect Do Not Disturb mode
RESPECT_DND="${RESPECT_DND:-false}"

# =============================================================================
# LOGGING
# =============================================================================
# Log file location (set to /dev/null to disable logging)
LOG_FILE="${LOG_FILE:-/tmp/claude-hook.log}"
