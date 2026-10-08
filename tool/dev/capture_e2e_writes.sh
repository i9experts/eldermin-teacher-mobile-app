#!/usr/bin/env bash
# Dev-only: runs ONE scenario of integration_test/e2e_writes_local_test.dart against a LOCALLY running backend (NOT staging, no stub),
# takes simulator screenshots on every `SHOT:<name>` marker, and performs the few DB / OS actions the test asks for with
# `DBACTION:<name>:<arg>` / `OSLINK:<name>` markers (stale-client situations: the DB is changed while a screen is open).
# DB writes touch ONLY the isolated database eldermin_teacher_verify (fixed list of actions below; nothing else is executable from the test).
# Credentials are never stored here: export LOCAL_TEACHER_EMAIL/PASSWORD, LOCAL_CLASS_EMAIL/PASSWORD, LOCAL_SCHOOL_SLUG
# (+ E2E_RESET_TOKEN, E2E_RESET_NEW_PASSWORD, E2E_LOGIN_JWT for the deeplink scenario) in the calling shell; they go to --dart-define and are never echoed.
# Usage: tool/dev/capture_e2e_writes.sh <simulator-udid> <out-dir> <hw|lp|marks|remarks|quiz|deeplink> [api-base-url]
# ANTI-LOOP: aborts when no new SHOT marker appeared for WATCHDOG_IDLE s (default 180) or after WATCHDOG_MAX s (default 900). It kills ONLY the
# flutter process it started (by PID, then that process's children) - never `pkill -f`. macOS has no `timeout`, so the script enforces the limits.
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"; SCEN="${3:?scenario}"; BASE="${4:-http://127.0.0.1:3998}"
cd "$(dirname "$0")/../.."
mkdir -p "$OUT"
DBN=eldermin_teacher_verify
FLAGS="${E2E_FLAG_DIR:-$OUT/flags}"; mkdir -p "$FLAGS"; rm -f "$FLAGS"/*.flag
case "$SCEN" in hw) START=10;; lp) START=20;; marks) START=30;; remarks) START=40;; quiz) START=50;; deeplink) START=60;; oslink) START=70;; *) echo "unknown scenario"; exit 2;; esac

mdb() { mongosh --quiet "mongodb://127.0.0.1:27017/$DBN" --eval "$1" 2>&1 | tail -3; }

db_action() { # name arg -> prints only counts
  case "$1" in
    lower_total)   mdb 'const r=db.assessments.updateOne({title:"Unit Test 1 - Mathematics"},{$set:{"subjects.0.totalMarks":20}}); print("lower_total matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    restore_total) mdb 'const r=db.assessments.updateOne({title:"Unit Test 1 - Mathematics"},{$set:{"subjects.0.totalMarks":50}}); print("restore_total matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    verify_row)    mdb 'const a=db.assessments.findOne({title:"Unit Test 1 - Mathematics"}); const r=db.assessment_marks.updateOne({assessmentId:a._id,subject:"Mathematics",studentId:ObjectId("'"$2"'")},{$set:{verified:true}}); print("verify_row matched="+r.matchedCount+" modified="+r.modifiedCount)';;
    manual_verified_mark_for_remaining_5a) mdb 'const at=db.quiz_attempts.findOne({status:"submitted",grade:"Grade 5"}); if(!at){print("no submitted 5-A attempt");} else { const r=db.assessment_marks.insertOne({assessmentId:at.assessmentId,studentId:at.studentId,subject:"Mathematics",schoolSlug:at.schoolSlug,studentName:at.studentName,grade:"Grade 5",section:"A",totalMarks:10,passingMarks:4,obtainedMarks:7,isAbsent:false,isExempt:false,verified:true,enteredBy:"Manual (e2e fixture)"}); print("manual verified mark inserted="+(r.acknowledged?1:0)); }';;
    *) echo "unknown db action";;
  esac
}

# fresh install (keychain reset so the session of an earlier run cannot leak in)
xcrun simctl uninstall "$SIM" com.eldermin.elderminTeacherApp >/dev/null 2>&1
xcrun simctl keychain "$SIM" reset >/dev/null 2>&1
sleep 1
HB="$OUT/.heartbeat"; touch "$HB"; START_T=$(date +%s)
FIFO="$OUT/.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"
flutter test integration_test/e2e_writes_local_test.dart -d "$SIM" \
  --dart-define=API_BASE_URL="$BASE" --dart-define=E2E_SCENARIO="$SCEN" --dart-define=E2E_SHOT_START="$START" --dart-define=E2E_FLAG_DIR="$FLAGS" \
  --dart-define=LOCAL_TEACHER_EMAIL="${LOCAL_TEACHER_EMAIL:-}" --dart-define=LOCAL_TEACHER_PASSWORD="${LOCAL_TEACHER_PASSWORD:-}" \
  --dart-define=LOCAL_CLASS_EMAIL="${LOCAL_CLASS_EMAIL:-}" --dart-define=LOCAL_CLASS_PASSWORD="${LOCAL_CLASS_PASSWORD:-}" \
  --dart-define=LOCAL_SCHOOL_SLUG="${LOCAL_SCHOOL_SLUG:-}" \
  --dart-define=E2E_RESET_TOKEN="${E2E_RESET_TOKEN:-}" --dart-define=E2E_RESET_NEW_PASSWORD="${E2E_RESET_NEW_PASSWORD:-}" \
  --dart-define=E2E_LOGIN_JWT="${E2E_LOGIN_JWT:-}" --dart-define=E2E_LOGIN_JWT2="${E2E_LOGIN_JWT2:-}" > "$FIFO" 2>&1 &
FPID=$!
(
  while sleep 10; do
    now=$(date +%s); last=$(stat -f %m "$HB" 2>/dev/null || echo "$now")
    if [ $((now - last)) -gt "${WATCHDOG_IDLE:-180}" ] || [ $((now - START_T)) -gt "${WATCHDOG_MAX:-900}" ]; then
      echo "WATCHDOG: no new screenshot marker for ${WATCHDOG_IDLE:-180}s (or ${WATCHDOG_MAX:-900}s total exceeded) - aborting run (killing PID $FPID only)"
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
    *DBACTION:*) rest="${line##*DBACTION:}"; rest="${rest%%[[:space:]]*}"; an="${rest%%:*}"; aa="${rest#*:}"; touch "$HB"
             echo "DB action $an: $(db_action "$an" "$aa" | tr '\n' ' ')"; touch "$FLAGS/$an.flag" ;;
    *OSLINK:reset*) touch "$HB"; echo "OS: xcrun simctl openurl (reset-password link, token not echoed)"
             xcrun simctl openurl "$SIM" "eldermin-teacher://reset-password?token=${E2E_RESET_TOKEN:-none}" 2>&1 | head -2
             sleep 3; xcrun simctl io "$SIM" screenshot "$OUT/os_prompt_after_openurl.png" >/dev/null 2>&1 && echo "captured os_prompt_after_openurl" ;;
    *) echo "$line" | cut -c1-300 ;;
  esac
done < "$FIFO"
wait "$FPID" 2>/dev/null
