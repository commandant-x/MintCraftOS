# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains V0.18.71:

V0.18.71 measures a settled height at each heat level only after eight fresh
samples with absolute vertical speed <=0.1 m/s. There is no sweep/level/sample
expiry. One confirmed sequence automatically checks every burner's initialization
and rescue signal, then measures; qualified restoring/damping dynamics can start
a session-only vertical hold using the actual altitude table and acknowledged
fractional heat modulation. Physical validation flags and horizontal flight are
not inferred. See [automatic altitude workflow](docs/ALTITUDE-0.18.71.md).

Previous Navigation workflow stage:

V0.18.70 reduces Navigation from 16 global views to eight workspaces. Bridge
identity, geometry, burner group, transmitter and receiver frequency suggestions
come from real cached discovery. Native choices and booleans are clickable
controls rather than free-text fields. Burner setup opens its populated settings
in one screen; saving and flight actions remain explicit. See
[Navigation workflow and checks](docs/NAVIGATION-0.18.70.md).

Previous common-contract stage:

V0.18.69 provides the common real-data contracts/cache readers for progressive
ASCENDANCY work: source provenance/freshness, frame/unit/clock compatibility,
bounded persistent map encoding, non-actuating waypoint-mission validation and
supervision status. No simulated Cosmonautics adapter or new major module is
claimed. It also prevents a legacy disabled-security setting from bypassing a
locked session. See the [final audit and delivery index](docs/FINAL-HARDENING.md)
and [ASCENDANCY contracts](docs/ASCENDANCY-CONTRACTS.md).

Previous Combat native stage:

V0.18.68 completes native Combat radar/cannon/network/alias configuration and
its staged radar setup. These reuse existing validators and save handlers;
configuration views do not issue aim/fire commands. Explicit fire controls and
single-use confirmations stay separate. See [native coverage and safety
checks](docs/HARDENING-0.18.68.md).

Previous Navigation native stage:

V0.18.67 completes Navigation's native secondary forms, calibration, setup,
Auto altitude and equipment projections while retaining the text rescue client.
Native controls use the existing field setters and authorized command handlers;
STOP remains visible independently of invalid form input. Full flight-limit
review is required before a native sweep confirmation. See
[native Navigation validation](docs/HARDENING-0.18.67.md).

Previous UI infrastructure stage:

V0.18.66 adds 1x/1.5x/2x pixel UI scaling and a bounded, session-scoped RAM
clipboard shared by Editor, Terminal and native client fields. Physical display
resolution/palette and text rescue are preserved; undersized screens use 1x.
See [UI behavior, benchmark evidence and game checks](docs/HARDENING-0.18.66.md).

Previous navigation stage:

V0.18.65 adds operator-configurable altitude-sweep speed and travel limits.
Both default to 0 (disabled), preserving the existing unrestricted settings.
Positive limits trigger rescue when exceeded. Telemetry, vessel identity,
physical validation, STOP/F10, owner and receiver checks remain mandatory.
See [the navigation audit](docs/HARDENING-0.18.65.md).

Previous security stage:

V0.18.64 rejects factory-empty admin login at the authentication API, gates app
authorization until secure enrollment, preserves existing protected account
identities on unlock and isolates cached windows across account changes. Normal
no-history updates no longer implicitly delete existing backups. See the
[stage-1 audit, remaining work and in-game procedure](docs/HARDENING-0.18.64.md).

Previous history-policy change:

V0.18.63 defaults to no retained version history. The installer removes old update
checkpoints before preparing the upgrade and does not keep a previous release
after success. Personal files/configuration are preserved. A temporary recovery
transaction still protects interrupted writes and is removed after success;
there is no post-install rollback in this mode. Existing explicit
`retainRollback=true` policies remain an opt-in compatibility mode.
See [no-history storage behavior](docs/NO-HISTORY-0.18.63.md).

Previous sweep changes:

V0.18.62 also removes the imposed world/altitude travel cutoff from the measurement sweep. World origin and altitude samples remain recorded; fresh pose/identity, tilt, time and manual stop checks remain.

Previous response/target changes:

