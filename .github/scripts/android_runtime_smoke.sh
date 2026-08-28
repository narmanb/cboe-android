#!/usr/bin/env bash
set -euo pipefail

PACKAGE="org.openboe.cboe.android"
ACTIVITY="org.openboe.cboe.android/.OpenBoEActivity"
APK="android/app/build/outputs/apk/debug/app-debug.apk"

launch_app() {
  local log_file="$1"
  adb shell am start -W -n "$ACTIVITY" 2>&1 | tee "$log_file"
  grep -q 'Status: ok' "$log_file"
}

adb install -r "$APK"
adb logcat -c
launch_app runtime-launch.txt
sleep 8

adb shell pidof "$PACKAGE" > runtime-pid.txt || true
test -s runtime-pid.txt
adb logcat -d -v threadtime > runtime-logcat.txt
adb exec-out screencap -p > runtime-before-resume.png
adb exec-out screencap > runtime-before-resume.raw
echo "Process PID: $(cat runtime-pid.txt)"
grep -E -i 'OpenBoEAndroid|OpenBoE|sfml-activity|AndroidRuntime|FATAL|DEBUG|SIG(SEGV|ABRT)|cboe|libc' runtime-logcat.txt | tail -n 300 || true

adb shell input keyevent KEYCODE_HOME
sleep 2
launch_app runtime-resume-launch.txt
sleep 5

adb shell pidof "$PACKAGE" > runtime-resume-pid.txt || true
test -s runtime-resume-pid.txt
test "$(cat runtime-pid.txt)" = "$(cat runtime-resume-pid.txt)"
adb exec-out screencap -p > runtime-after-resume.png
adb exec-out screencap > runtime-after-resume.raw
adb logcat -d -v threadtime > runtime-resume-logcat.txt
echo "Resume PID: $(cat runtime-resume-pid.txt)"
grep -E -i 'OpenBoEAndroid|OpenBoE|sfml-activity|AndroidRuntime|FATAL|DEBUG|SIG(SEGV|ABRT)|cboe|libc|EGL' runtime-resume-logcat.txt | tail -n 300 || true
python3 .github/scripts/verify_android_resume.py runtime-before-resume.raw runtime-after-resume.raw

CENTER=$(cat runtime-logcat.txt runtime-resume-logcat.txt | grep 'TUTORIAL_CENTER' | tail -n 1 | sed -E 's/.*TUTORIAL_CENTER ([0-9-]+) ([0-9-]+).*/\1 \2/')
test -n "$CENTER"
set -- $CENTER
echo "Tapping Tutorial at $1,$2"
adb shell input tap "$1" "$2"
sleep 2
adb logcat -d -v threadtime > runtime-after-tap-logcat.txt
grep 'STARTUP_BUTTON_CLICK' runtime-after-tap-logcat.txt

echo "Android runtime smoke passed"
