# No retained previous versions — 0.18.63

New default policy: `/system/config/update-storage.cfg` contains
`retainRollback=false`. This implements the requested removal of version history.
The installer validates the incoming changed Lua payload before removing the
fixed `/var/backups/update` directory, including the old latest/previous pointers.
It preserves personal files, packages, credentials and other configuration.
Interrupted install/rollback/restore/package operations must be recovered first.

No durable historical checkpoint is created by the new Update service in this
mode. An older Update callback may still create one during migration; the new
installer removes that checkpoint before writing its temporary transaction.
New Update callbacks reauthorize/commit before history cleanup. Existing explicit
`retainRollback=true` policies opt into the former checkpoint behavior; absent
policy flags adopt the bundled default and are persisted without deleting other
policy fields. Storage-policy edits preserve an existing false retention flag.

Installation still makes one temporary backup of the changed live files and a
journal before overwriting them. Interrupted writes recover from this transaction;
a successful commit removes it. It cannot restore a previous version after a
successful installation. No permanent deletion of personal data is introduced.

The no-history space estimate needs one old-file copy rather than two. The RAM
payload is not redundantly staged on disk during upgrades. Retained history is
removed before the free-space check so it can actually free the occupied space.
A failed disk preflight after cleanup leaves current live OS files unchanged,
but old version history has already been intentionally deleted.

Offline tests exercise a 1,000,000-byte disk with 100,000 bytes of personal data
and 160,000 bytes of obsolete history, deletion denial before cleanup, migration
through a legacy callback, absent checkpoints after success, interrupted live
writes/recovery and retry. Retained-history regression tests explicitly opt in
to their old policy, so that recovery path is tested separately.
