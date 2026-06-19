# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains the V0.17.1 base:

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
- Task Manager with process list, disk usage, Lua memory usage and estimated CPU activity
- Terminal with file commands, process commands and touch autocomplete
- Services, Logs and Task Manager apps with touch controls
- HTTP/WebSocket network wrappers, `networkd` service and Chrome-like text/color Browser app
- Browser tabs, address bar, Back/Forward/Reload/Home, clickable links, bookmarks, history, downloads and HTML cache
- CraftTube integrated from Browser for YouTube URLs/searches, using a configurable proxy/API with card-style results, favorites and history
- CraftTube defaults to the public Invidious API at `https://inv.thepixora.com`, with local fallback instances configurable
- CraftTube Play supports DFPWM audio through `tools/crafttube-dfpwm-proxy`; raw YouTube/Invidious audio is not decoded locally
- Store and local package manager with bundled example packages
- Rednet Messenger app for MintCraftOS-to-MintCraftOS chat with a modem
- Navigation app for CC:Sable telemetry, Create: Avionics sensor diagnostics, quadcopter force tables and confirmed Redstone Assist pulses
- Combat app for Create: Radars / CC:CBC probing, target lists, semi-auto aiming and confirmed fire control
- Combat reads Create: Radars track methods such as `getSelectedTrack`/`getTracks` when exposed, and shows a radar diagnostic when no target API is available
- user/session security service with declared app permissions, user permissions, lock/unlock and logged denials
- speaker audio driver and `audiod` service with Settings controls and notification/test tones
- app crash isolation for process, window draw and input errors, with log entry and notification

Not included yet: JavaScript/HTML5 video playback, encrypted password storage and per-file ACLs.

Install the repository contents at the root of a CC:Tweaked computer, then reboot or run:

```lua
shell.run("/boot.lua")
```

## Install From GitHub

On a CC:Tweaked computer with HTTP enabled:

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/main/install.lua
```

Then reboot:

```lua
reboot
```

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
