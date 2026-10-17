# Destructive provisioning and automatic MASTER keys

Deploy > Erase & provision freezes the selected group IDs after two explicit
confirmations. It writes a per-operation reset token to the trusted boot disk,
starts selected computers and reinstalls them without local reassociation prompts.
It destroys ALL writable internal files, including other programs and user data.
There is no data backup or secure-overwrite guarantee. Never approve it on a
computer you want to preserve. No Minecraft world or host filesystem is modified
by deployment tooling; deletion occurs through the target computer's CC filesystem.

The bootstrap checks selection, excludes the MASTER, verifies payload hashes and
Lua syntax, and requires a separate boot disk before deletion. It traverses only
the root hdd, skipping ROM, mounted disks and read-only paths, including nested
mounts. Completion is recorded only after installation. A successful agent is not
wiped again by the same operation. An interrupted reset resumes from the boot
disk; targets still require enabled disk startup and loaded chunks.

The disk is authoritative physical provisioning media, not proof of ownership.
Keep it private. Anyone who can change its manifest can change reset authorization.
Authenticated heartbeats must confirm both release and reset token before the
MASTER seals its credentials. A new Erase & provision confirmation creates a NEW
operation and can erase those agents again. Ordinary Automate remains non-destructive.

In Setup, leave the key empty and Save MASTER for automatic initial creation.
The MASTER requests 32 bytes of randomness over HTTPS from RANDOM.ORG's documented
integer interface, mixes local random bytes, and hashes the result. This trusts
the HTTPS provider and certificate validation; it is not an offline CSPRNG.
Existing MASTER keys are reused, not automatically rotated on boot or update.
HTTP failure or invalid responses fail closed, with manual key entry still
available. No predictable clock-only fallback is used. Secrets are neither shown
in UI snapshots nor sent as parameters in the entropy request.

Source: https://www.random.org/clients/http/api/
