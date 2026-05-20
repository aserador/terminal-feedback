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
# CMUX INTEGRATION
# =============================================================================
# When the plugin detects it's running inside a cmux pane (CMUX_PANEL_ID set),
# OSC 11/111 is skipped (cmux swallows it) and we drive cmux's CLI instead:
# `cmux workspace-action --color` for the tab indicator and `cmux notify`
# for notifications. terminal-notifier is also skipped to avoid duplicate
# macOS banners (cmux notify already triggers one).

# Workspace tab color when Claude needs input. Accepts a named color
# (Red, Crimson, Orange, Amber, Olive, Green, Teal, Aqua, Blue, Navy,
# Indigo, Purple, Magenta, Rose, Brown, Charcoal) or a #RRGGBB hex.
CMUX_ATTENTION_COLOR="${CMUX_ATTENTION_COLOR:-Amber}"

# Workspace tab color when Claude completes a task.
CMUX_COMPLETED_COLOR="${CMUX_COMPLETED_COLOR:-Green}"

# Set to "false" to skip `cmux notify` even inside cmux (tab color still applies)
USE_CMUX_NOTIFY="${USE_CMUX_NOTIFY:-true}"

# =============================================================================
# LOGGING
# =============================================================================
# Log file location (set to /dev/null to disable logging)
LOG_FILE="${LOG_FILE:-/tmp/claude-hook.log}"
