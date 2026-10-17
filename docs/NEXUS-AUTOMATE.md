# Unified Automate workflow

V0.18.24 exposes Automate and Pause in Deploy. Preparing the disk, deploying,
retrying, recovering and sealing are internal phases, not separate UI commands.
Keep one writable shared provisioning disk connected; multiple candidates cause
an explicit ambiguity error rather than writing to an arbitrary disk.

Automate requires approval for a frozen list of IDs and explicitly warns that
failed updates may erase ALL internal files without backup. Existing policies
do not gain this authority silently: run Automate again to approve recovery.

Normal installation gets two attempts separated by at least one minute. Recovery
requires evidence: an authenticated, current-release bootstrap failure report
for a protected/corrupt installed agent, or a fresh authenticated heartbeat from
the old release after an attempted deployment. Mere offline status is not evidence.
Bad provisioning payloads, missing disks or absent heartbeats do not authorize
erasure. Signed bootstrap reports are checked while fresh and retained against
the corresponding persisted attempt, so waiting for cooldown is not mistaken
for permission to accept stale messages.

Only the failed ID receives a release-specific reset token. Other selected
agents get ordinary updates. The reset has at most two power attempts and its
completion token prevents repeated erasure after success. Receipt of the correct
release and token is required before automatic disk sealing. Pause stops future
service actions, not a reset already running on a target from its boot disk.
Eject that disk to prevent further bootstrap starts if necessary.

Legacy service actions remain for compatibility, but the deployment UI no
longer offers Prepare, Deploy, Seal, Erase, Restart or Power off buttons.
