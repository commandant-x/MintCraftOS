# ASCENDANCY Implementation Ledger

## Scope And Baseline

User specification: MINTCRAFTOS PROJECT ASCENDANCY, sections 1-30.
This ledger preserves the entire scope, not just the features implemented so far.
Authoritative baseline checked against origin/main: eb37cdcf0e41d042f8f881c8b0ecd3e03b54f953
(MintCraftOS 0.18.26, NEXUS 0.4.0). Work proceeds on codex/nexus-bootstrap.

## Architecture Inspection

The kernel owns event normalization, services, scheduler and window lifecycles.
The existing compositor renders into a hidden standard window then publishes
changed text rows. WindowManager owns focus, stacking, minimize/maximize and
process cleanup. Each app renders to an isolated text window. renderer,
components, forms, menus, keyboard, icon and subpixel are character-based.
NEXUS already authenticates authorized agents, provisions selected computers,
coordinates bounded read-only observations and reports infrastructure alerts.
Navigation/Combat use cached acquisition services and independent safety checks.
No peripheral acquisition belongs in the new renderer.

Files inspected: kernel/{kernel,scheduler,event_bus,input}, gui/{compositor,
desktop,renderer,components,theme,subpixel,icon,keyboard}, wm/{window,window_manager},
services/{deviced,nexusd,radarnetd,combatd,flightd,avionicsd,sabled,updated},
NEXUS modules/docs, integrated app registrations and Settings, boot/recovery,
installer builder and existing regression/native tests.

## API Evidence

- https://www.craftos-pc.cc/docs/gfxmode : indexed modes, zero-based pixels,
  getSize(mode), byte-string drawPixels rows, freezing and palette semantics.
- https://github.com/sashafiesta/CC-Graphics : upstream source inspected at
  cbf448ab5d10a2b7ba87ccd1e1f733ca2df7fcf4. TermMethodsMixin implements
  graphics-size queries. TerminalWidgetMixin emits zero-based pixel pointers;
  UserComputerInputMixin prevents character-grid clamping.
- https://modrinth.com/mod/cc-terminals : terminal_* source-prefixed events.
  Upstream TerminalInputHandler/TerminalMenu inspected; full display selection
  and pixel-input integration remain pending, not claimed as working.
- Installed mod filenames inspected read-only: CC Graphics 0.2.1,
  CC Terminals 0.1.1 (Minecraft 1.21.1 NeoForge). Upstream source inspection is
  not proof of installed in-game behavior. No mods or worlds were modified.

## Current Increment: Pixel Backend And Compatibility

- backend: active mode probe (256 -> 16 -> text), actual dimensions, freeze
  restoration on all presentation outcomes, bounded indexed surface, metrics.
- surface: zero-based byte rows, clipped spans/fills, changed horizontal regions.
- fonts: embedded BSD Adafruit 5x7 bitmap, 6x9 advance, measurement, scales 1-4,
  explicit pixel rasterization; no screenshot magnification.
- primitives: clipped lines, outlined rectangles, circles, bitmap rows.
- legacy: rasterizes standard offscreen windows and preserves CC mosaic images;
  maps bitmask palettes to indexed palettes; prevents redirected clear() from
  erasing the physical graphics display.
- Existing compositor/kernel select the backend; Settings Display exposes Text,
  Pixel compatibility and Pixel 16 colors. Text remains default for this release.
- Boot/recovery always unfreeze and return to text. Display changes close the
  old backend; graphics presentation failure repaints the full text frame.
- Native computer pixel pointers convert once to existing cell hitboxes;
  original pixel coordinates are retained. Unselected terminal events are ignored.

This is an intermediate compatibility foundation, NOT the completed pixel UI.
Existing controls, icons, window layout and application interfaces still use
cell-based geometry. There is no claim of completed phases A-D or ASCENDANCY.

## Requirements And Proof Gates

