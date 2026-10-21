# Aircraft autonomy and sublevel equipment — 0.18.49

This release adds an opt-in waypoint pilot to Navigation, with text and native
pixel controls. It uses the installed Sable, Avionics and calibrated output
adapters. No server setting, existing mod JAR, physics force, teleport, assembly
state or chunk-loading policy is changed. It is a controller implementation with
simulated tests; actual aircraft behavior still needs commissioning in Minecraft.

## What it does

- Fly a route of 1–32 **world-coordinate** waypoints. Coordinates identify the
  Sable vehicle's logical origin; they are not GPS estimates or block positions
  inside the plot grid.
- Reach the next point's altitude before requesting horizontal travel. Brake
  existing horizontal drift during the climb, and require a stable arrival dwell.
- Hold the last point's position and altitude. **It does not land automatically
  and does not avoid terrain, buildings, ships or players.** The operator must
  verify the flight corridor and destination clearance.
- Keep the launch heading while translating. This supports hover-capable craft;
  it is not fixed-wing flight control, takeoff, docking or terrain following.
- Continue through the flight service when Navigation is minimized or the console
  is locked. Closing/killing/crashing Navigation applies the existing rescue
  behavior; the owning application must remain running. There is no autonomous
  mission resume after reboot.

There are two explicitly selected translation drivers:

| Driver | Suitable mechanical behavior | Commands |
| --- | --- | --- |
| `thrusters` | Separate forward/reverse and right/left propulsion | Bounded signed demand through dedicated calibrated signal channels |
| `tilt` | A hover-capable craft translates by pitching/rolling | Bounded attitude setpoints, with physically verified forward/right polarity |

Vehicle type or rotor count does not select a driver. Different craft can require
different mappings, limits, gains and signs. The default settings are conservative
software limits, not experimentally identified dynamics for a particular build.

## Commissioning and use

1. Put the Computer on the assembled Sable aircraft. Verify Navigation's world
   position and the sublevel identity. Configure fresh Avionics attitude, heading,
   altitude and rate measurements. A standalone balloon's altitude-only mode
   cannot run a horizontal route.
2. In **Navigation → Actuators**, map owned output endpoints. Complete the
   existing physical direction tests, hover-baseline confirmation, manual-input
   checks and rescue test/confirmation. Tune the existing PID gains. Autonomous
   start does not bypass these requirements and does not arm automatically.
3. For `thrusters`, add dedicated translation channels using `routeForward`,
   `routeReverse`, `routeRight` and `routeLeft` mixer fields. Keep pitch, roll,
   altitude and heading coefficients zero on these channels. Longitudinal and
   lateral outputs must also be separate. Both directions on each axis must be
   mapped and the two translation axes must be independent. Physically test
   propulsion **and braking**, not only a motor's activation.
4. Open **Navigation → Autopilot**. Choose **Add here** to capture a fresh position,
   then edit its X/Y/Z coordinates. Repeat for further points. The selected point
   can be edited or removed. Plans stay in RAM and active missions get a frozen
   copy, so editing the draft does not redirect an aircraft already flying.
5. In **Options**, choose `thrusters` or `tilt`; set speed, gains, limits, arrival
   tolerances, dwell, geofence and timeout. In tilt mode, verify both polarity
   signs. Confirm hover/translation/braking and clear route only after checking
   them on that craft. Verification is bound to the current sublevel UUID and
   is cleared when the driver or polarity changes.
6. **Arm** and read/confirm the stabilization warning. Then **Start route** and
   read/confirm all waypoint coordinates and mission limits. A previously armed
   aircraft can start a route only from its owning Navigation window. Keep that
   window open. Start with a short, clear route and low limits in a test area.
7. **Take over** (or **F10** in Navigation) cancels the mission and returns to manual stabilization at the
   current altitude/heading; it does not promise a stationary position. Configured
   physical pilot inputs and software manual overrides also cancel the mission.
   **Rescue/disarm** uses the physically verified rescue profile. Rescue is not
   assumed to mean signal zero or an immediate safe descent. Native controls keep
   Take over and Rescue visible above the paged actions, including during a
   confirmation dialog.

Directional coefficients are **signal deltas from the calibrated neutral**, not
force units or a guessed engine wiring diagram. For example, a genuinely tested
inverted output with neutral 15 and `routeForward=-6` reduces its signal toward 9
at full forward demand. A non-inverted output may need a positive coefficient.
Set signal bounds to the physically tested range. Do not copy neutral/rescue values or signs from another build. Reverse uses its
own mapped output, or the explicitly calibrated opposite range of a reversible
actuator. Requested direction reversals include one neutral control tick before
the opposing demand is applied, since separate peripheral writes are not atomic.

