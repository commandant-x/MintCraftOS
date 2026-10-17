# Existing association conflicts

Normal updates preserve the MASTER key. A rejection now distinguishes a changed
MASTER, agent ID or association key. The same MASTER ID alone does not prove
it still has the original private key.

Prepare the disk from the updated MASTER. On the affected owned agent, stop
the running agent with Ctrl+T, then run `disk/nexus/reassociate.lua` (replace
disk with its actual mount). Type the displayed computer-specific phrase to
approve replacement locally. The previous association is backed up at
`/nexus/previous-association.cfg`; receipt journals are archived separately.
Then eject the disk and reboot.

Foreign startups and full OS installations remain protected. Unselected agents
cannot use this workflow. No network message approves reassociation. The disk
contains credentials: keep it on a trusted network and seal it after deployment.
