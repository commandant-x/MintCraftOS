# Final hardening stage 3: pixel scale and shared clipboard — 0.18.66

Settings → Display offers 1x, 1.5x and 2x pixel interface scales. Applications and
window chrome compose in logical pixels. Changed logical spans are expanded
into the original physical framebuffer with nearest-neighbor sampling. Physical
display resolution, graphics mode and all palette bytes (including 255) remain
unchanged. Pointer hit-testing uses the inverse logical transform without
mutating raw/text input. No sensor acquisition rate is changed. Text rescue
resets pointer scaling; unsupported/small outputs keep effective 1x whenever a
requested scale would leave fewer than 154×131 logical pixels. Monitor text
scale remains a different setting.

The RAM text clipboard connects Editor, Terminal and native client fields.
Ctrl+C/V is supported in those client fields, and Editor gains Ctrl+V. Explicit
selected Terminal output is already masked before copying; authentication input
is not copied. Native secret fields refuse copying but allow deliberate paste.
File copy/move retains its separate existing permission-checked clipboard.

Shared text is limited to 65,536 bytes and never written to disk. Access checks
session revision, locked state and authorization. Lock, logout, credential or
identity changes invalidate it. No legacy local clipboard fallback can revive
old shared text in another session. Operating-system paste events remain separate
from this in-Minecraft shared clipboard. Existing account-switch window isolation
from 0.18.64 still applies; save work before sign-out.

## Evidence

`tests/ui-scale.lua` covers 1/1.5/2 transforms, palette bytes, dirty spans, unchanged
physical buffer dimensions, inverse pointer coordinates, invalid settings,
small-display fallback and text-rescue reset. Settings worker tests verify live
authorization and persistence of scale changes. Clipboard tests cover bounds,
lock/session/enrollment isolation and native field/secret keyboard handling.
Existing source and packed suites retain the 16 app clients and text fallbacks.

The synthetic, graphics-only `tools/graphics-profiles.lua` compares Stable,
Balanced and Performance at 306×171 and 960×540, verifying identical final pixels.
Results are in `docs/benchmarks/graphics-profiles-0.18.66.tsv`. Fewer batched
presentation calls do not imply a measured Minecraft FPS improvement; similar
Lua CPU times must not be described as a speedup. Profile presentation ceilings
remain 20/20/10 Hz and acquisition timers stay unchanged.

The exact 0.18.65→0.18.66 upgrade/retained-checkpoint rollback is tested under a
1,000,000-byte quota with 100,000 bytes of personal data. Normal updates do not
delete existing backups. Retained history remains opt-in, matching the operator's
prior no-history preference; transient recovery remains in both modes.

## In-game procedure (not executed here)

Use a disposable copied installation. At maximum physical resolution choose each
UI scale and exercise menus, drag/resize/maximize, mouse capture, touch and virtual
keyboard in all 16 apps. Check actual hardware resolution and extended colours,
then force text rescue and ensure text/pointer input works. Repeat on a small
classic computer where an unsupported requested scale must fall back to 1x.
Copy ordinary selected text from Editor to Terminal and into a native Browser
field. Try copying a secret field (must not replace the clipboard), lock/unlock,
and verify shared text is gone. Repeat across sign-out after saving test work.

For profile validation record actual render/service metrics on the real server
with real wired radars; do not substitute the synthetic drawing benchmark for
that result. Follow the stage-1 security/recovery acceptance procedure as well.

Remaining stages: complete legacy secondary views, then add common real-source
contracts for ASCENDANCY. No new ASCENDANCY runtime modules are introduced here.
