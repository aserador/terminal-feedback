#!/bin/bash
# SubagentStop: a subagent (Task/Agent tool) finished. We deliberately do
# NOT change the bg color here — the parent session is still working, and
# flashing green every time a subagent returns is the bug we're fixing.
#
# Why register at all? Two reasons: (1) defensive against any version where
# Stop semantics for subagents leak into the parent's hook context (see
# Claude Code v2.1.117 changelog: "SubagentStop hook semantics restored");
# (2) explicit registration documents the intent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$SCRIPT_DIR/_lib.sh"
hook_bootstrap "$SCRIPT_DIR"

SESSION_ID=$(json_field "$HOOK_INPUT" session_id)
log subagent-stop "fired session=$SESSION_ID (no-op)"

echo '{"suppressOutput":true}'
