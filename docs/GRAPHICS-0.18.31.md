# 0.18.31: Bitmap Typography And Files Transfers

## Changes

- Display-only text codec: explicit CP437, explicit UTF8 or strict autodetection.
  Supported French accents/combining forms map to the embedded BSD bitmap.
  Ligatures and typographic punctuation use ASCII substitutions. Unsupported
  codepoints become `?`. Assets and redistribution license are unchanged.
- `fonts.layout` / `drawText`: word/hard wrap, scale 1-4, horizontal/vertical
  alignment, spacing, tabs, line endings, clipping and overflow. Limits: 64 KiB
  display source, 4096 lines. Measurement/rasterization use the same glyphs.
- Native labels and inputs truncate glyphs, not incomplete UTF8 byte sequences.
  This never changes stored filenames/content. Legacy byte drawing is retained.
- Files: Copy, Cut, Paste and Properties in native menu and text toolbar.
  Clipboard is per Files window. Cut moves only when Paste succeeds. Navigate
  to the destination in the same window, then Paste.
- Transfers refuse overwrites, self/descendant copies, trash transfers and
  protected move sources/destinations. Descendant permissions are preflighted
  before transfer. Limits: 1024 entries, 32 levels; larger trees are refused.
- Errors retain clipboard and report failure. fs.copy/move are not transactional:
  a disk error can leave a partial destination; inspect it before retrying.
- Properties acquires available attributes only on request: type, file bytes,
  read-only state, modification epoch and path. No invented recursive folder
  size. Native properties wraps/scrolls and caches layout by width. No filesystem
  reads during native redraw.
- The 0.18.30 package-free graphics activation fix is retained.

## Validation

92 fast Lua 5.2 suites passed, covering malformed encodings, supported accents, measurement,
wrap/alignment/scale/spacing, nested clipping, native/text workflows, descendant
permissions, collision refusal, clipboard retention, properties and transfer
bounds. All Lua modules and generated installer passed syntax checks; staged
diff whitespace checks passed.

Normal visible CraftOS-PC tests use isolated storage/read-only source: accented
filename creation, copy/paste to a new folder, properties, drag/minimize/restore,
launcher/shared keyboard, six apps, 256/16/text. CC Terminals transport is simulated.
Exact successful framebuffer profiles are recorded in delivery notes.

Observed passing graphics profiles: 306x171 native, 156x180 pocket-sized UI,
960x540 high-resolution UI, and 480x270 source-isolated terminal simulation.
Raw indexed framebuffer exports were inspected for accented filename rendering
and tactile properties pagination on the small profile. Pocket-sized emulation
is not an actual Minecraft pocket computer test. Toasts remain dismissible
overlays; the pointer scenario dismisses covering notifications before menus.
The separate offline text-mode smoke also passed: twelve apps including NEXUS
opened, maximized and closed without requiring the optional addon peripherals.

## Migration And Limits

Install pinned installer, reboot, select Settings -> Display -> Pixel desktop.
Files/config remain preserved. No Minecraft mods/world changes.

Autodetection cannot distinguish valid UTF8 intentionally stored as CP437 bytes;
choose explicit `encoding="cp437"` for byte semantics. This is the embedded font's
repertoire, not full Unicode shaping, bidi or a new proportional UI font.
Editing/cursor movement still follows existing byte semantics; display layout
is improved, not all Unicode editing.

Native UI scaling and the full sixteen-app migration remain pending. Neither
Graphics 2.0 nor ASCENDANCY is complete. Real Minecraft validation is still
required. Aircraft/control/fire safety remains unchanged.
