# 0.18.39: Native Update And Associated Radar Agents

## Changes

- Update now uses native bitmap controls, installed/release versions, verified
  commit, rollback checkpoint, real transaction phases/counts and a bounded,
  wrapped diagnostic inspector. Drawing performs no filesystem/network reads.
  Small-window, keyboard, busy/disabled and hidden-confirmation states are tested.
- Check resolves a commit and reads that commit's VERSION. Apply confirmation
  binds the installed version, release version, repository and SHA; rollback
  binds the checkpoint. Single-use confirmations expire after 30 seconds and
  cannot transfer to another PID. Source/version/checkpoint changes refuse work.
- A protected service-owned raw scheduler worker replaces the app-owned worker.
  Closing Update, logout/session replacement or permission revocation before
  mutation refuses the operation at the next authorization checkpoint. Once the
  rollback checkpoint starts writing (or rollback recovery begins), the service
  completes/recoverably fails independently of the UI. There is no automatic
  retry of uncertain operations. Missing worker state remains recovery-required.
- Installer progress callbacks cannot abort a write. Success requires an explicit
  installer commit callback and the installed VERSION postcondition, not merely
  a beforeInstall hook. Transactional undo/checkpoints and user-data preservation
  remain in place. Installer HTTP input is bounded to 4 MiB (previously 1 MiB).
  Existing 0.18.38 clients can install this protocol-2 bundle; the new client
  requires the commit callback for subsequent installations. Downloaded pinned
  repository Lua is trusted code, not isolated arbitrary code.
- Combat's narrow-window toolbar no longer silently loses actions. Overflow
  commands use a scrollable, input-isolated menu; closing it cannot select a
  contact behind it. Existing manual fire confirmation remains mandatory.
- Associated NEXUS agents discover supported Create: Radars types in their
  peripheral inventory, then read only advertised getTracks/getScanGeometry/
  getPosition/getRange/getRotation/getDishCount. Acquisition runs in the agent
  worker, separate from the network receiver. No remote Lua or radar command
  methods are introduced. Samples go directly to the associated MASTER using
  the existing per-agent HMAC-SHA256 envelope, replay/freshness and membership
  checks. Combat imports them as remote observations, never commandable targets.

## Radar Setup

1. Update the MASTER, reboot, then update/reprovision only your associated agents
   with NEXUS Automate and the authorized provisioning disk. Old agents do not
   gain this capability until their payload has actually updated.
2. Put an Ender modem on the MASTER and each remote agent. Wired or ordinary
   wireless modems also work within their network/range. Both computers must
   remain running in loaded chunks. Ender transport is not a chunk loader.
3. Attach the bearing directly to the agent, or expose the bearing through an
   enabled wired modem network attached to that agent. Ender modems carry
   messages; they do not expose remote peripherals to peripheral.wrap.
4. Keep this deployment group within one world/dimension coordinate domain.
   Only the MASTER's current group is imported. The group is an operator-defined
   namespace, not automatic dimension detection. Ender transport can cross
   dimensions, so do not assign different dimensions to the same radar group.
5. Open Combat and select the imported `Agent <id> / <endpoint>` radar or Network
   overview. Names appear only when provided by the API; otherwise IDs remain.

Geometry is accepted only from geometry-v1 world position/heading/FOV data.
Stock bearing coordinates, heading and cone are not guessed when that API is
missing or fails: the radar remains diagnosable but cannot draw a reliable cone.
The optional Radar API bridge may be needed for source-world geometry; no JAR
or live Minecraft configuration is changed by this OS update.

Agent sampling targets two reports per second in total, round-robin across up to
eight discovered radars. Each report contains up to twelve contacts and marks
truncation; it is not an exhaustive large contact feed. A valid track progression
must be observed before freshness is asserted. Data older than five seconds
becomes stale; source cache entries expire after ten seconds. Cache limits are
64 agents/128 radars/128 exported contacts. MASTER ingress is separately bounded;
large fleets or slow APIs can reduce effective cadence. This is not a promise
of 20 Hz over Rednet. Local Combat acquisition still targets 20 Hz independently.

## Security Limits

Agents are not invulnerable. An authorized local player/server administrator can
read files/keys, replace startup, stop the PC or destroy it. Rednet traffic is
authenticated here, **not encrypted**. Per-agent keys prevent another ordinary
agent from authenticating as its peers or MASTER; compromise of the MASTER key
or a node's own key requires revocation/reprovisioning. Discovery alone never
authorizes a node. No suppression of local maintenance/termination is added.

Official transport/security references:
[CC modems](https://tweaked.cc/peripheral/modem.html),
[Rednet security](https://tweaked.cc/mc-1.21.x/module/rednet.html).

## Validation And Migration

Fast Lua 5.2 tests cover update confirmations, yielding ownership/session loss,
commit verification, rollback, observer failures and native layouts. Radar tests
cover automatic adjacent discovery, worker-only reads, real signed delivery,
wrong-key rejection, association revocation, geometry absence, cache bounds,
scan progression and expiry. 104 fast Lua 5.2 suites pass, with all 259 Lua files
syntax-checked and literal system/app requires resolved.

Visible, isolated CraftOS-PC validates ten apps in mode 256/16/text using the
installed CC Graphics window ROM, plus source-isolated CC Terminals transport
simulation. Captured 960x540 framebuffers include Combat 2D/3D and Update's
wrapped diagnostics. The twelve-app offline text smoke test passes. The network
workflow passes HTTP read failure/recovery, Update check, disk-full refusal,
apply and granular rollback. Native CC crypto also passes the eight-computer
NEXUS simulation including signed radar transport and revoked/wrong-key refusal.
The actual released 0.18.38 updater installs this bundle on a disposable default
1 MB CraftOS-PC disk and rolls back, retaining the test user's file/config.

No user files/configs are erased by the OS migration. NEXUS provisioning retains
its existing explicitly scoped reset policy; it does not authorize new machines.
Minecraft hardware, Ender delivery and the actual vessel/radar installation still
require in-game validation. The complete application migration and ASCENDANCY
CORE/ORACLE/ATLAS/planning milestones are not claimed complete.
