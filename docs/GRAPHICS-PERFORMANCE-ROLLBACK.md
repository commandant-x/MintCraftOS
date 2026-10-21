# Graphics performance and safe rollback — 0.18.45

Storage/install sizing below describes the original uncompressed 0.18.45 release.
For first installation under the pack's 1 MB limit, use [0.18.46 compact installation](COMPACT-INSTALL.md).

Starting reference: 0.18.44, `458a0f820c91c9822e52efb264ad041827f4ce31`.
Development branch: `codex/graphics-performance-rollback`. Main is not rewritten.

## Changes and controls

The pixel backend returns success without freeze/draw calls for empty presents.
Palette-only changes still present. Dirty intervals are bounded to eight per row;
small gaps (up to 16 pixels) merge. Compatible adjacent rows batch up to eight;
a target rejecting multi-row submissions falls back to individual rows. Exceptions
clear pending damage, thaw and select text. Resolution and indexed palette stay
at the actual device's detected values; no downscaling or compression is added.

Scene unions restart after every merge so transitive overlaps are included.
Final row equality still suppresses compensated overdraw. Two short edge changes
separated by at least 64 identical pixels can submit independently; larger changed
runs stay simple to avoid expensive pixel-by-pixel Lua scans. Scene work is bounded
by 256 layers and the existing 64-region full-frame fallback. Surface rows remain
compact strings, not tables of numbers.

The kernel dispatches events, scheduler work and application handlers before
coalescing visual changes. A single presentation timer enforces the configured
ceiling. Visible window state, client invalidation, shell revision and notification
membership request frames; unrelated traffic does not. Logs invalidate on changed
records rather than the kernel's diagnostic polling. Native pixel shell frames
skip the text desktop/taskbar and physical text-buffer comparisons; a failing
pixel presentation lazily rebuilds a complete text frame. Legacy clients retain
text drawing/conversion. No acquisition service timings or arm/fire behavior change.

Client surfaces retain a **2 MiB pixel-payload limit**, not a claim that Lua table
and string overhead are included in that figure. Caches prioritize the active
window, reuse moved/unchanged clients, evict old unpinned entries, and release
minimized/fully covered clients. A frame does not evict surfaces already referenced
by its layer closures. If the budget cannot hold a client, it draws into damaged
areas without a retained surface. Existing bounded sprite/font mechanisms remain.

Settings > Display (available in both text and pixels) adds:

- **Stable:** conservative event redraw behavior, individual row submission;
- **Balanced:** invalidation/coalescing, up to 20 presentations/s;
- **Performance:** same resolution/palette, default 10 presentations/s;
- explicit optimization on/off, and ceilings of 10/15/20 Hz.

An explicit ceiling overrides the profile default. These limit presentations only.
Failed setting saves leave the previous persisted and active policy intact.
Task Manager > Renderer shows presentation requests/skips, real successful API
presentations, draw calls, submitted bytes, dirty lines, scene rectangles,
preparation/composition/presentation times and maxima, and cache counters.
Existing compositor draws/s retain their definition; physical Minecraft FPS,
server CPU, VRAM and compressed network bandwidth are unavailable.
Settings > Display also shows version/backend/resolution, policy, Boot Guard,
checkpoint ID, render errors and measured Lua heap.

## Install without losing the previous version