| Spec | Required final result | Current evidence / remaining work |
| --- | --- | --- |
| 1-2 | Extend existing OS; inspect current remote and actual integrations; preserve data | Baseline verified; additive backend, existing tests retained |
| 3 | Actual 256/16 pixels, dimensions, detection, resizing, safe fallback | Engine + native test; target/device capabilities UI and all failure paths need expansion |
| 4 | Modular raster, clipping, windows, dirty rectangles, memory limits, metrics | Bounded rows, spans and basic primitives; native pixel compositor/occlusion/sprites/cache pending |
| 5 | Bitmap fonts, wrapping/alignment/accents, readable UI/mono, assets rights | BSD font + scales + measurement; wrapping/alignment/encoding and UI typography pending |
| 6 | Pixel WM, resize/drag/focus/minimize/restore, controls, shortcuts, terminal source routing | Existing cell WM preserved; true pixel controls/geometry and full CC Terminals integration pending |
| 7 | Dark polished desktop, wallpaper, taskbar, icons, menus, search, clock, notifications | Existing desktop rasterized only; redesign pending |
| 8 | All sixteen apps migrated without functionality loss | Six apps native compatibility-smoke tested; all native graphical redesigns pending |
| 9 | Virtual text compatibility preserving input/isolation | Offscreen window raster path and native smoke; cursor/selection/third-party coverage pending |
| 10 | Multiple actual framebuffer benchmarks, load, partial updates | Native 600x306 / 960x540 compatibility smoke and bounded surface test; comprehensive benchmarking pending |
| 11-12 | Shared NEXUS events, schema/source/time/frame/validity/confidence, capability registry | Existing authenticated fleet foundation only; cross-service CORE pending |
| 13 | ORACLE source-preserving fusion/dedup/stale history/alerts, no fake positions | Pending |
| 14 | ATLAS persisted dimension tiles, real terrain adapters, viewport loading, pan/zoom/layers/waypoints/uncertainty | Pending; vehicle localization must not masquerade as terrain |
| 15 | SYNAPSE objectives, dependency plans, reservations, capabilities/authorization, verification/replanning | Existing bounded read-only jobs only; planner pending |
| 16 | DOMINION industrial inventory/stress/speed/logistics, production/resource planning, configured actuation | Existing generic inventory/energy/fluid reads only; new adapters/planning pending |
| 17 | SWARM authorized turtle missions, fuel/location/routes/obstacles/recovery/work reservations | Pending |
| 18 | TACTICAL shared missions/reports/positions/waypoints/team alerts, permissions | Pending |
| 19 | Vehicle identification/world pose/freshness/destination/mission/link in ATLAS/WARROOM | Existing local Navigation stays intact; coordination pending |
| 20 | AEGIS recovery/replication/partition handling/reconciled effects, split-brain protection | Existing provisioning receipts/fallback only; distributed continuity pending |
| 21 | BLACKBOX bounded historical observations/statistics/resource trends/availability/decisions | Existing logs/alerts only; historical module pending |
| 22 | Graphical WARROOM overview/atlas/oracle/synapse/dominion/swarm/tactical/aegis/blackbox | Existing NEXUS UI preserved; integrated pixel views pending |
| 23 | First-run nonblank admin setup, existing permissions, explicit fleet authorization, truthful auth/confidentiality | Blank default admin confirmed in users.lua; first-run migration pending, not silently changed in graphics release |
| 24 | Graphics 20-case suite, full integration and ASCENDANCY failure/authorization tests | Existing 83 suites plus graphics coverage; full final gate not met |
| 25 | A-J incremental working releases, graphical completion before strategic expansion | A in progress; B-J not complete |
| 26 | Versioned source/tests/docs/changelog/installer/compatibility/migration/limitations | Required per increment; no blanket completion claim |
| 27 | All 18 invariants (no fake APIs/data/performance, bounded work, safety, optional addons, fallback) | Preserve as release gates; real in-game validation still required |
| 28-30 | Complete integrated product; finish graphics before broad new automation | Goal remains active; compatibility backend alone is not success |

## Validation And Migration

Run tests/graphics.lua and the unchanged regression suites with Lua 5.2.
Run tests/craftos-graphics.lua in a normal visible CraftOS-PC instance with an
isolated storage directory and read-only /source mount. It installs/boots,
opens six legacy apps, checks the physical framebuffer remains visible,
exports indexed bytes for visual inspection, then switches back to text.
Real CC Graphics / CC Terminals in-game behavior remains unverified.

No user config is overwritten to enable graphics. After updating, choose
Settings -> Display -> Pixel compatibility. Text renderer disables it live;
editing graphicsMode="text" in system.cfg also disables it. A reboot starts
boot/recovery in text regardless of the previous physical display state.
No external GPU, server changes, browser expansion or flight safety changes.

## Next Gates

Finish A with native pixel desktop layout/composition and cursor compatibility.
Then B: native pixel WM and reusable controls, robust target/source adapters.
Then C: migrate every app, explicitly tracking each of the sixteen, before
calling Graphics 2.0 complete. D benchmarks/themes/polish follows. Only after
the graphical foundation is stable proceed with CORE/ORACLE/ATLAS and E-J.
