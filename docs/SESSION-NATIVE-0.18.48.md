# Session authentication and native clients — 0.18.48

## Console access

The first start asks for an administrator password of 8–1024 characters, entered
twice. Existing nonempty credentials are retained. A configured computer starts
locked after reboot, including when the previous session was Guest. The console
authenticates the administrator; Guest's empty credential cannot unlock it.

Press **F12 before leaving**. Settings' existing Lock action also uses this screen. Locked input
is consumed before the application's scheduler and event bus. Password characters,
paste, pointer events, file transfers and terminate are never broadcast to apps.
The desktop, notifications and app surfaces are replaced in text and pixel modes;
old pixel workspace caches are discarded on transition. Background timers, modem
messages and sensor services continue. The authentication worker yields while
hashing; it cannot run two password operations concurrently. Password hashing uses
the existing PBKDF2-HMAC-SHA256 provider at 600,000 iterations. This can be slow in
Lua; the cost is not reduced to manufacture a faster login.

A disk-full failure when persisting a lock still locks the running console in
memory. Restart locks again. A new lock cancels an older in-progress login even
when the stored `locked=true` value did not change. Enrollment uses the same atomic
compare-and-save path and cannot overwrite an existing configured password.

### Closing a stock Computer screen

There is no reliable Lua close-screen or viewer identity event in the supplied
CC:Tweaked 1.120.2 Computer. In the exact upstream release
[`ServerInputState.close()`](https://github.com/cc-tweaked/CC-Tweaked/blob/c7ccc20c756bdd437b09908840485a0e15dc7d7b/projects/common/src/main/java/dan200/computercraft/shared/computer/menu/ServerInputState.java#L104),
closing calls `input.releaseInputs()`. Key/mouse releases also happen during normal
use and there may be no held input at closure. They cannot prove a departure.
This release therefore cannot guarantee automatic lock immediately on closing.
No invented `terminal_close` event or substituted inactivity delay is used.
That guarantee needs a mod/server capability which actually reports closure;
this release changes neither the pack nor server configuration.

This is console access control, not encryption or isolation from arbitrary Lua
with direct filesystem access. Server operators, raw disk access, alternate boot
programs and older releases are outside this boundary. Recovery remains available;
do not treat physical access to a CraftOS disk as protected cryptographic storage.

## Native clients

Browser, CraftTube, Store and NEXUS draw native pixel controls and accept client
pixel coordinates. They retain their text fallback. Shared widgets provide action
paging, selectable rows, scrolling, fields, masking and an optional touch keyboard.
Small clients ask to enlarge rather than expose out-of-bounds controls. CraftTube
and Store are visible in the launcher.

- Browser retains tabs, address/search, bookmarks, links, history navigation,
  reload, download and CraftTube hand-off, using its existing asynchronous worker.
- CraftTube retains proxy/audio configuration, search, selection/details,
  favorites, history and playback through its existing worker.
- Store retains selection, install/remove, refresh, package descriptions and the
  original permissions/audit path. Rendering reads a cached package list.
- NEXUS retains setup, deployment authorization, network agents, missions,
  infrastructure, alerts and monitoring thresholds. Setup keys are masked. Its
  native actions call the same command methods as text mode. Automatic destructive
  recovery still requires both confirmations for the captured IDs; long warnings
  must be scrolled through before confirmation becomes available.

## Wired radar performance

Acquisition cadence targets and the shared read/concurrency budget are unchanged.
Position and rotation remain fast reads; slow metadata keeps its existing cache.
Existing sources do not recount the source map, and unchanged per-radar safety
flags reuse the fused classification. A new source or changed evidence recomputes
the flags with the same true-wins conflict rule. Command checks still use the full
snapshot and per-radar freshness evidence.

The Combat UI receives a separate copied projection without the private
`observations` map. Trails, labels, timestamps, source links and fused safety flags
remain available. Modifying this projection cannot change command evidence. The
UI only invalidates for new telemetry, freshness changes or its changing setup /
network views, instead of dirtying every unchanged refresh.

The synthetic fixture exercises **24 wired radars reporting 15 common players**
for 40 cycles, including an application snapshot each cycle. Raw runs are in
[`benchmarks/combat-0.18.48.json`](benchmarks/combat-0.18.48.json). Against 0.18.47:

| Measure | 0.18.47 | 0.18.48 |
| --- | ---: | ---: |
| Median host Lua CPU, 3 runs | 0.727943 s | 0.491072 s |
| Copy calls across fixture | 517,557 | 415,477 |
| Nodes copied for one UI snapshot | 7,617 | 5,065 |

This is a synthetic CPU/copy comparison, not a Minecraft throughput measurement.
It does not establish 20 Hz on the user's server or predict the gain from its
reported 1.4 Hz. At 24 stock radars, three fast getters already require 72 reads
per full cycle, above the shared 32-read-per-tick budget before other sensors.
Do not label the configured 20 Hz target as achieved cadence. Use Combat's READ
measurement on the same scene before/after; inspect pending reads, errors and
server tick rate. Flight priority, freshness verification, conflict flags, manual
fire confirmation and release/error handling remain mandatory.

## Installation and rollback

Use the generated compact installer, pinned to the published commit. It performs
the existing quota preflight and retains the previous release's differential
checkpoint during an upgrade. Upgrade payloads stay in validated RAM instead of
creating a redundant disk staging copy; the existing checkpoint and transaction
backups remain durable before any live write. Recovery can restore that checkpoint while
preserving current credentials and personal data. A first installation has no
previous OS checkpoint. Do not delete the transaction or personal files to make
room. Source code remains readable in Git; installed packing is lossless.

Rolling back to an older OS also rolls back its security behavior: 0.18.47 lacks
this kernel session screen. Retaining credentials does not add new authentication
features to an older kernel.

Validation includes **133 passing Lua suites on sources and 133 on the packed
runtime**, 307 source/test chunks and 143 packed-tree chunks compiling, native
client bounds/interaction, kernel input isolation with 1,000 background modem
events, enrollment failures and concurrent re-lock, existing combat safety suites,
the 24-radar fixture, and strict 1 MB installation/update/rollback simulation.
With a 100,000-byte personal-data witness, first installation uses 769,238 bytes;
the exact 0.18.47 → 0.18.48 upgrade plus rollback peaks at about 983 KB under the
conservative 512-byte-per-file/directory allocation model. Interrupted upgrade
backup and live writes are also recovered to the previous release. Extra retained
checkpoints or personal data can still trigger the protective space refusal.
The production-cost SHA256/PBKDF2 credential suite also completed successfully.
Real Minecraft graphics, screen interaction and radar throughput still require
in-game commissioning; no such runtime is installed in the cloud environment.
