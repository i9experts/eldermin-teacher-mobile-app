#!/bin/bash
cd "$(dirname "$0")/../.."
S=${TMPDIR:-/tmp}/probe_matrix
OUT=$S/matrix; mkdir -p $OUT; : > $OUT/summary.txt
for w in 320 360 375 430; do for sc in 1.0 1.3; do for d in ltr rtl; do
  n=${w}_${sc}_${d}
  flutter test test/widget/academic_screens_test.dart test/widget/assessment_screens_test.dart test/widget/phase7b_screens_test.dart test/widget/phase7c_screens_test.dart test/widget/messaging_screens_test.dart test/widget/reference_screens_test.dart --dart-define=PROBE_W=$w --dart-define=PROBE_SCALE=$sc --dart-define=PROBE_DIR=$d --reporter expanded > $OUT/$n.log 2>&1
  echo "$(date +%T) $n failed=$(grep -c '\[E\]' $OUT/$n.log) $(grep -o '+[0-9]* -[0-9]*: Some tests failed\|+[0-9]*: All tests passed' $OUT/$n.log | tail -1)" >> $OUT/summary.txt
done; done; done
echo DONE >> $OUT/summary.txt
