# Radar setup / MintCraftOS 0.18.2

## Guided setup

Combat / Setup opens a four-stage touch workflow: radar selection, position,
orientation, review/save. Existing calibration is copied into a draft, not overwritten.
Cancel leaves it unchanged. Config remains available for advanced fields/cannon profiles.

- Position is read automatically only when exposed by the peripheral.
- Manual coordinates can be pasted as `X Y Z`, comma-separated or semicolon-separated.
  Centre means the actual block center; Bloc adds 0.5 to all three coordinates once.
  Missing/malformed coordinates are rejected, never filled with zero.
- Monde is the world frame. Sublevel is the actual local/plot coordinate frame and requires
  complete fresh Sable pose for conversion. A fixed manual world position is not accepted
  on a moving sublevel.
- Orientation remains unverified until explicitly confirmed. FOV stays unknown unless
  calibrated. Neither a heading nor a cone is invented for a missing API.
- Small toolbars and field lists page; the global touch keyboard handles coordinate input.
  The wizard never calls peripheral getters from its draw function.

## Inspected Radar 5 build

The user-supplied `create_radar-5.0-EA-3.0.0-1.21.1.jar` was inspected read-only with
JDK `javap -c -p`, including its mod metadata and ComputerCraft class signatures.
SHA-256: `773e0d3bf396d071753de76313dd05ac76be4be0e350255db89e15dfdd7c1b9a`.
No JAR is bundled, modified or installed by MintCraftOS.

The verified radar read contract still uses `getTracks`, `getRange`, and, on the bearing,
`getRotation`, `getRotationSpeed`, `getDishCount`. Track fields are `id`, `position`,
`velocity`, `category`, `scannedTime`, `entityType`, plus boolean `friendly` and `synthetic`.
Reads remain allowlisted; methods discovered by Probe are not automatically invoked.

There is a concrete bearing API signature issue in this build:
`RadarBearingPeripheral.getPosition(StationaryRadarBlockEntity)` accepts a stationary
radar, not `RadarBearingBlockEntity`. This explains why a bearing can expose the other
reads without exposing this one. Capability detection and manual origin remain necessary.

The actual plane-radar `getPosition(StationaryRadarBlockEntity)` implementation converts
Sable plotyard coordinates to a world block position, then returns its center. In the wizard,
select Profil API = `5.0-EA`; an API-backed fixed radar is then preset to Monde so its
position is not transformed a second time. A bearing without this method still needs
manual coordinates. CC does not expose the installed mod version through this read
contract, so Auto is capability detection, not a claimed automatic version identification.
Saved explicit frames/calibrations are never silently rewritten by the acquisition worker.

The JAR requires Minecraft 1.21.1, NeoForge 21.1+, Create 6.0.10..<6.1.0 and CBC 5.11.2+;
its optional CC:Tweaked range is 1.113.0..<2.0. These are metadata constraints, not an
instruction to modify the current installation.

## Contact classification and command safety

API-marked friendly contacts appear green; synthetic contacts appear orange. Selection
and stale styling take precedence. The target list also shows FRIENDLY/SYNTHETIC badges.
Neither an absent flag nor `friendly=false` is presented as proof of hostility.
Flags are updated even when `scannedTime` did not change. Aim/tracking/fire solutions are
refused for friendly or synthetic contacts, including commands rechecked in the worker.
No new radar controller output method is automatically invoked.

## Validation boundary

Unit tests cover coordinate parsing, cancellation/preserved config, safe defaults,
classification changes and command rejection. A normal-window isolated CraftOS-PC test
covers four wizard sizes, real button save/cancel, missing bearing position, yielding reads
and the EA plane-radar world-frame preset. The real 5.0 EA mod and physical setup still
need in-game verification. Other 5.0 releases are not declared validated by this JAR check.
