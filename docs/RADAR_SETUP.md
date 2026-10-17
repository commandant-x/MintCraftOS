# Radar setup / MintCraftOS 0.18.5

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
- Legacy orientation remains unverified until explicitly confirmed. FOV stays unknown
  unless calibrated or exposed by the [read-only API bridge](RADAR_API_BRIDGE.md).
  Bridge-equipped fixed bearings expose real scan geometry and support bulk Auto setup.
  Neither a heading nor a cone is invented for a missing API.
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

### Profile selection and capability evidence

`auto` selects the optional bridge only when `getScanGeometry` is advertised;
otherwise it selects the stock `4.x` compatibility reader, not a detected mod version.
Explicit `4.x` and `5.0-EA` use the stock getter allowlist and never invoke bridge
geometry. EA additionally normalizes the inspected fixed plane's API position as
world coordinates, including on a sublevel; manual coordinates retain their frame.
Explicit `bridge` reads only tracks and geometry v1: a missing, throwing or invalid
geometry method produces an error, not a silent stock fallback.

Setup and the radar diagnostics show the active profile, method evidence, adapter
origin and limitations. A method in the inventory is not proof of a successful read.
The inspected stock 4.x and EA bearing receiver can reject `getPosition`; Setup then
defaults to manual coordinates. Neither stock build exposes native `getScanGeometry`.
Bulk Auto setup requires a valid optional world-frame bridge response. No bridge
installation or Minecraft profile/mod changes are performed by this workflow.

The JAR requires Minecraft 1.21.1, NeoForge 21.1+, Create 6.0.10..<6.1.0 and CBC 5.11.2+;
its optional CC:Tweaked range is 1.113.0..<2.0. These are metadata constraints, not an
instruction to modify the current installation.

## Contact classification and command safety

API-marked friendly contacts appear green; synthetic contacts appear orange. Selection
and stale styling take precedence. The target list also shows FRIENDLY/SYNTHETIC badges.
Neither an absent flag nor `friendly=false` is presented as proof of hostility.
Classification evidence is retained per radar with source scan time, local reception
time and locally observed scan progression. True flags win across sources regardless
of their return order or unrelated source clock values. A duplicate or older scan may
add a safety flag, but cannot clear one; only a verified progressing scan from that
same source with an explicit false boolean can clear its flag. Missing flags or late
unverified progression cannot clear safety evidence. Conservative true evidence is retained until superseded or the contact
is evicted; absence of a radar is not evidence that a target became hostile.
Removed radar names are pruned from source maps; their true flags retire to two
contact-level booleans until contact eviction. Source maps are capped at 128 per
contact; overflow blocks commands until eviction instead of dropping safety flags.
Aim/tracking/fire solutions are refused for friendly or synthetic contacts, including
commands rechecked in the worker.
No new radar controller output method is automatically invoked.

A first observation is display-only, even if its scan tick is numeric. Without a
comparable source clock, commands require a strictly increasing tick from the same
radar within five local seconds of its preceding distinct observation. Duplicate
reads do not extend that window or contact age, and regressions invalidate that
source's verification. Late progression establishes a new baseline, not immediate
authorization. Service restart and contact eviction require verification again.
This proves locally observed progression, not absolute age on an unknown source clock.
Across local stock radars, the retained position uses the shared-world scan tick:
even a verified older source cannot replace a higher scan tick or refresh its age.
Remote stations never participate in command freshness.

Body-frame mount solutions require valid fresh pitch, roll and heading (at most
0.5 seconds old, respecting per-measurement expiry). Pitch and roll must be level
within 0.01 degree numeric tolerance. Inclined/unknown/stale attitude is explicitly
unsupported; no full 3D mount or gravity transformation is claimed. Terrain/world
profiles retain their existing vacuum ballistic estimate. CBC 1.1.1 `fire(false)`
returning false is successful release; a mismatched state or call error remains
uncertain. Single-use manual fire confirmation and no fire retries remain mandatory.

Acquisition targets 5 Hz and the graphical timer remains 20 Hz. This is not a
5 Hz throughput guarantee: with shared concurrency 4 and 16 reads per 50 ms,
40 six-getter cold radars require at least about 0.75 seconds of read budget,
before other services, server scheduling or network latency. Stock range, dish
count and rotation speed are cached for one second; tracks, rotation and position
remain fast reads. Atomic bridge geometry is not split or falsely cached as fresh.
Getter execution start and receipt times are retained separately; cached metadata
keeps its original field time, and bridge position/heading use geometry field time.

Overruns publish completed rows at most 5 Hz. Pending last-known radar/contact
rows keep their original timestamps and pending/stale flags, preserving selection;
commands are blocked during incomplete published cycles. Status includes elapsed
time, completed/pending devices, overrun, configured target rate, measured interval
between complete cycles and shared read-budget counters. No measured cadence is
claimed for the first cycle. Repeated frames do not interpolate, extrapolate or
manufacture observations.

## Validation boundary

Unit tests cover coordinate parsing, cancellation/preserved config, safe defaults,
classification changes and command rejection. A normal-window isolated CraftOS-PC test
covers four wizard sizes, real button save/cancel, missing bearing position, yielding reads
and the EA plane-radar world-frame preset. The real 5.0 EA mod and physical setup still
need in-game verification. Other 5.0 releases are not declared validated by this JAR check.
