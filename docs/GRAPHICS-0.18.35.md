# 0.18.35: Native Combat And Radar Acquisition

## Changes

- Native Combat clients for Radar 2D, schematic 3D, Targets, Cannons, Fire,
  Probe and Network. Settings/configuration and the radar setup assistant still
  use the working text compatibility client. The remaining OS applications
  have not all been migrated; this is not a complete Graphics 2.0 release.
- The existing world/body transformation, validation and projection are shared
  with the text renderer through an indexed pixel canvas. Charts use their
  actual client pixel dimensions, not an enlarged terminal mosaic.
- Multi-station range rings, measured cones/heading, bounded contact trails,
  native labels, persistent selection, second-tap deselection, category filters
  and counts. Missing geometry remains unavailable. Names come from existing
  API/alias/identifier normalization, not invented entity models or identities.
- Radar/view selectors, tactile zoom/rotation/tilt, separate details on wide
  windows, pixel lists, Tab/Enter focus, and modal fire confirmation. Narrow
  layouts wrap filters; clients below 180x180 show an enlarge diagnostic.
- Acquisition target changes from 5 Hz to 20 Hz (0.05 seconds). Existing user
  frequencies, geometry, profiles and aliases are not replaced. The service
  normalizes the refresh interval in memory; default configuration is updated.
- Acquisition stays in the serial, yielding periodic worker, never draw().
  Reads are not queued on top of an unfinished cycle. Shared read budgets and
  flight priority are unchanged. Slow diagnostic reads retain their cache.
- The readout distinguishes the 20 Hz target from measured completed-cycle Hz.
  CC ticks, read latency, server load and the number of radars can prevent
  20 completed acquisitions/second. Polling does not increase radar sweep speed
  or make an unchanged scan timestamp into a fresh detection.
- Native chart projection is cached by actual geometry, contacts, labels,
  filters and view inputs. Diagnostic-only revisions do not rebuild the chart.
  Circle trigonometry is precomputed. Existing bounded compositor client caches
  are also reused when dragging.
- Local aim remains permission-checked. Tracking remains 2 Hz. Fire retains
  the existing single-use, short-lived cannon/target-bound confirmation token;
  remote contacts remain display-only. No automatic firing or retry is added.

## Validation And Limits

95 fast Lua 5.2 suites pass, including native chart dimensions, empty/missing
geometry, filter toggles, deselection, bounded layouts, modal isolation,
keyboard focus and cache invalidation. Worker interval and 20 Hz partial-result
publication bounds are asserted. Lua syntax and installer loading are checked.

Visible isolated CraftOS-PC exercises the installed CC Graphics ROM window
API, native desktop/Combat and mode 256/16/text transitions. The text radar
suite explicitly selects safeMode and passes scanner/bearing reads, remote
station aggregation and forty yielding simulated radars. These are emulator
tests, not Minecraft validation or a 20 Hz benchmark on the user's server.

Synthetic framebuffer fixtures are titled SIMULATED RADAR FIXTURE. They affect
only drawing, never combatd's command snapshot or a real peripheral.

Install the pinned release and reboot. No config reset, mod replacement or
world-save modification is needed. Verify actual radar rate, rotating geometry,
pointer selection, resize and multiple windows in Minecraft. Remaining native
application migrations are tracked in ASCENDANCY.md.
