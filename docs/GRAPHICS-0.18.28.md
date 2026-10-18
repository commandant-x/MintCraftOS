# 0.18.28: Native Pixel Workspace

NEXUS stays 0.4.0. This release continues GRAPHICS 2.0 rather than expanding
network automation, browser functionality or aircraft/weapon authorization.

## Implemented

- Native pixel desktop with dark indexed palette, existing bitmap assets,
  responsive icon pages and original-size bitmap typography.
- Retained scene layers: damage rectangles, clipping, opaque occlusion,
  cached application content and unchanged-frame suppression.
- Pixel-coordinate window chrome with separate minimize/maximize/close hitboxes,
  focus/stacking, one-pixel movement, bounded resize and maximize/restore.
- Monitor interaction supports title tap then destination tap, and a resize-grip
  tap then destination tap. Application clicks still translate to their original
  client-cell coordinates; no click passes through a window or a notification.
- Taskbar with active/minimized state, touch-accessible task paging, clock and
  native searchable application launcher. Search accepts keyboard, paste and
  a compact AZERTY touch keyboard at supported launcher heights.
- Native desktop context menu opens Files creation dialogs for file/folder/Lua;
  write authorization and confirmation stay in Files. No file is created merely
  by choosing the desktop menu action. Monitor blank-desktop double-tap opens it.
- Dismissible notifications stack above the taskbar instead of covering titlebar
  controls at startup. Native search and context menus consume their input.
- Pixel-cache payloads are bounded to 2 MiB, excluding Lua overhead. When the
  budget is exhausted the renderer rasterizes damaged source rows without
  allocating another full client bitmap. Closing/switching releases caches.
- Extended palette slots are restored when leaving graphics mode. Preparation
  and shell-render faults thaw the terminal, repaint the complete text frame
  and retain the usable legacy OS.
- Fixed the shared list widget: nil rows no longer match a nil selection, and
  unselected text uses the theme's foreground instead of hard-coded black.

## Migration

Install the pinned release and reboot. Existing settings/data remain in place.
Choose Settings -> Display -> Pixel desktop (graphicsMode="auto") or Pixel 16
colors. Text renderer disables it live. No optional graphics mod is required
for normal text startup. No host mod, Minecraft world or save is modified.

The native shell follows the existing theme accent (mint/cyan) while retaining
a dark workspace. Application interiors still use their current app theme.

## Evidence And Limits

The 88 fast Lua 5.2 suites include four new regression files for scene damage,
pixel workspace interaction, shell fault fallback/palette restoration, and
list selection. Existing window, file, security, NEXUS and flight tests remain.

Visible CraftOS-PC tests use isolated storage and a read-only source mount.
The native script tests the pixel desktop, raw pointer drag/minimize/restore,
launcher filtering, touch keyboard, deferred file creation, six applications,
256/16 modes and text restoration. Framebuffer/palette exports are inspected at
306x171, 600x306, 156x180 (pocket-sized) and 960x540. These are emulated frame
sizes, not evidence of real Minecraft monitor or pocket-addon behavior.

The default text boot is also smoke-tested with twelve apps. No actual server
or Minecraft interaction test is claimed. No FPS claim is made from os.clock's
coarse resolution.

The desktop and chrome are native pixels, NOT a screenshot of the old desktop.
Application client regions are still bitmap-rasterized legacy containers.
This release does NOT claim that all sixteen apps are migrated. Native app
controls, comprehensive typography/fonts, CC Terminals target integration,
UI scaling, wallpaper customization, more benchmarks and ASCENDANCY CORE/J
milestones remain tracked in docs/ASCENDANCY.md.
