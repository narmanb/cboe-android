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
  local launch_status=0

  # API-35 emulators occasionally return `Status: timeout` from `am start -W`
  # even though the Activity process has already been created and continues
  # starting normally. Do not let that shell status bypass the real verifier:
  # the title-marker, PID, framebuffer, touch and dialog checks below remain
  # authoritative. A launch with neither Status:ok nor a live process still
  # fails immediately.
  set +e
  adb shell am start -W -n "$ACTIVITY" 2>&1 | tee "$log_file"
  launch_status=${PIPESTATUS[0]}
  set -e

  if grep -q 'Status: ok' "$log_file"; then
    return 0
  fi

  if adb shell pidof "$PACKAGE" >/dev/null 2>&1; then
    echo "am start -W returned status ${launch_status}, but OpenBoE is alive; continuing to strict runtime assertions"
    return 0
  fi

  echo "OpenBoE launch failed before a live app process appeared"
  return 1
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

extract_tutorial_center() {
  local log_file="$1"
  local output_file="$2"
  python3 - "$log_file" "$output_file" <<'PY'
import re, sys
log_file, output_file = sys.argv[1:]
text = open(log_file, errors='replace').read()
matches = re.findall(r'TUTORIAL_CENTER\s+(-?\d+)\s+(-?\d+)', text)
if not matches:
    raise SystemExit(1)
with open(output_file, 'w') as out:
    out.write(f"{matches[-1][0]} {matches[-1][1]}\n")
PY
}

adb install -r "$APK"

# A fresh API-35 emulator can cover the app with Android's one-time immersive
# mode confirmation. The failure artifact from the previous strict run showed
# that system overlay instead of OpenBoE, so the adb Tutorial tap never reached
# the game even though the app itself was alive underneath. Match the runtime
# smoke test and acknowledge the emulator-only confirmation before launch.
adb shell settings put secure immersive_mode_confirmations confirmed >/dev/null 2>&1 || true

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

# Persist a known-good title coordinate while the verified landscape title is
# definitely visible. Home/resume does not necessarily redraw the title, and a
# busy emulator can rotate the older marker out of logcat before we tap it.
extract_tutorial_center verify-title.log tutorial-center.txt
test -s tutorial-center.txt
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

# Prefer a freshly-emitted coordinate after resume when available. If the title
# did not redraw (which is valid when the framebuffer and PID remained intact),
# reuse the coordinate captured from the same verified landscape title layout.
if extract_tutorial_center verify-after-resume.log tutorial-center-after-resume.txt; then
  mv tutorial-center-after-resume.txt tutorial-center.txt
else
  echo "No fresh TUTORIAL_CENTER after resume; reusing the pre-resume landscape coordinate"
fi

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

# SFML's Android backend can transiently print context-activation warnings while
# the Activity surface is being recreated. They are not by themselves evidence
# of a broken resume: the process may remain alive and the restored framebuffer
# may be identical. The PID and framebuffer assertions above are authoritative.
if grep -q "Failed to activate the window's context" verify-dialog-after-resume.log; then
  echo "SFML reported transient context activation warnings; PID and framebuffer resume checks passed"
  grep "Failed to activate the window's context" verify-dialog-after-resume.log | tail -n 20
fi

# Still reject an actual app-process crash if one somehow occurs after the
# framebuffer capture but before the verifier completes.
test "$(adb shell pidof "$PACKAGE")" = "$(cat verify-pid-before.txt)"

echo "Android title/touch/dialog/resume verification passed"
