# 0.18.44: Native Terminal

## Changes

- Terminal renders its existing built-in command engine directly as bitmap text,
  not a magnified hidden window. Output wraps to the client width with colored
  welcome/error records, a Live follow mode, page/wheel/scrollbar navigation and
  pointer selection of whole output records. Copy preserves the retained source
  records, not their visual wrapping; paste uses the existing first-line policy.
- The input has a real cursor, mouse placement, Left/Right/Home/End/Delete and
  insertion/backspace in the middle of a line. Up/Down preserve command history.
  The shared tactile keyboard includes compact small-window composition.
- Quick commands and local copy/paste use an input-isolated, scrollable menu.
  Ctrl+L clears output, Ctrl+U clears input and Ctrl+C copies selected output.
  Key releases clear the modifier even after focus changes; cleanup removes the
  listener. Native paste events are not duplicated by a second Ctrl+V handler.
- Autocomplete runs outside drawing, uses the actual cursor, and accepts the
  displayed suggestion without silently recomputing a different candidate.
  Provider failure leaves input usable. Named authentication commands stay out
  of completion/history and render masked input/echo, not plaintext passwords.
- Output is bounded to 200 records, 4096 bytes per record and 8192 visual rows.
  Truncation is marked. Width/revision caches reuse unchanged record reflow.
  Input is capped at 4096 bytes and command history at 100 entries.
- Live read guards were missing from several old command paths. `ls`, `cd`,
  `cat`, `type`, `cp`, `ps` and `logs` now check their relevant permission before
  acquisition. Filesystem completion also checks read permission. Terminal now
  declares logs.read in its app capabilities; user/session permission is still
  required. Existing destructive-operation confirmations and rechecks remain.

## Migration And Limits

Use the normal installer/Update workflow and reboot. Existing files/configs and
the old command vocabulary are preserved. The standard text fallback remains
usable; the native input cursor returns to end-of-line when using that fallback.
No external mod, Minecraft configuration or world is modified.

This is the existing MintCraft built-in console, not a new POSIX shell, ANSI
parser, arbitrary Lua executor or secure sandbox. Program-level legacy terminal
compatibility remains the OS's separate virtual-window contract. Selection is
record-based; the clipboard is local to this Terminal window, not the host OS or
another app. Editing is byte-oriented, not full Unicode/grapheme-aware.
Most old commands retain synchronous execution, so large filesystem operations
can still delay input. No throughput/FPS improvement is invented or promised.

## Validation

116 fast Lua 5.2 suites pass. All 279 Lua sources compile, literal app/system
requires resolve and generated-installer equality passes. New coverage includes
cursor insertion/deletion, output ID/color rollover, local copy, private-command
completion exclusion, stable displayed Tab acceptance after provider changes,
provider failure, denied read commands and modifier-listener cleanup. Native
layouts cover 200x120 through 960x500 client sizes, bounded reflow, selection,
masked framebuffer text, tactile keyboard and menu input isolation.

Normal visible CraftOS-PC with isolated storage and the installed CC Graphics
window ROM passes the thirteen-app workflow in 256/16/text modes. Actual routed
Terminal input edits/executes pwd, recalls history, masks a display-only private
draft, rolls output metadata past 200 records and copies selected output. The
CC Terminals source-isolated transport simulation passes the same workflow.
Captured 960x540 masked-input and history/selection/keyboard frames were inspected.

The twelve-app offline text smoke and HTTP failure/recovery, Update check/apply/
granular rollback workflows pass. The actual published 0.18.43 updater installs
this bundle and rolls back while retaining the test user's file/config. Native
CraftOS-PC reports host-volume capacity, not a proven quota-enforced 1 MB disk.
These are unit/simulated transport/CraftOS-PC results, not Minecraft tests.
Complete Graphics 2.0 and ASCENDANCY remain open.
