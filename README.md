# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains the V0.8.1 base:

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
- Editor app with Lua compile check and Tab autocomplete/snippets
- richer Settings pages for system, display, desktop, network, storage, apps, packages and developer information
- GitHub Update app and boot-time update check through the `updated` service
- Task Manager with process list, disk usage, Lua memory usage and estimated CPU activity
- Terminal with file commands, process commands and touch autocomplete
- Services, Logs and Task Manager apps with touch controls
- HTTP/WebSocket network wrappers, `networkd` service and text Browser app
- Store and local package manager with installable package manifests
- Rednet Messenger app for MintCraftOS-to-MintCraftOS chat with a modem

Not included yet: CraftTube, users/permissions enforcement, audio and update rollback.

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