## Existing ways to interact with the sublevel

The pack lists Sable 2.0.6, CC:Sable 1.3.4, Avionics 0.6.0, Aeronautics 1.3.2,
Create 6.0.10, CC:Tweaked 1.120.2 and CCC Redstone Link 0.1.1. Navigation reuses:

| Capability | Usable route | Boundary |
| --- | --- | --- |
| Identity and pose | CC:Sable `getUniqueId` / `getLogicalPose` | Read the Computer's containing sublevel; no remote physics control |
| Flight instruments | Avionics gimbal, altimeter and navigation table | Fresh, valid selected measurements are required |
| Local signals | Computer analog redstone | Explicitly mapped physical side |
| Remote wired signals | CC redstone relay | Explicit relay name and side; network membership does not prove vehicle ownership |
| Avionics signal outputs | Supported throttle/analog endpoints and `setSignal` | Only the supported, discovered endpoint types |
| Create radio signals | Redstone Link bridge `sendLinkSignal` | Explicit pair of item IDs/colors; shared frequencies may also affect other builds |
| Geometry and equipment | Optional existing MintCraft Vehicle Bridge | Read-only inventory of the loaded parent plot; no automatic motor binding |
| Other peripherals | Devices / NEXUS | Their existing supported APIs and permissions; not arbitrary block access |

The new **Sublevel equipment** view combines cached wired flight endpoints,
optional measured propellers/burners and detected Create link frequencies. It
does not issue discovery-time actuator commands. Links' frequencies and positions
are observations; the connection between a link, shaft and propeller remains a
user-declared, physically checked binding. Use distinct owned frequencies rather
than assuming a color label identifies one motor.

The existing Java bridge remains read-only and is not rebuilt by this release.
Its limits remain 128 loaded chunks, 4,096 block entities and 256 entries per
supported equipment category. Partial discovery stays partial. It does not export
all Aeronautics Diagram forces, recursively enumerate child sublevels or operate
every block in the vehicle. Access to additional equipment requires an actual
exposed peripheral/wired/radio API; no nonexistent general-purpose sublevel setter
is called.

## Guidance and failure behavior

Position samples and UUID are read from the cached Sable service. UUID now travels
with its fast read batch instead of slow diagnostics. Two fresh successive poses
provide velocity in blocks/second, avoiding an assumed conversion for Sable's raw
velocity getters. Position error becomes a bounded desired horizontal velocity;
velocity error is rotated into body forward/right using the measured world
heading. The selected driver then produces tilt setpoints or directional demand.
Altitude correction uses the change in logical-origin world Y, preserving the
sensor's mounted height offset. The existing flight PID/mixer owns all writes.

Default requested speed is 3 blocks/s, tilt limit 5 degrees, horizontal arrival
radius 3 blocks, altitude tolerance 2 blocks, dwell 2 seconds, launch geofence
512 blocks and route timeout 600 seconds. Limits/gains are configurable within
hard bounds. No route can bypass owner permissions, arming, manual priority,
output bounds or the calibrated rescue path. No PID auto-tuning is introduced.

Future/expired/malformed poses, stale identity, changed sublevel, excessive measured
velocity or discontinuity, lost flight measurements, exceeded geofence and timeout
stop guidance. Guidance faults immediately enter the existing rescue path. Owner
loss and failed actuator writes retain their existing failsafe behavior. A new
route requires explicit operator action; there is no automatic rearming.

## Validation and rollback

New fixtures cover two-waypoint settling on a simple simulated plant, heading /
body conversion, both drivers, bounds, immutable active plans, manual takeover,
UUID binding/change, stale/future samples, timeout/geofence, permissions, missing
and mixed mappings, directional braking/deadband, rescue, owner loss and native
confirmation/field handling. These fixtures do not model Minecraft aerodynamics
or prove real-flight PID tuning, collision clearance or network timing.

Validation completed with **136 passing Lua suites on source and 136 on the
packed runtime**, with 312 source/test Lua chunks and 145 packed-tree chunks
compiling. The exact upgrade/rollback fixture peaks at **896,300 bytes**, including
the 100,000-byte personal-data witness (fresh installation with that witness:
784,806 bytes).

The generated compact installer keeps the existing durable rollback mechanism
and personal configuration retention. Exact 0.18.48 → 0.18.49 upgrade/rollback and
interrupted upgrade recovery are exercised on the conservative 1,000,000-byte
disk fixture with 100,000 bytes of personal witness data. Extra retained backups
can still cause a protective space refusal. Disarm before updating or rolling
back. An older release does not implement this autonomous pilot; rollback does
not erase personal files or silently reset control calibration.
