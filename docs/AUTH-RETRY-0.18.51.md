# Password retry delays and faster repeat login — 0.18.51

The first four failed attempts have no added waiting period. Further failures
require 30 seconds, 1 minute, 5 minutes, 15 minutes, then 1 hour between attempts.
Further failures remain capped at 1 hour. No data is erased and there is no
permanent lockout. A successful authenticated verification clears the counter.
The counter is shared across authentication entry points and user names, so
changing the name does not obtain a separate allowance.

The counter and deadline live in the protected, transactionally written
`/system/security/users.db`. An attempt is reserved durably **before** hashing:
rebooting or killing a comparison cannot remove an attempted guess. A failed
comparison renews its wait from completion. Rejected attempts during a wait do
not compute a password hash, write the database or extend the deadline. A storage
failure refuses authentication; malformed persisted retry state fails closed.
UTC deadlines survive reboot. Within a boot, an observed wait cannot be shortened
by moving the wall clock forward. If UTC is absent or rolls backward, the wait
uses a monotonic countdown; reboot without a trustworthy UTC clock reapplies the
bounded waiting period. Server-clock/file control is outside this protection.

The kernel console shows a countdown, consumes input during the wait, and keeps
background service events running. The timer does not repeatedly read or rewrite
the account database. Cancellation, failed persistence and concurrent session
changes cannot unlock the console. Reserving before comparison also means an
interrupted attempt or an unavailable verifier can consume an attempt; this is
a deliberate choice to prevent interruption bypasses.

## Faster repeat login and migration

A successful login prepares a new independently salted **PBKDF2-HMAC-SHA256
15,000-iteration** record. Later attempts use that record, reducing derivation
work by 40× relative to 600,000 iterations. Based on the reported two-minute
verification this aims for a few seconds, but timing depends on server load and
CC:Tweaked scheduling; no in-game timing is claimed.

The original high-cost `passwordHash` remains intact for retained older OS
versions. The quick record is tied to an exact copy of its source credential.
If an older release changes the password, the source no longer matches and the
quick record is ignored. Successful verification of the new password rebuilds it.
Password changes replace both records; old quick credentials are never reused.
The first migrated login, enrollment and password changes still run the high-cost
calculation once. Passwords are not stored in plaintext. There is no dependency
on a new Minecraft mod and the password minimum remains eight characters.

**Security tradeoff:** anyone who steals users.db can attack the cheaper record
offline. The retained expensive record does not offset that weaker record.
Increasing retry delays protects the running OS authentication paths; it does
not replace secure hardware, file encryption or server access control. This
implements progressive waiting similar to a phone UI, not iPhone hardware
security. Do not use a short numeric PIN as the password.

## Rollback and validation

Use the existing Updates rollback action or Recovery. The live user database is
preserved, including the original high-cost credential. Older releases ignore
the quick record and retry state, authenticate with the original password hash,
and may again take minutes. They do not enforce this new persistent retry policy.
A simulation verifies that an older release changing the retained password
invalidates the newer quick record when returning to this release.

Tests cover every delay and its cap, blocked attempts doing no KDF, successful
reset, reload/reboot, interrupted verification, persistence failures, corrupted
state, clock changes, old and quick credential selection, password changes,
concurrent changes, UI countdown and locked-input isolation. The real quick KDF
is checked against an independent Python hashlib vector, including incorrect
passwords, production-cost creation, progress and cancellation. The existing
600,000-iteration production cryptography test is also run. Installer tests
check updates/rollback and interrupted writes under the strict 1 MB disk quota
with a 100 KB user-data witness. These are offline tests, not Minecraft validation.

The strict 0.18.50 → 0.18.51 upgrade/rollback fixture peaks at **859,941
bytes** with a 100,000-byte user-data witness; fresh installation including that
witness uses **792,365 bytes**. Interrupted backup and live writes restore the
previous release and retain its durable checkpoint. The interruption fixture
selects an actually changed Lua file, including releases that change only system
code. The previous release's actual users module also authenticates the retained
high-cost record after migration in the account test harness.
