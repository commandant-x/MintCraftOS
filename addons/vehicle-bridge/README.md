# MintCraft Vehicle Bridge 0.2.1

Standalone, read-only NeoForge addon. It exposes the containing Sable vehicle to
ComputerCraft as the global `mintcraft_vehicle` API. No existing mod is patched.

0.2.1 corrects burner association: `hasBalloon` means a positive-capacity balloon
reference whose heater collection contains this burner. Aeronautics 1.3.2
`ServerBalloon.isValid()` actually tests filled/target gas amounts, so it is now
exported only as `gasActive`, never used as proof of structural association.
This allows associated empty balloons without bypassing missing-heater checks.

This build also compiles against the profile's Sable 2.0.6 using
`-PsableJar=sable-neoforge-1.21.1-2.0.6.jar` (default remains 2.0.5).

## Installation

1. Stop Minecraft/the server normally. Back up the world before trying a new mod.
   Remove the previous Vehicle Bridge JAR when replacing it; do not keep two versions.
2. Add `dist/mintcraft-vehicle-bridge-1.21.1-0.2.1.jar` to the chosen profile's
   `mods` directory, alongside CC:Tweaked, Sable, Create and Aeronautics.
   For multiplayer, install on the server and clients using that modpack.
3. Restart Minecraft. Place the computer on the assembled Sable vehicle.
4. Update MintCraftOS to 0.18.15 or later. Open Navigation > Vehicle > Discover.
5. Review/import the measured model, confirm the suggested vehicle type and axes,
   then Save. Outputs and motor commands are never created by discovery.
   Existing command channels can select a `Measured actuator #` to reuse its
   geometry. That association is declared by the user and still needs physical
   calibration; it does not infer a shaft/redstone connection.

The build does not install itself, modify mod JARs, change a world or launch
Minecraft. In-game validation is still required; compile/tests are not a claim
of compatibility with every pack or live vehicle.

## API

`mintcraft_vehicle.status()` returns schema/version/read-only capabilities.
`mintcraft_vehicle.snapshot()` runs on the server thread and returns:

- `ok`, `code/error` for absence/API failures, `schema = 1`, `readOnly = true`;
- `vehicleId`, `name`, `frame = "body_plot"`, `originPlot`;
- `mass`, `centerOfMass`, `inertia` when mass data are valid;
- `actuators`: IDs, block IDs, center positions, positive-thrust directions,
  active state, signed/scaled thrust, active force and torque per unit thrust;
- `links`: Create redstone-link position, receiver/transmitter, both frequency
  items/colors and current signal; not an inferred motor wiring diagram;
- `features.burners`, `burners`: heater positions, signal, gas output and balloon
  association. Heater coordinates are not buoyancy force application points.
- sample revision/game tick, cache age, limits, errors and completeness.

Coordinate contract: positions and COM are in the unrotated parent plot frame,
translated by the integer `getCenterBlock()` origin. Block centers include +0.5.
Sable mass data are stored in plot coordinates; translating both COM and force
points preserves moment arms. Inertia is row-major, about the COM, in plot axes.
This is not a world-coordinate snapshot. Vehicle forward is not inferred.

Mass is labelled `sable_mass`; forces are `pixel_newton`, matching the inspected
Aeronautics getter/tooltip convention. No unverified SI conversion is applied.
MintCraftOS retains its user kg calibration and displays raw bridge mass separately.

Orientation-based roles and rotor-count-based vehicle types are suggestions.
Reaction torque, power polarity, geared shafts, wireless control links, servo
response, aerodynamic surfaces, balloon forces and child sublevels are not
automatically modelled. Imported geometry is analysis data, not actuator calibration.

With the corresponding OS changes, detected burners open a collective-altitude
setup guide. See `../../docs/BALLOON_SETUP.md`. It proposes one item pair and
requires wiring confirmation; it never sends power or arms automatically.

## Scope and Limits

Only the computer's containing server sublevel is visible. No remote world scan,
chunk load, assembly, output write or physics mutation is performed. Loaded plot
chunks are bounded to 128, block entities to 4096, propellers and links to 256
each. Limits/errors mark the loaded inventory partial; the OS refuses to import
a partial model as complete. Even a complete result describes loaded parent-plot
block entities, not every possible force provider in an Aeronautics Diagram.

Snapshots are cached for 20 game ticks per vehicle in a weak-key cache, shared
between computers. Lua acquisition runs at 1 Hz; cached getters/draw perform no
acquisition. Repeated revisions do not refresh local measurement freshness.

Inspected/compiled against Minecraft 1.21.1, NeoForge 21.1.244, CC:Tweaked 1.120.2,
Sable 2.0.5, Aeronautics 1.3.2 (bundled) and Create 6.0.10. Avionics is not required
by the Java bridge. Wider declared patch ranges require commissioning, not blind
assumption of unchanged internal APIs.

## Rebuild

Requires JDK 21 and read-only copies of the listed installed mod JARs:

```powershell
$env:JAVA_HOME = 'C:/Program Files/Java/jdk-21'
.\gradlew.bat --no-daemon '-PmodsDir=C:/path/to/profile/mods' build
```

The wrapper pins Gradle 9.2.1 and its official distribution checksum. Build tasks
extract nested compile dependencies only under `build/local-deps`; none are
bundled into the output. `build/libs` contains the standalone addon. Six Java
tests check origin/torque math, invalid numbers, roles, main-thread annotation,
the bytecode's read-only public surface and absence of chunk-loading/world-write
calls. They do not start a Minecraft world.
