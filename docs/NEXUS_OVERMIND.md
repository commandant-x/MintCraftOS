# NEXUS OVERMIND 0.1.0

One Mind. Many Machines. Total Coordination.

This is a MintCraftOS application, not another OS. The first release implements
the administrative bootstrap demonstration and its communication/UI foundation.
It does not implement a cyberwarfare agent, arbitrary remote Lua execution or
propagation outside the selected infrastructure.

## Eight-Computer Demonstration

1. Install MintCraftOS 0.18.18 on the MASTER. The other seven computers should
   have blank local storage. Back up any computer you intend to provision.
2. Connect all eight computers and a disk drive to the same wired modem network.
   Enable peripheral sharing by right-clicking the wired modems. Insert a data
   disk and verify that the MASTER sees the seven computers and drive.
3. Open Terminal and run `nexus deploy`, or open NEXUS OVERMIND from the desktop.
4. In Setup enter a private MASTER key of at least 32 characters and group
   `factory`. Save MASTER. Keep this key private and back up its configuration.
5. In Deploy, Rescan. Tap the `[ ]` checkbox of each of your seven computers.
   A discovered computer is NOT automatically authorized. The MASTER cannot
   select itself. Selection and group membership are saved locally.
6. Select the shared disk using Disk. Deploy selected prepares the disk and,
   after confirmation, restarts the authorized computers in the current group.
   `nexus deploy --group factory` opens this group, it does not silently deploy.
7. Wait for ONLINE with the expected deployment release. If installation fails,
   inspect the target computer's local bootstrap error. An old agent heartbeat
   does not count as confirmation of a new installation.
8. After all seven enroll, choose Seal disk to remove the provisioning keys,
   their backups and the disk startup. Eject the disk. Restart an agent and
   check that it returns ONLINE without the drive.
9. Select a computer by its row (not its checkbox). Dashboard actions Ping,
   Inventory and Storage submit signed read-only missions. Results appear in
   Missions. The task engine also supports the bounded `sum` compute mission.

Disk boot requires `shell.allow_disk_startup=true` on the target computers.
Ordinary peripherals cannot read/change that setting remotely. The shared
drive must be visible at boot. The MASTER can request power/reboot, not bypass
CraftOS startup settings or a server's peripheral-sharing restrictions.

The disk bootstrap skips unselected IDs and continues an existing local
`startup.lua` when present. Selected existing OS/startup installations are
protected and are not overwritten. This release provisions lightweight,
standalone agents on blank computers; embedding agents in existing OS profiles
requires a later explicit opt-in integration.

## Implemented Interfaces

- `system.services.nexusd`: cached snapshot, explicit authorization, bounded
  worker action queue, wired discovery and power management, disk provisioning,
  authenticated enrollment, heartbeats and persistent mission records.
- `system.nexus.bootstrap`: fixed-path payload hashes and syntax validation,
  staged slots, configuration activation, protected startup and repair/resume.
- `system.nexus.agent`: local independent startup, peripheral inventory,
  reconnect attempts and read-only mission allowlist. No `load`/`shell.run` of
  network-supplied instructions.
- `system.nexus.protocol`: per-agent HMAC-SHA256 keys, source/destination checks,
  30-second freshness, bounded replay window, 8 KiB payload limit.
- `apps.nexus.main`: Setup, Dashboard, Deploy, logical Network map and Missions.
  Uses existing action menus, forms, touch keyboard, windows and subpixel/blit
  canvas. The graph is logical, not physical cable routing.

## Reliability and Lifecycle

The agent writes a receipt before sending a mission result. A repeated job ID
returns the stored result even after restart. Only idempotent read-only missions
are enabled. Unknown command types return an error. Pending jobs retry at most
three times with the same job ID; a timeout never claims successful execution.
MASTER jobs and authorization survive reboot. Agents are marked offline after
15 seconds without a verified heartbeat. Chunks must actually be loaded; NEXUS
does not provide a chunk loader.

Prepare/deploy again creates a new slot. A successful install retains the
previous slot. The local launcher tries that slot if loading/running the new
agent raises an error. A failed in-game connectivity check alone does not yet
automatically roll back. Updating MintCraftOS on the MASTER supplies new payload
code; this release updates agents via the trusted disk, not remote code upload.

For local uninstall, remove the ID from the MASTER, eject provisioning disks,
stop the agent with Ctrl+T, then run `/nexus/uninstall.lua` in CraftOS. Type
`UNINSTALL` to remove only the NEXUS-owned startup and `/nexus`. A non-NEXUS
startup is protected. Existing application files outside that directory are
not deleted.

Bounds: 64 managed computers, 128 jobs in the MASTER history and 128 durable
receipts per agent, 32 ingress messages, four verifications per worker tick.
The bounded histories currently require local archival/reprovisioning when full;
there is no automatic history rotation. Heartbeats are staggered to reduce
simultaneous startup bursts. This is not protection against every modem flood.

## Security Boundary

The initial disk is a TRUSTED provisioning medium, not a security boundary
against its readers. Every computer which can read it can read the selected
agents' provisioning keys. Provision on a private wired segment, keep unknown
computers off that segment and seal/eject the disk afterwards. Seal removes
keys from that disk, not copies an observer has already made. If exposure is
suspected, reprovision with new credentials rather than assuming sealing fixes it.

The MASTER root key is never copied to agents. Application snapshots and logs
do not expose it. Per-agent keys separate agents once the provisioning disk is
removed. HMAC authenticates messages; it does NOT encrypt inventory/results.
Rednet IDs, labels, group names and physical discovery alone are not trusted
authentication. Physical filesystem access or replacing the trusted disk can
defeat this model. Use backups; there is no claimed hostile-code sandbox.

## Validation and Remaining Phases

Automated tests simulate the eight-computer installation, outsider exclusion,
disk-independent agents, signed enrollment, duplicate/reboot job handling,
spoof/expiry rejection, interrupted file operations and protected startups.
UI bounds and modal input are exercised on small/large screens. Native CraftOS-PC
smoke tests run in visible windows with isolated storage. These are NOT a claim
that eight physical computers on your Minecraft server were operated by Codex.

Remaining before the requested OVERMIND 1.0:

- General Rednet service mapping and richer topology beyond wired/NEXUS inventory.
- Capability-based multi-agent assignment, batch missions and history rotation.
- Fully transactional network-delivered signed updates with health rollback.
- Create/Aeronautics industrial control, per-action policies and safe shutdown.
- BREACH local source audit and isolated lab simulation, kept separate from deploy.
- Existing-MintCraftOS agent background integration and remote lifecycle controls.

## Technical Sources

- CraftOS disk-first startup implementation:
  https://github.com/cc-tweaked/CC-Tweaked/blob/mc-1.21.x/projects/core/src/main/resources/data/computercraft/lua/rom/startup.lua
- Computer power peripherals: https://tweaked.cc/peripheral/computer.html
- Rednet security and protocols: https://tweaked.cc/module/rednet.html