V0.18.61 removes the imposed vertical-speed cutoff from altitude measurements.
The qualified response model estimates speeds between measured heat levels.
Auto altitude adds Arm hold, Target altitude (whole world metres) and Set altitude,
with live measured altitude, speed, target and error. Setting a target requires
an explicitly armed hold owned by the same Navigation process. Model interpolation
is an estimate, not a fractional redstone signal or a guaranteed metre-precision
flight result. See [response measurements and target control](docs/AUTO-ALTITUDE-0.18.61.md).

Previous unified workflow:

V0.18.60 consolidates burner preflight, measurements, reports and proposed gains
in **Navigation → Auto altitude**. Its next-check action follows live validation
state without reinitializing already confirmed burners. Heat levels advance on
sustained measured vertical-speed stability, never just elapsed dwell time.
Per-level and overall timeouts remain safety limits; unsettled response aborts
and returns to the configured rescue. Stable vertical speed and stable altitude
are shown separately. See [the unified workflow](docs/AUTO-ALTITUDE-0.18.60.md).

Earlier measurement/model design:

V0.18.55 adds a confirmed, bounded altitude characterization sweep, default heat
levels 7–15, recording altitude and vertical speed with per-heater acknowledgment.
A validated first-order velocity response can produce an interpolated hover and
conservative PI candidate (D=0); noisy/unbracketed results never invent gains.
No automatic arming or physical validation occurs. Stop/F10, owner/permission
loss, world/altitude excursion, tilt, speed and telemetry guards apply rescue.
See [workflow, model assumptions and rollback](docs/AUTO-ALTITUDE-0.18.55.md).

V0.18.54:

V0.18.54 retains a successful positive burner initialization for the exact group
in the current flight-service run. Returning to rescue signal 0 no longer
mistakes Aeronautics' missing idle reference for a new initialization failure.
Raw association remains visible separately. Active heat still requires live
feedback, with a bounded 2-second association-restart window. See
[idle burner handling, safeguards and rollback](docs/BURNER-IDLE-0.18.54.md).

V0.18.53:

V0.18.53 adds a private RAM-only verifier for repeated password unlocks during
one boot, avoiding repeated PBKDF2 work after a successful sign-in. It retains
persistent attempt delays, disk credentials and older-release compatibility.
Authentication screens distinguish a slow first verification, migration and
quick unlock. First sign-in after reboot still verifies the stored credential;
no plaintext password or volatile verifier is saved to disk. See
[behavior and limits](docs/QUICK-UNLOCK-0.18.53.md).

V0.18.52:

V0.18.52 checks fresh heater-side feedback for every burner in a collective
calibration pulse, reports frequency/wiring vs balloon-association failures,
and keeps a transmitter acknowledgment from falsely validating heaters.
The guide exposes explicit burner group selection (all selected by default).
CC:Sable membership can be proved by fresh native containing-sublevel identity
and pose even if the separate plot-grid probe returns false or fails.
See [burner feedback, setup and limits](docs/BURNER-FEEDBACK-0.18.52.md).

V0.18.51:

V0.18.51 adds persistent escalating password retry delays with a visible console
countdown. After one successful migration, logins use 15,000 PBKDF2 iterations
instead of 600,000, while preserving a high-cost credential for older OS rollback.
This deliberately reduces resistance to offline guessing; retry delays protect
the running console, not stolen account files. See [policy, migration and limits](docs/AUTH-RETRY-0.18.51.md).

V0.18.50:

V0.18.50 adds live measured equipment diagrams (top, side, front and isometric),
component selection/inspection and zoom. Burner diagnostics separate signal,
gas output, balloon association and gas activity. An incomplete centre of mass
or propeller direction no longer hides an otherwise complete burner inventory;
stale/truncated scans still refuse setup and complete geometry is still required
for physical model import. Hull blocks, shafts and nested sublevels are **not**
exported by Vehicle Bridge 0.2.1. See [usage and limits](docs/VEHICLE-DIAGRAM-0.18.50.md).

V0.18.49:

V0.18.49 adds Navigation's opt-in autonomous waypoint pilot, with dedicated
directional thrusters or verified tilt guidance, altitude-first travel and final
position hold. Native/text controls expose route editing, explicit start,
manual takeover and passive sublevel equipment discovery. Fresh world pose and
vehicle identity, calibrated full flight control and a clear flight corridor
are required; there is no automatic landing or obstacle avoidance. See
[aircraft setup, supported APIs, limits and rollback](docs/AUTOPILOT-0.18.49.md).

