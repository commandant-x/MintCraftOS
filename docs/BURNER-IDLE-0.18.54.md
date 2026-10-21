# Successful initialization survives the off/no-reference state — 0.18.54

The user screenshots show **both** burners at signal 3, `balloon=true`, active gas
and confirmed feedback during Initialize. After the test, rescue signal 0 is
applied; both then report signal 0 and `no_balloon_reference`. The previous OS
mistook that particular idle reading for failure of the initialization that had
just succeeded. These screenshots establish working command reception during
the pulse; they do not establish a wiring fault. No additional heater power is
needed just to preserve the successful test result.

## State policy

A completed Initialize pulse that observed a nonzero expected heater signal,
fresh complete feedback and association for every selected burner, and then
successfully applied rescue, creates a **volatile initialization confirmation**.
The confirmation binds the exact vehicle UUID, burner ID set and tested output.
It is not a replacement for instantaneous measurements and is not written into
the bridge's `hasBalloon`, gas activity or any saved configuration.

With that confirmation, idle readiness accepts the precise combination exported
by Vehicle Bridge 0.2.1: signal 0, gas output 0, association source
`heater_membership`, association state `no_balloon_reference`. The burner must
still exist on the same vehicle in a fresh, complete inventory. An explicit
invalid capacity/heater-membership state, unsupported legacy association source,
missing burner, changed group/vehicle or expired/partial scan still refuses.
A raw missing reference at signal 0 without a completed positive test does not
obtain this allowance.

The calibration view separately shows `Initialization this run: confirmed
(retained while off)` and each burner's instantaneous `association_now`. Long
calibration diagnostics wrap and scroll, including on a small Computer viewport.
An Initialize value that would produce zero heat with inverted wiring is refused.
After a successful test and rescue, continue with **More → Verify direction**;
perform and confirm the remaining physical hover/manual/rescue checks and set
suitable altitude PID gains. The initialized state does not fill or bypass any
of those prerequisites. Editing/saving a changed control configuration resets
calibration as before, so configure gains and mappings before final calibration.

## Armed operation

When the calibrated controller requests positive heater output after a zero-output
period, the last commanded value determines heat demand (including the declared
inversion). The service provides a bounded **2-second** restart interval for the
lazy association to reappear; a changed positive output does not restart that
interval. While waiting, the inventory must remain fresh/complete and all selected
burners must remain present on the same vehicle. Explicit invalid membership is
not treated as a warming-up state. After the interval, a missing heater signal or
association applies rescue in the same control step. Zero demand can again use
the narrowly defined idle allowance. This does not impose a minimum heat, change
the rescue value, repeat initialization or hold heaters on automatically.

The volatile confirmation clears on service start/restart, a changed control
configuration, a new output test (including one that fails), or a failsafe.
Thus a reboot requires a new positive initialization when the burners are off.
It remains valid between successful calibration steps during one service run.
Idle data cannot prove that the balloon envelope has not changed while off;
that limitation is handled by renewed live feedback when heat is requested,
not by pretending the missing reference is present.

## Validation and rollback

Offline tests recreate the two screenshots, verify that initialization survives
rescue-to-zero, and confirm that this alone cannot arm incomplete calibration.
They cover calibrated cold start, the bounded restart interval, successful live
reassociation, a missing receiver during requested heat, missing association after
the interval, applied rescue, failed retest invalidation, service restart,
wrong/changed groups, explicit invalid membership, missing burners and stale scans.
UI tests verify the retained-state label and bounded wrapped calibration output.
Source/compact regressions and strict 1 MB update/rollback/interruption fixtures
are also run. The Minecraft mod itself is unchanged; no in-game validation is
claimed beyond the user's provided observations.

Use Updates rollback or Recovery for the retained checkpoint. Live user accounts,
passwords and personal data remain preserved. No new Minecraft JAR is required;
Vehicle Bridge **0.2.1** remains supported.

The source regression run passes **143 suites** and compiles **320 Lua files**.
The strict 0.18.53 → 0.18.54 update/rollback simulation peaks at **907,451 bytes**
with a 100,000-byte user-data witness. Fresh installation including that witness
uses **797,485 bytes**. Interrupted backup and live writes recover the previous
release while retaining the durable checkpoint.
