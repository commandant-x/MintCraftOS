# 0.18.40: Native Devices Inventory And Inspector

## Changes

- Devices is a native bitmap client with a searchable inventory, role dropdown,
  stable endpoint selection, keyboard navigation, draggable scrollbar and a
  side-by-side inspector on wide displays. Smaller windows use an inspector
  view rather than overlapping panels. Dropdowns isolate input from the list.
- The inspector shows the actual reported types and advertised methods; a method
  name is not a button and is never automatically invoked. Primitive false/zero
  values remain distinct from unavailable data. Nested/cyclic diagnostics have
  depth/field/byte caps. Layout is cached until its text or width changes.
- A protected, app-owned raw scheduler worker acquires cached inventory/display
  state and the selected endpoint's method metadata. Redraws do not read files,
  terminals or peripherals. One request runs at a time; hotplug/rescan intent
  coalesces instead of stacking workers. Closing/crashing/killing the app cancels
  its read-only worker and releases its queued Combat diagnostic requests.
- Full peripheral types are now included in deviced.list() as an additive copied
  field. Role classification considers secondary types. Inventory UI retains at
  most 512 devices and selected metadata at most 128 methods, with explicit caps.
  Only the current selection retains method/Probe detail caches; changing device
  does not accumulate hundreds of sensor snapshots in the application's heap.
  Rescan requests discovery, not an implicit display-target change.
- Read-only Probe retains Combat's existing permission checks and method
  allowlist, plus its export to /var/logs/peripheral_probe.log. Results now carry
  their owner PID and operation ID. Devices accepts only a matching endpoint,
  owner, request and unchanged inventory generation. Late/detached/cross-request
  results are not displayed as a current sample. A lost result times out after
  eight seconds without retrying or permanently disabling the Probe control.
- Routine metadata refreshes do not erase the operator's Probe/error message.
  Scan errors preserve the previous inventory with a retained-scan indication.
- The Display command opens Settings directly at its existing Display section.
  It does not grant Devices configuration permissions or switch an output from
  a drawing callback. Settings accepts only known page IDs; its existing display
  selection, scale and rendering authorization paths remain unchanged.
- Text fallback retains Rescan, Display, Probe, selection and scrolling. Pixel
  sizes below 200x170 display a diagnostic with no stale action hitboxes.

## Validation

107 fast Lua 5.2 suites cover metadata suspension, no draw acquisition, owner
cleanup, permission denial, selection/result identity, detach/replacement,
timeout/late-result refusal, cached layouts, search/filter/keyboard, bounded
diagnostics and small layouts. Existing regression suites remain in the gate.
The installer-bundle test checks every embedded source against the release tree
and requires the new Devices modules, preventing a stale installer release.

The CraftOS-PC eleven-app graphical workflow includes a clearly labelled mocked
Devices inventory, native search and pointer selection, method metadata, a real
unknown-endpoint Probe failure, and the Settings Display shortcut. Captured
960x540 indexed framebuffers are inspected for layout. Terminal routing,
offline/text fallback and prior-release migration are separate runtime gates.
The eleven-app native-computer and source-isolated terminal-transport workflows
pass, as do the twelve-app offline text smoke test and the network Update/apply/
rollback workflow. All 264 Lua files pass syntax checks and literal system/app
requires resolve. These simulations are not Minecraft peripheral validation.
The previous released updater installs this bundle and rolls back while retaining
the test file/config on disposable CraftOS-PC storage. This native filesystem
reports host-volume capacity; it does not prove quota-enforced 1 MB acceptance.
Real CC installations still need sufficient space for staging and checkpoints;
the updater refuses before installation when its disk preflight fails.

## Migration And Limits

Install the pinned release and reboot; no user configuration or data reset is
required. The former misleading "Use monitor" refresh action is replaced by the
existing Display settings workflow, which can select an actual available target.
Hotplug remains managed by deviced. No graphics/mod JAR is installed or replaced.

Probe still uses Combat's diagnostic service; if that service/profile is disabled,
Devices reports refusal rather than starting weapon-control services implicitly.
Metadata inspection itself does not require the radar/CBC addons. Unknown device
commands are never guessed or offered for execution. This increment does not
finish Settings, Editor, Messenger or the other pending app migrations, and does
not mark the complete ASCENDANCY goal finished.
