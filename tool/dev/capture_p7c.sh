#!/usr/bin/env bash
# Dev-only: ONE scenario of integration_test/p7c_local_test.dart (Phase 7 part 2 + 2026-10-08 re-check: marks lock/drafts/upload/header refresh, B5 field hiding, safeguarding, profile/avatar, help/KB, delete-account, calendar/circulars/events, hung-server refresh)
# against a LOCALLY running backend (isolated DB eldermin_teacher_verify; LOCAL verification, NOT staging, no stub, no shim).
# Modeled on capture_e2e_writes.sh / capture_phase4_local.sh. The script kills ONLY PIDs it started (never pkill -f), never resets the simulator
# keychain (the test signs out through the app UI), and never touches mongod.
#   * a backend must already answer on 127.0.0.1:3998 (start it with local-verification/start_backend.sh; if none answers this script starts one and stops it again)
#   * a logging proxy (local-verification/p7_proxy.py, 127.0.0.1:3997 -> 3998: METHOD+path+status, and the NUMBER of messages of a messages GET; no headers/bodies/tokens)
#     is started for the run; the log is kept in <out-dir>/proxy.log
# `SHOT:<name>` markers -> simulator screenshots. `DBACTION:<name>:<arg>` markers -> ONE action of the fixed list in local-verification/p7c_ops.js (writes only
# eldermin_teacher_verify) or a read-only check; their output is printed as `DB> ...` lines in the log.
# Dummy credentials come from the calling shell (LOCAL_TEACHER_EMAIL/PASSWORD = A, LOCAL_CLASS_EMAIL/PASSWORD = B, LOCAL_SCHOOL_SLUG); never echoed.
# ANTI-LOOP watchdog: no new marker for WATCHDOG_IDLE s (default 180) or WATCHDOG_MAX s (default 1200) -> only the flutter PID started here is killed.
# Usage: tool/dev/capture_p7c.sh <simulator-udid> <out-dir> <marks|b5|safe|profile|help|cal|hung> [shot-start-number]
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"; SCEN="${3:?scenario}"; SHOTSTART="${4:-1}"
cd "$(dirname "$0")/../.."
APP="$PWD"; LV="$APP/../eldermin-teacher-app-docs/local-verification"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
MONGO="mongodb://127.0.0.1:27017/eldermin_teacher_verify"
FLAGS="$OUT/flags"; mkdir -p "$FLAGS"; rm -f "$FLAGS"/*.flag
PLOG="$OUT/proxy.log"; : > "$PLOG"; MODEF="$OUT/proxy.mode"; echo forward > "$MODEF"
NODE=/usr/local/bin/node
BPID=""; PPROXY=""
up() { [ "$(curl -s -o /dev/null -m 3 -w '%{http_code}' http://127.0.0.1:3998/api/v1/auth/me)" = "401" ]; }
case "$SCEN" in marks|b5|safe|profile|help|cal|hung) ;; *) echo "unknown scenario"; exit 2;; esac
[ -s "$LV/out/p7c_ids.txt" ] || { echo "run local-verification/p7c_fresh.sh first (out/p7c_ids.txt missing)"; exit 2; }

# fixture ids (dummy, not secrets) and two dummy student names for the picker
IDS=$(awk '/^#/ {next} NF>=2 {printf "%s=%s;", $1, $2}' "$LV/out/p7c_ids.txt")

start_backend() {
  nohup "$LV/start_backend.sh" >/dev/null 2>&1 &
  BPID=$!; echo "$BPID" > "$LV/out/p7_backend.pid"
  for i in $(seq 1 30); do up && { echo "backend up (PID $BPID, started by this script)"; return 0; }; sleep 2; done
  echo "backend did not come up in 60 s"; return 1
}
db_action() { # name arg
  case "$1" in
    mark_*) echo "$(date +%T) MARK $1" >> "$PLOG"; echo "proxy log marker $1";;
    proxy_hang) echo blackhole > "$MODEF"; echo "$(date +%T) MARK proxy_hang" >> "$PLOG"; echo "proxy mode -> blackhole";;
    proxy_forward) echo forward > "$MODEF"; echo "$(date +%T) MARK proxy_forward" >> "$PLOG"; echo "proxy mode -> forward";;
    publish_open|unpublish_open|lower_total|publish_quiz|unpublish_quiz|check_*) ( cd "$LV" && $NODE p7c_ops.js "$1" "${2:-}" 2>&1 | grep -E "^DB>" );;
    *) echo "unknown action $1";;
  esac
}
cleanup() { kill $WD_PID 2>/dev/null; kill $FPID 2>/dev/null; [ -n "$PPROXY" ] && kill "$PPROXY" 2>/dev/null; [ -n "$BPID" ] && kill "$BPID" 2>/dev/null; rm -f "$HB" "$FIFO"; }

if up; then echo "backend already answering on 3998 (not started by this script; left running)"; else start_backend || exit 3; fi
python3 "$LV/p7_proxy.py" "$PLOG" "$MODEF" >/dev/null 2>&1 &
PPROXY=$!; sleep 1; BASE=http://127.0.0.1:3997; echo "proxy PID $PPROXY on 3997 (started here)"
xcrun simctl uninstall "$SIM" com.eldermin.elderminTeacherApp >/dev/null 2>&1   # this app only; the keychain is NOT reset (owner's other app shares the simulator)
sleep 1
HB="$OUT/.heartbeat"; touch "$HB"; START_T=$(date +%s)
FIFO="$OUT/.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"
flutter test integration_test/p7c_local_test.dart -d "$SIM" \
  --dart-define=API_BASE_URL="$BASE" --dart-define=P7_SCENARIO="$SCEN" --dart-define=P7_SHOT_START="$SHOTSTART" --dart-define=E2E_FLAG_DIR="$FLAGS" \
  --dart-define=P7_IDS="$IDS" \
  --dart-define=LOCAL_TEACHER_EMAIL="${LOCAL_TEACHER_EMAIL:-}" --dart-define=LOCAL_TEACHER_PASSWORD="${LOCAL_TEACHER_PASSWORD:-}" \
  --dart-define=LOCAL_CLASS_EMAIL="${LOCAL_CLASS_EMAIL:-}" --dart-define=LOCAL_CLASS_PASSWORD="${LOCAL_CLASS_PASSWORD:-}" \
  --dart-define=LOCAL_SCHOOL_SLUG="${LOCAL_SCHOOL_SLUG:-}" > "$FIFO" 2>&1 &
FPID=$!
(
  while sleep 10; do
    now=$(date +%s); last=$(stat -f %m "$HB" 2>/dev/null || echo "$now")
    if [ $((now - last)) -gt "${WATCHDOG_IDLE:-180}" ] || [ $((now - START_T)) -gt "${WATCHDOG_MAX:-1200}" ]; then
      echo "WATCHDOG: no new marker for ${WATCHDOG_IDLE:-180}s (or ${WATCHDOG_MAX:-1200}s total exceeded) - aborting run (killing PID $FPID only)"
      pkill -INT -P "$FPID" 2>/dev/null; kill -INT "$FPID" 2>/dev/null; sleep 6; pkill -KILL -P "$FPID" 2>/dev/null; kill -KILL "$FPID" 2>/dev/null
      exit 0
    fi
  done
) &
WD_PID=$!
trap cleanup EXIT
while IFS= read -r line; do
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"; touch "$HB"
             xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$(date +%T) captured $name" ;;
    *DBACTION:*) rest="${line##*DBACTION:}"; rest="${rest%%[[:space:]]*}"; an="${rest%%:*}"; aa="${rest#*:}"; touch "$HB"
             db_action "$an" "$aa" > "$OUT/.act" 2>&1; echo "$(date +%T) action $an:"; sed 's/^/    /' "$OUT/.act"; touch "$FLAGS/$an.flag" ;;
    *RESULT:*|*"MARK "*|*STEP*|*FAILED_STEP*|*P7_DONE*|*SKIPPED*|*Exception*|*"Some tests failed"*|*"All tests passed"*) touch "$HB"; echo "$(date +%T) ${line##*flutter: }" | cut -c1-700 ;;
    *) echo "$line" | cut -c1-400 >> "$OUT/raw.log" ;;
  esac
done < "$FIFO"
wait "$FPID" 2>/dev/null
