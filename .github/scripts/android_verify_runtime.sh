#!/usr/bin/env bash
set -euo pipefail

PACKAGE="org.openboe.cboe.android"
ACTIVITY="${PACKAGE}/android.app.NativeActivity"
APK="android/app/build/outputs/apk/debug/app-debug.apk"

capture_failure_diagnostics() {
  set +e
  adb logcat -d -v threadtime > verify-failure-logcat.txt
  adb shell dumpsys activity exit-info "$PACKAGE" > verify-exit-info.txt 2>&1
  adb shell dumpsys activity activities > verify-activities.txt 2>&1
  adb shell ps -A > verify-ps.txt 2>&1
  adb exec-out screencap > verify-failure.raw 2>/dev/null
}
trap capture_failure_diagnostics ERR

adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$ACTIVITY"

# Require the real OpenBoE title screen, not Android's launch splash.
title_ready=0
for i in $(seq 1 35); do
  if adb shell pidof "$PACKAGE" >/dev/null 2>&1; then
    adb logcat -d -v threadtime > verify-title.log
    if grep -q 'TUTORIAL_CENTER' verify-title.log; then
      title_ready=1
      break
    fi
  fi
  sleep 1
done
if [[ "$title_ready" != "1" ]]; then
  echo "Real OpenBoE title screen did not appear"
  exit 1
fi

adb shell pidof "$PACKAGE" > verify-pid-before.txt
test -s verify-pid-before.txt
grep 'TUTORIAL_CENTER' verify-title.log | tail -n 5
adb exec-out screencap > verify-before.raw

# Prove title-screen Home/resume keeps the same process and a usable frame.
adb shell input keyevent KEYCODE_HOME
sleep 1
adb shell am start -W -n "$ACTIVITY"
sleep 3
adb shell pidof "$PACKAGE" > verify-pid-after.txt
test -s verify-pid-after.txt
test "$(cat verify-pid-before.txt)" = "$(cat verify-pid-after.txt)"
adb logcat -d -v threadtime > verify-after-resume.log
adb exec-out screencap > verify-after.raw
python3 .github/scripts/verify_android_resume.py verify-before.raw verify-after.raw

# Tap Tutorial and require actual modal entry, not only the pressed-blue marker.
python3 -c "import re; t=open('verify-after-resume.log',errors='replace').read(); m=re.findall(r'TUTORIAL_CENTER\\s+(-?\\d+)\\s+(-?\\d+)',t); assert m, 'TUTORIAL_CENTER missing'; print(*m[-1])" > tutorial-center.txt
test -s tutorial-center.txt
read -r tutorial_x tutorial_y < tutorial-center.txt
echo "Tapping Tutorial at ${tutorial_x},${tutorial_y}"
adb shell input tap "$tutorial_x" "$tutorial_y"

dialog_ready=0
for i in $(seq 1 12); do
  adb logcat -d -v threadtime > verify-after-tap.log
  if grep -q 'STARTUP_BUTTON_CLICK' verify-after-tap.log && grep -q 'DIALOG_OPEN' verify-after-tap.log; then
    dialog_ready=1
    break
  fi
  sleep 1
done
if [[ "$dialog_ready" != "1" ]]; then
  echo "Tutorial tap never progressed into cDialog::run"
  exit 1
fi

test "$(adb shell pidof "$PACKAGE")" = "$(cat verify-pid-before.txt)"
grep -E 'STARTUP_BUTTON_CLICK|DIALOG_OPEN' verify-after-tap.log | tail -n 10
adb exec-out screencap > verify-dialog.raw
python3 .github/scripts/verify_android_changed.py verify-after.raw verify-dialog.raw

# Prove Home/resume while the inline modal is open.
adb shell input keyevent KEYCODE_HOME
sleep 1
adb shell am start -W -n "$ACTIVITY"
sleep 3
adb shell pidof "$PACKAGE" > verify-dialog-resume-pid.txt
test -s verify-dialog-resume-pid.txt
test "$(cat verify-pid-before.txt)" = "$(cat verify-dialog-resume-pid.txt)"
adb logcat -d -v threadtime > verify-dialog-after-resume.log
adb exec-out screencap > verify-dialog-after-resume.raw
python3 .github/scripts/verify_android_resume.py verify-dialog.raw verify-dialog-after-resume.raw

if grep -q "Failed to activate the window's context" verify-dialog-after-resume.log; then
  echo "SFML context activation failure detected"
  grep "Failed to activate the window's context" verify-dialog-after-resume.log | tail -n 20
  exit 1
fi

echo "Android title/touch/dialog/resume verification passed"