V0.18.48:

V0.18.48 adds first-run password enrollment, authentication after reboot and a
kernel-level session screen. Press **F12 before leaving the computer**; Settings
also provides a Lock action. Stock CC:Tweaked does not
report closing the computer screen, so automatic lock on closing is not promised.
Browser, CraftTube, Store and NEXUS have native pixel clients; CraftTube and Store
are now listed in the launcher. Combat avoids repeated classification work and
copies less private radar evidence to its UI. See [usage, limits and validation](docs/SESSION-NATIVE-0.18.48.md).

V0.18.47:

V0.18.47 refuses application access when security verification is unavailable,
restricts security-data reads to explicitly authorized admin sessions/apps,
preflights Terminal directory copies and protects system/checkpoint writes.
Legacy whole-system rollback preserves live credentials and roles. The compact
1 MB installation remains supported. See [security fixes, tests and boundaries](docs/SECURITY-0.18.47.md).

V0.18.46:

V0.18.46 retains every application while reducing the first-install payload from
1,031,390 to 609,435 bytes using lossless installed Lua source packing. Readable
sources remain in Git; boot, Recovery and transaction code remain unpacked.
The strict 1,000,000-byte disk test includes personal witness data, a subsequent
update and rollback. No server quota change is needed for that tested workflow.
See [compact installation, storage evidence and limits](docs/COMPACT-INSTALL.md).

V0.18.45:

V0.18.45 suppresses empty graphical presentations, batches compatible pixel rows,
retains bounded sparse damage and coalesces visible invalidations without gating
service/event dispatch. Display settings expose Stable/Balanced/Performance and
an optimization off switch. Manual upgrades now retain differential rollback
checkpoints and refuse insufficient space; Recovery verifies new checkpoint
checksums and restores text mode while retaining personal data. An incomplete
graphical boot selects text rescue on the next boot. See
[performance measurements, recovery and Minecraft commissioning](docs/GRAPHICS-PERFORMANCE-ROLLBACK.md).

V0.18.44:

V0.18.44 adds a native pixel Terminal with wrapped/colored output, cursor editing,
command history, scrolling, record selection/local copy and a tactile keyboard.
Autocomplete no longer reads during drawing and private commands remain masked.
Read commands now check their live permission before accessing data. See
[Terminal graphics notes](docs/GRAPHICS-0.18.44.md).

V0.18.43 adds a native pixel Editor with line numbers, caret, selection, literal
search, basic Lua coloring and shared tactile input. Existing draft recovery,
conflict-checked saves and compile-without-execution remain intact. Only visible
rows are drawn and unchanged visible text reuses its token cache. See
[Editor graphics notes](docs/GRAPHICS-0.18.43.md).

V0.18.42 gives Messenger native wrapped message history, bitmap draft input,
Live scrolling and a tactile keyboard. Transport runs outside drawing; receive
cursors survive full inbox rotation. Public chat remains explicitly insecure,
not authenticated or encrypted. See [Messenger graphics notes](docs/GRAPHICS-0.18.42.md).

V0.18.41 migrates all twelve Settings sections to native pixel controls, cached
diagnostics, dropdowns, checkboxes and masked keyboard/touch input. Configuration
writes run in a serialized service with live permissions and session checks.
Text rescue and the existing asynchronous authentication path remain available.
UI scaling remains fixed; see [Settings graphics notes](docs/GRAPHICS-0.18.41.md).

V0.18.40 migrates Devices to native pixel inventory/search/filter/inspector views.
Metadata acquisition is asynchronous and outside drawing; Probe results are
bound to their request and inventory generation. The Display shortcut opens the
existing authorized Settings page. See [Devices graphics notes](docs/GRAPHICS-0.18.40.md).

V0.18.39 adds a native pixel Update client, service-owned confirmed update and
rollback transactions, and signed read-only radar telemetry from associated
NEXUS agents into Combat. Ender modems carry Rednet, not peripheral access:
the radar must be attached to its agent. See [release notes](docs/GRAPHICS-0.18.39.md).
Application migration remains in progress; this is not the full ASCENDANCY release.

