#!/usr/bin/env bash
# Dev-only: ONE scenario of integration_test/phase4_checklist_local_test.dart against a LOCAL backend (isolated DB eldermin_teacher_verify; NOT staging, no stub).
# LOCAL verification only. The script starts what it needs and kills ONLY the PIDs it started (never pkill -f):
#   * the backend (local-verification/start_backend.sh, port 3998) unless one already answers there (then it is left alone),
#   * a logging proxy (local-verification/p4_proxy.py, port 3997) for every scenario except `offline` (that one talks to 3998 directly so that a
#     stopped backend means a real "connection refused").
# `DBACTION:<name>:<arg>` markers from the test trigger ONE action of a fixed list (DB writes ONLY on eldermin_teacher_verify, backend stop/start of the
# backend this script started, proxy mode switch). `SHOT:<name>` markers become simulator screenshots in <out-dir>.
# Credentials (dummy) come from the calling shell: LOCAL_TEACHER_EMAIL/PASSWORD, LOCAL_CLASS_EMAIL/PASSWORD, LOCAL_SCHOOL_SLUG; never echoed.
# ANTI-LOOP watchdog: no new SHOT marker for WATCHDOG_IDLE s (180) or WATCHDOG_MAX s (900) -> only the flutter PID started here is killed.
# Usage: tool/dev/capture_phase4_local.sh <simulator-udid> <out-dir> <home|refresh|offline|unreach|cap|tz> [shot-start-number]
set -u
SIM="${1:?simulator udid}"; OUT="${2:?output dir}"; SCEN="${3:?scenario}"; SHOTSTART="${4:-1}"
cd "$(dirname "$0")/../.."
APP="$PWD"; LV="$APP/../eldermin-teacher-app-docs/local-verification"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
DBN=eldermin_teacher_verify; MONGO="mongodb://127.0.0.1:27017/$DBN"
FLAGS="$OUT/flags"; mkdir -p "$FLAGS"; rm -f "$FLAGS"/*.flag
PLOG="$OUT/proxy.log"; : > "$PLOG"; MODEF="$OUT/proxy.mode"; echo forward > "$MODEF"
BPID=""; PPID_PROXY=""
mdb() { mongosh --quiet "$MONGO" --eval "$1" 2>&1 | grep -v -i "warning\|^$" | tail -3; }
up() { [ "$(curl -s -o /dev/null -m 3 -w '%{http_code}' http://127.0.0.1:3998/api/v1/auth/me)" = "401" ]; }
start_backend() {
  nohup "$LV/start_backend.sh" >/dev/null 2>&1 &
  BPID=$!; echo "$BPID" > "$LV/out/p4_backend.pid"
  for i in $(seq 1 30); do up && { echo "backend up (PID $BPID)"; return 0; }; sleep 2; done
  echo "backend did not come up in 60 s"; return 1
}
stop_backend() {
  [ -n "$BPID" ] && kill "$BPID" 2>/dev/null
  for i in $(seq 1 15); do up || { echo "backend stopped (connection refused)"; BPID=""; return 0; }; sleep 1; done
  echo "backend still answering"; return 1
}
db_action() { # name arg -> prints only counts / outcome
  case "$1" in
    backend_stop)  stop_backend;;
    backend_start) start_backend;;
    proxy_blackhole) echo blackhole > "$MODEF"; echo "proxy mode blackhole (accepts, never answers: unreachable host emulation)";;
    proxy_forward)   echo forward > "$MODEF"; echo "proxy mode forward";;
    fixture_change_for_refresh) mdb 'const ua=db.users.findOne({email:"teacher.a@demo-school.local"}); const t=db.message_threads.findOne({subject:"Math help"}); delete t._id; t.subject="P4 refresh new thread"; t.staffHasUnread=true; t.status="open"; db.message_threads.insertOne(t); const n=db.notifications.findOne({recipientUserId:ua._id,isRead:false}); delete n._id; n.title="P4 refresh notif"; n.isRead=false; db.notifications.insertOne(n); print("inserted 1 open unread thread + 1 unread notification for A")';;
    flip_class_teacher_on)  mdb 'const g=db.grades.findOne({name:"Grade 6"}); const r=db.teacherProfiles.updateOne({employeeId:"LV-T-001"},{$set:{isClassTeacher:true,classTeacherOfGradeId:String(g._id),classTeacherOfGradeName:"Grade 6",classTeacherOfSectionName:"A",classTeacherOfName:"Grade 6 - A"}}); print("A isClassTeacher=true modified="+r.modifiedCount)';;
    flip_class_teacher_off) mdb 'const r=db.teacherProfiles.updateOne({employeeId:"LV-T-001"},{$set:{isClassTeacher:false}}); print("A isClassTeacher=false modified="+r.modifiedCount)';;
    cap_on)  ( cd "$LV" && /usr/local/bin/node seed-phase4-checklist.js --cap 2>&1 | grep -E "cap:|FAILED" );;
    cap_off) ( cd "$LV" && /usr/local/bin/node seed-phase4-checklist.js --uncap 2>&1 | grep -E "uncap|FAILED" );;
    cleanup_refresh) mdb 'const a=db.message_threads.deleteMany({subject:"P4 refresh new thread"}).deletedCount; const b=db.notifications.deleteMany({title:"P4 refresh notif"}).deletedCount; db.teacherProfiles.updateOne({employeeId:"LV-T-001"},{$set:{isClassTeacher:false}}); print("cleanup threads="+a+" notifs="+b)';;
    *) echo "unknown action";;
  esac
}
cleanup() {
  kill $WD_PID 2>/dev/null; kill $FPID 2>/dev/null; [ -n "$PPID_PROXY" ] && kill "$PPID_PROXY" 2>/dev/null
  [ -n "$BPID" ] && kill "$BPID" 2>/dev/null; rm -f "$HB" "$FIFO"
}

if up; then echo "backend already answering on 3998 (not started by this script; left running)"; else start_backend || exit 3; fi
BASE=http://127.0.0.1:3998
if [ "$SCEN" != "offline" ]; then
  python3 "$LV/p4_proxy.py" "$PLOG" "$MODEF" >/dev/null 2>&1 &
  PPID_PROXY=$!; sleep 1; BASE=http://127.0.0.1:3997; echo "proxy PID $PPID_PROXY on 3997"
fi
xcrun simctl uninstall "$SIM" com.eldermin.elderminTeacherApp >/dev/null 2>&1
xcrun simctl keychain "$SIM" reset >/dev/null 2>&1
sleep 1
HB="$OUT/.heartbeat"; touch "$HB"; START_T=$(date +%s)
FIFO="$OUT/.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"
flutter test integration_test/phase4_checklist_local_test.dart -d "$SIM" \
  --dart-define=API_BASE_URL="$BASE" --dart-define=E2E_SCENARIO="$SCEN" --dart-define=P4_SHOT_START="$SHOTSTART" --dart-define=E2E_FLAG_DIR="$FLAGS" \
  --dart-define=LOCAL_TEACHER_EMAIL="${LOCAL_TEACHER_EMAIL:-}" --dart-define=LOCAL_TEACHER_PASSWORD="${LOCAL_TEACHER_PASSWORD:-}" \
  --dart-define=LOCAL_CLASS_EMAIL="${LOCAL_CLASS_EMAIL:-}" --dart-define=LOCAL_CLASS_PASSWORD="${LOCAL_CLASS_PASSWORD:-}" \
  --dart-define=LOCAL_SCHOOL_SLUG="${LOCAL_SCHOOL_SLUG:-}" > "$FIFO" 2>&1 &
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
trap cleanup EXIT
while IFS= read -r line; do
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"; touch "$HB"
             xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$(date +%T) captured $name" ;;
    *DBACTION:*) rest="${line##*DBACTION:}"; rest="${rest%%[[:space:]]*}"; an="${rest%%:*}"; aa="${rest#*:}"; touch "$HB"
             db_action "$an" "$aa" > "$OUT/.act" 2>&1; echo "$(date +%T) action $an: $(tr '\n' ' ' < "$OUT/.act")"; touch "$FLAGS/$an.flag" ;;
    *MARK:*) touch "$HB"; echo "$(date +%T) ${line##*flutter: }" | cut -c1-200 ;;
    *) echo "$line" | cut -c1-2500 ;;
  esac
done < "$FIFO"
wait "$FPID" 2>/dev/null
case "$SCEN" in refresh) db_action cleanup_refresh > "$OUT/.act" 2>&1; echo "cleanup: $(tr '\n' ' ' < "$OUT/.act")";; esac
