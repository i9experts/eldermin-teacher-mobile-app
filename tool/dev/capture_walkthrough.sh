#!/usr/bin/env bash
# Dev-only: runs an integration_test walkthrough against the LOCAL stub and
# takes simulator screenshots on every `SHOT:<name>` marker it prints.
# Usage: tool/dev/capture_walkthrough.sh <simulator-udid> <out-dir> [test-file] [port]
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"
TEST="${3:-integration_test/phase3_demo_test.dart}"; PORT="${4:-3999}"
cd "$(dirname "$0")/../.."
mkdir -p "$OUT"
python3 tool/dev/stub_server.py --port "$PORT" >/dev/null 2>&1 &
STUB_PID=$!
trap 'kill $STUB_PID 2>/dev/null' EXIT
sleep 1
flutter test "$TEST" -d "$SIM" --dart-define=API_BASE_URL=http://localhost:$PORT 2>&1 | while IFS= read -r line; do
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"
             xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "captured $name" ;;
    *STUB:*) p="${line##*STUB:}"; p="${p%%[[:space:]]*}"; curl -s -X POST "http://localhost:$PORT$p" >/dev/null ;;
    *) echo "$line" | cut -c1-200 ;;
  esac
done
