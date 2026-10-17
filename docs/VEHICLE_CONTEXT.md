# Vehicle context

Navigation has a vehicle profile, actuator descriptions, geometry analysis and
top/side subpixel diagrams. Mono-, bi-, tri-, quadri-, hexa- and other layouts
do not imply any hard-coded motor wiring. Rotor count is distinct from the
number of independent actuator commands needed to control four flight axes.

Each mapped command retains its endpoint, frequency label, signal bounds,
neutral and rescue. It also records a role (lift, propulsion, stabilization,
yaw, strafe or mixed), body-frame position and direction of positive thrust.
A lift rotor may also stabilize the vehicle through differential thrust; roles
are descriptions, not mutually exclusive physical effects or automatic wiring.

Body convention is +X right, +Y up, +Z forward. Position and COM use the same
body origin. Analysis requires explicit physical verification of both geometry
and COM. It reports normalized force directions and r cross F coupling per unit
of positive thrust. It does not infer thrust magnitude, signal polarity, rotor
reaction torque or controllability from rotor count. The controller's calibrated
manual mixer is unchanged; these previews are not applied to live outputs.

Read mass copies only a fresh, valid Sable measurement. Sable COM remains
unknown-frame until its conversion is validated, so it is not silently copied
into the body model. Propeller and signal-endpoint counts come from cached
discovery, not from drawing-time calls or from guessing Create frequency links.

## Aeronautics diagram boundary

The installed Avionics 0.6.0 peripheral classes and their base interfaces were
inspected read-only. Propeller bearings expose thrust vectors and scalar thrust;
physics assemblers expose mass, COM and inertia. No complete Aeronautics Diagram
export with per-actuator body positions and command-to-propeller wiring was
identified in that inspection. SCADA identifiers alone are not a verified
geometric or mechanical wiring contract.

The current views reconstruct only declared, verified geometry. They do not
claim to import the Aeronautics Diagram item. A future adapter/exporter needs
body-frame COM/inertia, actuator positions/directions, stable IDs and explicit
control links. No mod binary is patched by this release.

## Control work still required

PID tuning requires measured actuator response, delays, thrust-versus-signal
curves and axis coupling. Gains remain user-calibrated; there is no automatic
tuning or output excitation in this change. Kalman filtering is state estimation,
not a substitute for PID: sensor noise, process noise, timestamps and an adequate
dynamic model must first be identified. No unvalidated Kalman or inferred gains
are placed in the flight safety path.

Avionics reference: https://solastrius.github.io/CreateAvionics/
