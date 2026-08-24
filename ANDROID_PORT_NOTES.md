# Android port notes

This branch is intended to port Classic Blades of Exile to Android while preserving the existing game behavior and content as much as possible.

Initial target:
- Android ARM64 (`arm64-v8a`)
- Landscape orientation
- Existing C++ game code retained
- SFML/TGUI Android backends
- GitHub Actions produces a debug APK for testing

The desktop `master` branch remains untouched while the Android build is developed.
