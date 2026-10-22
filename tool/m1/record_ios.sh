#!/bin/zsh
# Dev tool: cold-start the M1 stub app on the booted iOS simulator and record it.
#   record_ios.sh NAME SCENARIO SECONDS   (SCENARIO = loggedout | loggedin | slow, optional extra words `intro` / `reduce`)
# Needs build/ios/iphonesimulator/Runner.app built from tool/m1/m1_stub_main.dart.
U=${M1_UDID:-508001D9-669B-49AD-8D1B-C6F1FCFCE99D}; B=com.eldermin.elderminTeacherApp
R=$(cd "$(dirname $0)/../../../eldermin-teacher-app-docs/design/m1-recordings" && pwd)
xcrun simctl terminate $U $B 2>/dev/null; sleep 1
echo "$2 ${*:4}" > "$(xcrun simctl get_app_container $U $B data)/tmp/m1_scenario"
xcrun simctl io $U recordVideo --codec h264 --force $R/$1.mov >/dev/null 2>&1 & P=$!
sleep 2; xcrun simctl launch $U $B >/dev/null; sleep $3
kill -INT $P; wait $P 2>/dev/null; sleep 1; xcrun simctl terminate $U $B 2>/dev/null
