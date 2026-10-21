# Automatic altitude measurements and PI candidate — 0.18.55

Historical release description. For the current unified, stability-driven workflow, see [0.18.60](AUTO-ALTITUDE-0.18.60.md).

Navigation → Views → **Auto altitude** (also in Calibration actions) provides a
bounded flight experiment. It defaults to heater levels **7 through 15**, one
level at a time, **6 seconds per level**, a **120-second** overall deadline,
**8-block** altitude/world-travel limit and **1 block/s** vertical-speed limit.
Options are editable within explicit bounds: heat 1–15 with at least three levels,
dwell 4–15 seconds, travel 1–32 blocks, speed 0.1–2 blocks/s, timeout 10–180 seconds.
The whole requested sequence must fit its deadline. These defaults are limits,
not an assertion that 7 is safe or that this range brackets your balloon's hover.

## Workflow

1. Configure one collective burner output in altitude mode. Initialize it and
   physically confirm direction, manual takeover and rescue. Fresh world pose,
   matching containing-vehicle UUID, altitude and vertical-speed telemetry are
   mandatory. Hover and PID gains need not already be calibrated, since those are
   the quantities being investigated. The output must use a unit altitude mix.
2. Check the area and choose an appropriate range, especially if the balloon
   already climbs below 7. Start sweep opens a read-through confirmation containing
   the frozen range, vessel identity, all limits and rescue value. Every page must
   be displayed before CONFIRM, including on small windows. A changed underlying
   control configuration refuses start and requires review again.
3. CONFIRM starts actual actuation. The service durably marks an interrupted
   operation **before** issuing a heater command. On boot an interrupted sweep
   requests rescue, never resumes the experiment. The service owns all writes and
   existing configured signal/rescue limits continue to apply. Inverted wiring
   translates a requested heat level to `15 - heat`; direct wiring transmits heat.
4. Results show each measured level, sample count, min/max altitude, mean vertical
   speed and whether altitude was actually stable. Constant heat can cause steady
   climb: a stable vertical speed is not a stable altitude. A stable-altitude label
   needs at least two seconds of recent data, ≤0.2 block range and ≤0.05 block/s.
5. On completion or abort, apply the configured rescue output. **Save report** then
   writes a uniquely named `/home/user/documents/altitude-sweep-<time>-<n>.cfg` with
   timestamped samples, limits, per-level summaries, model or rejection reason and
   vessel/burner identity. It does not replace an older report and preflights
   durable-write space. Until saved, measurements are in the flight service's RAM;
   they survive closing Navigation but not reboot/restarting that service.
6. If a candidate is justified, **Apply candidate** explicitly saves only proposed
   neutral and PI gains through the existing configuration transaction. It does
   **not** arm or assert hover/manual/rescue/direction success. Saving a changed
   control configuration resets physical calibration as before. Verify the new
   response and complete calibration before separately arming altitude hold.

## Measurement and model

Measurements use fresh, distinct altitude/rate sensor timestamps, at most twice
per second, only after complete, fresh feedback from **every** selected burner
matches the current command and confirms association. A change of level gives
at most two seconds for receiver feedback. Cached pre-command samples cannot
qualify. At least four acknowledged measurements are required for each palier;
maximum storage is 360 samples. This is an identification flight, not a promise
that each level settles to a fixed altitude.

The candidate model is a first-order **vertical-speed** response:

`dv/dt = a*v + b*u + c`, with measured heat `u`, vertical speed `v` and finite
sample differences. Average speed over a sample interval is used in the fit.
At least three levels and twelve dynamic rows are needed, with a nonsingular
regression, full-fit R² ≥ 0.9 and a chronological held-out prediction check.
The inferred time constant must be 0.5–60 seconds and the response positive.

`tau = -1/a`, `k = -b/a`, `hover = -c/b`.

Hover must lie **within the actually tested range**, with measured rates on both
sides of zero and at least one integer signal of control margin in both directions.
No out-of-range extrapolation, all-positive climb extrapolation, constant-response
or noisy-response guess is accepted. A thermal balloon may not fit this model;
then only the observations/rejection reason are retained. Change the test range
or use physical/manual tuning rather than treating a missing model as success.

For a supported model the proposal uses `P = 1/(8*k*tau)`, `I = P/(8*tau)`, `D=0`,
with bounded correction/slew/integral and rounded hover signal. This conservative
PI rule targets the fitted first-order-speed/altitude-integrator model; it is
**not** a guaranteed tune for arbitrary nonlinear/thermal aircraft. Static
altitudes cannot identify all PID terms. D is intentionally not guessed. Time
constant, fit quality and the candidate remain visible for review. No automatic
closed-loop verification flight is included in this release.

## Interruptions and boundaries

**STOP / rescue**, **F10**, a configured physical manual input, closing/killing
the owning Navigation process, revoked permissions/locked session, stale/missing
sensor data, changed/missing pose identity, missing/incomplete inventory, absent
heater acknowledgment, an invalid output or an exceeded limit aborts and queues
rescue. World pose is required throughout: position must stay within the selected
3D travel radius, and body-up tilt must remain within **10 degrees** of world up.
The same travel bound also applies independently to the altitude sensor reading.
A value changing within a positive stage does not extend the acknowledgment wait.

Rescue is the operator's preconfigured and physically verified output. Cutting
gas does not stop motion instantly or guarantee descent, so there must be clearance
outside the software limits as well. The procedure does not add obstacle sensing,
air-traffic avoidance or attitude/horizontal stabilization to altitude mode.
Normal maximum two-second manual calibration pulses remain unchanged; this is a
separate explicitly confirmed bounded experiment, not an implicit longer pulse.

## Validation and rollback

Offline tests identify a known first-order balloon plant and reject noisy,
unidentifiable or unbracketed responses. Service tests cover the complete sweep,
one-second bridge samples, durable preparation, unchanged gains before Apply,
explicit application and invalidated physical flags, report export/quota checks,
configuration changes, stale sensors, tilt, 3D travel, receiver/identity/owner loss,
manual/permission/operator stops, failed startup persistence and reboot rescue.
UI tests verify frozen confirmation values, read-through at 12×9, F10 and bounded
layout. Source/compact regressions and strict 1 MB actual-release update/rollback
and interrupted-write recovery are run. No live Minecraft tuning claim is made.

Use Updates rollback or Recovery to restore the retained release. Current account
credentials and personal data are retained. Saved measurement reports are user
documents and are not deleted by rollback. Vehicle Bridge **0.2.1** remains required;
no new Minecraft JAR is included.

Validation results: **145 source suites and 145 compact-runtime suites pass**;
323 source/test Lua files and 147 installed chunks compile. The exact
0.18.54 → 0.18.55 update/rollback fixture peaks at **909,955 bytes** including
a 100,000-byte user-data witness. Fresh installation with that witness uses
**809,469 bytes**. Interrupted backup/live writes restore the prior release and
retain its durable checkpoint. A stop arriving during a transmitter operation
also returns to rescue rather than allowing that operation to resume the sweep.

## Sable orientation compatibility (0.18.59)

The sweep accepts Sable quaternions represented as `{a=scalar, v={x=..., y=..., z=...}}`, as observed on the deployed server, as well as flat `{x,y,z,w}` named components and numeric arrays. The scalar is mapped to `w`; the vector components retain their axes. No Euler-angle conversion or assumed upright orientation is used. Missing, nonnumeric, nonfinite and zero-norm rotations are refused. The 10-degree tilt guard remains active at start and during the sweep. Offline flight tests use the Sable representation for the complete simulated sweep and exercise all supported layouts against the tilt guard.
