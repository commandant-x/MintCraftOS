# Automatic provisioning

In NEXUS, configure the MASTER once with a private key, then authorize the
computers you own in Deploy. Connect a shared writable data disk and choose
Automate. Confirm the background deployment authorization.

The saved policy freezes the currently authorized IDs in the chosen group.
Discovery cannot authorize new computers. The service prepares the disk,
starts or restarts eligible computers, waits for authenticated heartbeats,
and removes provisioning credentials when every scoped computer confirms
the expected content-addressed release. It continues with the window closed
and after a MASTER restart. A single writable disk is selected automatically;
multiple disks require a choice. Existing foreign startups remain protected.

There are at most two power attempts per ID and release, separated by one
minute. Attempts are saved before requesting power. Pause automation stops
future attempts. Renewing Automate explicitly approves another attempt cycle.
Power off creates a maintenance hold; Restart agent clears that hold.
Changing group membership blocks the policy until renewed. Already enrolled
agents are never restarted merely because their heartbeat becomes stale.

Keep provisioning on a trusted network: its disk contains per-agent keys.
HMAC authenticates messages but does not encrypt them. Eject the disk after
automatic sealing. Disk startup must be enabled on target computers.

This release automates disk provisioning, not arbitrary remote execution,
network streaming updates, autonomous industrial control, or self-enrollment
of unknown machines. Agent updates still require the shared provisioning disk.
