#!/bin/bash
# End-to-end smoke test for the bundled DeepSeek Harness .app.
#
# NOTE: launches the real GUI binary, which writes its app-data dir under
# ~/Library and a test harness home inside the repo, so it must run with full
# access (sandbox escalation) on the build machine.
#
# Usage: scripts/test-app.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/DeepSeek Harness.app"
BIN="$APP/Contents/MacOS/pake"
TEST_HOME="$ROOT/.dsh-test-home"
LOG="$ROOT/.dsh-test-home/server.out.log"
BUNDLE_ID="com.deepseek-harness.desktop"

launch_and_wait() {
  rm -rf "$TEST_HOME"
  mkdir -p "$TEST_HOME"
  rm -f "$LOG"
  DSH_HOME="$TEST_HOME" "$BIN" >"$LOG" 2>&1 &
  APP_PID=$!
  echo "    app pid: $APP_PID"
  for i in $(seq 1 60); do
    URL=$(grep -oE "http://127\.0\.0\.1:[0-9]+" "$LOG" 2>/dev/null | head -1)
    [[ -n "$URL" ]] && break
    sleep 1
  done
  if [[ -z "$URL" ]]; then
    echo "FAIL: no server URL in app output" >&2
    cat "$LOG" 2>/dev/null | head -20
    kill -9 "$APP_PID" 2>/dev/null
    exit 1
  fi
  echo "    server URL: $URL"
  CODE=$(curl -s -o "$ROOT/.dsh-test-home/index.html" -w "%{http_code}" --max-time 15 "$URL/")
  if [[ "$CODE" != "200" ]] || ! grep -q "__DSH_BOOT__" "$ROOT/.dsh-test-home/index.html"; then
    echo "FAIL: GUI did not answer 200 with __DSH_BOOT__ (HTTP $CODE)" >&2
    kill -9 "$APP_PID" 2>/dev/null
    exit 1
  fi
  echo "    GUI verified (HTTP 200, __DSH_BOOT__)"
  # The server must be the bundled node, not the system node.
  NODE_PID=$(pgrep -f "Contents/Resources/runtime/node" | head -1)
  if [[ -z "$NODE_PID" ]]; then
    echo "FAIL: bundled node server not found" >&2
    kill -9 "$APP_PID" 2>/dev/null
    exit 1
  fi
  echo "    server process: bundled node (pid $NODE_PID)"
}

check_no_orphan() {
  sleep 2
  LEFTOVER=$(pgrep -f "dsh/lib/bin.js" || true)
  if [[ -n "$LEFTOVER" ]]; then
    echo "FAIL: orphaned server process left behind: $LEFTOVER" >&2
    pkill -9 -f "dsh/lib/bin.js" 2>/dev/null
    exit 1
  fi
  echo "    no orphan server process ✓"
}

echo "==> [1/2] quit via AppleScript (normal Tauri exit path)"
launch_and_wait
osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null \
  || osascript -e "tell application \"System Events\" to tell process \"pake\" to click menu item \"Quit DeepSeek Harness\" of menu 1 of menu bar item 1 of menu bar 1" 2>/dev/null
for i in $(seq 1 20); do
  kill -0 "$APP_PID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$APP_PID" 2>/dev/null; then
  echo "WARN: app did not quit via AppleScript; sending SIGTERM"
  kill "$APP_PID"
  sleep 3
fi
check_no_orphan

echo "==> [2/2] SIGTERM (logout/shutdown path)"
launch_and_wait
kill "$APP_PID"
for i in $(seq 1 10); do
  kill -0 "$APP_PID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$APP_PID" 2>/dev/null; then
  echo "WARN: app survived SIGTERM; killing hard"
  kill -9 "$APP_PID"
fi
check_no_orphan

echo "==> TEST PASSED"
