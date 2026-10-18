# 0.18.29: Native Files And CC Terminals Workstations

## Changes

- Files now draws its client in pixels: toolbar symbols, path, search, bitmap
  file/folder glyphs, selection, paging/scroll controls, action menu and native
  input/confirmation dialogs. Existing create/rename/trash/restore/protected-path
  functions remain the single source of filesystem behavior.
- New native app contract and clipped local views preserve window/process
  ownership. Mouse drag/release are captured for the originating client; native
  callback exceptions close only the app. Legacy clients still rasterize.
- The native and text keyboards now share one pure layout/action module. Full
  AZERTY, punctuation pages, Shift/Caps/Ctrl/Tab/Enter are available in Files and
  the launcher; compact key margins keep modifiers readable on pocket-sized UI.
- Final-row reconciliation removes false dirty output from repainting unchanged
  controls. Skinny oversized framebuffers are rejected; payload budgets remain.
- CC Terminals devices appear in Settings -> Display. Selection is explicit,
  never an automatic takeover from the PC. Normal terminals expose keyboard;
  advanced/color terminals also expose mouse. No unsupported setTextScale call
  is made on terminals.
- Input is accepted only from the selected terminal's attachment name. Other
  terminals and bare PC key/char/paste/mouse events are ignored while that
  terminal is selected. Monitors keep PC keyboard input but reject PC mouse.
- A 1 Hz bounded geometry worker handles missing terminal-resize events. Data
  acquired for a previous target is not published after switching targets.
- F1 opens the launcher in text or pixels. `display` lists displays, and
  `display computer` restores the PC from a keyboard-only terminal. Listing and
  changes require devices.list and system.config respectively, with actor/user
  authorization and audited successful changes.
- Terminal paste now works, is bounded and keeps only the first pasted line;
  it never executes pasted multi-line commands automatically. Authentication
  text remains excluded from history, visible echo and autocomplete.
- Small screens show fewer simultaneous notifications to avoid covering the
  application toolbar. Text mode remains the default and graphics fallback.

## Compatibility And Setup

After updating/rebooting choose Settings -> Display -> Pixel desktop. To use a
CC Terminals block, connect it as a peripheral and select its actual name in
Settings -> Display, or run `display terminal_0` with configuration permission.
Use F1, type Terminal, Enter, then `display computer` to return without a mouse.
Monitor scales remain per-monitor; a terminal's GUI size is not monitor scale
or Minecraft fullscreen. No fullscreen API or arbitrary RGB capability is claimed.

The published source exposes type `terminal`, inherited TermMethods and the
source-prefixed terminal_* events. Inspected source commit:
c3b91173affb8c23508ea65c5de2b5abca69fc9a at
https://github.com/sashafiesta/CC-Terminals . Input events are broadcast by the
block to its attached computers: use a single explicit display owner. MintCraftOS
filters input locally; it does not claim a cross-computer exclusive display lease.

No user files/config are wiped; no host mod or Minecraft world is modified.
Browser, aircraft control permissions, radar/fire safety and NEXUS are unchanged.
NEXUS remains 0.4.0.

## Verification

91 fast Lua 5.2 suites plus syntax checks. New tests cover workstation selection,
input source/coordinate routing, detach/reconnect, app-local clipping/crash
isolation, keyboard modifiers/punctuation and native Files' existing operations.
File/editor audit tests forbid filesystem acquisition during native draw.

Visible isolated CraftOS-PC tests exercise the pixel desktop, native Files
creation via pointer and paste, shared keyboard/launcher, six apps, mode 2/1/text,
and a separate twelve-app classic boot. Resolutions: 306x171, 600x306, 156x180
(pocket-sized) and 960x540. Raw indexed frames and palettes are inspected.

CC Terminals is tested with a simulated peripheral transport over a real native
framebuffer: selected/foreign/native input separation and keyboard-only return
to the PC. This is NOT real Minecraft peripheral validation. No actual in-game
test, fullscreen claim or measured FPS is reported.

## Remaining Scope

Files' existing workflows have a native UI; GUI copy/move/clipboard, expanded
file properties and broader keyboard editing remain requirements before calling
the final explorer complete. Other application clients still need migration.
UI scale, full font/UTF-8 work, more widgets/performance testing, first-run admin
setup and the remaining ASCENDANCY modules stay on the main requirement ledger.
