# 0.18.32: CC Graphics Routing And One Desktop

## Fix And Policy

The installed CC Graphics 0.2.1 ROM window.lua initializes its text palette by
calling parent.getPaletteColour(2^i), including 256 at line 133. A selected
peripheral may remain in mode 2 across a computer reboot. Creating a plain text
window directly on that physical indexed palette can therefore fail during boot.

- Text initialization now explicitly thaws/resets the selected display to mode 0.
- Legacy palette adapters follow the physical mode rather than a stale captured
  mode, including a false/text return from getGraphicsMode after fallback.
- ROM window initialization is guarded. A graphics-incompatible window API
  closes graphics, reports the error and retries text initialization rather
  than immediately terminating the OS.
- Normal boot now uses the pixel desktop: 256 colors, supported 16-color fallback,
  then diagnostic text when graphics is unavailable/fails. The ordinary Settings
  menu offers Retry pixel desktop, not multiple competing desktop renderers.
- safeMode=true in system.cfg preserves explicit text rescue. Recovery and boot
  diagnostics always remain text. Runtime backend switching remains available
  internally for tests/recovery, not removed from the engine.
- New installs prefer the computer. Existing display selections/configs remain
  preserved. CC Terminals selection and its source-specific input routing remain.

## Resolution: Actual Configuration, Not Fake Pixels

The inspected instance originally had both terminal dimensions at 51x19. Neither
mod exposes a verified Lua set-resolution method. Use the existing server config
settings, with Minecraft stopped, to request the high-resolution target:

computercraft-server.toml:
```toml
[term_sizes.computer]
width = 160
height = 60
```

ccterminals-server.toml:
```toml
[term_sizes.terminal]
width = 160
height = 60
```

For the inspected local instance these files are in its config directory. Other
loaders/server installations may use world-specific config; inspect the effective
file instead of blindly duplicating it. Reopen/reload terminals as the mod requires.
These settings are bounded 1-255 in the inspected configuration, but choosing 255
for both is not a tested performance target and exceeds this engine's framebuffer
payload budget. 160x60 targets approximately 960x540, subject to the actual reported
getSize(2). Lua always uses the reported dimensions. This does not grant Minecraft
fullscreen control or guarantee the visible GUI occupies 960 physical screen pixels.

At the user's request, after confirming Minecraft was stopped and checking no
Java game process remained, the two local instance config sections were updated
to 160x60. Backups with suffix .mintcraft-before-160x60-20261019.bak were retained.
TOML parsing/diff verified every other setting, including pockets and monitors,
was unchanged. No mod jar/save was changed. The GitHub installer does not edit
Minecraft host configs automatically. Effective game dimensions still require
verification after restarting the instance.
Native Navigation/radar client migration is still pending; a bigger framebuffer
does not magically add detail to rasterized legacy instruments.

## Validation

93 fast Lua 5.2 suites passed plus Lua syntax checks. New tests model an external
display initially in mode 2, palette namespace changes, and ROM window creation
failure with safe fallback. Normal CraftOS-PC also loads window.lua extracted
read-only from the installed CC Graphics jar, rather than testing only the
emulator's window implementation. This is still emulation, not a Minecraft test.
The terminal transport fixture additionally checks selected-source routing.
Both the native and terminal-routed ROM-window graphics scenarios passed at
960x540 in the emulator. The latter also starts from a persisted legacy text
preference, verifying normal boot still chooses the pixel desktop. It checks
foreign input rejection and authorized return to the computer. No Minecraft
session was launched or called validated.
The explicit safeMode text-rescue smoke also passed: twelve integrated apps
opened, maximized and closed with optional addon peripherals absent.
