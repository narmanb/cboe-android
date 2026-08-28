#!/usr/bin/env bash
set -euo pipefail

PACKAGE="org.openboe.cboe.android"
ACTIVITY="org.openboe.cboe.android/.OpenBoEActivity"
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

launch_app() {
  local log_file="$1"
  adb shell am start -W -n "$ACTIVITY" 2>&1 | tee "$log_file"
  grep -q 'Status: ok' "$log_file"
}

# sensorLandscape can briefly expose a portrait-sized surface just after
# Home/resume on the emulator. Do not compare frames or tap coordinates until
# the requested landscape surface has returned.
wait_for_landscape() {
  local raw_file="$1"
  for i in $(seq 1 15); do
    adb exec-out screencap > "$raw_file"
    if python3 - "$raw_file" <<'PY'
import struct, sys
data = open(sys.argv[1], 'rb').read(12)
if len(data) < 12:
    raise SystemExit(1)
w, h, _ = struct.unpack('<III', data)
raise SystemExit(0 if w > h else 1)
PY
    then
      return 0
    fi
    sleep 1
  done
  echo "OpenBoE did not restore a landscape surface after resume"
  return 1
}

adb install -r "$APK"
adb logcat -c
launch_app verify-launch.txt

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
  echo "OpenBoE startup did not reach draw_startup"
  exit 1
fi

sleep 5
wait_for_landscape verify-orientation-title.raw
adb logcat -d -v threadtime > verify-title.log
adb shell pidof "$PACKAGE" > verify-pid-before.txt
test -s verify-pid-before.txt
grep 'TUTORIAL_CENTER' verify-title.log | tail -n 5
adb exec-out screencap > verify-before.raw

adb shell input keyevent KEYCODE_HOME
sleep 1
launch_app verify-resume-launch.txt
wait_for_landscape verify-orientation-resume.raw
sleep 1
adb shell pidof "$PACKAGE" > verify-pid-after.txt
test -s verify-pid-after.txt
test "$(cat verify-pid-before.txt)" = "$(cat verify-pid-after.txt)"
adb logcat -d -v threadtime > verify-after-resume.log
adb exec-out screencap > verify-after.raw
python3 .github/scripts/verify_android_resume.py verify-before.raw verify-after.raw

# Refresh the title log and use coordinates produced after landscape resumed.
adb logcat -d -v threadtime > verify-after-resume.log
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

adb logcat -c
adb shell input keyevent KEYCODE_HOME
sleep 1
launch_app verify-dialog-resume-launch.txt
wait_for_landscape verify-orientation-dialog-resume.raw
sleep 1
adb shell pidof "$PACKAGE" > verify-dialog-resume-pid.txt
test -s verify-dialog-resume-pid.txt
test "$(cat verify-pid-before.txt)" = "$(cat verify-dialog-resume-pid.txt)"
adb logcat -d -v threadtime > verify-dialog-after-resume.log
adb exec-out screencap > verify-dialog-after-resume.raw
python3 .github/scripts/verify_android_resume.py verify-dialog.raw verify-dialog-after-resume.raw

if grep -q "Failed to activate the window's context" verify-dialog-after-resume.log; then
  echo "New SFML context activation failure detected during dialog resume"
  grep "Failed to activate the window's context" verify-dialog-after-resume.log | tail -n 20
  exit 1
fi

echo "Android title/touch/dialog/resume verification passed"
