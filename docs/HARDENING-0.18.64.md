# Final hardening stage 1: security and backup preservation — 0.18.64

Audit base: GitHub main `47329591f75ee2d1eedb8e12ee819ec8fa86392f`.
Existing features are retained. This stage does not claim completion of the full
Graphics 2.0/ASCENDANCY objective.

## Security fixes

The factory-empty admin credential cannot log in through the API. First-start
enrollment gates app authorization as well as the session screen, including
legacy configurations with security disabled. Trusted internal system actors
still have boot/recovery access. Enrollment only changes factory-empty admin;
existing password hashes, roles and per-user permissions remain untouched.

Protected existing accounts are selected for unlock without requiring an account
named admin. Empty guest never unlocks the console. Current protected identity
is preferred, then admin, then another protected account deterministically.

Lock/unlock by the same identity preserves application windows. Sign-out or an
account change closes old-account windows and runs normal worker cleanup, so
cached private editor/terminal content cannot appear to a different user. Save
work before signing out: unsaved in-memory drafts are closed, while personal
files on disk are neither written nor removed. Navigation worker cleanup retains
its existing rescue behavior.

## History policy

The operator's prior choice of `retainRollback=false` remains supported and no
new permanent history is created by the current Update service in that mode.
This audit removes implicit deletion of already existing backups. Only an
explicit installer `purgeHistory=true` operation can delete that fixed history
directory; ordinary Update does not set it. Legacy callback-created checkpoints
are preserved unless an explicit purge was requested. Retained-history opt-in
(`retainRollback=true`) keeps durable checkpoint/rollback functionality.
Temporary transactional backups continue to protect interrupted installation in
both modes and are removed after successful completion.

## Audit findings and next stages

All 16 registered applications have pixel clients. Navigation still uses legacy
text for several setup/calibration/configuration/diagram views; Combat also has
legacy setup/configuration paths. Do not equate a pixel entry point with complete
native coverage. Existing native clients, extended palette, maximum physical
resolution, profiles, fallback and service scheduling are not removed.

A larger candidate containing UI scales 1/1.5/2, a session-scoped shared clipboard
and optional operator speed/travel limits passed functional suites, but failed
the retained-checkpoint 1 MB migration preflight as one combined release. It is
not published as a verified main release. Split these changes into smaller
independently tested delivery stages before the native-view completion work.
ASCENDANCY runtime modules must wait until the critical gaps are closed.

## Verification and in-game acceptance (not executed here)

New regressions cover API-level factory login/authorization refusal, atomic
failed enrollment, current/custom protected identity migration, empty guest
rejection, retained windows on same-user lock, closure on account switch and
preservation of existing backup bytes during normal no-history installation.
Existing source/packed security, permission, credential rollback and interrupted
installation suites are rerun. `tests/compact-disk.lua <previous-install.lua>`
opts into retained history and checks exact-version update/rollback under a
1,000,000-byte quota with 100,000 bytes of user data. No real backup is deleted
by these isolated fake-filesystem tests.

In game, use disposable computer/disk copies. On a fresh copy, verify mandatory
8-character enrollment and blank-admin refusal; reboot and unlock. On an existing
copy, compare account hashes/roles/permissions locally before/after upgrade and
opt-in rollback, including an account without the name admin. Never publish
credential values. Open a test draft, lock/unlock as the same user, then save it
and sign out: the next identity must not see the prior user's windows. Verify
F12 and text rescue. Classic CC does not expose a dependable GUI-close event.

Test interrupted staging, backup and live writes only on disposable copies;
retry the pinned installer or recovery shell and verify personal-file checksums.
Repeat with a saturated disk and verify live files remain recoverable. In retained
mode check a successful rollback; in no-history mode verify temporary recovery
only, without expecting a previous version after successful commit. Inject a
graphics failure only in a disposable environment and verify text fallback.

Flight acceptance remains physical: verify both selected burners, direction,
manual takeover and rescue; test STOP/F10, closed owner, lost permission,
stale/future telemetry, wrong vessel and receiver loss. Never mark a physical
check from software acknowledgment alone. No game physics, real server FPS or
metre-accurate altitude hold is claimed by offline tests.
