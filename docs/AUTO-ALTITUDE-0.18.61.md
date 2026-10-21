# Measured speeds and world-altitude targets — 0.18.61

The sweep no longer has a configured vertical-speed cutoff. Its measurement
options and confirmation remove that field. Finite fresh vertical speed remains
required data; world/altitude travel, tilt, receiver, ownership and time guards
are unchanged. The 15-second per-level timeout and overall deadline are abort
limits, never triggers to move to the next level. Stable speed still controls
progression as described in [0.18.60](AUTO-ALTITUDE-0.18.60.md).

The independently qualified first-order response model now reports the observed
vertical-speed range and estimates steady speed at intermediate heat levels,
including half levels, strictly within the tested heat interval. The estimate is
`speed = fittedSensitivity * (heat - fittedHover)`. Model identification,
holdout/noise rejection and no-extrapolation gates remain. Intermediate estimates
are not new measurements: the current hardware output remains integer redstone
0–15, and this version does not add untested pulse-width modulation.

In the same Auto altitude tab, Arm hold explicitly arms an already calibrated
configuration at current altitude. Target altitude opens a numeric editor;
Set altitude separately confirms a whole-metre world-altitude target, then uses
the existing authorized flight setpoint API. The caller must own the armed hold.
No target command bypasses calibration or arms control. Apply the measured gain
candidate and complete required physical checks before arming. The live page
shows measured altitude, vertical speed, active target and signed altitude error.
After arming, enter the intended target and confirm Set altitude. It uses world
height, not height above terrain.

The existing PI feedback moves heat according to altitude error and observed
response; the model does not promise that the physical vehicle will stay within
one metre. Gas/thermal inertia, integer actuator resolution, sensor precision and
changing load still determine actual error. No simulated precision claim is made.

Tests cover high measured speed without an imposed speed rejection, retained
world-travel abort, interpolated model speeds without extrapolation, target
confirmation in the consolidated tab, exact target retention and rejection of
foreign-owner/nonfinite target commands. Source and packed runtime checks plus
the exact 0.18.60→0.18.61 upgrade/rollback run under the 1 MB disk fixture.
