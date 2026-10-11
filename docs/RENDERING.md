# Rendering and calculation costs

The shared renderer writes coloured spans through `term.blit()`. The root
compositor draws into a hidden CC window and compares text, foreground and
background strings against the previous successful frame. Only changed rows
are sent to the display. Resize, target changes and explicit display rescans
invalidate this cache. Cursor position/blink are restored after a flush.
`ctx.renderStats()` exposes cumulative frames, output rows and output cells.

This reduces display I/O, not all scene drawing work: applications still
receive their events and draw into their window buffers. No unmeasured CPU
speedup is claimed.

V0.18 acquisition-worker interval timers and native `task_complete` events
dispatch without a full scene redraw. Visible instruments refresh on their
own 5 Hz UI timers; a new worker error notification still requests a frame.
The private clock timer only updates HH:MM when its text changes.

## Subpixel graphics

`system.gui.subpixel.new(columns, rows, background)` provides a canvas with
`width = columns * 2` and `height = rows * 3`. It supports `pixel`, clipped
`line`, filled `rect`, `clear`, cached `getLine` and `draw(x, y)`. Pixel colours
are CC colour constants; display coordinates remain terminal cells.

CC mosaic characters 128-159 encode six points per cell using two colours.
All two-colour patterns are exact. For cells containing more colours the two
most frequent colours are retained, with deterministic palette-order ties;
the remaining pixels become background. The fourth `getLine` return value
counts discarded pixels. This is not a GPU or additional physical pixels:
text still uses the native character grid and the screen palette remains 16
colours. At 51x19 cells graphics have a 102x57-point grid.

Desktop icons use `.spx` bitmap assets (NFP hexadecimal colour syntax at
subpixel resolution), falling back to existing `.nfp` files. Images and
compiled background variants are cached. `icon.invalidate(path)` clears a
single asset, or all assets with no argument; Desktop's Refresh icons command
does this manually. Eight desktop icons are 14x15 points, drawn in 7x5 cells.

## Calculation caches

- Files retains its directory snapshot until navigation/mutation/Refresh.
- Icons no longer access the filesystem on every redraw.
- Autocomplete returns the first priority match without constructing all
  candidates. Module discovery is cached for five seconds; `invalidate()`
  forces refresh. Editor local symbols are keyed by document and revision
  using weak keys. Mutations increment the revision.
- Terminal suggestions reuse unchanged input/cwd for up to one second and
  invalidate immediately after commands.
- Task Manager samples processes, disk and Lua heap at most once per second
  during redraw; Refresh/Kill invalidate immediately. Its existing CPU figure
  is a ready-process ratio, NOT a measurement of CPU utilisation.

## Validation

Lua tests cover renderer clipping, unchanged/changed frame output, all 64
binary mosaic patterns, line clipping, row-cache invalidation, icon load counts
and autocomplete scan counts. `tests/craftos-render.lua` installs into an
isolated normal-window CraftOS-PC instance, boots offline and exercises a
Terminal window. Actual runtime counts: 100 identical frames cause zero output
blits; changing one row causes one output blit. Physical Minecraft monitor
timing and mod-specific radar/navigation rendering still require in-game tests.

References: https://tweaked.cc/module/term.html and the CC charset discussion
https://github.com/cc-tweaked/CC-Tweaked/discussions/2452.
