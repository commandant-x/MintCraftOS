# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains V0.18.28:

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
