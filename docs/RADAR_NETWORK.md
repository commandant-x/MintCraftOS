# Radar filters and remote stations - 0.18.5

## Touch controls

Radar, 3D and Targets share Players / Mobs / Vessels / Projectiles / Other filters.
No checked category means all contacts; tap categories to combine them, tap again
to remove one, or tap All to reset. Tap a contact marker, visible name or list row
to select; tap it again to deselect. Hiding a selected category cancels tracking
and pending fire confirmation. Alias edits a local name without changing API data.

Radar 5 EA categories are read from the provided JAR. Older generic entity contacts
remain Other unless the API explicitly identifies a player. This is not a mob guess.
The provided JAR does not expose player names: UUIDs cannot be converted into
pseudos by this OS. Names are displayed when provided by the API, otherwise use Alias.

## Several stations

1. Install this version of MintCraftOS on every station and the central computer.
2. Connect each radar locally or by CC wired peripherals and complete Combat > Setup.
   Stations must have a valid world position/range. Moving stations require a valid
   world transform, not a fixed origin on a moving ship.
3. Attach a modem to each computer. Use wired modems on the same cable network, or
   wireless modems within their supported range. Keep computers/chunks loaded.
4. Combat > Network > Zone/Group: choose the same group on every station. Only
   stations in the SAME world/dimension/coordinate system may share a group.
5. On radar stations tap Station OFF to turn publication ON. On the central computer
   tap Network OFF to turn reception ON. Discovery is automatic at 5 Hz.
6. Tap each discovered station and confirm inclusion. Tap again to exclude it.
7. Radar/3D > Overview fits the station positions/ranges, with measured cones where
   calibrated orientation/FOV exist. Local coverage is green; remote coverage blue.

Use a paginated toolbar's arrows when controls do not fit a small window.
Up to 16 stations, 64 radar geometries per station (256 remote geometries total)
and 128 aggregated contacts are supported. Matching IDs are
deduplicated; station IDs distinguish sensors. Offline stations stop contributing
after 5 seconds. Sender-side measurement age is preserved, so retransmission does
not refresh old data. Remote measurements are never relayed by another station.

## Perimeter

Zone/Group sets a world X/Y/Z centre and horizontal radius in metres. Enable Perimeter
alerts explicitly after setting the zone. Its orange circle is a user-defined alert
boundary, not a guarantee that radar can see everything inside. Entry alerts are
visual/logged, limited to one every 2 seconds; stale, friendly and synthetic contacts
do not trigger them. X/Z determine entry; Y positions the circle in the 3D schematic.
Filters affect the display, not perimeter detection. No automatic firing or movement.

Rednet is not encrypted. Configure the same shared key (16..256 bytes) on each
station for HMAC-SHA256 authentication; key holders can impersonate any station.
Without a key, networking is blocked unless allowInsecure is explicitly enabled.
Inclusion by computer ID alone is not authentication. A configured key never falls
back to unsigned packets, even when allowInsecure is set. Authenticated envelopes
bind the sender and payload, require UTC freshness and reject recorded sequences.
Remote contacts are display/alert only and cannot be used for aim/fire.
Do not use this perimeter as an authoritative defence or safety mechanism.
Official transport reference: https://tweaked.cc/module/rednet.html

## Bounded Ingress

The actual Rednet listener only admits raw packets; it does not run HMAC or
deserialize. A separate raw periodic worker verifies at most five packets per
50 ms cycle. Paired-ID and discovery lanes each hold at most 16 packets, with
at most one pending per sender. New admitted arrivals replace that sender's raw
packet without changing its queue position; claimed sequences are not inspected
until authentication. This retains the latest arrival, not necessarily the latest
authentic packet: a spoof can replace pending input but cannot authenticate it.
Each cycle reserves four verifications for paired IDs and one for discovery;
unused capacity can serve the other lane. At an ideal 20 cycles/s this is a
100-verification/s ceiling, with 80/s reserved for 16 paired stations at 5 Hz and
20/s for discovery. These are work-count budgets, not measured throughput;
server lag or expensive payloads reduce the achieved cycle rate. Pairing reserves capacity,
never bypasses authentication. Spoofed paired IDs can still deny that sender's
slot: Rednet IDs are not proof of identity.

Verification yields via a queued mintcraft_radar_verify event between packets,
so other raw workers can run without a timer tick per verification. Wake tokens
are unique across restarts; reset/stop during a yield prevents further draining.
One HMAC plus decoding/validation remains synchronous and cannot be preempted.
The current kernel does not classify this custom event as internal, so it can
also request a frame pass. No kernel changes or native event impersonation are
used to suppress that pass.

The periodic worker waits at least 50 ms after completing its work: five packets
therefore take verification/dispatch time PLUS that wait, not a guaranteed 50 ms
cycle. For example, a native Lua 5.2 test measured about 150 ms for five invalid
64 KiB HMACs, with four heartbeat dispatches between them. Including only the
minimum periodic wait would yield about 25 verifications/s at that payload size,
before kernel/render overhead. This host measurement is not a Minecraft result,
a CPU deadline, or a guarantee of 16 x 5 Hz under maximum-size traffic. Overload
coalesces pending input instead of accumulating a backlog.

Before verification, fixed one-second admission windows allow at most 128 paired
and 16 discovery attempts globally, and eight attempts per sender. Malformed and
invalid-signature traffic consumes these limits too. Sender accounting is bounded
to 64 entries per window. Excess packets are dropped, not retried. Keyed payloads
are capped at 64 KiB each. Limits bound work counts and retained packet slots,
not wall-clock latency or total CC transport allocation under hostile traffic.
Explicit insecure mode still receives CC-decoded tables and cannot provide the
same authenticated serialized-byte bound.

status().ingress reports cumulative queued/coalesced/processed/accepted/rejected counts,
dropped counts by admission rate, queue capacity and envelope shape, highWater,
and current pending counts. Status scans only bounded station metadata, not
contact/history snapshots. Stop discards queues and terminates both workers
without closing shared modems; saved configuration changes discard pending input
and reset ingress counters. receive() remains a synchronous verification API for
trusted local callers and compatibility tests, not an event-bus callback.

## Refresh

Acquisition, station publication and visible graph refresh are capped at 5 Hz,
not 2 Hz. Filter/selection/camera changes redraw immediately. Actual new radar
measurements remain limited by the mod/server. Minimized graphs stop drawing;
services continue acquiring. All views render cached snapshots using subpixels
and term.blit through the compositor, never peripheral/network calls in draw.
