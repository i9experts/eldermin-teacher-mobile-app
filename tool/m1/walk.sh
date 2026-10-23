#!/bin/zsh
# Dev tool: record one M2/M3 walkthrough scenario on an iOS simulator and cut stills.
#   walk.sh UDID SCENARIO OUT_PREFIX [KEYBOARD_HEIGHT]     SCENARIO = a..g (see integration_test/m2m3_walk_test.dart)
# Stills: tool/m1/cut_stills.py when $M1_PY (default python3) has numpy + pillow, else the ffmpeg-only cut_stills_ffmpeg.py.
U=$1; W=$2; P=$3; KB=${4:-336}
PY=${M1_PY:-python3}
cd "$(dirname $0)/../.."
RAW=${TMPDIR:-/tmp}/m1_walk_raw.mov; LOG=${TMPDIR:-/tmp}/m1_walk.log
xcrun simctl io $U recordVideo --codec h264 --force $RAW >/dev/null 2>&1 & REC=$!
sleep 2
flutter test integration_test/m2m3_walk_test.dart -d $U --dart-define=M1_WALK=$W --dart-define=M1_KB=$KB 2>&1 | tee $LOG | grep -a "MARK:\|Some tests failed\|All tests passed\|Exception\|Error"
kill -INT $REC; wait $REC 2>/dev/null; sleep 1
if $PY -c "import numpy, PIL" 2>/dev/null; then $PY tool/m1/cut_stills.py $RAW $LOG $P; else python3 tool/m1/cut_stills_ffmpeg.py $RAW $LOG $P; fi
cp $LOG ${P}_test.log
