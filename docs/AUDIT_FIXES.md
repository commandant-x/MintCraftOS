# Audit Remediation - 0.18.7

This release integrates the audit fixes in an isolated managed worktree. No
Minecraft save, profile, mod JAR or Windows security setting was modified.

## Implemented With Regression Coverage

| Audit topic | Resolution | Tests |
| --- | --- | --- |
| Partial flight rescue | Healthy endpoints receive rescue independently; missing/refused/uncertain endpoints are reported, not silently retried | service-safety, navigation |
| Locked admin reset | Separate admin permission, old-secret reauthentication, rate limiting, stale-write guards | security-users, settings-audit |
| Password storage | Salted PBKDF2-HMAC-SHA256, 600,000 iterations; legacy records migrate only after valid authentication | password-crypto |
| Auth responsiveness | Native-event workers with progress/cancellation; closing an app releases the auth mutex before retiring the worker | auth-worker, craftos-audit-core, craftos-security |
| Crash cleanup and logger failure | Cleanup is independent of log/notification failure; logger is best-effort | crashes, scheduler-hardening, logging |
| Process leaks and CPU claim | Terminal records capped at 64; coroutine/window references released; fake CPU percentage removed | scheduler-hardening, taskmanager |
| Recovery and transactional writes | Recognized save staging reconciled before defaults, dependency-free system-tree restoration, resumable rollback | storage-recovery, safe-write, installer |
| Incremental/legacy update recovery | Whole manifest validated first, added-file markers handled, checkpoints retained | backup, update-storage, craftos-backup |
| Concurrent update windows | Apply/Rollback share a service-level lock; installed version checked again before mutation | update-storage |
| Package ownership | Reserved core IDs/paths rejected, install/remove journaled, DB stores ownership rather than source copies | package-storage |
| Log viewer | Compact records plus legacy parser, bounded rotation and cached tails | logging, log-service-viewers |
| Render load | Per-window dirty/cache, timer ownership, covered-window culling; unchanged apps do not rerun draw on radar ticks | render-cache, craftos-audit-core |
| Service health and radar cache | Cached health exposes failures/worker state; faults advance revisions and healthy readers survive slow devices | service-health, service-safety |
| Browser | TTL/revalidation, forced Reload, bounded HTTP body reads and owned network workers | http-client, network-apps-audit |
| CraftTube and audio proxy | Owned native workers; proxy allowlist, concurrency/size/deadline limits and child cleanup | network-apps-audit, Node server.test.js |
| Trash | Original paths/names retained, explicit permanent delete, numeric suffix names preserved | file-editor-audit |
| Editor | Save/Discard/Cancel close contract, recoverable drafts, disk-change conflict detection, hideable keyboard | editor, file-editor-audit |
| Settings/compact views | Local hitboxes, responsive menus and scroll, themed pages, permission guards and confirmed storage cleanup | settings-audit |
| Radar transport | HMAC-SHA256 envelopes, signed sender/freshness, replay/downgrade rejection; trusted slots reserved | radar-auth, radar-network |

## Important Behavior Changes

- Third-party app execution is blocked before import. Package data installation is
  transactional, but CC does not provide a verified hostile-code CPU/memory sandbox.
  Built-in apps remain trusted cooperative code. This is containment, not a claim
  that arbitrary Lua can be safely executed.
- Radar stations must configure the same shared key (16+ characters) in Combat /
  Network configuration. Authentication does not encrypt measurements. Unsigned
  legacy networking requires explicit allowInsecure and remains visibly marked.
- Password derivation can take significant time on CC. It runs outside input
  callbacks, shows progress in Settings, and can be cancelled before commit.
- App profiles control activation, not uninstall. Existing service changes require
  an explicit restart/reboot; active flight outputs are never stopped by a profile
  toggle. Storage cleanup requires confirmation and protects recovery checkpoints.
- The source SHA256/PBKDF2 implementation and license are preserved in
  system/libraries/password_crypto.lua. Fixed-width packing was adapted and checked
  against SHA, RFC HMAC and PBKDF2 vectors, including Python hashlib comparisons.

## Limits Not Represented As Closed Bugs

Non-yielding host code and loss of computer power cannot be handled by a software
failsafe. Physical flight/CBC calibration and addon compatibility still require
in-game commissioning. CBC remains confirmed-fire, estimated vacuum ballistics.
Browser remains an HTML text reader, not a JavaScript/HTML5 engine. Radar data is
acquired at 5 Hz while render timing targets 20 Hz. No new full web engine, GPU
renderer, or full hostile-code sandbox is delivered by this corrective release.
