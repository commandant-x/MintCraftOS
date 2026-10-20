# ASCENDANCY Implementation Ledger

## Scope And Baseline

User specification: MINTCRAFTOS PROJECT ASCENDANCY, sections 1-30.
This ledger preserves the entire scope, not just the features implemented so far.
Authoritative baseline checked against origin/main: eb37cdcf0e41d042f8f881c8b0ecd3e03b54f953
(MintCraftOS 0.18.26, NEXUS 0.4.0). Work proceeds on codex/nexus-bootstrap.

## Architecture Inspection

The paragraphs below describe the inspected baseline. As of 0.18.44 the normal
boot path is the native pixel desktop (256 -> 16 -> diagnostic text fallback).
Terminal, Files, Editor, Messenger, Settings, Devices, Update, Logs, Services, Task Manager, Navigation Flight and the main Combat views have native clients; other
clients/views continue to use isolated text compatibility buffers pending their
explicit migration. Combat's 0.18.35 increment is documented separately.

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
| 24 | Graphics 20-case suite, full integration and ASCENDANCY failure/authorization tests | 107 fast suites, native Files/Flight/Combat/Update/Devices and raw-pointer tests, installed CC Graphics ROM-window emulation, terminal-transport simulation, signed radar agents, verified installer bundle and prior-updater migration; full final gate not met |
| 25 | A-J incremental working releases, graphical completion before strategic expansion | A native workspace usable in emulation, B partial; C-J not complete |
| 26 | Versioned source/tests/docs/changelog/installer/compatibility/migration/limitations | Required per increment; no blanket completion claim |
| 27 | All 18 invariants (no fake APIs/data/performance, bounded work, safety, optional addons, fallback) | Preserve as release gates; real in-game validation still required |
| 28-30 | Complete integrated product; finish graphics before broad new automation | Goal remains active; compatibility backend alone is not success |

## Application Migration Matrix

| Application | Current native client evidence | Remaining final requirements |
| --- | --- | --- |
| Terminal | Native built-in console, bitmap input/caret, wrapped colored records, scroll/follow/selection/local copy, history and tactile keyboard; drawing is cache-only and private commands excluded from completion | In-game input/resize validation, byte/glyph editing expansion, cross-app/system clipboard, long-command responsiveness and richer terminal program/color contracts remain |
| Browser | Legacy reader retained, no new web features | Native client while preserving reader/HTML/JS limitations |
| CraftTube | Hidden legacy app retained | Native client, existing media limitations preserved |
| Messenger | Native wrapped history, draft, keyboard/touch input, Live/scroll/clear and connection/error states; worker-only transport and sequence-based full-inbox delivery | Public chat is unauthenticated/unencrypted; in-game modem/multi-client validation and richer message selection/copy remain |
| NEXUS OVERMIND | Existing 0.4 workflows retained in container | Native WARROOM and later shared ASCENDANCY modules |
| Navigation | Native Flight horizon/metrics, cache-only drawing, stale expiry and hybrid routing; existing calibration/control retained | Remaining panels and in-game sensor/render checks; safety gates unchanged |
| Combat | Native 2D/3D radar, filters/details/lists/network/probe/fire; 20 Hz acquisition target with measured Hz and serial workers; existing fire tokens retained | Native configuration/setup forms, richer keyboard/accessibility, actual in-game acquisition/render validation |
| Files | Native navigation/search/create/rename/trash/restore/copy/cut/paste/properties; descendant permission preflight and no draw acquisition tested | Cross-window clipboard, richer editing/accessibility and Unicode editing coverage |
| Settings | Twelve native sections, cached diagnostics, keyboard/touch controls, renderer/capabilities/dimensions/target/theme and text rescue; serialized service-owned mutations and asynchronous authentication | UI scale remains fixed, performance policy read-only; configurable scaling/performance and real in-game validation remain |
| Task Manager | Native process/metric/renderer/acquisition views, bounded measured charts, backend generations, no draw acquisition and PID-bound delegated kill | In-game validation, richer sorting/search/accessibility; CPU/physical RAM/aggregate network counters remain unavailable rather than invented |
| Logs | Native list/filter/details, live tail, draggable scrollbar and keyboard; reads/parse outside draw; read errors and compact inspector tested | In-game validation, search/copy/export and broader accessibility polish |
| Services | Native cached state/list/details/errors, protected controls and confirmation; serialized manager-owned actions with live permissions and per-service locks | Runtime/performance presentation expansion and actual in-game lifecycle validation |
| Store | Hidden legacy package UI retained | Native package states without inventing a populated catalog |
| Devices | Native cached inventory/search/category/inspector, keyboard and scrollbar, asynchronous metadata, identity-bound Probe results, hotplug invalidation and authorized Display-settings shortcut | In-game peripheral/hotplug validation, richer sorting and independent diagnostic-service lifecycle when Combat is disabled |
| Editor | Native visible-row text/caret/line numbers, selection/drag/literal search, local clipboard, basic Lua coloring and tactile input; existing conflict-safe saves, compile and draft recovery retained | Unicode/grapheme editing, cross-app/system clipboard, large-file draft/write optimization and in-game legibility/input validation remain |
| Update | Native cached versions/source/checkpoint, wrapped diagnostic inspector, keyboard, disabled states; service-owned yielding transaction with single-use source/version-bound confirmations and live caller/session checks | In-game lifecycle validation and broader recovery/fault UX; trusted installer is not a Lua sandbox |

