#!/usr/bin/env bash
# Dev-only: runs the two Phase 7a integration_test walkthroughs against the LOCAL stub and takes simulator screenshots on every `SHOT:<name>` marker.
# Usage: tool/dev/capture_7a.sh <simulator-udid> <out-dir> [port] [which: messages|leaves|both]
# Process rules: starts only its OWN processes and stops only those PIDs (never pkill / kill-by-pattern); never boots, shuts down or resets the
# simulator or its keychain (the owner has another Flutter project on it; the app signs out through its own UI instead); watchdog: no SHOT / STEP /
# STUB marker for 180 s -> the flutter run launched here is stopped and the script ends with a non-zero exit code.
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"; PORT="${3:-3977}"; WHICH="${4:-both}"
cd "$(dirname "$0")/../.."
mkdir -p "$OUT"
LOGDIR="$(mktemp -d)"
python3 tool/dev/stub_server.py --port "$PORT" >"$LOGDIR/stub.log" 2>&1 &
STUB_PID=$!
FLUTTER_PID=""
stop_mine() {
  if [ -n "$FLUTTER_PID" ] && kill -0 "$FLUTTER_PID" 2>/dev/null; then
    for c in $(pgrep -P "$FLUTTER_PID" 2>/dev/null); do kill "$c" 2>/dev/null; done
    kill "$FLUTTER_PID" 2>/dev/null
  fi
  kill "$STUB_PID" 2>/dev/null
}
trap stop_mine EXIT
sleep 1
xcrun simctl uninstall "$SIM" com.eldermin.elderminTeacherApp >/dev/null 2>&1   # only OUR app, never the keychain / other apps

run_one() {
  local test_file="$1" log="$LOGDIR/$(basename "$1").log"
  : >"$log"
  flutter test "$test_file" -d "$SIM" --dart-define=API_BASE_URL="http://localhost:$PORT" >"$log" 2>&1 &
  FLUTTER_PID=$!
  local seen=0 last; last=$(date +%s)
  while kill -0 "$FLUTTER_PID" 2>/dev/null; do
    sleep 1
    local total; total=$(wc -l <"$log" | tr -d ' ')
    if [ "$total" -gt "$seen" ]; then
      while IFS= read -r line; do
        case "$line" in
          *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"; last=$(date +%s)
                   xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "captured $name" ;;
          *STUB:*) p="${line##*STUB:}"; p="${p%%[[:space:]]*}"; last=$(date +%s); curl -s -X POST "http://localhost:$PORT$p" >/dev/null ;;
          *STEP:*) last=$(date +%s); echo "$line" | cut -c1-160 ;;
          *DONE:*|*"All tests passed"*|*"Some tests failed"*|*"[E]"*|*TestFailure*|*"Timed out"*) echo "$line" | cut -c1-200 ;;
        esac
      done < <(sed -n "$((seen + 1)),${total}p" "$log")
      seen=$total
    fi
    if [ $(( $(date +%s) - last )) -gt 180 ]; then
      echo "WATCHDOG: no marker for 180 s, stopping the flutter run I started ($FLUTTER_PID)"
      stop_mine; return 2
    fi
  done
  wait "$FLUTTER_PID"; local rc=$?
  FLUTTER_PID=""
  tail -n 25 "$log" | cut -c1-200 | grep -E "Expected|Actual|Timed out|TestFailure|budget|Some tests|All tests" | head -8
  return $rc
}

rc=0
if [ "$WHICH" = "both" ] || [ "$WHICH" = "messages" ]; then run_one integration_test/phase7a_messages_test.dart || rc=$?; fi
if [ "$WHICH" = "both" ] || [ "$WHICH" = "leaves" ]; then run_one integration_test/phase7a_leaves_test.dart || rc=$?; fi
echo "logs: $LOGDIR"
exit $rc
