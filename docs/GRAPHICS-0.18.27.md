# MintCraftOS 0.18.27: Graphics Foundation Increment

NEXUS remains 0.4.0. No enrollment, flight control, radar authorization, physical
outputs, provisioning policy, browser or user data behavior is changed.

## Changelog

- Optional PIXEL256 / PIXEL16 backend, automatic mode fallback and actual sizes.
- Byte-row framebuffer (at most 1,048,576 pixels), clipped dirty-span updates.
- Licensed embedded bitmap font, scaled pixel text and basic drawing primitives.
- Legacy windows rasterized to actual pixels, including mosaic icons and radar.
- Indexed/bitmask palette bridge and isolated offscreen clear operations.
- Computer/monitor pixel pointer conversion and source-filtered terminal events.
- Display settings select compatibility mode or return live to text.
- Boot/recovery unfreeze and disable graphics before showing diagnostics.

## Compatibility And Migration

Existing installations keep text by default. Graphics requires supported target
APIs, e.g. CC Graphics; optional addons are not required to boot. Select Settings
-> Display -> Pixel compatibility (256 then 16), or Pixel 16 colors explicitly.
Text renderer restores the previous path. Preferences live in system.cfg under
graphicsMode; older configurations need no destructive migration.

The current interface still has legacy cell layout and hitboxes; the new backend
is not a claim that all sixteen apps have been redesigned. Native pixel desktop,
WM/controls, font typography/wrapping, all-app migration, CC Terminals display
selection and final performance benchmarks remain on the ASCENDANCY ledger.
The logical framebuffer is not Minecraft fullscreen or the monitor's GUI scale.

## Validation

Lua 5.2 regression suites plus tests/graphics.lua cover compact buffers, clipping,
bitmap text, 960x540 allocation, actual dimensions, dirty spans, palette mapping,
mosaics, mode 2 / mode 1 / text fallback, thaw-on-error, and input coordinates.

tests/craftos-graphics.lua runs a visible CraftOS-PC instance in isolated storage,
installs and boots the OS in PIXEL256, opens Files/Terminal/Settings/Navigation/
Combat/NEXUS, checks display survival after legacy clears, exports a raw indexed
framebuffer for independent visual inspection and switches back to text.
The inspected 600x306 image shows the desktop, bitmap icons, labels and taskbar.
The same visible native scenario also passes at an actual 960x540 framebuffer,
including native mode 1 and a live return to text. This is not a measured FPS
claim: os.clock() has insufficient resolution for individual short flushes.
All 84 fast Lua 5.2 suites and Lua syntax checks are the release regression gate.
Unit tests and emulation are not real Minecraft validation.

Known issue found and fixed during native testing: graphics-mode window palette
initialization rejected bitmask color 256; the legacy parent now translates
palettes. A second issue let legacy clear() erase the physical GPU; every
offscreen compatibility window now explicitly reports text mode.

Installed addon filenames were inspected read-only, but no real in-game test or
CC Terminals workstation test is claimed. No host mod files or worlds changed.