V0.18.33 gives Navigation's Flight view native pixel instruments, cached
row-based attitude rendering, and explicit stale/unavailable telemetry. Other
Navigation pages retain their existing controls/safety while their UI migration
continues. See [Navigation graphics notes](docs/GRAPHICS-0.18.33.md).

V0.18.32 makes the pixel desktop the normal boot path (256 -> 16 -> diagnostic
text fallback). It resets persistent peripheral graphics state before text
buffers and isolates incompatible ROM window initialization. See
[routing and resolution notes](docs/GRAPHICS-0.18.32.md).

V0.18.31 adds bounded bitmap text layout (wrapping, alignment, spacing, scales,
UTF8-to-font display conversion), plus Files copy/cut/paste and cached properties.
Transfers refuse overwrites and preflight descendant permissions. See
[release notes](docs/GRAPHICS-0.18.31.md) for limits and validation.

V0.18.30 fixes pixel desktop activation under the boot loader's require-only
environment, where the global package table is absent. The graphics regression
test now renders with package explicitly removed.

V0.18.29 migrates Files to a native pixel client, adds an application pixel API,
shares the full AZERTY keyboard between text/pixels/launcher, and supports explicit
CC Terminals workstation selection with source-isolated input. F1 opens the app
launcher; `display computer` returns to the PC from Terminal (permission required).
See [release notes](docs/GRAPHICS-0.18.29.md) and [native app API](docs/PIXEL-APP-API.md).

V0.18.28 adds the native pixel desktop, launcher/search, taskbar, notifications
and window chrome with pixel-precise move/resize and minimize/restore. Select
Settings -> Display -> Pixel desktop. Legacy apps keep their rasterized client
areas; their complete graphical redesign remains in progress. Text is still
the default and safe fallback. See [release notes](docs/GRAPHICS-0.18.28.md).

V0.18.27 adds the optional Graphics 2.0 pixel backend and legacy-window bitmap
rasterizer. Select Settings -> Display -> Pixel compatibility to try it; Text
renderer restores the existing display. Boot and recovery always start in text.
This is a compatibility foundation, not the finished native pixel interface.
See [ASCENDANCY scope, migration, validation and remaining work](docs/ASCENDANCY.md).

V0.18.26 / NEXUS 0.4 adds observation lease failover, strict sample freshness,
central alerts with acknowledgements/history and configurable monitoring thresholds.
Boot waves retain zero intentional inter-start delay; monitoring never actuates machines.
See [resilient supervision and alert rules](docs/NEXUS-MONITORING.md).

V0.18.25 / NEXUS 0.3 dispatches a complete boot wave without an intentional
inter-start delay, reuses verified package bytes and adds automatic coordinated
inventory/energy/fluid observation with persistent owner assignments.
See [deployment performance and infrastructure coordination](docs/NEXUS-FLEET.md).

Deploy now exposes only Automate and Pause. Approved automatic recovery resets
only an agent with a confirmed failed update, never simply an offline agent.
See [the unified workflow and destructive recovery limits](docs/NEXUS-AUTOMATE.md).

V0.18.23 adds explicitly confirmed internal-disk reset provisioning for selected
agents, with one-shot completion tokens and protected external mounts. Empty-key
MASTER setup now generates a key via HTTPS once and preserves existing keys.
See [destructive provisioning and key management](docs/NEXUS-RESET.md).

V0.18.21 adds NEXUS OVERMIND 0.2.0: a paginated 2D network roster,
capability-aware group missions, balanced assignment and bounded task journals.
Authorized shared-disk deployment and authenticated agents remain compatible.
Start with `nexus deploy` in Terminal. This is an incremental HIVE foundation,
not the complete eight-phase OVERMIND 1.0 specification.
See [setup, security boundaries and remaining phases](docs/NEXUS_OVERMIND.md).
See [automatic provisioning](docs/NEXUS-AUTOMATION.md) and
[HIVE missions and 2D network](docs/NEXUS-HIVE.md).

V0.18.17 separates balloon association from gas activity and diagnoses the old
bridge's empty-balloon false negative. Replace Vehicle Bridge 0.2.0 with 0.2.1;
the fix checks actual heater membership and capacity without forcing assembly
or gas output. Physical calibration and altitude PID gains are still required.

