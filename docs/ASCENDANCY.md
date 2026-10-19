# ASCENDANCY Implementation Ledger

## Scope And Baseline

User specification: MINTCRAFTOS PROJECT ASCENDANCY, sections 1-30.
This ledger preserves the entire scope, not just the features implemented so far.
Authoritative baseline checked against origin/main: eb37cdcf0e41d042f8f881c8b0ecd3e03b54f953
(MintCraftOS 0.18.26, NEXUS 0.4.0). Work proceeds on codex/nexus-bootstrap.

## Architecture Inspection

The paragraphs below describe the inspected baseline. As of 0.18.33 the normal
boot path is the native pixel desktop (256 -> 16 -> diagnostic text fallback).
Files and Navigation Flight have native clients; other clients/views continue
to use isolated text compatibility buffers pending their explicit migration.

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
  Upstream TerminalInputHandler/TerminalMenu inspected; explicit selection and
  pixel-input routing now have unit and native-transport simulation coverage.
  Real Minecraft CC Terminals validation remains pending.
- Installed mod filenames inspected read-only: CC Graphics 0.2.1,
  CC Terminals 0.1.1 (Minecraft 1.21.1 NeoForge). Upstream source inspection is
  not proof of installed in-game behavior. No mods or worlds were modified.

## Current Increment: Native Files And Workstations (0.18.29)

Files now has a native drawPixels/handlePixels client, sharing its existing
filesystem actions with the text fallback. Native and text keyboards share one
layout/press module. Explicit CC Terminals selection, source-scoped events,
bounded geometry polling and permission-checked keyboard-only display recovery
are integrated. App-local views and callback guards isolate graphical failures.
See GRAPHICS-0.18.29.md and PIXEL-APP-API.md for exact evidence and limits.

The 0.18.27 backend now hosts a native dark desktop, retained pixel scene,
bitmap sprite layout, native taskbar/launcher/search/context menus/notifications
and pixel-precise window chrome. Move, resize, maximize/restore, minimize/restore,
focus, source-to-client input and text-mode fallback preserve the original WM
and process ownership. Native widgets are reusable; all-app migration is next.
See GRAPHICS-0.18.28.md for exact tests, behavior and limitations.

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
  Pixel desktop and Pixel 16 colors. Text remains default for this release.
- Boot/recovery always unfreeze and return to text. Display changes close the
  old backend; graphics presentation failure repaints the full text frame.
- Native computer pixel pointers convert once to existing cell hitboxes;
  original pixel coordinates are retained. Unselected terminal events are ignored.

This is NOT the completed OS-wide graphical migration. Desktop/window geometry
is now native pixels; existing application clients still use cell-based controls
inside rasterized containers. There is no claim of completed A-D in-game gates
or finished ASCENDANCY.

## Requirements And Proof Gates

| Spec | Required final result | Current evidence / remaining work |
| --- | --- | --- |
| 1-2 | Extend existing OS; inspect current remote and actual integrations; preserve data | Baseline verified; additive backend, existing tests retained |
| 3 | Actual 256/16 pixels, dimensions, detection, resizing, safe fallback | Engine + native test; target/device capabilities UI and all failure paths need expansion |
| 4 | Modular raster, clipping, windows, dirty rectangles, memory limits, metrics | Retained native scene, clipped damage/opaque occlusion, bitmap sprites, 2 MiB payload cache; extended primitives and benchmark expansion remain |
| 5 | Bitmap fonts, wrapping/alignment/accents, readable UI/mono, assets rights | BSD bitmap + scales, bounded UTF8/CP437 layout/wrap/align/spacing and supported accents tested; richer UI font, full encoding/editing coverage and in-game legibility remain |
| 6 | Pixel WM, resize/drag/focus/minimize/restore, controls, shortcuts, terminal source routing | Native chrome, input fields, shared keyboard, pointer capture, source-isolated terminal routing and F1 integrated; complete widget set, UI scale and in-game checks pending |
| 7 | Dark polished desktop, wallpaper, taskbar, icons, menus, search, clock, notifications | Native dark shell, sprite icons, paged launcher/tasks, search, context menu and dismissible notifications; wallpaper/customization/polish remain |
| 8 | All sixteen apps migrated without functionality loss | Files' existing workflows have native UI; other fifteen app clients and remaining explorer requirements pending (see app matrix) |
| 9 | Virtual text compatibility preserving input/isolation | Offscreen windows rasterized in native chrome with cursor underline; selection/blink/third-party coverage pending |
| 10 | Multiple actual framebuffer benchmarks, load, partial updates | Native 156x180 / 306x171 / 600x306 / 960x540 interaction smoke and bounded surface test; comprehensive benchmarking pending |
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
| 24 | Graphics 20-case suite, full integration and ASCENDANCY failure/authorization tests | 94 fast suites, native Files/Flight/raw-pointer tests, installed CC Graphics ROM-window emulation, terminal-transport simulation and framebuffer inspection; full final gate not met |
| 25 | A-J incremental working releases, graphical completion before strategic expansion | A native workspace usable in emulation, B partial; C-J not complete |
| 26 | Versioned source/tests/docs/changelog/installer/compatibility/migration/limitations | Required per increment; no blanket completion claim |
| 27 | All 18 invariants (no fake APIs/data/performance, bounded work, safety, optional addons, fallback) | Preserve as release gates; real in-game validation still required |
| 28-30 | Complete integrated product; finish graphics before broad new automation | Goal remains active; compatibility backend alone is not success |

