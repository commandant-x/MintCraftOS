# Native Pixel Clients

Apps retain run(ctx), their original draw(w,h)/handle(event) implementation,
permissions, WindowManager ownership and cleanup. Native rendering is opt-in:

```lua
function app:drawPixels(canvas, width, height, palette)
  canvas:rect(0, 0, width, height, palette.panel)
end

function app:handlePixels(event, window)
  -- mouse_* args are button/direction, client-local x, client-local y.
  return false
end
```

Both methods must exist to opt in. app.graphicsActive is maintained by the WM;
it is false after leaving graphics. Physical key/char/paste events continue to
handle(event). Native client mouse events go only to handlePixels, not both.
Zero-based pointer drag/up can be outside the client during pointer capture.
Closing/crashing/minimizing and switching physical displays invalidate capture.

canvas.width/height are actual available client pixels, not character counts.
The canvas view is transient: use it only during drawPixels, not from a retained
reference or a background worker. Virtual legacy client cell counts are derived
from available pixels and font metrics, not capped to the physical text grid.
canvas:span(x,y,byteString), :rect(x,y,w,h,paletteIndex), :pixel(x,y,index) and
:setClip(x,y,w,h) use zero-based client coordinates. The returned clip can be
restored with canvas.clip=oldClip. The view and the compositor's damage clip
jointly prevent drawing into window chrome or another window.

palette exposes desktop/panel/button/border/text/muted/accent/ink indices. These
are indexed colors, not arbitrary RGB. Use system.graphics.widgets for native
labels, buttons, input fields and symbols; system.graphics.keyboard for tactile
input. Both keyboard renderers share system.gui.keyboard_layout and its press
semantics, including punctuation pages, Shift/Caps XOR, Ctrl, Tab and Enter.

ctx.system.graphicsCapabilities() returns a COPY of cached detection state:
backend, text/pixel dimensions, graphics API presence, palette/freezing support,
color capability when known, and probed. Text preference without probing reports
probed=false rather than claiming the graphics addon is absent.

drawPixels must consume cached app state only. Acquire filesystem/peripheral/
network data in startup, explicit actions or existing background workers. A
native callback exception closes only its owning app through Window:crash and
the scheduler's existing cleanup/notification path. This is fault isolation,
not a secure sandbox for arbitrary untrusted Lua.

minPixelWidth/minPixelHeight are optional create-window hints, constrained by
the actual viewport. Text-mode dimensions and legacy apps remain compatible.
Apps without the native pair stay in the bitmap-rasterized text container.

The scene compares final byte rows after damaged layers are recomposed. Static
controls repainted by an app are not retransmitted when their final pixels did
not change. Frontbuffer memory and legacy pixel-cache budgets remain bounded.

Reference implementation: apps/files/pixel.lua. Its filesystem actions are
delegated back to Files' existing validated and permission-checked functions.
