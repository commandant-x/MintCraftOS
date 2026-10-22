# Final hardening stage 2: operator limits — 0.18.65

The safety audit retains all existing Auto altitude behavior: explicit physical
initialization/direction/manual/rescue checks, complete fresh per-burner command
feedback, fresh world-frame vessel identity/pose, finite altitude/rate telemetry,
10-degree tilt guard, STOP/F10, ownership and permission checks, rescue and
interruption recovery. No gains or physical validations are fabricated.

Options now include optional `maxSpeed` (0–1000 blocks/s) and `maxTravel`
(0–10,000,000 blocks). Both default to 0, disabled, preserving the operator's
request to remove imposed speed/travel cutoffs. Older option tables lacking these
fields also mean disabled. A positive speed limit checks absolute vertical rate;
a positive travel limit checks both vertical displacement and full 3D displacement
from the measured start pose. Exceeding either aborts the run and uses configured
rescue. Settings are frozen and shown during the existing read-through flight
confirmation. Negative, nonnumeric/nonfinite and out-of-range settings are refused.

Tests cover unrestricted defaults, explicit speed/altitude/world constraint
activation and rescue, invalid settings, known-model fitting, clock/identity/pose/
receiver faults, revocation/owner loss and user stop. Source and packed runtime
suites are rerun. Exact 0.18.64→0.18.65 upgrade and opt-in checkpoint rollback are
verified with a 1,000,000-byte quota and 100,000-byte personal-data witness.
Normal updates preserve existing backups. Retained history remains opt-in per
the operator's prior no-history preference; interrupted-write recovery works in
both policies. No in-game flight validation is claimed.

In-game procedure: on a disposable aircraft, verify all physical controls, then
set small explicit limits and confirm each causes abort/rescue. Repeat with both
fields 0 and verify ordinary displacement/speed alone does not trigger those
limits. Test STOP/F10 and wired receiver disconnection. Do not test dangerous
conditions on an occupied or operational aircraft. Continue using the full
[stage-1 acceptance procedure](HARDENING-0.18.64.md).

Remaining audit stages: UI scaling and session clipboard, native secondary views,
then common real-data contracts for ASCENDANCY. These are not claimed complete.
