# 0.18.43: Native Editor

## Changes

- The Editor launched from Files is a native pixel client with bitmap monospace
  text, line numbers, caret, vertical scrolling/scrollbar and horizontal cursor
  reveal. Drawing visits only visible rows and keeps a bounded token cache for
  unchanged visible fragments. Autocomplete is refreshed outside drawing.
- Shift/arrows and pointer drag select text, including across lines. Typing,
  paste, backspace and Delete replace/remove selections through the existing
  edit/draft path. Cursor movement handles line boundaries and Home/End/Page keys.
  Copy/cut/select-all and local paste are available through the More menu.
- Find uses literal case-sensitive text, selects the next match and wraps at EOF.
  Search input is isolated from document input. Escape closes it. Ctrl+F opens
  Find; Ctrl+S saves; Ctrl+A/C/X select/copy/cut. Native paste events still insert
  supplied text; no invented OS clipboard API or duplicate Ctrl+V insertion.
- Basic Lua keywords, numbers, quoted strings and line comments are colored.
  This is fragment-based highlighting, not a complete multiline Lua parser.
- The shared tactile keyboard has compact composition on small windows. Unsaved
  close confirmation is centered, input-isolated and keyboard navigable; no hidden
  edit/compile action runs behind it. Global key releases clear modifiers even
  after focus moves; the listener is removed on process cleanup.
- Existing file permissions, protected paths, on-disk conflict checks, safe_write,
  draft ownership/recovery and compile-without-execution remain authoritative.
  Text fallback stays available and drops native-only search/selection focus.

## Migration And Limits

Use the normal installer/Update workflow, then reboot. Editor remains integrated
with Files and is not added as a redundant desktop icon. Existing documents,
drafts and configuration are preserved by the OS update.

File/cursor positions are byte-based; full Unicode/grapheme editing is not claimed.
The copy buffer belongs to this Editor window, not the host OS or another app.
Only viewport drawing is optimized here: existing full-text draft serialization
and synchronous filesystem writes can still cost time on large documents.
Undo/redo and richer multiline syntax remain future work. These limits do not
constitute completed Graphics 2.0 or ASCENDANCY acceptance.

## Validation

114 fast Lua 5.2 suites pass. All 276 Lua sources compile, literal app/system
requires resolve and installer-bundle equality passes. New tests cover reversed
and multiline selection, replacement, cursor limits, wrapped literal search,
visible-row token reuse, small layouts, close-modal isolation, native drag/shift
selection, tactile keyboard and modifier listener cleanup. The original Editor
and file/draft/conflict regression suites remain green.

Normal visible CraftOS-PC with isolated storage and the installed CC Graphics
window ROM passes the thirteen-app native workflow in 256/16/text modes. Editor
uses actual routed Ctrl+A/paste/Ctrl+S, disk readback, compile, find, selection
replacement and unsaved-close cancellation. The source-isolated CC Terminals
transport simulation passes the same workflow. Actual 960x540 indexed captures
of search, selection, close confirmation and keyboard were visually inspected.

The dedicated CraftOS-PC Editor test passes compile-without-execution, invalid
Lua errors and failed-save preservation of both file and buffer. Twelve-app
offline text smoke and HTTP failure/recovery, Update check/apply/granular rollback
pass. The actual released 0.18.42 updater installs this bundle and rolls back,
retaining the test user's file/config. The native filesystem reports host-volume
capacity; this is not proof of operation on a quota-enforced 1 MB disk.

These are unit, simulation and CraftOS-PC results. Real Minecraft input and
legibility remain unverified; the complete ASCENDANCY objective remains open.
