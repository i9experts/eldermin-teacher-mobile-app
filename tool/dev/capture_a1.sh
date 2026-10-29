#!/usr/bin/env bash
# Dev-only: runs ONE scenario of integration_test/a1_release_local_test.dart on the simulator against a LOCALLY running backend (NOT staging, no stub),
# takes a simulator screenshot on every `SHOT:<name>` marker and performs the few DB actions the scenario asks for with `DBACTION:<name>:`.
# DB writes touch ONLY the isolated database eldermin_teacher_verify (fixed list below; nothing else is executable from the test).
# Credentials are never stored here: export A1_EMAIL / A1_PASSWORD in the calling shell (dummy local accounts); they go to --dart-define.
# Usage: tool/dev/capture_a1.sh <simulator-udid> <out-dir> <base|class|viewonly|noassess|suspended|deactivated|tarbiyah> <api-base-url>
# ANTI-LOOP: aborts when no new SHOT marker appeared for WATCHDOG_IDLE s (default 180) or after WATCHDOG_MAX s (default 900). It stops ONLY the flutter
# process it started (by PID, then that process's children): never `pkill -f`.
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"; SCEN="${3:?scenario}"; BASE="${4:?api base url}"
cd "$(dirname "$0")/../.."
mkdir -p "$OUT"
DBN=eldermin_teacher_verify
FLAGS="$OUT/flags"; mkdir -p "$FLAGS"; rm -f "$FLAGS"/*.flag
case "$SCEN" in base) START=10;; class) START=20;; viewonly) START=30;; noassess) START=40;; suspended) START=50;; deactivated) START=60;; tarbiyah) START=70;; *) echo "unknown scenario"; exit 2;; esac
mdb() { mongosh --quiet "mongodb://127.0.0.1:27017/$DBN" --eval "$1" 2>&1 | tail -3; }
db_action() {
  case "$1" in
    suspend_school)  mdb 'const r=db.tenants.updateOne({slug:"demo-school"},{$set:{status:"suspended"}}); print("suspend matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    restore_school)  mdb 'const r=db.tenants.updateOne({slug:"demo-school"},{$set:{status:"active"}}); print("restore matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    deactivate_staff) mdb 'const u=db.users.findOne({email:"deact.a1@demo-school.local"}); const r=db.staff.updateMany({userId:u._id},{$set:{isActive:false}}); print("deactivate matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    restore_staff)   mdb 'const u=db.users.findOne({email:"deact.a1@demo-school.local"}); const r=db.staff.updateMany({userId:u._id},{$set:{isActive:true}}); print("restore matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    *) echo "unknown db action";;
  esac
}
xcrun simctl uninstall "$SIM" com.eldermin.elderminTeacherApp >/dev/null 2>&1
xcrun simctl keychain "$SIM" reset >/dev/null 2>&1
sleep 1
HB="$OUT/.heartbeat"; touch "$HB"; START_T=$(date +%s)
FIFO="$OUT/.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"
flutter test integration_test/a1_release_local_test.dart -d "$SIM" \
  --dart-define=API_BASE_URL="$BASE" --dart-define=A1_SCENARIO="$SCEN" --dart-define=E2E_SHOT_START="$START" --dart-define=E2E_FLAG_DIR="$FLAGS" \
  --dart-define=A1_EMAIL="${A1_EMAIL:-}" --dart-define=A1_PASSWORD="${A1_PASSWORD:-}" > "$FIFO" 2>&1 &
FPID=$!
(
  while sleep 10; do
    now=$(date +%s); last=$(stat -f %m "$HB" 2>/dev/null || echo "$now")
    if [ $((now - last)) -gt "${WATCHDOG_IDLE:-180}" ] || [ $((now - START_T)) -gt "${WATCHDOG_MAX:-900}" ]; then
      echo "WATCHDOG: no new screenshot marker for ${WATCHDOG_IDLE:-180}s (or ${WATCHDOG_MAX:-900}s total exceeded) - aborting run (stopping PID $FPID only)"
      pkill -INT -P "$FPID" 2>/dev/null; kill -INT "$FPID" 2>/dev/null; sleep 6; pkill -KILL -P "$FPID" 2>/dev/null; kill -KILL "$FPID" 2>/dev/null
      exit 0
    fi
  done
) &
WD_PID=$!
trap 'kill $WD_PID 2>/dev/null; kill $FPID 2>/dev/null; rm -f "$HB" "$FIFO"' EXIT
while IFS= read -r line; do
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"; touch "$HB"
             xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "captured $name" ;;
    *DBACTION:*) rest="${line##*DBACTION:}"; rest="${rest%%[[:space:]]*}"; an="${rest%%:*}"; touch "$HB"
             echo "DB action $an: $(db_action "$an" | tr '\n' ' ')"; touch "$FLAGS/$an.flag" ;;
    *) echo "$line" | cut -c1-300 ;;
  esac
done < "$FIFO"
wait "$FPID" 2>/dev/null