V0.18.16 adds a confirmed two-second burner initialization test, distinct
missing/off/unassociated heater diagnostics, and separate measured altitude and
altitude target labels. Aeronautics discovers balloons on a 20-game-tick lazy
tick while the heater is powered; the generic 0.3-second test may be too short.
The bridge remains read-only and arming prerequisites are not bypassed.

V0.18.15 adds a guided balloon/burner setup, collective frequency output and
altitude-only control. Burner discovery requires Vehicle Bridge 0.2.0.
See [the balloon setup guide](docs/BALLOON_SETUP.md). Physical calibration and
PID tuning remain required; discovery and saving never activate the outputs.

[Vehicle bridge addon](addons/vehicle-bridge/README.md): standalone read-only
NeoForge JAR and sources. Navigation > Vehicle > Discover imports cached measured
propeller positions, COM and Create link frequencies into a draft model. It never
creates motor mappings or arms control. See the addon documentation for exact
versions, coordinate/unit contracts, loaded-parent-plot scope and remaining limits.

[Vehicle context](docs/VEHICLE_CONTEXT.md): vehicle types, independent rotor count,
actuator roles, verified body geometry, top/side diagrams and force/torque coupling
previews. This is a configuration/analysis foundation, not an Aeronautics Diagram
importer, automatic PID tuner or Kalman flight controller.

Calibration Test always provides visible feedback: missing outputs and unsaved
configuration open a setup dialog; a neutral/rescue signal offers editing rather
than silently applying an unchanged signal. No motor power is selected automatically.

Successful calibration pulses now return to disarmed after confirmed rescue,
without a false failsafe. Unchanged configuration saves preserve calibration;
real actuator errors still latch failsafe and invalidate the repeated test.

Flight heading uses the selected Avionics navigation table, or a fresh Sable
world quaternion when no navigation table is explicitly selected. Blank sensor
selection automatically chooses a unique device; ambiguous setups require an
explicit selection. Calibration shows arming blockers and retains confirmed
progress in the current configuration draft. No safety prerequisites are bypassed.

V0.18.26 fixes artificial-horizon freshness and reserves acquisition capacity for flight sensors. A stale horizon is held for at most one second from its original observation, explicitly marked stale; control never uses this display hold.

CC/addon contract fixes and commissioning limits: [V0.18.8 remediation](docs/AUDIT_ADDONS_FIXES.md).

Audit fixes, regression coverage and remaining limits: [V0.18.7 audit remediation](docs/AUDIT_FIXES.md).

Radar setup and the inspected Radar 5.0 EA read contract: [Radar setup](docs/RADAR_SETUP.md).
Touch filters, remote radar stations and perimeter alerts: [Radar network](docs/RADAR_NETWORK.md).
Automatic bearing positions and measured scan volumes: [experimental Radar API bridge](docs/RADAR_API_BRIDGE.md).
Pocket-sized bitmap icons, paged desktop and per-computer app selection: [App profiles](docs/APP_PROFILES.md).
Responsive Browser/Update requests and reduced update staging: [Network app fixes](docs/NETWORK_APP_FIXES.md).
Direct Navigation/Combat action pickers and 20 Hz radar redraw: [Action menus](docs/ACTION_MENUS.md).

