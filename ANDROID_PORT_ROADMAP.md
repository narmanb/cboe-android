# OpenBoE Android Port Roadmap

This file tracks Android-specific work that must not be lost while the desktop UI is progressively replaced. Physical-device testing is authoritative; CI success alone does not prove an interaction works correctly on Android.

## Current near-term priorities

1. **Physically validate the v14 native Android Preferences page.**
   - File -> Preferences should remain inside the native Android MENU overlay.
   - Verify every retained setting changes and persists correctly.

2. **Repair the runtime-smoke CI harness.**
   - The embedded Android ARM64 workflow currently launches the obsolete `android.app.NativeActivity` component and therefore reports a false failure before OpenBoE starts.
   - Update the harness to launch the current OpenBoE Android activity.
   - Revisit stale startup assertions such as the old Tutorial-center tap once the correct activity is running.
   - Keep physical-device testing as the final authority even after this test is repaired.

3. **Fix save-slot / New Party save behavior.**
   - Slot 1 works, while other slots can overwrite/reuse `NewParty.exg` or fail to save.
   - Trace the actual in-game picker/save path before changing code.
   - `nav_put_party()` may be involved but is not assumed to be the entire cause.

4. **Begin the wider real-world viewport experiment only after the current direct panel controls remain physically stable.**
   - First target: 11x9 real terrain tiles, not a stretched 9x9 image.
   - Coordinate renderer loops, visibility/fog/light arrays, characters, items/fields, hit testing, animations/effects, and town/combat/outdoor assumptions rather than changing one draw loop in isolation.

## Deferred Android UI work

### Combat and spell targeting — REQUIRED

The old Preferences dialog exposed keyboard-specific targeting choices (`TargetLock` and `DirectionalKeyScrolling`). Those desktop controls are intentionally absent from Android Preferences, but the underlying gameplay problem must be solved before combat is considered complete.

Planned direction:
- Reuse the existing on-screen D-pad contextually while a spell/attack target is active rather than permanently adding another set of arrows.
- Decide whether D-pad input moves the target cursor, pans the camera, or switches between those behaviors according to the active targeting state.
- Preserve the useful concept behind `TargetLock` — automatically positioning the view so useful targets are visible — if it improves touch play.
- Test targeting ranges, off-screen targets, cancellation/Android Back, multi-target spells, and combat camera movement on a physical device.

### Mobile UI / text accessibility scaling — REQUIRED, but not the old desktop implementation

The desktop `UIScale` preference is retired on Android because the Android layout is independently positioned in physical screen coordinates. However, Android should eventually have its own accessibility-oriented control if testing shows text/buttons need user-adjustable sizing.

Possible future control:
- Compact / Normal / Large mobile UI, or a limited mobile scale slider.
- Must scale native Android controls coherently without breaking the world viewport or recreating desktop window scaling.

### Mobile minimap sizing / visibility — REQUIRED TO EVALUATE

The desktop `UIScaleMap` preference is not appropriate for Android as-is. Once the final gameplay layout is more stable, evaluate native choices such as:
- minimap size,
- minimap visibility,
- possibly compact/normal/large presets.

Do not restore the desktop minimap-scale widget directly.

### Autosave advanced settings — BACKLOG

v14 exposes Autosave On/Off only. The old `pref-autosave` Details dialog is another desktop-form UI and is intentionally not opened from the Android page.

Later:
- Inspect which advanced autosave controls materially matter on Android (for example maximum retained autosaves).
- Rebuild only useful controls in a touch-native page/subpage instead of embedding the old dialog.

### Tutorial / instant-help / general popup modernization — BACKLOG

Existing help/tutorial dialogs remain usable but can be too small and desktop-oriented on a phone/handheld.

Later audit:
- tutorial/instant-help text sizing,
- touch target sizing,
- dialog width/height and centering,
- Android Back behavior,
- whether common informational popups should use a native/mobile presentation while preserving game content.

This is not required before the current gameplay UI and targeting systems are stable, but it should not be forgotten.

## Preferences intentionally retired on Android

These items are **not** missing work unless a new Android-specific need appears:

| Desktop preference | Android decision |
| --- | --- |
| Display alignment: Top Left / Top Right / Center / Bottom Left / Bottom Right | **Retire.** This positions/scales a desktop game window. Android uses its own responsive landscape layout. |
| Small Window (not full screen) | **Retire.** Desktop window-mode concept; Android remains immersive/full-screen. |
| Use in-game save file browser | **Retire the toggle, not the functionality.** Android should use the in-game picker as platform policy. Save-picker correctness remains required work. |

## Preferences removed from the Android page but represented elsewhere in this roadmap

| Old setting | Android plan |
| --- | --- |
| UI Scale (`UIScale`) | Replace, if needed, with Android-native accessibility/UI sizing. |
| Minimap Scale (`UIScaleMap`) | Replace, if useful, with Android-native minimap size/visibility controls. |
| Target Lock (`TargetLock`) | Fold the useful behavior into the mobile combat/targeting system. |
| Directional Key Scrolling (`DirectionalKeyScrolling`) | Replace with contextual D-pad targeting/camera behavior. |
| Autosave Details | Rebuild useful advanced options as a touch-native subpage later. |

## Current Android behavior that must be preserved

- Eight-direction D-pad movement works physically; do not rewrite it without a new physical regression.
- Android Back works with the full map and native menu hierarchy.
- Desktop TGUI menubar remains hidden on Android.
- Modal dialogs must remain isolated from gameplay-panel touch routing.
- Party Stats, Inventory, and Transcript panels remain part of the Android layout.
- Panel actions should call real engine actions directly rather than restoring generic desktop-coordinate mouse remapping.
- App-switch/minimize/resume behavior that is physically working must not be reopened without a demonstrated regression.

## Testing policy

- ARM64 compilation success means the APK is buildable, not that UI behavior is correct.
- Emulator smoke tests are useful only when their harness is valid.
- Physical-device results override emulator assumptions for touch, Android Back, lifecycle/resume, layout, and controller behavior.
