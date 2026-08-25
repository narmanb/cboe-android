import struct
import sys


def load(path):
    data = open(path, "rb").read()
    if len(data) < 12:
        raise SystemExit(f"{path}: screencap too short")
    w, h, _fmt = struct.unpack_from("<III", data, 0)
    n = w * h * 4
    if w <= 0 or h <= 0 or len(data) < n:
        raise SystemExit(f"{path}: invalid screencap dimensions {w}x{h}")
    return w, h, data[-n:]


if len(sys.argv) != 3:
    raise SystemExit("usage: verify_android_resume.py BEFORE.raw AFTER.raw")

w1, h1, before = load(sys.argv[1])
w2, h2, after = load(sys.argv[2])
if (w1, h1) != (w2, h2):
    raise SystemExit(f"resume screenshot dimensions changed: {w1}x{h1} -> {w2}x{h2}")

pixels = w1 * h1
changed = 0
nonblack = 0
for i in range(0, len(after), 4):
    ar, ag, ab = after[i], after[i + 1], after[i + 2]
    if max(ar, ag, ab) > 20:
        nonblack += 1
    if max(
        abs(before[i] - ar),
        abs(before[i + 1] - ag),
        abs(before[i + 2] - ab),
    ) > 45:
        changed += 1

changed_ratio = changed / pixels
nonblack_ratio = nonblack / pixels
print(f"resume changed-pixel ratio: {changed_ratio:.4f}")
print(f"resume nonblack ratio: {nonblack_ratio:.4f}")
if nonblack_ratio < 0.08:
    raise SystemExit("resume screen is effectively black")
if changed_ratio > 0.15:
    raise SystemExit("resume screen differs too much from the pre-background title screen")