## Application Migration Matrix

| Application | Current native client evidence | Remaining final requirements |
| --- | --- | --- |
| Terminal | Compatibility container; paste and authorized display CLI tested | Native terminal UI, scrolling/selection/copy, resize and keyboard coverage |
| Browser | Legacy reader retained, no new web features | Native client while preserving reader/HTML/JS limitations |
| CraftTube | Hidden legacy app retained | Native client, existing media limitations preserved |
| Messenger | Legacy client retained | Native chat input, lists, connection/error states |
| NEXUS OVERMIND | Existing 0.4 workflows retained in container | Native WARROOM and later shared ASCENDANCY modules |
| Navigation | Native Flight horizon/metrics, cache-only drawing, stale expiry and hybrid routing; existing calibration/control retained | Remaining panels and in-game sensor/render checks; safety gates unchanged |
| Combat | Existing radar and safety retained | Native 2D/3D radar, filters/details and confirmed local fire workflow |
| Files | Native navigation/search/create/rename/trash/restore/copy/cut/paste/properties; descendant permission preflight and no draw acquisition tested | Cross-window clipboard, richer editing/accessibility and Unicode editing coverage |
| Settings | Legacy configuration center retained, terminal selector added | Native controls, detected capabilities/UI scale/performance/recovery panels |
| Task Manager | Legacy measured/estimated metrics retained | Native graphs, rendering/network statistics with accurate labels |
| Logs | Legacy filtering and readable records retained | Native list/filter/details with scrolling |
| Services | Legacy protected service controls retained | Native state/actions/error panels |
| Store | Hidden legacy package UI retained | Native package states without inventing a populated catalog |
| Devices | Legacy peripheral list retained, terminal role added | Native inventory/probe/display workflows |
| Editor | Hidden integrated editor retained | Native mono text, selection/caret/scroll/search/save/errors without whole-document redraw per key |
| Update | Legacy update/rollback behavior retained | Native progress, version/state/errors and safe confirmations |

No row is marked globally complete merely because the compatibility container
boots. Native client adoption and full feature acceptance are separate gates.

## Validation And Migration

Run tests/graphics.lua and the unchanged regression suites with Lua 5.2.
Run tests/craftos-graphics.lua in a normal visible CraftOS-PC instance with an
isolated storage directory and read-only /source mount. It installs/boots,
opens six legacy apps, checks the physical framebuffer remains visible,
exports indexed bytes for visual inspection, then switches back to text.
Real CC Graphics / CC Terminals in-game behavior remains unverified.

No user config is overwritten to enable graphics. After updating, choose
Settings -> Display -> Pixel desktop. Text renderer disables it live;
editing graphicsMode="text" in system.cfg also disables it. A reboot starts
boot/recovery in text regardless of the previous physical display state.
No external GPU, server changes, browser expansion or flight safety changes.

## Next Gates

Continue B: complete reusable controls, UI scale, typography, cursor behavior,
native WM polish and real CC Terminals validation.
Then C: migrate every app, explicitly tracking each of the sixteen, before
calling Graphics 2.0 complete. D benchmarks/themes/polish follows. Only after
the graphical foundation is stable proceed with CORE/ORACLE/ATLAS and E-J.