- bootloader, splash, recovery and panic handling
- persistent logs
- cooperative scheduler and process table
- event bus
- terminal renderer, themes and window manager
- desktop, taskbar, start menu, right-click context menu and stacked notifications
- monitor auto-display through `deviced`, tuned for a 4x3 block monitor minimum at text scale 0.5
- larger `.nfp` app icons with text fallback, searchable start menu and AZERTY touch keyboard
- shared GUI components for buttons, tabs, toolbars, lists, inputs and dialogs
- complete touch-first Files app with toolbar, open, create, rename, trash and delete confirmation
- shared global AZERTY keyboard component reused by desktop search, Files, Terminal and Editor
- Editor integrated through Files for text/Lua files, with Lua compile check and Tab autocomplete/snippets
- richer Settings pages for system, display, desktop, network, storage, apps, packages and developer information
- GitHub Update app and boot-time update check through the `updated` service
- update rollback snapshot restored from Update or Recovery
- Task Manager with process list, disk usage, Lua heap, active wall time and bounded acquisition counters (not CPU percentage)
- Terminal with file commands, process commands and touch autocomplete
- Services, Logs and Task Manager apps with touch controls
- HTTP/WebSocket network wrappers, `networkd` service and Chrome-like text/color Browser app
- Browser tabs, address bar, Back/Forward/Reload/Home, clickable links, bookmarks, history, downloads and HTML cache
- CraftTube integrated from Browser for YouTube URLs/searches, using a configurable proxy/API with card-style results, favorites and history
- CraftTube defaults to the public Invidious API at `https://inv.thepixora.com`, with local fallback instances configurable
- CraftTube Play supports DFPWM audio through `tools/crafttube-dfpwm-proxy`; raw YouTube/Invidious audio is not decoded locally
- Store and local package manager with bundled example packages
- Rednet Messenger app for MintCraftOS-to-MintCraftOS chat with a modem
- Navigation: measured horizon, altitude, heading, vertical speed, environment, hybrid output mapping and calibrated PID control
- Native coroutine workers: target flight telemetry/control 10 Hz, radar 5 Hz and slow diagnostics 1 Hz, with bounded acquisition and measured overruns
- Combat: subpixel 2D/3D schematic scopes, measured/calibrated radar heading, bounded trails, persistent target IDs and local aliases
- Shared category filters and second-tap deselection; immediate touch redraw with 5 Hz cached instruments
- Optional Rednet station discovery/inclusion, aggregated contacts, multi-radar overview and explicitly enabled perimeter alerts
- Remote contacts are display/alert only, including authenticated Rednet; shared-key authentication does not encrypt measurements
- CC:CBC 1.1.1 mount adapter: calibrated ballistic estimates, mechanical limits, asynchronous aiming/tracking and separately confirmed fire pulses
- No simulated radar sweep, fabricated name, origin, angle or fallback target position; unknown coordinate frames block control
- Navigation gains start at zero and arming requires output tests, direction/hover/manual/rescue confirmation and fresh selected sensors
- Navigation supports calibrated CC redstone relay outputs by peripheral name and side, in addition to PC sides and Avionics
- Body-mounted CBC aiming is blocked when attitude is unknown or inclined; full 3D mount ballistics is not implemented
- Closing/crashing/killing the Navigation owner requests calibrated rescue; never automatically rearm after rescue or reboot
- Browser/CraftTube remain legacy features in pause; V0.18 adds no browser/HTML5 work
- user/session security service with declared app permissions, user permissions, lock/unlock and logged denials
- speaker audio driver and `audiod` service with Settings controls and notification/test tones
- app crash isolation for process, window draw and input errors, with log entry and notification

Not included yet: JavaScript/HTML5 video playback, full 3D mount ballistics and per-file ACLs. Passwords use salted PBKDF2 hashes, not reversible encryption. Arbitrary third-party Lua execution remains blocked.

Install the repository contents at the root of a CC:Tweaked computer, then reboot or run:

```lua
shell.run("/boot.lua")
```

## Install From GitHub

On a CC:Tweaked computer with HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/<COMMIT_SHA>/install.lua
```

Then reboot:

```lua
reboot
```

Use the published full commit SHA, not `main`, for a reproducible installation.
See [V0.18 commissioning and API evidence](docs/V0.18.md). Software rescue requires a functioning,
powered computer; it is not a hardware failsafe. Real ship commissioning is still required.

## CraftTube Audio

On your PC, install `yt-dlp` and `ffmpeg`, then run:

```powershell
cd tools\crafttube-dfpwm-proxy
npm start
```

CraftTube uses `http://127.0.0.1:8787` by default. If Minecraft runs on another machine, open CraftTube, tap `Audio`, and enter the proxy PC IP instead.

## Browser Error Codes

- `BRW-001`: HTTP API disabled in CC:Tweaked.
- `BRW-002`: network/TLS/DNS/request failure.
- `BRW-003`: MintCraft permission denied.
- `BRW-004`: too many redirects.
- `BRW-005`: invalid URL.
- `BRW-006`: YouTube routed to CraftTube.
- `BRW-007`: browser cache issue.
- `BRW-008`: download/write failure.
