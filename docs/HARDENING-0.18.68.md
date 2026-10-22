# Final hardening stage 5: native Combat secondary views — 0.18.68

Combat's radar/cannon/alias/network configuration forms and four-stage radar
setup now use the shared native form panel. Existing native radar 2D/3D, targets,
cannon list, fire, probe and network supervision remain unchanged. Text rescue
retains the original form client. Native and text setup call one shared wizard
action implementation, including source-profile handling, manual-coordinate
parsing, frame validation and final save; no second geometry inference is added.

Read-only radar capability/position/profile information is displayed as native
rows. Real configuration descriptors drive editable numeric/enum/boolean fields.
The network shared key remains masked and cannot be copied by the native
clipboard's secret-field copy action. Escape discards pending invalid text.
Cancel/stop-tracking is always available independently of field validity.
Configuration save still uses existing authorization and confirmation handlers.
No configuration view calls aim/fire. The existing fire page keeps its separate
explicit, expiring, single-use confirmation token.

Tests follow the complete native four-stage wizard, ensure there is no implicit
save/aim/fire, explicitly verify heading before saving, cancel invalid input while
tracking and inspect network secret masking. Existing native Combat rendering,
coordinate/profile/filter tests, fire authorization/replay tests and source/packed
suites remain active. Exact 0.18.67→0.18.68 retained-checkpoint migration/rollback
is checked with a 1,000,000-byte quota and 100,000-byte user-data witness.

## Native application audit matrix

- Browser, CraftTube, Store and NEXUS use the shared native client model and keep
  existing network/package/service authorization.
- Editor and Terminal have dedicated native input/output, selection/clipboard
  and virtual keyboard paths; textual documents/console output are content,
  not a legacy terminal-cell render of the whole application.
- Files, Logs, Devices, Services, Settings, Task Manager, Messenger and Update
  retain their existing dedicated native list/form/action/modal clients.
- Navigation's remaining form/guide/calibration/equipment pages were completed
  in 0.18.67; its attitude and route/sublevel clients were retained.
- Combat's remaining configuration/setup pages are completed here; its existing
  live graphic views and independently confirmed fire workflow are retained.

All 16 application entry points have native clients. The known secondary-view
fallback gaps found in the audit are now covered. Memory/unsupported-display
fallback and explicit text rescue remain intentional recovery paths, not removed
features. This matrix does not claim Minecraft/mod-specific integration was run.

In game, on a disposable installation, compare every radar setup field against
the native and text clients. Exercise manual/API coordinates, unknown frames,
source-profile changes, disconnected radar rejection, cancel and final save.
Check cannon/network/alias forms, masking and scale/pointer mapping. Confirm
that visiting/editing configuration never moves or fires a mount. Test aim/fire
only on an isolated unloaded/test rig with deliberate operator confirmation;
verify expired/reused tokens and changed targets cannot fire. No real firing or
server performance validation was executed here.

Remaining objective: publish common real-source interfaces/contracts for ORACLE,
ATLAS, SYNAPSE, WARROOM and ASTRAL, without inventing providers, sensor readings
or autonomous mission execution.
