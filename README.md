# MintCraft OS

MintCraft OS is a CraftOS environment for CC:Tweaked 1.21.1 / NeoForge.

This repository currently contains the V0.6 base:

- bootloader, splash, recovery and panic handling
- persistent logs
- cooperative scheduler and process table
- event bus
- terminal renderer, themes and window manager
- desktop, taskbar, start menu, right-click context menu and notifications
- monitor auto-display through `deviced`, tuned for a 4x3 block monitor minimum at text scale 0.5
- custom `.nfp` app icons with text fallback, searchable start menu and AZERTY touch keyboard
- complete touch-first Files app with toolbar, open, create, rename and delete confirmation
- shared global AZERTY keyboard component reused by desktop search, Files, Terminal and Editor
- Editor app with Lua compile check and Tab autocomplete/snippets
- richer Settings pages for system, display, network and developer information
- GitHub Update app and boot-time update check through the `updated` service
- Task Manager with process list, disk usage, Lua memory usage and estimated CPU activity
- minimal Terminal, Files, Settings, Task Manager, Update, Services, Devices and Logs apps

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
