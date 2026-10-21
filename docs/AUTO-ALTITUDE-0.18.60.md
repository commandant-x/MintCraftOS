# Auto altitude: unified workflow and measured settling — 0.18.60

Open Navigation → Auto altitude. Configure the burner group/frequency once using
the existing Setup guide if it has not been configured. The Auto altitude tab
then contains preflight status, the next required check, options, live results,
report export and candidate application. Options and read-through confirmation
are internal views of the same tab. No automatic arming is added.

## Workflow

1. The next-check button proposes Initialize burners, Verify direction, Manual
   OK, Test rescue, then Rescue OK, according to current service/configuration
   state. Each operation still requires explicit confirmation and physical
   verification when appropriate. Already confirmed initialization is not repeated.
   During an operation the button waits for actual feedback/rescue completion.
2. Options configures the heat range and safety limits. Defaults: heat 7–15,
   maximum 15 seconds per level, 180 seconds overall, 8-block world/altitude travel
   and 1 block/s vertical speed. A lower range is needed if 7 already climbs too
   strongly. The per-level safety limit accepts 4–60 seconds; it is not dwell time.
3. Start sweep retains the full read-through confirmation, frozen options/control
   binding and durable interruption marker before actuation. STOP/F10, physical
   manual takeover, closed/locked owner, lost permission and sensor/pose/receiver
   faults continue to stop the run and apply configured rescue.
4. Live results remain in the tab. Save report exports the measured samples and
   level/model summaries. Apply candidate requires confirmation, writes neutral
   and PI only, resets physical calibration and never arms control.

## Settling criterion

Each level must accumulate eight distinct acknowledged altitude/rate samples,
with at least 3 seconds between the oldest and newest. Collection is capped at
2 Hz, and every adjacent gap in this window must be at most 1.25 seconds. All
samples must be fresh and measured after the current command, with feedback
from every selected burner. The eight-sample tail is bounded.

A level advances only when that measured window has vertical-speed range at most
0.04 block/s and absolute least-squares speed slope at most 0.01 block/s². It may
advance before its per-level safety deadline. If it never settles, expiry aborts
the complete sweep and applies rescue; it never labels that level settled or
advances simply because time passed. Global motion, tilt, time and sample limits
can end a run earlier. Elapsed time remains necessary for freshness and measured
stability; no fixed measurement wait forces advancement.

A steady climb/descent is not a stable altitude. Stable altitude is shown
separately and additionally requires altitude range at most 0.2 block and speed
magnitude at most 0.05 block/s in the same qualified window. The model continues
to use transient samples as well as settled samples. Its identifiability,
noise/holdout and hover-bracketing gates are unchanged; no extrapolation or
unjustified PID proposal is added. PI uses D=0. Long thermal delays or changing
loads can still invalidate this simple model; observed settling is not a flight
certification or a promise of later stationary altitude.

## Compatibility, validation and rollback

The bounded Initialize (2s) receiver/association check remains separate from the
stability-driven measurement flight. Physical direction/manual/rescue confirmations
are not fabricated. Sable scalar/vector quaternions from 0.18.59 remain supported.

Offline tests cover early measured settling, no advancement for oscillation or
slow acceleration, sample-gap rejection, per-level timeout, known simulated
plant identification and guard/rescue integration. UI tests follow all five
preflight actions in the same tab, assert explicit confirmation, verify no
repeated initialization and check narrow viewports. Tests run on source and
packed runtime. No Minecraft physics validation is claimed.

The normal installer retains user data/configuration and a durable checkpoint;
Update rollback restores the previous covered runtime. Existing saved measurements
are not overwritten. An aborted unsaved report remains in RAM until reboot or
flight-service restart. The exact 0.18.59 → 0.18.60 upgrade/rollback is checked
under a 1,000,000-byte quota with a 100,000-byte user-data witness.