V0.18.39 also connects associated NEXUS agents to Combat through bounded,
signed read-only radar samples. This is not the full ORACLE/CORE milestone.
Source geometry can remain unknown and is not invented. See release notes
for deployment-group/dimension and remote cadence limitations.

No row is marked globally complete merely because the compatibility container
boots. Native client adoption and full feature acceptance are separate gates.

## Validation And Migration

Run tests/graphics.lua and the unchanged regression suites with Lua 5.2.
Run tests/craftos-graphics.lua in a normal visible CraftOS-PC instance with an
isolated storage directory and read-only /source mount. It installs/boots,
opens six legacy apps, checks the physical framebuffer remains visible,
exports indexed bytes for visual inspection, then switches back to text.
Real CC Graphics / CC Terminals in-game behavior remains unverified.

No user config is overwritten to enable graphics. Normal boot now selects the
pixel desktop unless safeMode=true. Settings -> Display -> Requested renderer
offers Automatic pixels, 16-color pixels and confirmed Text rescue. Text rescue
sets safeMode=true; stale graphicsMode="text" alone no longer disables pixels.
Bootloader/recovery always start in text regardless of physical display state.
No external GPU, server changes, browser expansion or flight safety changes.

## Next Gates

V0.18.38: Task Manager is native with honest measured charts and a bounded
sampling history. Source resets and missing counters form gaps; no fake CPU,
RAM percentages or FPS. 100 fast suites pass. See GRAPHICS-0.18.38.md. The
remaining clients, remaining Navigation/Combat forms and full ASCENDANCY scope
are still required; the goal stays active.

V0.18.37: Services is native and UI control runs in a manager-owned yielding
worker. Permission, owner, refusal, concurrency and hidden-confirmation guards
have dedicated tests; 98 fast suites pass. See GRAPHICS-0.18.37.md for real
boundaries and recovery limits. Remaining app migrations and ASCENDANCY stay open.

V0.18.36: Logs is native, with cached acquisition, scrolling and full-message
inspection. Combat's native keyboard delivery is corrected. Fast suites: 96;
visible isolated graphics and terminal-transport scenarios pass. See
GRAPHICS-0.18.36.md. The remaining applications and broader scope stay pending.

V0.18.35: main Combat views now render natively. Acquisition targets 20 Hz,
not a guaranteed source or display rate. See GRAPHICS-0.18.35.md for boundaries,
tests and migration. Configuration/setup remain compatible pending migration;
all sixteen application migrations and the full ASCENDANCY objective remain
required. No strategic-module completion is claimed.

V0.18.34: native client bitmaps are cached by content revision, dimensions
and palette, within the shared 2 MiB payload budget. Moving a window reuses
its content instead of invoking drawPixels for each damaged rectangle.
Mouse dragging coalesces visual frames at 20 Hz; event bus and scheduler
dispatch remain unconditional. Release flushes the final position. Measurement
expiry and flight safety thresholds are unchanged. Fast suites: 94 passed;
visible isolated CraftOS-PC with the installed CC Graphics ROM: passed.
Actual Minecraft telemetry under sustained dragging remains to be validated.

V0.18.41: all twelve Settings sections now use native controls and cached
diagnostics. Configuration changes use a serialized service-owned worker with
live caller/session/permission checks; authentication retains its cancellable
worker. 110 fast suites and isolated native/text/update workflows pass. See
GRAPHICS-0.18.41.md. UI scale and performance policy are still fixed/read-only;
their configurable final-scope controls and other application migrations remain.

V0.18.42: Messenger now has native cached history/input/touch controls and an
asynchronous transport worker. The full-inbox cursor bug is fixed with monotonic
sequences. Public chat remains explicitly unauthenticated/unencrypted, distinct
from NEXUS association. 112 fast suites, twelve-app native/terminal simulations,
text fallback and update/migration gates pass. See GRAPHICS-0.18.42.md.

V0.18.43: Editor now uses native visible-row rendering, caret, line numbers,
selection/drag/literal search, basic Lua coloring and tactile input. Existing
conflict/draft/save/compile protections are retained. 114 fast suites and the
thirteen-app native/terminal workflows pass. See GRAPHICS-0.18.43.md for limits.
Remaining app/forms migration, global UI scale and E-J scope stay required.

V0.18.44: Terminal's existing command engine now has a native cached console,
cursor editing, wrapped colored output, scrolling/record selection/local copy
and tactile input. Private commands bypass completion/history; read commands
gain missing live guards. 116 fast suites and thirteen-app native/terminal,
text fallback and update/migration workflows pass. See GRAPHICS-0.18.44.md.
Remaining app/forms migration, global UI scale and E-J scope remain required.

Continue B: complete reusable controls, UI scale, typography, cursor behavior,
native WM polish and real CC Terminals validation.
Then C: migrate every app, explicitly tracking each of the sixteen, before
calling Graphics 2.0 complete. D benchmarks/themes/polish follows. Only after
the graphical foundation is stable proceed with CORE/ORACLE/ATLAS and E-J.
