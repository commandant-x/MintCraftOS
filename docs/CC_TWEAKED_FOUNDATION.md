# CC:Tweaked foundation

The rebuild first targeted CC:Tweaked alone. V0.18 re-enables Navigation and
Combat after adding documented adapters and cached asynchronous workers.
See [V0.18 commissioning](V0.18.md) for the current release scope and safety limits.

## Foundation acceptance gates

- Boot and recovery on a computer without optional mods or HTTP access.
- Files, integrated editing, terminal, settings, logs and process management
  remain usable on both the computer terminal and an advanced monitor.
- Shared peripheral inventory refreshed on attach/detach and explicit rescan;
  drawing consumes cached state without peripheral acquisition.
- Monitor resizing and scale changes preserve windows and focus. Text,
  touch controls and the global keyboard stay within their visible bounds.
- Process and service errors are contained and logged. Timers and listeners
  are released on shutdown; audio playback does not block desktop input.
- Rednet messaging works with a detected modem and reports disconnects.
- Installation preserves user files and configuration. Updates are staged,
  validated and recoverable before replacing the running installation.
- Verification includes executable Lua tests and actual CC:Tweaked smoke
  scenarios. A require scan is not a syntax or runtime test.

## Deferred work

Browser/CraftTube remain paused. Existing code is retained but is not a
foundation acceptance criterion. Sable, Avionics, Big Cannons and radar
now use documented adapters and shared snapshots. Missing telemetry
must stay unknown: do not manufacture ranges, bearings or target identities.

## Historical First Step

The initial foundation profile deferred Navigation/Combat. V0.18 enables them
and their Settings pages again; Devices and drawing consume cached state.
The checks below describe foundation development, not real ship validation.

## Executable checks completed

- `tests/craftos-editor.lua`: passed in `mintcraft-foundation-editor-18`.
  Actual filesystem save/readback, valid compile without execution, invalid Lua
  diagnostic, and refusal of an existing unfinished-save directory while both
  disk contents and the unsaved editor buffer remain intact. This is not an
  exhaustive power-loss injection test.
- `tests/craftos-files.lua`: latest run `mintcraft-foundation-cache-17` passed
  paged toolbar actions, Home/Back/Up history, virtual-keyboard name entry,
  overwrite refusal, rename, trash/restore and protected system paths. The
  harness rejects directory enumeration/stat during draw. It injects app events
  and some fixture selection state; it does not prove physical monitor input.

- `tests/craftos-launcher.lua`: passed in disposable normal-window CraftOS-PC
  directory `mintcraft-foundation-launcher-09`. Opens search over Terminal,
  routes char/paste to search without changing Terminal input, launches Files,
  then verifies Escape returns typing to Terminal. Follow-up run
  `mintcraft-foundation-layout-12` passed the same scenario. Its screenshot
  confirms search hides the underlying Terminal keyboard and the window shadow
  no longer overwrites the taskbar. This verifies this 51x19 launcher layout,
  not the remaining app layouts or physical monitor behavior.

- `tests/backup.lua`: retained backup generations, publication failure fallback,
  manifest allowlist, missing backup preflight, and copy failure preserving the
  active file.
- `tests/update-source.lua`: full commit pinning, encoded branch names, invalid
  GitHub responses rejected, and stable file URLs after branch movement.
- `tests/craftos-backup.lua`: passed in normal-window CraftOS-PC with disposable
  data directory `mintcraft-foundation-backup-06`. Real filesystem checks cover
  nested directory backup/restore, removal of app files added after backup,
  preservation of `/home/user`, and rejection of incomplete backup before writes.
  This does not prove recovery from power loss between multiple tree replacements.

The later `mintcraft-foundation-crashes-05` normal-window CraftOS-PC smoke run
also passed offline boot and nine core app launches after scheduler changes.

- `tests/display.lua`: correct monitor name with multiple attached monitors,
  resize events, defensive display snapshots, fallback after peripheral error,
  and native dimensions unaffected by app terminal redirection.
- `tests/crashes.lua`: import and entry-point failures report one notification,
  runtime failures leave healthy processes running, all owned windows close
  on crash/kill/normal exit, and terminal process states cannot be overwritten.
- `tests/version.lua`, `tests/update.lua`, `tests/messenger.lua` and
  `tests/services.lua`: numeric versions, asynchronous update checks,
  messaging hotplug and service lifecycle behavior using mocked APIs.

The isolated normal-window CraftOS-PC smoke run in
`mintcraft-foundation-offline-04` passed installation, explicit HTTP-disabled
boot, running core services, and opening/maximizing nine core apps. This
does not verify touch input, a physical monitor, modem delivery or sound.

- `tests/keyboard.lua`: rendering bounds at widths 12/20/35/48/100,
  matching control hitboxes, Caps/Shift interaction, control callbacks and
  all printable ASCII characters reachable through symbol pages.

- `tests/foundation.lua`: deferred service registration, cached inventory,
  defensive list copies, no duplicated listeners after restart.
- `tests/windows.lua`: minimized windows cannot intercept clicks, keyboard
  focus falls back to a visible window, background timers are delivered,
  resize and maximize/restore keep bounds inside the desktop.
- `tests/audio.lua`: asynchronous DFPWM playback returns on speaker
  backpressure, retains the pending buffer, filters events by speaker name,
  closes files on completion/error and unregisters listeners on stop.

These run using an isolated Lua runtime under `.tools/lua-test-runtime`
with mocked CC APIs. They do not prove actual monitor rendering, audio
quality or full boot behavior in Minecraft.

- `tests/installer.lua`: preserve existing configuration and user files,
  reject invalid Lua before live writes, restore after simulated disk failure,
  reject traversal paths and refuse to overwrite an interrupted transaction.

`tools/build-installer.ps1` builds the local `install.lua` from runtime
directories only, excluding host tools, tests and development dependencies.
It has been rebuilt and syntax checked, but is not a published release.
The installer stages and validates Lua, backs up affected files, and restores
them on a caught write failure. Power loss leaves a journal and backups in
`/var/tmp/mintcraft-install`; `system.libraries.installer.recover()` can
restore a valid journal. Abrupt interruption before the journal is written
requires inspecting the staging directory; the installer refuses to erase it.
