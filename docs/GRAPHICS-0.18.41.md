# 0.18.41: Native Settings Center

## Changes

- All twelve Settings sections use native pixel layouts: System, Display,
  Desktop, Network, Storage, Sound, Security, Apps, Packages, Dev, Navigation
  and Combat. Sidebar/dropdown navigation, radio choices, app/audio checkboxes,
  bounded diagnostic wrapping, scrolling and keyboard focus replace rasterized
  character controls. Compact windows use an isolated tactile keyboard.
- Metadata acquisition runs outside drawing in a bounded app-owned read worker.
  Only one read is active; page changes coalesce. Minimized windows stop polling.
  Passwords never enter the cached presentation model and remain masked.
- New `settingsd` serializes an allowlist of configuration actions. Actual caller,
  process identity, live permissions and authentication generation are checked
  before execution. Closing/replacing a caller or changing its session before
  execution refuses queued work. Already-started setters finish under service
  ownership, including yielding display changes. Missing worker state is shown
  as uncertain and is not retried automatically.
- Authentication retains its separate cancellation-aware worker. Text rescue
  and old-backup cleanup require confirmation. Essential apps cannot be disabled.
  Theme changes apply in memory only after their configuration saves successfully.
- Display reports the actual active backend and framebuffer dimensions separately
  from text cells and fallback mosaics. Requested 16-color mode survives reboot;
  text rescue uses safeMode. Unsupported graphics still fall back safely.

## Migration And Compatibility

Update through the existing pinned installer/Update workflow, then reboot to
register the Settings service. Existing user files, profiles and custom settings
are preserved. No external mods, Minecraft config or worlds are modified.
The ordinary text Settings interface remains usable without graphics.
Settings is a core app and starts its service dependency when launched.

## Limits

The UI scale is still fixed at 1x; monitor text scale is a different control.
The retained/event-driven frame policy is reported, not a configurable performance
mode. These final-scope requirements remain open in ASCENDANCY.md. No in-game
validation is claimed. Built-in Lua apps remain trusted code, not an untrusted
application sandbox. Authentication does not encrypt Rednet traffic.

## Validation

110 fast Lua 5.2 suites pass. All 269 Lua sources compile, literal app/system
requires resolve and the generated installer matches the release tree.
New tests cover twelve native sections at 200x120 through 960x500 client sizes,
hitboxes, scroll/dropdown focus, masked input, tactile keyboard, modal resize,
queued permission/session/owner changes, yielding setters, uncertain workers
and failed theme persistence. Existing text Settings/authentication checks pass.

Normal visible CraftOS-PC with isolated storage and the installed CC Graphics
window ROM passes the eleven-app graphical workflow in 256/16/text modes,
including all twelve Settings sections and a real service-owned label write.
The corresponding CC Terminals source-isolated transport simulation passes.
Captured 960x540 indexed framebuffers were visually inspected. The twelve-app
offline text smoke and HTTP failure/recovery, Update check/apply/granular rollback
workflows pass. The actual released 0.18.40 updater installs this bundle and rolls
back while retaining the test user's file/config. Its native filesystem reports
host-volume capacity, not a verified quota-enforced 1 MB disk.

These are unit, simulated transport and CraftOS-PC results, not Minecraft tests.
No complete ASCENDANCY claim is made.
