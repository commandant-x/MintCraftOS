# Navigation / Combat controls - 0.18.6

Views now use a direct picker instead of scrolling through category arrows. Common
actions stay in the command strip; More opens every action in a touch-friendly grid.
The grid uses two-row hitboxes, wrapped labels, responsive columns, and Previous/Next
pages only when the window cannot fit all choices. Close/outside click/Escape dismiss
the overlay; input cannot reach a control or radar contact behind it.

Combat's Show picker toggles categories without closing after each choice. Active
filters remain marked; tapping an active category again disables it. Fire and Arm
remain visually distinct and still require their existing safety confirmation.
No permission, calibration or fire-control logic has been relaxed.

Radar and 3D render timers target 20 Hz (50 ms); peripheral acquisition stays at 5 Hz.
The service exposes its cached revision so the app only copies a snapshot when new
measurements arrive. Projection/canvas/labels remain cached between unchanged inputs;
no positions or scan headings are interpolated or invented. This improves redraw and
interaction latency, not the sensor's physical update frequency. Actual frame rate
depends on the Minecraft server and monitor size. Other Combat pages remain at 5 Hz,
and minimized windows poll only once per second without acquiring or drawing data.

Tests cover action reachability, two-row hitboxes, overlap/bounds, modal routing,
category toggles and Navigation/Combat at pocket and monitor window sizes.
