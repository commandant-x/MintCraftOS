# Final hardening stage 4: native Navigation secondary views — 0.18.67

Navigation's setup, group selection, vehicle/output/sensor/PID/manual forms,
calibration, Auto altitude options/read-through/results, control, geometry,
component detail, environmental diagnostics and legacy-estimate pages now have
native pixel clients. Flight and route/sublevel clients remain unchanged.
The original terminal client remains available in text rescue. No functionality
is removed to obtain native coverage.

The native form panel consumes the same field descriptors/setters and command
handlers as the text client. Numeric/boolean/enum edits are parsed completely
before any pending edit is applied; Escape cancels pending text. Touch keyboard,
Ctrl+A replacement and shared clipboard controls are available. Existing service
authorization, ownership, frozen configuration and explicit confirmations still
run. STOP is rendered outside paginated controls and remains effective when a
form contains invalid input. F10 keeps the existing sweep/mission stop handling.

The native flight warning view uses the same warning paragraphs as text mode.
Long paragraphs are split into readable rows. Confirmation remains blocked until
the last warning is actually displayed; undersized windows and stale native
scroll state cannot mark a review complete. The frozen source configuration is
rechecked by the existing service. No UI path fabricates physical validation or
automatically arms control.

Equipment top/side/front/isometric projections draw directly from the existing
verified model, including component selection/zoom/direction vectors and measured
COM when available. No hull, shafts, wiring, nested-ship structure or unknown COM
is invented. Right-click a component for native details; toolbar inspection and
all projection/selection controls remain available. Geometry is measured/saved
information, not a proof of physical output mapping.

Tests exercise all secondary views as native surfaces, real field contracts,
atomic validation, always-visible STOP, small-window review rejection, complete
native flight review and unchanged backend confirmation. Projection tests verify
all four views, point identity/hit bounds, canvas clipping and missing geometry.
Source and packed suites are rerun. Exact-version update/checkpoint rollback is
checked under the 1 MB quota with personal data preserved.

In game (not executed here), use a copied installation and visit every Navigation
view at each supported UI scale. Edit valid/invalid numeric fields, cancel with
Escape, cycle choices, save, and verify the configured values through the text
fallback. Check both receiver feedback rows, all physical confirmations and
native read-through before sweeping. Verify STOP/F10 while a field is invalid.
Inspect real equipment in each projection and confirm unknown hull/wiring stays
unknown. Never arm an unverified aircraft to test the graphical controls.

Remaining stages: native Combat secondary configuration/setup and common
ASCENDANCY real-data contracts. No fabricated data/provider is added here.
