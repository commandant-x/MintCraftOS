# Burner feedback and containing-sublevel checks — 0.18.52

The reported screenshots show two distinct burner readings on the same vehicle:
local `-1:-2:2` has signal 0, gas 0, no balloon reference; `-1:-2:3` has signal 15,
gas 500, an associated balloon and active gas. This proves the bridge recognizes
one working heater. It does not prove both heaters receive the Computer's command.
The user wants **both** controlled: keep both selected in the guide. A flying
balloon may be supported by one heater; flight alone does not confirm the second.

## Test both receivers

1. Keep the containing Computer attached to the assembled vessel. Install the
   existing Vehicle Bridge **0.2.1** JAR server/client; no JAR upgrade is needed.
2. In Setup guide, keep both burners selected. Group optionally lets an operator
   explicitly change the group; nothing is automatically dropped for being off.
   Selected and excluded IDs are shown before saving. All remain in diagnostics.
3. Check **each** Create receiver is in RX mode, with the same ordered item pair
   and dyed colors shown in the guide and with a working redstone path to its
   burner. Check for another transmitter/lever on that pair: a stronger signal
   on the same network can keep a heater at 15 while the Computer requests 5.
   A new pair proposed by the guide is not configured in Minecraft by
   Apply + Save. Neighbouring machines may also share the frequency.
4. After checking the setup, save and use Calibration → Initialize (2s) with a
   physically checked signal. This performs one confirmed bounded pulse and
   returns to the saved rescue output. It does not repeat or increase heat.
5. A successful transmitter API return is no longer enough. Before marking that
   output test complete, the service requires a fresh bridge sample **after**
   application, the same vehicle, a complete inventory, every selected burner,
   the expected signal on each and a confirmed structural association. Gas
   activity is not required: an empty associated balloon remains valid.

Direct wiring expects burner signal equal to the transmitted value. For the
explicit inverted-wiring option (negative altitude mix), it expects `15-value`.
Custom nonlinear wiring is not automatically identified and cannot be certified
by this check. A 0.3-second generic test is refused for this collective burner
channel; use Initialize (2s), which allows time for the bridge's one-second scan.
A stale or missing sample may fail the test even if the heater appears lit.

When a test cannot be confirmed, the output returns to rescue and calibration
remains unverified. The reason identifies a missing/stale sample, a burner with
`received 0/15, expected 5` (check RX/frequency/wiring), or a burner that receives
the signal but has no association (check envelope/clearance in Aeronautics).
Do not infer the cause from flame animation alone or repeatedly initialize an
already flying balloon. No code can repair a disconnected receiver from here.
The previous physical direction, hover, rescue, manual-input and PID prerequisites
remain; this does not automatically arm, tune gains or certify a safe descent.
Existing user-confirmed mappings are not silently replaced or recalibrated.

## CC:Sable membership

CC:Sable 1.3.4's native `getUniqueId` and `getLogicalPose` both call
`getSublevel()`, which resolves Sable's `getContaining` and rejects a Computer
that is not on a server sublevel. Its `isInPlotGrid` is a separate helper call.
The OS previously returned early on a false/failed grid probe and never tried
those getters, potentially hiding valid containing-sublevel data. It now accepts
a nonempty bounded identity plus a finite measured pose as membership evidence;
failed or malformed getters do not supply that evidence. The existing grid-true
compatibility path remains. Freshness timestamps use the identity/pose reads.
There is no fallback from plot geometry to a guessed world pose or sensor data.

Upstream contract inspected:
[SubLevelAPI.java, v1.3.4](https://github.com/TechTastic/CC-Sable/blob/v1.3.4/common/src/main/java/io/github/techtastic/cc_sable/apis/SubLevelAPI.java).
This addresses one possible source of the screenshot's contradictory membership
message; it does not claim that its in-game cause was reproduced. If containing
identity/pose getters fail, sensor/membership prerequisites continue to block.

## Validation and rollback

Offline regressions recreate the mixed 0/15 burner group, missing association,
wrong/stale feedback, rescue application, failed repeat-test invalidation and
fresh acknowledgment from both burners without bypassing arming. UI tests cover
explicit group confirmation and rejection of an empty group. Sable tests cover
a false/failed grid probe with good native getters, identity loss and malformed
pose. Full Lua source/packed regressions and strict 1 MB installation, real-release
upgrade/rollback and interrupted-write simulations are run. In-game behavior
still needs verification on the actual wiring and mod installation.

Use Updates rollback or Recovery to restore the retained checkpoint; live user
credentials and personal data are retained. No Minecraft mod or world blocks
are changed by the OS installer.

The strict 0.18.51 → 0.18.52 upgrade/rollback simulation peaks at **924,826
bytes** with a 100,000-byte user-data witness; fresh installation including that
witness uses **795,212 bytes**. Interrupted backup and live writes restore the
previous release and retain its durable checkpoint. Source and installed compact
runs each pass 140 Lua suites. Actual mod/world wiring is not simulated.

The installed CC: Create Redstone Link 0.1.1 API signature was also checked
against its tagged upstream source: `sendLinkSignal(freq1, freq2, strength,
color1, color2)` matches the OS call. This check does not establish that a
physical receiver is configured to that pair or wired to a specific heater.
[Upstream v0.1.1 peripheral](https://github.com/ryleu/ccc-redstone-link/blob/v0.1.1/src/main/java/me/ryleu/cccredstonelink/RedstoneLinkBridgePeripheral.java).
