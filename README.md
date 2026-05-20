# Terminal Feedback for Claude Code

Visual feedback for Claude Code sessions — terminal background colors change based on Claude's state, with macOS notifications to get your attention.

## What It Does

| State | Background | Notification |
|-------|------------|--------------|
| **Needs input** | Amber (`#3d2a1a`) | "Claude needs input" |
| **Task completed** | Green (`#1a3d2a`) | "Task completed" |
| **You respond** | Default | — |

## Quick Install (< 2 min)

### Step 1: Install terminal-notifier

```bash
brew install terminal-notifier
```

### Step 2: Add the marketplace and install

In Claude Code:

```
/plugin marketplace add aserador/terminal-feedback
/plugin install ghostty-terminal-feedback@terminal-feedback
```

Or from the shell:

```bash
claude plugin marketplace add aserador/terminal-feedback
claude plugin install ghostty-terminal-feedback@terminal-feedback
```

### Step 3: Add shell integration

The plugin gets installed into a versioned cache directory (`~/.claude/plugins/cache/terminal-feedback/ghostty-terminal-feedback/<version>/`). Add this auto-resolving snippet to your `~/.zshrc` so the focus handler keeps working across plugin updates:

```bash
# Terminal-feedback focus handler — auto-resolves to the latest installed version
__tf_root="$HOME/.claude/plugins/cache/terminal-feedback/ghostty-terminal-feedback"
if [[ -d "$__tf_root" ]]; then
  __tf_handler=$(ls -td "$__tf_root"/*/shell/claude-focus-handler.zsh 2>/dev/null | head -1)
  [[ -n "$__tf_handler" ]] && source "$__tf_handler"
fi
unset __tf_root __tf_handler 2>/dev/null
```

Then reload your shell:

```bash
source ~/.zshrc
```

### Step 4: Done!

Start a new Claude Code session. The plugin works out of the box with **Ghostty**.

---

## Using a Different Terminal?

The default config is for Ghostty. For other terminals, create a local config:

```bash
cp ~/.claude/plugins/ghostty-terminal-feedback/config.sh \
   ~/.claude/plugins/ghostty-terminal-feedback/config.local.sh
```

Edit `config.local.sh` and change the terminal bundle ID:

| Terminal | Bundle ID |
|----------|-----------|
| **Ghostty** | `com.mitchellh.ghostty` (default) |
| **iTerm2** | `com.googlecode.iterm2` |
| **Kitty** | `net.kovidgoyal.kitty` |
| **Alacritty** | `org.alacritty` |
| **WezTerm** | `com.github.wez.wezterm` |

```bash
# Example for iTerm2:
TERMINAL_BUNDLE_ID="com.googlecode.iterm2"
```

<details>
<summary>How to find any terminal's bundle ID</summary>

```bash
osascript -e 'id of app "YourTerminalName"'
# Example:
osascript -e 'id of app "iTerm"'
```

</details>

---

## Terminal Compatibility

| Terminal | Background Colors | Focus Detection | Status |
|----------|:-----------------:|:---------------:|--------|
| Ghostty | Yes | Yes | Full support |
| iTerm2 | Yes | Yes | Full support |
| Kitty | Yes | Yes | Full support |
| Alacritty | Yes | Yes | Full support |
| WezTerm | Yes | Yes | Full support |
| Terminal.app | No | No | Not supported |

**Technical requirements:**
- OSC 11/111 escape sequences (background colors)
- DECSET 1004 (focus detection)

---

## Configuration

All options in `config.local.sh`:

```bash
# Which terminal to activate on notification click
TERMINAL_BUNDLE_ID="com.mitchellh.ghostty"

# Background colors (hex)
ATTENTION_BG="#3d2a1a"   # Amber when Claude needs input
COMPLETED_BG="#1a3d2a"   # Green when task completed

# Path to terminal-notifier
TERMINAL_NOTIFIER="/opt/homebrew/bin/terminal-notifier"

# Feature toggles
DISABLE_NOTIFICATIONS="false"   # "true" to disable notifications
DISABLE_BELL="false"            # "true" to disable dock bounce
RESPECT_DND="false"             # "true" to respect Do Not Disturb

# Logging (set to /dev/null to disable)
LOG_FILE="/tmp/claude-hook.log"
```

---

## Troubleshooting

### Background not changing?

Test if your terminal supports OSC 11:

```bash
# Should turn background red
printf '\033]11;#ff0000\033\\'

# Reset to default
printf '\033]111\033\\'
```

### Notifications not appearing?

```bash
# Check terminal-notifier is installed
which terminal-notifier

# If path differs from /opt/homebrew/bin/, update config.local.sh
```

### View debug logs

```bash
tail -f /tmp/claude-hook.log
```

### Scripts not running?

```bash
chmod +x ~/.claude/plugins/ghostty-terminal-feedback/hooks-handlers/*.sh
```

---

## How It Works

The plugin runs a small state machine per terminal (`/tmp/claude-state-<tty>`) and only changes the background when the transition is valid. This prevents the green/brown flicker that happens when several hooks fire in quick succession.

```
SessionStart ──► idle
UserPromptSubmit ──► working   (default bg)
Notification ──► attention     (amber)
Stop ──► completed             (green) — but only if not already in attention
SubagentStop ──► no-op         (parent is still working)
SessionEnd ──► clears state
```

| Hook Event | What Happens |
|------------|--------------|
| `SessionStart` | Registers your terminal session (TTY) and seeds state=`idle` |
| `UserPromptSubmit` | Resets bg, sets state=`working` |
| `Notification` | Sets amber bg, sets state=`attention`, sends macOS notification |
| `Stop` | If state ≠ `attention`, sets green bg and notifies. Otherwise leaves the brown waiting indicator alone |
| `SubagentStop` | No-op — prevents green flashes when a subagent finishes mid-turn |
| `SessionEnd` | Clears per-session and per-TTY state files |

The shell integration (`claude-focus-handler.zsh`) uses DECSET 1004 to detect when you switch to the tab, resetting the background automatically.

---

## File Structure

```
ghostty-terminal-feedback/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── hooks/
│   └── hooks.json               # Hook event bindings
├── hooks-handlers/
│   ├── _lib.sh                  # Shared: jq parsing, TTY discovery, state machine
│   ├── register-session.sh      # SessionStart
│   ├── session-end.sh           # SessionEnd
│   ├── claude-notification.sh   # Notification
│   ├── claude-completed.sh      # Stop
│   ├── subagent-stop.sh         # SubagentStop (no-op)
│   └── user-prompt-submit.sh    # UserPromptSubmit
├── shell/
│   └── claude-focus-handler.zsh # Focus detection
├── tests/
│   └── smoke.sh                 # Run before publishing changes
├── config.sh                    # Default config
├── config.local.sh              # Your overrides (gitignored)
└── README.md
```

---

## Uninstall

```bash
claude plugin uninstall ghostty-terminal-feedback
claude plugin marketplace remove terminal-feedback

# Then remove the focus-handler snippet from ~/.zshrc
```

---

## Development

If you're working on this plugin, clone it locally and load it directly from source:

```bash
git clone https://github.com/aserador/terminal-feedback ~/src/terminal-feedback
alias claude-dev='claude --plugin-dir ~/src/terminal-feedback'
```

`--plugin-dir` bypasses the marketplace cache so edits take effect immediately on restart.

Run smoke tests before publishing:

```bash
./tests/smoke.sh
```

To release changes:
1. Bump `version` in `.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json`
2. Commit and push to `main`
3. Users get the new version on the next `claude plugin marketplace update terminal-feedback`

---

## License

MIT
