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

# sensorLandscape can briefly return a portrait-sized surface after launch or
# Home/resume on the emulator. Wait until the actual landscape surface is back
# before comparing screenshots or using coordinates emitted by draw_startup.
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
  echo "OpenBoE did not restore a landscape surface"
  return 1
}

adb install -r "$APK"
adb logcat -c
launch_app runtime-launch.txt

title_ready=0
for i in $(seq 1 35); do
  if adb shell pidof "$PACKAGE" >/dev/null 2>&1; then
    adb logcat -d -v threadtime > runtime-logcat.txt
    if grep -q 'TUTORIAL_CENTER' runtime-logcat.txt; then
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

wait_for_landscape runtime-orientation-before.raw
sleep 1
adb shell pidof "$PACKAGE" > runtime-pid.txt || true
test -s runtime-pid.txt
adb logcat -d -v threadtime > runtime-logcat.txt
adb exec-out screencap -p > runtime-before-resume.png
adb exec-out screencap > runtime-before-resume.raw
echo "Process PID: $(cat runtime-pid.txt)"
grep -E -i 'OpenBoEAndroid|OpenBoE|sfml-activity|AndroidRuntime|FATAL|DEBUG|SIG(SEGV|ABRT)|cboe|libc' runtime-logcat.txt | tail -n 300 || true

adb shell input keyevent KEYCODE_HOME
sleep 1
launch_app runtime-resume-launch.txt
wait_for_landscape runtime-orientation-after.raw
sleep 1

adb shell pidof "$PACKAGE" > runtime-resume-pid.txt || true
test -s runtime-resume-pid.txt
test "$(cat runtime-pid.txt)" = "$(cat runtime-resume-pid.txt)"
adb exec-out screencap -p > runtime-after-resume.png
adb exec-out screencap > runtime-after-resume.raw
adb logcat -d -v threadtime > runtime-resume-logcat.txt
echo "Resume PID: $(cat runtime-resume-pid.txt)"
grep -E -i 'OpenBoEAndroid|OpenBoE|sfml-activity|AndroidRuntime|FATAL|DEBUG|SIG(SEGV|ABRT)|cboe|libc|EGL' runtime-resume-logcat.txt | tail -n 300 || true
python3 .github/scripts/verify_android_resume.py runtime-before-resume.raw runtime-after-resume.raw

# Use coordinates emitted after the landscape surface has returned rather than
# stale pre-Home coordinates from a different transient surface geometry.
CENTER=$(grep 'TUTORIAL_CENTER' runtime-resume-logcat.txt | tail -n 1 | sed -E 's/.*TUTORIAL_CENTER ([0-9-]+) ([0-9-]+).*/\1 \2/')
test -n "$CENTER"
set -- $CENTER
echo "Tapping Tutorial at $1,$2"
adb shell input tap "$1" "$2"

click_ready=0
for i in $(seq 1 10); do
  adb logcat -d -v threadtime > runtime-after-tap-logcat.txt
  if grep -q 'STARTUP_BUTTON_CLICK' runtime-after-tap-logcat.txt; then
    click_ready=1
    break
  fi
  sleep 1
done
if [[ "$click_ready" != "1" ]]; then
  echo "Tutorial tap was not received"
  exit 1
fi

grep 'STARTUP_BUTTON_CLICK' runtime-after-tap-logcat.txt | tail -n 5
echo "Android runtime smoke passed"
