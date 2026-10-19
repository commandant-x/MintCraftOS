# 0.18.33: Native Navigation Flight Instruments

## Delivered

- Flight is a native pixel client, not an enlarged character/mosaic image. The
  horizon uses row partitions and clipped ladder/reference lines. Geometry is
  cached by size/displayed attitude (0.1 degree precision), reusing its buffer.
  The existing pitch sign and 60-degree vertical scale remain.
- Native altitude, vertical speed, heading (+Z=0), speed, mass and control state.
  Wide clients have a separate instrument panel; compact clients show metrics
  which fit. View menu and Control are tactile.
- 0.2-second UI refresh collects service snapshots outside drawing. No native
  draw reads peripherals/FS. No 20 Hz acquisition claim is made.
- Fresh attitude is MEASURED; display-only hold lasts at most one second and is
  STALE. Missing attitude is blank, not level. Numeric values expire by source
  deadline; future observations are refused. Expiry is rechecked during drawing
  so restoring a minimized window cannot show old numbers as live.
- Buttons select views or call existing Rescan. No native button arms, changes
  gains or commands actuators. Calibration/mapping/confirmation/control keep
  their existing permission-checked implementation and cleanup.
- Hybrid routing preserves every view: Flight uses pixels; other Navigation
  pages retain their current UI until migrated. Unknown vehicle still opens
  Vehicle setup: choose Flight from Views. `{page="flight"}` selects the
  instrument view without changing/validating the vehicle profile.
- Native clients no longer build redundant legacy text images. Dirty revisions
  still propagate. Hybrid transitions release unused bitmap caches. Text rescue
  clears native routing and restores the original renderer.
- No PID/calibration/rescue/manual-priority/ownership/fire safety is relaxed.

## Validation

94 fast Lua 5.2 suites passed, covering cached geometry, stale/held/missing/future data,
toolbar bounds, expiry after restore, hybrid input routing and no acquisition
in native drawing. Syntax/diff checks and regenerated installer accompany release.

Normal visible CraftOS-PC tests use isolated storage/read-only source plus the
window.lua extracted from installed CC Graphics 0.2.1. They open/maximize native
Flight and capture missing telemetry, then inject a clearly labeled SIMULATED
display fixture for nonzero pitch/roll. Synthetic values never enter the flight
service. Switching to Control must not arm the service.

This is emulation, not an in-game aircraft test. Effective 160x60 game dimensions
and actual sensor/frame semantics still require Minecraft validation.
Native and source-isolated terminal simulations passed at 960x540 with the
installed ROM-window implementation. The synthetic horizon framebuffer was
visually inspected. The text-rescue smoke passed with twelve integrated apps
opening/maximizing/closing. All Lua syntax and staged diff checks passed.

## Remaining

Native Combat radar is next, not delivered here. Most Navigation configuration
views and the other OS apps still need migration. This is not complete Graphics
2.0/ASCENDANCY or Minecraft fullscreen control. Prior host config backups and
CC Graphics/CC Terminals routing fixes remain intact.
