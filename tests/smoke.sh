#!/bin/bash
# Smoke test: exercise every hook handler with synthetic JSON input
# against an isolated fake-TTY (a regular file, since the OSC writes
# only need a writable destination — they don't care if it's a real tty).
#
# Asserts:
#   1. Every handler exits 0 and emits valid JSON.
#   2. The state file transitions correctly through a full lifecycle.
#   3. claude-completed.sh respects state=attention (the key fix).
#   4. OSC 11/111 sequences are actually written to the target.
#
# Usage: ./tests/smoke.sh
# Exits non-zero on any assertion failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
HANDLERS="$PLUGIN_ROOT/hooks-handlers"

PASS=0
FAIL=0
FAILED_TESTS=()

# Use a temp dir for isolation
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Override config knobs so the test never sends real notifications or bells
export DISABLE_NOTIFICATIONS=true
export DISABLE_BELL=true
export LOG_FILE="$TMPDIR_TEST/hook.log"

# Stand up a fake TTY (regular file). The lib's TTY discovery and resolution
# both honor these env vars so handlers write to our fixture instead of the
# real controlling terminal of the test runner.
FAKE_TTY_NAME="smoke-tty-$$"
FAKE_TTY_PATH="$TMPDIR_TEST/tty"
touch "$FAKE_TTY_PATH"
export CLAUDE_HOOKS_FORCE_TTY_NAME="$FAKE_TTY_NAME"
export CLAUDE_HOOKS_FORCE_TTY_PATH="$FAKE_TTY_PATH"
export CLAUDE_HOOKS_FORCE_TAB_NAME="smoketest"

SESSION_ID="smoke-test-session-$$"
LOC_DIR="$HOME/.claude/session-locations"
mkdir -p "$LOC_DIR"
LOC_FILE="$LOC_DIR/$SESSION_ID"
trap 'rm -f "$LOC_FILE"; rm -rf "$TMPDIR_TEST"' EXIT

state_file="/tmp/claude-state-${FAKE_TTY_NAME//\//-}"
pending_file="/tmp/claude-pending-reset-${FAKE_TTY_NAME//\//-}"
cleanup_state() {
    rm -f "$state_file" "$pending_file" "${pending_file}.session"
}
cleanup_state

assert() {
    local label="$1"
    local actual="$2"
    local expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        PASS=$((PASS+1))
        echo "  ok   $label"
    else
        FAIL=$((FAIL+1))
        FAILED_TESTS+=("$label: expected '$expected', got '$actual'")
        echo "  FAIL $label: expected '$expected', got '$actual'"
    fi
}

assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS+1))
        echo "  ok   $label"
    else
        FAIL=$((FAIL+1))
        FAILED_TESTS+=("$label: '$haystack' does not contain '$needle'")
        echo "  FAIL $label: '$haystack' does not contain '$needle'"
    fi
}

run_hook() {
    local handler="$1"
    local payload="$2"
    printf '%s' "$payload" | "$HANDLERS/$handler"
}

input_json() {
    local extra="${1:-}"
    if [[ -n "$extra" ]]; then
        echo "{\"session_id\":\"$SESSION_ID\",\"transcript_path\":\"/tmp/fake.jsonl\",\"cwd\":\"$TMPDIR_TEST\",$extra}"
    else
        echo "{\"session_id\":\"$SESSION_ID\",\"transcript_path\":\"/tmp/fake.jsonl\",\"cwd\":\"$TMPDIR_TEST\"}"
    fi
}

echo
echo "== Test 1: SessionStart writes location and sets idle =="
cleanup_state
out=$(run_hook register-session.sh "$(input_json '"source":"startup"')")
assert "SessionStart exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
assert "state file is idle" "$(cat "$state_file" 2>/dev/null)" "idle"

