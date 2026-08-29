# Android Port Next Steps

Current branch: `android-port`

Current migration checkpoint before the responsive-layout pass:
- `f31e8ebbcb1c0d65d870a74f508a7ab96e587c36` — Codeberg monster-facing and trim-mask fixes
- Latest CI for that checkpoint passed ARM64 build, runtime smoke, and strict Android touch/dialog/Home-resume verification.

## Immediate priority: responsive Android UI

Use the current phone layout as the visual reference, but replace device-specific/fixed assumptions with resolution- and aspect-ratio-aware layout rules.

Required work:
1. Gameplay layout
   - scale the main game viewport uniformly to the usable display area
   - derive HUD/stat/inventory sizing from the logical canvas instead of fixed physical pixels
   - anchor minimap, ACT grid, MENU, and D-pad relative to the usable right-side region
   - preserve spacing/proportions on shorter 16:9 devices such as Retroid Pocket 5
   - avoid clipping, off-screen controls, and large unintended dead space

2. Dialog layout/scaling
   - render each dialog in its original logical coordinate space and uniformly scale the whole dialog to fit
   - keep text and button geometry together so labels do not shift, disappear, or clip
   - verify character creation, Save Party, and scenario picker specifically

3. Verification targets
   - current phone layout must remain visually correct
   - 16:9 Retroid-class landscape layout must be usable and correctly proportioned
   - solution must be general Android responsive behavior, not device-specific special cases

## After responsive-layout work

Resume the Codeberg upstream migration from `codeberg-upstream`, continuing the existing rule: transplant useful upstream changes in small coherent batches while preserving all Android-specific UI/input/resume work. Build and verify each meaningful batch; physical Android testing remains authoritative for behavior.
