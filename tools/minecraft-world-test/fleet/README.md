# Native fleet fixture

Builds real tricopters, quadcopters with reversible drive banks and hot-air balloons in a **disposable copy of the supplied VENATOR world**. Requires the exact modpack and the existing Sputnik graph template in that world; this is not a general-purpose mod for installation in a live server. No third-party binaries or private worlds are distributed.

The fixture also accepts a production clipboard in a **new disposable world**.
This mode works with the `.mrpack` alone; it does not require a private save or
the historical VENATOR ship UUID. Install the server-compatible files from the
pack first, and keep the original Minecraft EULA/settings for that installation.
Set `server-ip=127.0.0.1`, `level-name=world`, and use an empty superflat test world.
Keep the campaign output outside the server directory. The runner preserves
previous working worlds and records the source of each run.

```sh
python tools/minecraft-world-test/fleet/run.py --server /path/to/disposable-server --graph-template platforms/sputnik/dist/mintcraft-hybrid-autopilot.clipboard.txt --probe /path/to/built-probe.jar --java-home /path/to/jdk21 --output /path/to/campaign --architectures tri quad hex octo balloon-lift
```

Choose either `--original-world` or `--graph-template`. The template is copied into
each case's output before launch. Controller/setup/supervisor sources are also
archived there. A process exit of zero does not imply a successful flight: the
runner checks the fixture's completion/export events and returns nonzero for
exceptions, timeouts or incomplete sequences. The separate report scores flight
performance; a completed sequence can still fail every stability criterion.

Additional fixed-rotor constructions are `quad` (four lift rotors, no drive banks),
`hex` and `octo`. Their positions and native sail counts are declared in
`catalog.json`. The report requires actual lateral displacement for these craft;
it cannot award a hold-only result for an unperformed strafe. Helicopter,
fixed-wing aircraft and a V22 transition are not implemented by these additions.

`--controller-for CASE=/absolute/path/controller.lua` selects an explicit writer
for an experiment without silently retuning other cases. Each selected source is
copied, archived and hashed before launch.

To prepare an existing **disposable copy** for viewing, launch the fixture with
`-Dmintcraft.prepareWorld=true -Dmintcraft.exportGraph=/absolute/path/vehicle.clipboard.txt`.
It reloads the actual saved Sable craft, replaces the graph with the seven
production nodes, sets creative motor sources to zero and levers OFF, retains
the Physics Staff lock and sets a nearby creative spawn. It verifies the graph
and source settings before saving/shutting down. `mintcraft-world-export` records
the checks. This mode does not construct another craft or run another flight.
Restore the measured 256 RPM sources explicitly before any later commissioning.

```sh
python tools/minecraft-world-test/build.py --fixture fleet --server /path/to/disposable-server --java-home /path/to/jdk21 --work /tmp/fleet-build
python tools/minecraft-world-test/fleet/run.py --server /path/to/disposable-server --original-world /path/to/pristine-venator --probe /path/to/built-probe.jar --java-home /path/to/jdk21 --output /tmp/fleet-runs --architectures tri quad-balanced quad-turns balloon-lift
```

Use the probe JAR path printed by build.py. Server root must contain copies of production `mintcraft-autopilot-control.lua` as `mintcraft-generic-controller.lua`, the montage setup Lua as `mintcraft-generic-setup.lua`, and operations Lua as `mintcraft-operations.lua`. Check the production manifest for their paths. Requires server-ip=127.0.0.1, level-name=world and a distinct pristine source world; existing working worlds are moved aside, never used as source. Review storage requirements before copying a large world. The runner starts a fresh JVM per case, defaults to a 900-second process timeout and preserves console/fixture output. Never point it at an active server.

Cases: `tri`, `quad-banks` (unbalanced rear propulsion), `quad-balanced` (lateral command mode), `quad-turns` (same geometry, yaw/differential mode), `balloon` (rear propulsion), `balloon-lift` (symmetric vertical-only). Geometry is in catalog.json. The current factory includes later commissioning fixes, a forced chunk ticket and actual clamped burner-setting readback. Archived campaign sources record earlier revisions exactly; rerunning current code is not byte-identical to those earlier cases.

`--wait-for-viewer` waits for the test observer: connect the compatible client manually as MintObserver to the disposable local server (campaign port 25585). It does not launch or restart clients. `--screenshots` indexes matching observer PNG timestamps; capture requires the separate graphical observer instrumentation. Spectator has no physical contact. Client/mod caches may require a fresh client between copied worlds.

Pilot OFF commissioning drives each real shaft at signal10 (expected80RPM), checks direction/thrust, then removes the test transmitter before arming. Native analog transmission input/output sides matter: the Simulated reduction GameTest structure differs from the multiplication structure. Sixteen cloth blocks are placed; actual bearing counts are eight vertical/sixteen horizontal in these constructions, not an assumed half-power coefficient. Read native assembled counts. Balloon warmup uses 20 fresh force observations within5% of measured weight and the actual setter-clamped capacity, not envelope capacity. Missing gas-provider association is recorded separately from zero volume.

The fixed sequence and strict 200-observation final stability criteria are documented in the published report. It is not progressive calibration. Failures propagate into subsequent phases; do not describe chained shock results as isolated trials. One propeller per drive bank is tested. No suspended payload, helicopter or deliberate in-flight mass change is covered.

`report-sputnik-fleet.py` creates per-case reports. `export-clipboard.py` exports only production nodes, restores the known geometry connection, assigns fresh IDs and clears cached inputs/outputs. Verify resulting TXT with tools/VerifySputnikClipboard.java and the actual Sputnik codec. These files are experimental vehicle-specific imports, never live-flight hot swaps.

See platforms/sputnik/reports/minecraft-fleet-0.4.1/README.md for measured results, source provenance, plots and limitations.
