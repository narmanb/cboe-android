#!/usr/bin/env bash
set -euo pipefail

PACKAGE="org.openboe.cboe.android"
ACTIVITY="org.openboe.cboe.android/.OpenBoEActivity"
APK="android/app/build/outputs/apk/debug/app-debug.apk"

launch_app() {
  local log_file="$1"
  local launch_status=0

  # API-35 emulators occasionally return `Status: timeout` from `am start -W`
  # even though the Activity process is alive and continuing to start normally.
  # Let the real PID/title/frame/touch assertions below decide whether OpenBoE
  # is healthy instead of failing solely on that Android shell timeout.
  set +e
  adb shell am start -W -n "$ACTIVITY" 2>&1 | tee "$log_file"
  launch_status=${PIPESTATUS[0]}
  set -e

  if grep -q 'Status: ok' "$log_file"; then
    return 0
  fi

  if adb shell pidof "$PACKAGE" >/dev/null 2>&1; then
    echo "am start -W returned status ${launch_status}, but OpenBoE is alive; continuing to runtime assertions"
    return 0
  fi

  echo "OpenBoE launch failed before a live app process appeared"
  return 1
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

# A fresh API-35 emulator can cover the first immersive-mode frame with
# Android's own "Viewing full screen" confirmation. If that OS overlay lands
# in the pre-Home screenshot but disappears after resume, the framebuffer
# comparison reports a huge false difference even though OpenBoE is healthy.
# Mark the emulator confirmation as acknowledged before launching the app.
adb shell settings put secure immersive_mode_confirmations confirmed >/dev/null 2>&1 || true

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

# Match the stricter verifier's initial settle period. Besides allowing SFML's
# first landscape surface to stabilize, this keeps transient Android system UI
# out of the baseline even on emulator images that ignore the setting above.
sleep 5
wait_for_landscape runtime-orientation-before.raw
sleep 1
adb shell pidof "$PACKAGE" > runtime-pid.txt || true
test -s runtime-pid.txt
adb logcat -d -v threadtime > runtime-logcat.txt
python3 -c "import re; t=open('runtime-logcat.txt',errors='replace').read(); m=re.findall(r'TUTORIAL_CENTER\\s+(-?\\d+)\\s+(-?\\d+)',t); assert m, 'TUTORIAL_CENTER missing'; print(*m[-1])" > runtime-tutorial-center.txt
test -s runtime-tutorial-center.txt
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

# Prefer coordinates emitted after landscape resume when available. OpenBoE
# does not necessarily redraw the title screen on every resume, so fall back to
# the already-validated pre-Home coordinates if no newer marker was logged.
python3 - <<'PY'
import re
from pathlib import Path
post = Path('runtime-resume-logcat.txt').read_text(errors='replace')
matches = re.findall(r'TUTORIAL_CENTER\s+(-?\d+)\s+(-?\d+)', post)
if matches:
    x, y = matches[-1]
else:
    x, y = Path('runtime-tutorial-center.txt').read_text().split()[:2]
Path('runtime-tutorial-center-active.txt').write_text(f'{x} {y}\n')
PY
read -r tutorial_x tutorial_y < runtime-tutorial-center-active.txt
echo "Tapping Tutorial at ${tutorial_x},${tutorial_y}"
adb shell input tap "$tutorial_x" "$tutorial_y"

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

# Probe a fitted modal at the same landscape emulator resolution. The two title
# button columns are adjacent equal-width rectangles, so the Make New Party
# center is exactly three times the Tutorial center's X value.
adb shell am force-stop "$PACKAGE"
sleep 1
adb logcat -c
launch_app runtime-dialog-launch.txt

dialog_title_ready=0
for i in $(seq 1 35); do
  if adb shell pidof "$PACKAGE" >/dev/null 2>&1; then
    adb logcat -d -v threadtime > runtime-dialog-logcat.txt
    if grep -q 'TUTORIAL_CENTER' runtime-dialog-logcat.txt; then
      dialog_title_ready=1
      break
    fi
  fi
  sleep 1
done
if [[ "$dialog_title_ready" != "1" ]]; then
  echo "OpenBoE dialog probe did not reach draw_startup"
  exit 1
fi
wait_for_landscape runtime-dialog-orientation.raw
sleep 2
python3 -c "import re; t=open('runtime-dialog-logcat.txt',errors='replace').read(); m=re.findall(r'TUTORIAL_CENTER\\s+(-?\\d+)\\s+(-?\\d+)',t); assert m, 'TUTORIAL_CENTER missing'; x,y=m[-1]; print(int(x)*3, y)" > runtime-new-party-center.txt
read -r new_party_x new_party_y < runtime-new-party-center.txt
echo "Tapping Make New Party at ${new_party_x},${new_party_y}"
adb shell input tap "$new_party_x" "$new_party_y"

new_party_clicked=0
for i in $(seq 1 10); do
  adb logcat -d -v threadtime > runtime-dialog-logcat.txt
  if grep -q 'DIALOG_CONTROL_CENTER' runtime-dialog-logcat.txt; then
    new_party_clicked=1
    break
  fi
  sleep 1
done
if [[ "$new_party_clicked" != "1" ]]; then
  echo "Make New Party did not open a clickable modal"
  exit 1
fi
sleep 1
adb exec-out screencap -p > runtime-new-party-dialog.png
test -s runtime-new-party-dialog.png

# The Retroid regression was specifically press-success/release-failure. Use the
# exact physical center emitted by the fitted dialog renderer, tap Cancel, and
# require the control's click handler to dispatch after MouseButtonReleased.
adb logcat -d -v threadtime > runtime-dialog-logcat.txt
python3 - <<'PY'
import re
from pathlib import Path
text = Path('runtime-dialog-logcat.txt').read_text(errors='replace')
matches = re.findall(r'DIALOG_CONTROL_CENTER\s+.*?\s+cancel\s+(-?\d+)\s+(-?\d+)', text)
assert matches, 'Cancel control center missing from fitted dialog log'
x, y = matches[-1]
Path('runtime-dialog-cancel-center.txt').write_text(f'{x} {y}\n')
PY
read -r cancel_x cancel_y < runtime-dialog-cancel-center.txt
echo "Tapping fitted dialog Cancel at ${cancel_x},${cancel_y}"
adb shell input tap "$cancel_x" "$cancel_y"

cancel_clicked=0
for i in $(seq 1 10); do
  adb logcat -d -v threadtime > runtime-dialog-after-cancel-logcat.txt
  if grep -q 'DIALOG_CONTROL_CLICK cancel' runtime-dialog-after-cancel-logcat.txt; then
    cancel_clicked=1
    break
  fi
  sleep 1
done
if [[ "$cancel_clicked" != "1" ]]; then
  echo "Fitted dialog Cancel press did not survive MouseButtonReleased mapping"
  exit 1
fi
adb exec-out screencap -p > runtime-new-party-after-cancel.png
test -s runtime-new-party-after-cancel.png
grep 'DIALOG_CONTROL_CLICK cancel' runtime-dialog-after-cancel-logcat.txt | tail -n 3

echo "Android runtime smoke passed"