Use the immutable commit URL supplied with the release:

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/<NEW_COMMIT_SHA>/install.lua
reboot
```

Do this first on a disposable computer with witness files. The new bundled
installer uses its bundled checkpoint implementation even over an older installed
service. For an existing `/VERSION`, manual installation creates the same durable
**differential checkpoint** as Update before changing live files. Update's own
callback creates it once. Existing configs, `/home`, packages and external apps
are retained. Unknown free space or insufficient staging + transaction backup +
retained checkpoint + metadata margin refuses an upgrade before live writes.
It does not delete checkpoints to make room. The supplied pack explicitly sets
`computer_space_limit = 1000000` and `floppy_space_limit = 125000`. The embedded
stable tree contains 1,002,390 source bytes and this release 1,025,908, before
filesystem overhead or personal data. If the pack limit is applied, even the fresh
candidate cannot fit. The measured delta requires 594,588 free bytes for staging,
two backup copies and margin (35 changed files, excluding already present user
config). These are lower-level estimates, not a claim about the live server's
usage. The installer queries its real free space and refuses unsafe installation.
Allow at least 2 MiB plus personal/retained data on a test server before deployment;
changing that server setting is a separate user operation. No pack configuration
was changed. Never bypass the checkpoint to squeeze the release onto a 1 MB disk.

New file checkpoints compare backup bytes with their source and record Adler-32
corruption checks in their manifest. Both Update rollback and dependency-free
Recovery prevalidate every covered file before restoring anything. This detects
accidental corruption; it is **not cryptographic authentication**. Legacy checkpoints
without these checks remain supported with their existing structural validation.
Backups and interrupted-operation journals are retained on failure. Never manually
remove the only valid checkpoint or an unresolved transaction to force an upgrade.

## Text rescue and full version restore

If the desktop still works, select **Settings > Display > Text rescue**. Disabling
new optimizations is a separate option and preserves the graphical resolution.

From the ordinary **CraftOS shell**, even if the desktop cannot start:

```lua
/boot.lua --text
```

This saves `safeMode=true`, `graphicsMode="text"` and disables new optimizations,
using a recoverable save without deleting the rest of the config. To enter the
standalone Recovery shell directly:

```lua
/boot.lua --recovery
```

Recovery does not depend on backend, scene, workspace, compositor or Window Manager.
Use `version`, `checkpoint`, `crash`, `logs`, `safe`, `shell`, `rollback`, `reboot`.
`rollback` asks you to type **RESTORE**. It restores the covered system version,
removes covered files that were absent previously, retains user data/configs and
backups, and saves text rescue before reporting success. Then run `reboot`.
There is no promise that reinstalling the old `install.lua` alone removes new
system files: the checkpoint is the supported full version rollback.

Boot Guard stores `/var/graphics-boot.cfg`, separately from user config. It journals
before graphics initialization and validates only after three successful compositor
passes and at least one second. An incomplete or failed attempt selects text on
the next boot with a diagnostic; it never automatically rolls back or deletes data.
An incomplete marker can also mean server shutdown during startup, not a software
crash. A healthy session does not write the marker on every frame. Explicitly select
Automatic pixels or 16-color pixels in Settings to retry. A blocked event loop cannot
be interrupted by Lua running inside that same loop: stop/restart the computer and
use text rescue/Recovery. No unimplemented recovery hotkey is advertised.

## Reproducible validation

From the repository root, use Lua 5.2. Run each `tests/*.lua` in its own process,
excluding `craftos-*.lua` (actual CraftOS runners), `storage-fixture.lua` (helper),
and the slow production-cost `password-crypto.lua` from the fast run. Run that
cryptographic suite separately when required; it was not completed for this release.

```sh
python3 tools/build-installer.py
lua5.2 tests/installer-bundle.lua
lua5.2 tools/graphics-batches.lua
lua5.2 tools/graphics-benchmark.lua /path/to/reference/tree 1
lua5.2 tools/graphics-benchmark.lua . 8
```

The Python builder is the portable equivalent of `build-installer.ps1`. The bundle
equality test verifies every embedded file against the source tree. See
[measured before/after tables and raw data](benchmarks/graphics-performance.md).
Benchmark workloads use synthetic rectangles and simulated radar/navigation pixels;
they do not claim to be actual app traces. Integration/regression tests separately
exercise native apps, legacy rendering, CC Terminals source isolation, drag/resize,
minimize/restore, notifications, app crashes, NEXUS, Navigation and Combat mocks.

The final fast validation passes 123 Lua suites; all 290 Lua sources compile.
The five Node proxy tests also pass.

New tests cover 1,000 empty presentations without API activity, palette changes,
exact framebuffer pixels with batches 4/8/16/32, sparse spans and bounded damage,
GPU failure/thaw/text rescue, nonvisual kernel events without lost dispatch,
presentation ceilings, cache reuse/eviction, corrupted/missing checkpoints,
interrupted rollback/resume, manual-upgrade disk refusal, preserved witness files,
and pending/healthy/failed Boot Guard states. Existing crash-stage transaction and
save recovery tests remain intact. No Minecraft or CraftOS-PC executable was
available in this cloud image; those runtime tests are **not performed**.

## Minecraft commissioning protocol — not performed

The supplied Modrinth pack identifies Minecraft 1.21.1, NeoForge 21.1.249,
CC:Tweaked 1.120.2, CC: Graphics 0.2.1 and CC: Terminals 0.1.1. No mod JAR or server
configuration is changed by this release.

1. Copy an instance/computer into a disposable test world. Record version,
   available disk, display mode/resolution, mod settings and checkpoint ID.
   Create document, vehicle-config and NEXUS-key witness files; keep an external copy.
2. Before upgrading, run the stable version's desktop, Terminal typing, Editor
   scroll, window drag/resize/overlap, Task Manager, Combat radar and Navigation.
   Record the same renderer counters and observation duration for each.
3. Install the pinned candidate. Verify 960x540 and 256 colors **only on a display
   that reports them**; repeat at 306x171, 480x270 and 600x360 when supported.
   Repeat the same workflow under Balanced, Stable and Performance. Confirm no
   visual changes, no click-through, command responsiveness and unchanged sensor
   service periods. Never arm or fire to benchmark rendering.
4. Let a static desktop settle; record counters again after 60 seconds. Move,
   resize, minimize/restore and close several native and legacy clients, open menus,
   wait for notification expiry, type/paste via CC Terminals and detach/reconnect it.
   Record presentation API counters and heap; server load only if separately measured.
5. Perform a real Settings text rescue and explicit pixel retry. On this disposable
   copy only, stop during graphics initialization and confirm text Boot Guard after
   restart. Inject controlled draw/palette failures only through test instrumentation.
6. Enter `/boot.lua --recovery`, inspect the checkpoint, run `rollback`, type
   `RESTORE`, reboot, verify the old version, text mode and all witness files.
   Separately test low disk and interrupted update/restore on disposable copies;
   preserve any ambiguous journals for inspection. Verify a later update works.
7. Only then repeat installation on a computer holding valued data, after external
   backup. Actual Minecraft performance and complete deployment acceptance remain
   pending until this protocol succeeds.
