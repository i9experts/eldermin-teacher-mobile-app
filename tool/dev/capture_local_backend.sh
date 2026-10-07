#!/usr/bin/env bash
# Dev-only: runs integration_test/local_backend_smoke_test.dart against a LOCALLY running backend (NOT staging, no stub) and takes
# simulator screenshots on every `SHOT:<name>` marker the test prints. Credentials are never stored here: export
# LOCAL_TEACHER_EMAIL/LOCAL_TEACHER_PASSWORD/LOCAL_CLASS_EMAIL/LOCAL_CLASS_PASSWORD/LOCAL_SCHOOL_SLUG (and optionally
# LOCAL_SCENARIO=full|asbuilt) in the calling shell; they are passed with --dart-define and never echoed.
# Usage: tool/dev/capture_local_backend.sh <simulator-udid> <out-dir> [api-base-url]
# Watchdog (anti-loop): aborts the run when no new SHOT marker appeared for WATCHDOG_IDLE seconds (default 180) or after
# WATCHDOG_MAX seconds in total (default 900). macOS has no `timeout`, so this script enforces the limits itself.
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"; BASE="${3:-http://127.0.0.1:3998}"
cd "$(dirname "$0")/../.."
mkdir -p "$OUT"
xcrun simctl uninstall "$SIM" com.eldermin.elderminTeacherApp >/dev/null 2>&1
xcrun simctl keychain "$SIM" reset >/dev/null 2>&1
sleep 1
HB="$OUT/.heartbeat"; touch "$HB"; START=$(date +%s)
(
  while sleep 10; do
    now=$(date +%s); last=$(stat -f %m "$HB" 2>/dev/null || echo "$now")
    [ $(( (now - START) % 60 )) -lt 10 ] && echo "WATCHDOG: idle $((now - last))s, total $((now - START))s"
    if [ $((now - last)) -gt "${WATCHDOG_IDLE:-180}" ] || [ $((now - START)) -gt "${WATCHDOG_MAX:-900}" ]; then
      echo "WATCHDOG: no new screenshot marker for ${WATCHDOG_IDLE:-180}s (or ${WATCHDOG_MAX:-900}s total exceeded) - aborting run"
      pkill -f "integration_test/local_backend_smoke_test.dart" 2>/dev/null
      exit 0
    fi
  done
) &
WD_PID=$!
trap 'kill $WD_PID 2>/dev/null; rm -f "$HB"' EXIT
flutter test integration_test/local_backend_smoke_test.dart -d "$SIM" \
  --dart-define=API_BASE_URL="$BASE" \
  --dart-define=LOCAL_TEACHER_EMAIL="${LOCAL_TEACHER_EMAIL:-}" --dart-define=LOCAL_TEACHER_PASSWORD="${LOCAL_TEACHER_PASSWORD:-}" \
  --dart-define=LOCAL_CLASS_EMAIL="${LOCAL_CLASS_EMAIL:-}" --dart-define=LOCAL_CLASS_PASSWORD="${LOCAL_CLASS_PASSWORD:-}" \
  --dart-define=LOCAL_SCHOOL_SLUG="${LOCAL_SCHOOL_SLUG:-}" --dart-define=LOCAL_SCENARIO="${LOCAL_SCENARIO:-full}" 2>&1 | while IFS= read -r line; do
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"; touch "$HB"
             xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "captured $name" ;;
    *) echo "$line" | cut -c1-260 ;;
  esac
done
