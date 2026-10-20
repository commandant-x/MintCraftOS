# 0.18.42: Native Messenger

## Changes

- Messenger has a native pixel history, wrapped messages with sender headings,
  draft input, Send, clear-view, modem refresh and Live controls. Scroll/page
  navigation and a draggable scrollbar work independently of the follow state.
  Touch input uses the shared bitmap keyboard, including a compact composition
  view on small clients. History layout is reused until width/content changes.
- Neither native nor text drawing reads the inbox or calls peripherals. Cached
  inbox synchronization runs on receive/hotplug/timer events, not during redraws.
  Minimized windows stop polling. Transport work uses a serial app-owned worker;
  queued requests recheck current send permission. No automatic send retry.
- The receive buffer uses monotonic sequence cursors rather than its length.
  New messages continue arriving after the 100-record buffer fills. Slow readers
  see a gap marker; snapshot records are copies. Clear removes only this view,
  advances no network state and does not replay old messages on refresh.
- Drafts are bounded to 4096 bytes; local history is bounded to 80 messages.
  Successful sends clear the draft only if the user has not edited it meanwhile.
  Failed/uncertain sends retain it. Closing a window cancels its transport worker;
  if a peripheral was already executing, delivery is not guaranteed or retried.
- Launch no longer restarts the shared Messenger service and its listeners for
  every window. The existing app dependency starts the service if needed.

## Security And Compatibility

This remains PUBLIC Rednet chat: unauthenticated, unencrypted and spoofable.
The warning is visible in the normal history and compact keyboard views. Sender
names are supplied by remote peers, not verified identities. NEXUS authentication
is separate and is not silently applied to this public protocol.

No new remote execution, account, transport protocol or private messaging is
introduced. Existing text chat, hotplug and plain/serialized receive formats
remain available. Update/reboot through the ordinary installer workflow. No user
files/configs, mods or worlds are erased or modified by this migration.

## Validation

112 fast Lua 5.2 suites pass. All 272 Lua sources compile, literal system/app
requires resolve and the generated installer matches the source tree. New tests
cover full inbox rotation, copied snapshots, no duplicate delivery, cache-only
drawing, queued permission revocation, retained concurrent drafts, input/history
bounds and pixel layouts from 200x120 to 960x500 client sizes.

Normal visible, isolated CraftOS-PC with the installed CC Graphics window ROM
passes the twelve-app graphical workflow in 256/16/text modes. Messenger receives
115 simulated public packets, displays the latest after rollover, clears without
replaying old records, accepts native paste and opens the tactile keyboard.
Actual captured 960x540 framebuffers were visually inspected. The CC Terminals
source-isolated transport simulation passes the same workflow.

The twelve-app offline text smoke and HTTP failure/recovery, Update check/apply/
granular rollback workflows pass. The actual published 0.18.41 updater installs
this bundle and rolls back while retaining the test user's file/config. Native
CraftOS-PC reports host-volume capacity, not a proven quota-enforced 1 MB disk.
These are unit/simulated transport/CraftOS-PC results, not in-game tests.
Minecraft modem/hotplug/multi-client testing remains required. Other application
migration and ASCENDANCY remain open.
