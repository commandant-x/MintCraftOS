# Faster repeat unlock without a new weaker disk record — 0.18.53

The previous 15,000-iteration persistent verifier may still take several seconds
in Lua. An unmigrated account still requires its original 600,000-iteration check
once before a quick credential can be prepared. This release does not skip
proof of the old password, delete credentials or reset the user's password.

After a successful login/enrollment/password change, the trusted users module
keeps one private volatile verifier for the authenticated account. It consists
of an HMAC-SHA256 comparison closure with a per-instance key and expected MAC;
it does not capture the plaintext password. Repeated locks/unlocks during that
boot use this check rather than deriving PBKDF2 again. The returned closure
compares every byte of the fixed-length MAC. It bounds candidate input and
provides no unthrottled public verification entry point into the cached account.
The users module holds the closure privately; it is not part of the database,
service status, account listing or serialization. RAM key generation is used only
for this volatile verifier, not as an encryption key or a hardware security claim.

The cache is bound to the user name and exact source password, quick password and
quick-source records. A credential change invalidates it; successful password
changes replace it. Logout discards it even if persistence fails. Reboot/module
reload discards it. One account is cached at a time. A broken/missing verifier
provider still refuses authentication. The same durable attempt reservation,
increasing retry delays, session cancellation and compare-and-save checks run
before a cached comparison can unlock anything. A correct cached password cannot
skip the waiting period or a storage failure, and wrong guesses are counted.

## What to expect

- **Quick unlock:** repeat unlock in the same boot, with no PBKDF2 calculation.
  It still performs small transactional account writes. Actual server latency
  needs measurement in game; instantaneous execution is not promised.
- **Password check:** first login after reboot using the 15,000-iteration disk
  verifier, if it was previously prepared and still matches the original record.
- **First verification (slow):** the original expensive verifier is required,
  usually for the first migration. Let one correct login finish. Repeatedly
  rebooting before completion cannot finish the migration or warm the RAM cache.
- **Preparing quick unlock:** creation of the persistent quick record after the
  first old-password verification. The completed account transaction retains it.
- **Password setup (slow):** enrollment/password changes still calculate the
  original high-cost record for older OS rollback compatibility.

Settings and the kernel lock screen now show these stages instead of the same
ambiguous authentication percentage. Updates require **reboot** to load the new
running authentication modules. F12 locks the screen without logging out and
preserves the volatile verifier; Logout or reboot requires a disk verification
next time. Background service events continue while slow work is running.

## Security and rollback

This change does not lower the 15,000-iteration persistent cost again. The offline
file-guessing tradeoff from 0.18.51 remains, and a long password is still needed.
A process/server operator who can inspect or modify trusted kernel memory or
account files is outside the screen-lock boundary. This is not a secure enclave,
file encryption or protection against a malicious server administrator.

The original high-cost disk credential is retained. Existing Updates rollback
and Recovery continue to work; an older version simply ignores the RAM-only
optimization. Personal data and current credentials are retained. No new
Minecraft addon is needed.

Offline tests cover initial/reboot KDF selection, repeat locks without KDF,
incorrect cached passwords, persistent delay enforcement, failed durable writes,
logout (including failed logout), credential/source changes, reauthentication,
concurrent permission/session updates, cancellation, stage labels and absence
of the plaintext as an upvalue of the actual cryptographic comparison closure.
HMAC correct/incorrect/bounded input and independent closures use the real crypto
provider; the unchanged PBKDF2 quick path is still checked against Python hashlib
vectors. Source/packed regression suites and strict 1 MB actual-release
upgrade/rollback and interruption tests are run. No in-game timing is claimed.

Validation: 142 Lua suites pass in source form. The exact 0.18.52 → 0.18.53
update/rollback simulation peaks at **891,640 bytes**, including a 100,000-byte
user-data witness. Fresh installation including that witness uses **796,270
bytes**. Interrupted backup/live writes recover the previous release with its
checkpoint retained. A standalone Lua CPU benchmark measures approximately
**0.0004 s** per volatile HMAC comparison (100 comparisons) versus **2.022 s**
for a 15,000-iteration derivation. This excludes database I/O, rendering and game
scheduling and is not an in-game end-to-end login time.
