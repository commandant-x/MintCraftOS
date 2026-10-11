# Radar 5 EA read-only API bridge - MintCraftOS 0.18.3

The exact user-provided `create_radar-5.0-EA-3.0.0-1.21.1.jar` has a bearing
`getPosition` method whose receiver is mistakenly StationaryRadarBlockEntity.
Its CC peripheral also lacks the scanner's actual FOV/angle/height. Lua cannot
retrieve those hidden values or locate 40 bearings through wired peripheral names.

## Experimental patched copy

`tools/build-radar-api.ps1` copies the JAR, changes exactly three classes and keeps
all other ZIP entries unchanged. It checks the exact SHA-256 below, refuses an
existing output, rejects signed JARs, and never installs anything in Minecraft.
The bridge only adds read methods: no scan settings, rotation or weapon commands.

Input SHA-256:
`773e0d3bf396d071753de76313dd05ac76be4be0e350255db89e15dfdd7c1b9a`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-radar-api.ps1 -InputJar "C:/Users/monfi/Downloads/create_radar-5.0-EA-3.0.0-1.21.1.jar"
```

JDK 21 is required. The reproducible patcher uses that JDK's bundled ASM; its
implementation never executes code from the input JAR. Original mod binaries
are not redistributed by this repository.

Close Minecraft/server first, preserve the original outside the mods directory,
and replace it with the generated copy. Do NOT leave two copies of Create Radar
in mods. On multiplayer, update the relevant server/client installations together.
This is not an official Radar release. Bytecode stack analysis and Lua mocks pass;
actual NeoForge loading, discovery and physics MUST be tested in game.

## Read contract

Bearing `getPosition()` now has the correct receiver and retains the mod's own
Sable plot-to-world conversion. No coordinate guessing or computer GPS offset.
`getScanGeometry()` runs on the server main thread and returns:

```lua
{ version=1, position={x,y,z}, positionFrame="world",
  heading=number, headingFrame="world" or "body",
  fov=number, halfHeight=number, range=number,
  rotation=number, rotationSpeed=number, dishCount=number, running=boolean }
```

Angle, FOV and half-height come from the same scanningBehavior fields/getters
used by the mod's detector. FOV is not IRadar's generic default. Half-height is
the scanner's vertical band in metres, NOT a guessed vertical cone angle.
Bearings on a Sable plot mark their heading as body-frame; MintCraftOS refuses
to treat this as world heading without a verified transform/calibration.

## One bulk action

Install MintCraftOS 0.18.3, then Combat > Rescan > Auto setup > Confirm on each
source computer. All local bearings with the bridge switch to automatic world
positions in one write. Existing manual coordinates/calibrations remain as backups.
No manual coordinate entry is required for fixed bearings, including 40 wired sensors.
Without the bridge, the OS retains a clear diagnostic instead of inventing origins.
Station publication now accepts up to 64 radar geometries per station; all central
computers must also be updated. Aggregation keeps at most 256 remote geometries.

## Drawing

Both 2D and 3D draw every valid radar's range circle, not just coordinate axes.
Measured beams use green boundaries/ribs and a yellow centreline. Unknown heading
or FOV remains unknown; a range circle is still drawn. A stopped scanner has no
active beam. Multi-radar views use the same geometry, including the actual height
band sent through Rednet. Refresh remains 5 Hz, with no extrapolated/fake sweep.
