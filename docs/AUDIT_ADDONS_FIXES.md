# Addon audit remediation - 0.18.8

This change addresses the fourteen findings in
[the dated audit](AUDIT_CC_ADDONS_2026-10-17.md). A guarded unsupported operation
is not described as fully implemented hardware support.

## Finding Tracker

| ID | Resolution | Regression coverage |
| --- | --- | --- |
| A01 | CBC release accepts the resulting false/off state; actual errors and uncertain fire remain latched without retrying fire | combat-audit, craftos-addon-audit |
| A02 | A new contact is display-only until scan progression is observed within a bounded interval; duplicate/regressed scans cannot refresh its command validity | combat-audit |
| A03 | Sable pressure receives three finite numeric coordinates | telemetry-contracts, craftos-addon-audit |
| A04 | Guarded limitation: body-mounted aiming requires fresh level attitude; inclined or unknown attitude is refused, not a fabricated 3D solution | combat-audit |
| A05 | Required/optional capability and field-type checks; individual healthy measurements survive partial failure | telemetry-contracts |
| A06 | Stock 4.x, explicitly selected EA and optional geometry bridge have separate capability profiles and limitations in setup | combat-audit, radar-setup |
| A07 | Guarded limitation: raw centre of mass is labelled unknown frame until a real transformation is verified | telemetry-contracts, craftos-addon-audit |
| A08 | Measurements preserve observation/receipt/expiry metadata, including slow cached data; slim flight reads retain selected sensor identity | telemetry-contracts, flight-relay |
| A09 | Per-source scan/classification evidence; older source positions cannot replace newer positions, and positive safety flags win conflicts | combat-audit |
| A10 | Bounded device/read fan-out, shared read budget, flight priority, inventory cache, slow radar metadata, partial acquisition and overrun counters | addon-budget, service-safety, combat-audit |
| A11 | Event bus only admits bounded input; worker verifies authentication, with reserved paired capacity, rate limits and pending-input coalescing | radar-ingress, radar-auth, radar-network |
| A12 | Update uses bounded HTTP reads with separate VERSION, commit metadata and installer limits; handles close on every read outcome | io-contracts, http-client, update-storage |
| A13 | Output failures fall back to native display without replaying render callbacks; app render errors remain visible as errors | display-fallback, display, compositor |
| A14 | Speaker false/busy is no longer reported as a successful sound; cached configuration and bounded notification priority queue | audio |

## Additional Improvements

- Navigation mapping supports `relay` endpoints: peripheral name plus one of its
  six sides. Each endpoint still requires explicit limits, neutral, rescue and
  physical calibration. Existing Create frequency labels are preserved.
- Duplicate relay side mappings are refused for arming; missing relays prevent
  readiness. Output tests return to the configured rescue signal, not assumed zero.
- Flight uses selected slim telemetry instead of repeatedly copying all device
  snapshots. Mixer rank is cached for an unchanged configuration object.
- Radar static circles/beam geometry and compiled subpixel rows are cached by
  actual geometry and view inputs; contact overlays use independent cloned
  canvases, so old contacts do not contaminate subsequent frames. Cache size is
  bounded and large canvases are not retained in the background cache.
- The compositor reuses row buffers and retains partial clock drawing. It still
  sends changed rows through `term.blit`, not full screen pixel calls.
- Settings exposes automatic/native/named-monitor selection and the full
  0.5..5 monitor scale range. Scales persist per monitor; missing selected
  monitors fall back to the computer while retaining the preference.
- Task Manager adds read/in-flight/queue/overrun counters. These are not CPU
  percentages. The ordinary Lua heap and disk information remain available.

## Validation

Integration passed 66 Lua 5.2 suites, five Node proxy tests and syntax checks
for 164 Lua files. Normal-window isolated CraftOS-PC checks cover the core,
addon contracts, network/update apps, radar views and application launching.
Cancelled fan-out branches release queued tickets, active permits and owned
timers. Separate diagnostic workers keep slow metadata reads outside the fast
flight acquisition cycle. Shared admission remains bounded; configured target
rates are not a guarantee of throughput on a busy Minecraft server.
Native integration covers raw `task_complete` handling, numeric pressure,
unknown COM frame, slim telemetry, relay rescue, scan progression and the CBC
false/off release contract. Its peripherals are simulated, not live world devices.

No mod JAR, Minecraft profile/save or Windows security setting is modified by
this work. Sable 2.0.6 is not installed automatically. The dated inventory is
evidence for one inspected profile, not proof of the server's loaded mod list.

## Commissioning Limits

- Hardware flight/CBC calibration and full-scale radar performance still require
  in-game commissioning. Start with a copied world and disabled outputs.
- Radar render timing targets 20 Hz; acquisition targets 5 Hz. Shared budget,
  server ticks, number of devices and latency determine achieved rates. Pending
  and stale data are exposed; no extrapolated sweep is presented as a measurement.
- Stock bearing position/FOV API defects cannot be repaired in Lua. Automatic
  geometry still needs the optional, explicitly identified source-PC bridge or
  a future upstream API. No modified mod binary is distributed here.
- Full quaternion mount ballistics, calibrated COM conversion and additional
  Avionics peripheral families remain separate commissioning/feature work.
- Remote radar contacts remain display/alert only. Authentication is not
  encryption, and shared-key holders can impersonate stations. Flood admission
  control limits work but cannot guarantee availability against spoofed IDs.
- No automatic rearming, fire retry or live-world output testing is added.
  Software rescue cannot act while the host is frozen or without power.
