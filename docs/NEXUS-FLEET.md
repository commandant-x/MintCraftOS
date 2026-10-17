# NEXUS 0.3: deployment wave and coordinated infrastructure

## Faster deployment

Automate prepares a content-addressed package once. Module bytes, hashes and
node keys are cached until the service restarts. Existing disk files are compared
with the cached bytes and rewritten only if different. Agents verify the payload
before installation, then copy those already-verified bytes from memory.

All eligible computers receive power requests in one pass, with NO programmed
delay between requests. This is not a guarantee of literally simultaneous CPU
execution: peripheral calls, HMAC verification, disk I/O, server ticks and chunk
loading still take time. Per-target retry cooldowns remain to prevent reboot loops.
First heartbeat staggering is at most 350 ms, instead of several seconds.

Approved destructive recovery is now also carried by the trusted boot disk.
An association mismatch, foreign internal OS/startup or corrupt installed agent
can be diagnosed and recovered locally during the same boot, without waiting
for a failure report to reach a MASTER with a different key. Healthy installations
are not erased. The boot payload must verify before any reset, and the MASTER,
ROM and mounted disks remain excluded. Keep provisioning media private.

## Coordinated read-only infrastructure

Automate also enables automatic observation jobs. Agents prioritize advertising
supported inventory, energy_storage and fluid_storage endpoints. The MASTER
deduplicates shared wired names and assigns each endpoint to an online authorized
agent advertising observe. Assignment accounts for outstanding tasks and current
responsibilities, rather than sending every agent to scan the entire same network.
Local side names remain scoped to the agent, since left on two PCs is not one device.

The Infrastructure tab shows owner, counts/levels, errors and sample age. Reports
and assignments survive MASTER restart. Observations target a minimum 30-second
interval per endpoint; actual refresh can be slower at capacity or on a slow server.
Only two observation jobs are queued globally per second and at most two active
jobs per eligible agent. Limits are 128 endpoints and 24 advertised peripherals
per agent, prioritizing supported sensors among the first 128 discovered names.
Reports older than 60 seconds are marked stale. Pause stops new coordination jobs.
Observation deadlines are 45 seconds, keeping their receipt retention bounded
even when one agent handles the entire two-jobs-per-second admission budget.

Agent reads run in a separate coroutine, so a suspended peripheral read does not
block heartbeats. Queues and retries are bounded. Unsupported peripheral methods
are never guessed or invoked; no redstone, item transfer or other machine command
is issued. Generic inventories report bounded totals (partial after 256 entries),
energy reports current/capacity and fluid stores report up to 64 tank entries.

This is the observation foundation of SPIDER/DOMINION, not full Create automation.
No stress/RPM adapter, production rule engine, flight controller, arbitrary remote
Lua execution or network streaming updater is introduced by this release.

Official read-only APIs:
- https://tweaked.cc/generic_peripheral/inventory.html
- https://tweaked.cc/generic_peripheral/energy_storage.html
- https://tweaked.cc/generic_peripheral/fluid_storage.html
