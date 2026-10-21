# Compact installation — 0.18.46

This release targets a **first installation on a CC:Tweaked computer limited to
1,000,000 bytes**, without changing the server, removing applications or lowering
graphics quality. It replaces the oversized 0.18.45 distribution.

## Size and preservation

| Quantity | Bytes |
|---|---:|
| Readable source tree distributed by the installer | 1,031,390 |
| Same files with lossless Lua source packing | 609,435 |
| Downloadable `install.lua` | 618,052 |
| Installed fixture, including 100,000 bytes of personal witness data | 750,353 |
| Peak fixture allocation across install, subsequent update and rollback | 801,124 |

The fixture charges **at least 512 bytes for every file and directory** and enforces
a 1,000,000-byte ceiling after every filesystem mutation. This is a conservative
simulation, not a measurement from a Minecraft server. The installer still checks
actual free space and retains its disk refusal when existing data/checkpoints do
not leave enough room. This does not promise unlimited future updates or user data.

Every application and module is retained. Source packing is **lossless LZSS plus
Base85**: comments, strings, whitespace, byte content and license notices survive.
The byte-for-byte bundle equality test decodes every packed payload and compares
it with its readable Git source. Fonts, indexed colors, resolution, graphics
settings, sensor periods and application behavior are not reduced to save space.
Non-Lua assets/configuration are unchanged. Existing personal scripts/documents/configuration
are preserved unchanged by the installer.

The readable development tree remains in GitHub. Installed system/app `.lua` files
may be compact loader wrappers, so inspect/edit the Git source and regenerate the
installer rather than editing encoded payloads directly on the computer.

## Runtime and recovery

An installed wrapper decodes its source, checks its declared byte length and
Adler-32 corruption checksum, compiles it in the original environment and forwards
all chunk arguments/return values. The existing `require` cache avoids decoding
again on every frame. This adds module-load work, not continuous compression or
additional compression of pixel transfers. The checksum is corruption detection,
not cryptographic authentication.

The decoder dictionary window is bounded to 65,535 bytes; matches have length
4–258. Payload bounds and invalid offsets/encoding/checksums are rejected. The
shared loader has a hard decoded-source bound of 4 MiB, well above current modules.

These files stay directly readable and runnable, without the packed-source decoder:

- `/boot.lua` and `/startup.lua`;
- `/system/boot/recovery.lua`;
- `/system/libraries/safe_write.lua`;
- `/system/libraries/installer.lua`;
- `/system/libraries/packed_source.lua` itself.

Before writing files, the installer validates **both** each wrapper and its decoded
Lua source. It retains staging, journaling, old-file backups and durable update
checkpoints. A subsequent checkpoint contains the compact installed bytes, which
are restored by the existing raw Recovery path without needing to decode them.
The loader already exists before a normal subsequent update, so an unchanged
loader is not removed when rolling that update back.

A recognized incomplete staging transaction can be discarded safely because live
files are not touched until its journal is published. A published journal restores
the prior installation before a retry. Rerunning the same pinned installer invokes
that recovery automatically. Unknown/malformed transaction metadata is refused
and retained, not guessed or deleted. There remains a distinction between repairing
an incomplete installation and rolling back a successfully completed update.

## Install on an empty computer

Run the immutable command supplied with the 0.18.46 commit:

```lua
wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/<COMMIT_SHA>/install.lua
reboot
```

Do not use the old 0.18.45 URL: it still contains the oversized uncompressed
payload. No quota increase, mod replacement or server configuration change is
needed for the tested first-installation footprint. If interrupted, return to the
ordinary CraftOS shell and rerun the **same pinned command**. If the installer
reports ambiguous/corrupt recovery metadata, retain it for diagnosis.

After a later successful update, use `/boot.lua --recovery`, `rollback`, confirm
`RESTORE`, then `reboot` to restore its checkpoint while preserving user data.
For text rescue use `/boot.lua --text`. Keep checkpoints; do not bypass the free
space check to force a large update onto a full computer.

Migrating a nearly full, older **unpacked** installation is a separate problem:
this release does not silently rewrite its existing files to create space. Its
normal upgrade can still refuse if a safe checkpoint/staging cannot fit. The
user's target here was confirmed to be a first installation.

## Development and validation

```sh
python3 tools/build-installer.py
lua5.2 tests/packed-source.lua
lua5.2 tests/installer-bundle.lua
lua5.2 tests/compact-disk.lua
```

`build-installer.ps1` delegates to that same Python 3 builder. No external Python
packages or network are required to regenerate the deterministic payload.

Validation covers:

- all **125 fast Lua suites** against the readable source modules;
- the same suites with `require` resolving actual packed installed modules;
- all **293** development Lua files compiling, plus **137** installed Lua chunks;
- exact decoded source equality, argument/multiple-return behavior, binary bytes,
  empty sources, malformed input, invalid sizes and corruption refusal;
- first installation, a later module/version update, durable rollback, preserved
  100,000-byte witness data/config fields, and staging/live-write interruptions
  under the allocation ceiling.

The existing slow production-cost password-crypto suite is excluded from the fast
run. Minecraft/NeoForge and CraftOS-PC are **not executed** in this cloud image;
real-world boot time, Lua heap and graphics commissioning still need confirmation.
No claim of measured physical Minecraft FPS or server memory reduction is made.
