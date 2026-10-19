# 0.18.36: Native Logs And Diagnostic Input

## Changes

- Logs now has a native pixel client with All/Error/Warn/Info/Debug filters,
  source/time/message columns, selectable records, live-tail toggle and a
  draggable vertical scrollbar. Wheel, arrows, Home/End and Page Up/Down work.
- Wide windows separate the list from wrapped details. Compact windows expose
  an inspector with Back/Escape so complete messages remain reachable without
  overlapping the list. Details have independent scrolling and cached layout.
- File reads and deserialization happen during refresh, never native or legacy
  drawing. Refresh checks the log revision every 0.5 seconds and reuses the
  existing bounded log cache. Filters use parsed records in memory.
- The viewer retains at most 120 entries. Exact duplicate records have distinct
  selection identities within the retained tail. Existing archive limits and
  rotation remain unchanged. Selection is cleared if its entry leaves the tail.
- log.tailStatus() exposes read failure rather than silently representing old
  cached entries as a successful fresh read. The viewer displays that failure;
  Refresh retries. Cached records are retained, not destroyed by read failure.
- Combat now forwards native keyboard events from the active window's normal
  handler. Its Tab/Enter controls were previously implemented but only pointer
  events reached the native handler. Permissions/fire confirmation are unchanged.
- Shared pixel scrollbar drawing/position conversion is available to later app
  migrations. Undersized Logs clients clear hidden input boxes and remain safe
  during a drag/resize transition. The original text UI remains the rescue path.

## Validation

96 fast Lua 5.2 suites and syntax checks pass. Coverage includes filter reachability,
no draw-time reads, read failure/retry, duplicate identities, scrollbar drag,
selection, small/wide layouts, wrapped-message inspection, keyboard navigation
and hidden-hitbox cleanup after resize.

Visible isolated CraftOS-PC tests cover native Logs input, details and filters,
Combat keyboard routing, seven apps and mode 256/16/text transitions using the
installed CC Graphics ROM window implementation. A separate source-isolated
CC Terminals transport simulation passes the same workflow. Framebuffer captures
are inspected; test log entries are explicitly sourced from isolated-test.
These are emulator tests, not Minecraft validation.

Install the pinned release and reboot. No log/config reset or mod replacement is
required. Existing log files remain usable. OS-wide app migration is still in
progress: see the application matrix in ASCENDANCY.md. Services, Settings, Update
and other legacy clients have not been declared migrated by this increment.
