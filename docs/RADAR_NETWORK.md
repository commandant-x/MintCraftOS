# Radar filters and remote stations - 0.18.4

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

Rednet is not authenticated or encrypted; inclusion by computer ID is not secure
authentication. Remote contacts are display/alert only and cannot be used for aim/fire.
Do not use this perimeter as an authoritative defence or safety mechanism.
Official transport reference: https://tweaked.cc/module/rednet.html

## Refresh

Acquisition, station publication and visible graph refresh are capped at 5 Hz,
not 2 Hz. Filter/selection/camera changes redraw immediately. Actual new radar
measurements remain limited by the mod/server. Minimized graphs stop drawing;
services continue acquiring. All views render cached snapshots using subpixels
and term.blit through the compositor, never peripheral/network calls in draw.
