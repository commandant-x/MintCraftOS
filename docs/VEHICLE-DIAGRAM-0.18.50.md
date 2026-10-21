# Navigation equipment diagram and burner feedback — 0.18.50

Install Vehicle Bridge **0.2.1** in the server and client `mods` directories and
restart. Put the Computer on the assembled vehicle. Open Navigation → Vehicle
→ Diagram. No import or saved geometry is needed to inspect current bridge data.

The diagram offers Top (+X right / +Z up), Side (+Z right / +Y up), Front
(+X right / +Y up), and isometric projection of Sable's **plot** coordinates.
These axes do not identify the vehicle's nose. Prev/Next selects a component;
Zoom+/Zoom- spans 1×–8×, following the selected component when zoomed. Details
shows wrapped, scrollable coordinates, identity and readings. Orange marks the
measured centre of mass; lime thrusters, red burners, cyan receivers and magenta
transmitters. Thruster arrows show measured force direction, not force magnitude.
IDs are sorted for stable selection within the same inventory. Overlapping
projected components remain accessible using Prev/Next and Details.

Current bridge data is preferred exclusively over the saved model, preventing
mixing two vehicles. Stale samples and saved geometry are labelled explicitly;
partial scans remain partial. Saved geometry is only a fallback when the bridge
has no valid vehicle frame/identity. Opening the diagram, zooming, inspecting,
rescanning and running the guide emit no control signal. The diagram does not
change the saved vehicle, control mapping, permissions, calibration or arming.

## Structural boundary

This is a diagram of **supported measured equipment**, not a complete hull scan.
Vehicle Bridge 0.2.1 enumerates loaded block entities on the containing Sable
sublevel. It exports supported propellers, burners and Redstone Links. It does
not export every hull block, shafts/gears, balloon envelope shapes or nested
sublevels, and cannot prove which actuator is driven by a nearby receiver.
The former COM-to-thruster radial lines have been removed: they were not
structural members. No guessed mechanical or wireless connections are drawn.
A complete hull reconstruction requires a new, bounded read-only block-state
exporter in the Java addon and validation against the installed mod versions;
this release does not include or claim that exporter.

## Guide

Open Setup guide to see bridge availability/version/errors and each burner's
signal, gas output, structural association and gas activity. A nonzero signal
alone does not prove working gas transfer or adequate buoyancy. Association may
be confirmed while gas activity is false; an empty associated balloon is not a
missing balloon. Use Calibration → Initialize (2s) only after checking the
physical setup and confirming the existing bounded test. Then Rescan; Detect
rebuilds the guide proposal. Neither the guide nor diagram auto-initializes heat.

The bridge's complete inventory flag is tracked separately from COM/thrust
geometry completeness. Missing COM or an uninitialized propeller direction no
longer blocks passive burner setup. A stale, failed or truncated Java inventory
still refuses setup and balloon readiness. Geometry import retains its stricter
requirements. Saving a guide proposal rechecks fresh inventory and vehicle and
burner identities. Existing calibration and physical confirmations remain.

## Validation and rollback

Lua regressions cover inventory vs geometry, missing bridge messages, stale and
truncated scan rejection, burner association vs gas activity, all four diagram
views at small/large sizes, zoom clipping, live/saved separation and inspector
readings. These are offline tests; no in-game validation is claimed.

Use the existing Updates rollback action to return to the retained checkpoint;
Recovery is available if boot fails. The update does not change the Minecraft
JAR or automatically delete older checkpoints. Installer storage tests include
a strict 1,000,000-byte quota and preservation of a 100,000-byte user-data witness.

The exact 0.18.49 → 0.18.50 update/rollback simulation peaks at **876,310
bytes**, including the 100,000-byte user witness. Fresh installation uses
789,316 bytes with that witness. Interrupted backup and live writes recover
the previous release with its durable checkpoint retained. The UI harness also
checks passive inspection, live burner feedback, absent bridge messages, and
refusal to save when the inventory becomes incomplete during confirmation.
