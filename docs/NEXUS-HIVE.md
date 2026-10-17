# NEXUS 0.2.0: HIVE and 2D network

The Network view is a logical 2D roster, not a physical map. CC:Tweaked does
not expose cable routes or node coordinates. It shows MASTER, named agents,
registration status, groups and a selectable details pane on wide displays.
Pockets use paginated rows and a compact selected-agent summary. All 64
managed computers remain reachable with touch controls. Selecting a node
does not authorize it or send a command.

Missions adds Ping group, Inventory group and Storage group. These target
only authorized agents in the configured group, with a recent authenticated
heartbeat and the requested advertised capability. Auto assign check sends
one storage check to the eligible agent with the fewest active missions;
ties use computer ID for deterministic assignment.

Jobs carry a stable ID and a two-minute deadline across retries/restarts.
Retries remain on the original agent. They never broaden authorization or
execute arbitrary Lua. Active jobs are retained; completed history is compacted
at 96 entries, keeping recent jobs and a bounded 128-entry summary archive at
/var/nexus/job-history.cfg. The archive is not a complete permanent audit log.

New 0.2 agents reclaim expired task receipts while refusing expired requests.
Old 0.1 agents remain protocol-compatible but need disk redeployment for the
receipt reclamation changes. Regenerate the provisioning disk from the updated
MASTER, then approve Automate for the desired group.

This completes another HIVE foundation increment, not the entire specification.
Network streaming updates, OS-background agents, SPIDER service discovery,
industrial DOMINION controls and BREACH LAB are not implemented here.