echo
echo "== Test 2: UserPromptSubmit transitions to working and writes OSC 111 =="
> "$FAKE_TTY_PATH"
out=$(run_hook user-prompt-submit.sh "$(input_json)")
assert "UserPromptSubmit exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
assert "state -> working" "$(cat "$state_file")" "working"
assert_contains "OSC 111 written" "$(cat "$FAKE_TTY_PATH")" $'\033]111\033\\'

echo
echo "== Test 3: Notification transitions to attention and writes OSC 11 brown =="
> "$FAKE_TTY_PATH"
out=$(run_hook claude-notification.sh "$(input_json '"message":"Claude needs your permission","notification_type":"permission"')")
assert "Notification exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
assert "state -> attention" "$(cat "$state_file")" "attention"
assert_contains "OSC 11 brown written" "$(cat "$FAKE_TTY_PATH")" $'\033]11;#3d2a1a'

echo
echo "== Test 4: Stop while state=attention is a no-op (the critical fix) =="
> "$FAKE_TTY_PATH"
out=$(run_hook claude-completed.sh "$(input_json)")
assert "Stop exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
assert "state stays attention (not overwritten)" "$(cat "$state_file")" "attention"
assert "no OSC written when waiting" "$(cat "$FAKE_TTY_PATH")" ""

echo
echo "== Test 5: After working state, Stop sets completed/green =="
echo "working" > "$state_file"
> "$FAKE_TTY_PATH"
out=$(run_hook claude-completed.sh "$(input_json)")
assert "Stop exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
assert "state -> completed" "$(cat "$state_file")" "completed"
assert_contains "OSC 11 green written" "$(cat "$FAKE_TTY_PATH")" $'\033]11;#1a3d2a'

echo
echo "== Test 6: SubagentStop is a true no-op (no state or bg change) =="
echo "working" > "$state_file"
> "$FAKE_TTY_PATH"
out=$(run_hook subagent-stop.sh "$(input_json)")
assert "SubagentStop exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
assert "state untouched" "$(cat "$state_file")" "working"
assert "no OSC written" "$(cat "$FAKE_TTY_PATH")" ""

echo
echo "== Test 7: SessionEnd clears state files =="
echo "completed" > "$state_file"
touch "$pending_file"
echo "$SESSION_ID" > "${pending_file}.session"
out=$(run_hook session-end.sh "$(input_json '"reason":"clear"')")
assert "SessionEnd exits 0 with JSON ack" "$out" '{"suppressOutput":true}'
[[ ! -f "$state_file" ]] && \
    { PASS=$((PASS+1)); echo "  ok   state file removed"; } || \
    { FAIL=$((FAIL+1)); echo "  FAIL state file still exists"; FAILED_TESTS+=("state file still exists"); }
[[ ! -f "$pending_file" ]] && \
    { PASS=$((PASS+1)); echo "  ok   pending-reset file removed"; } || \
    { FAIL=$((FAIL+1)); echo "  FAIL pending-reset file still exists"; FAILED_TESTS+=("pending-reset still exists"); }

echo
echo "== Test 8: Handlers tolerate missing session_id without exploding =="
out=$(run_hook claude-completed.sh '{}')
assert "Stop with empty payload exits 0 cleanly" "$out" '{"suppressOutput":true}'
out=$(run_hook claude-notification.sh '{}')
assert "Notification with empty payload exits 0 cleanly" "$out" '{"suppressOutput":true}'

echo
echo "== Test 9: jq parsing handles escaped quotes in message =="
> "$FAKE_TTY_PATH"
echo "working" > "$state_file"
out=$(run_hook claude-notification.sh "$(input_json '"message":"Allow Bash command: \"echo hi\"?","notification_type":"permission"')")
assert "Notification handles escaped quotes" "$out" '{"suppressOutput":true}'
assert "state -> attention even with escaped quotes" "$(cat "$state_file")" "attention"

echo
echo "============================================"
echo "  $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    printf '  - %s\n' "${FAILED_TESTS[@]}"
    exit 1
fi
echo "============================================"
exit 0
