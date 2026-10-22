# Final hardening delivery index — 0.18.69

Audit began at GitHub main `47329591f75ee2d1eedb8e12ee819ec8fa86392f`.
Existing features were inspected and reused. Delivery was split because the
combined checkpoint plus temporary recovery copies did not fit a 1 MB computer.
No real user backup was deleted during the audit.

## Delivered stages

- [0.18.64: security](HARDENING-0.18.64.md): API-level factory-empty login refusal,
  mandatory first-start authorization gate, existing protected identity unlock,
  isolation of cached windows on account change, and no implicit backup purge.
- [0.18.65: navigation limits](HARDENING-0.18.65.md): operator-configurable speed
  and displacement bounds; zero remains disabled per the operator's preference.
- [0.18.66: graphics infrastructure](HARDENING-0.18.66.md): 1x/1.5x/2x logical UI
  scale without reducing physical resolution/palette, text rescue, session-scoped
  shared text clipboard and measured graphics-profile benchmarks.
- [0.18.67: Navigation native views](HARDENING-0.18.67.md): secondary forms,
  calibration/setup, complete flight review, real equipment projection/details,
  and STOP independent of invalid text edits.
- [0.18.68: Combat native views](HARDENING-0.18.68.md): remaining forms and staged
  radar setup reuse existing validation; aim/fire stay separate and explicitly
  authorized. These stages close the known native secondary-view audit gaps.
- [0.18.69: ASCENDANCY interfaces](ASCENDANCY-CONTRACTS.md): actual cache readers,
  provenance/freshness/clock/frame/unit contracts, persistent map format,
  non-actuating mission validation and supervision status. Major modules are
  intentionally not fabricated. Cosmonautics remains explicitly unsupported
  until a real adapter is implemented.

0.18.69 also rejects malformed boolean optional-limit values instead of silently
disabling a constraint, and ensures legacy `security.enabled=false` cannot
bypass a locked session's non-authentication authorization check. Trusted system
boot/recovery actors remain available.

## Storage/compatibility policy

The operator previously chose no new permanent history (`retainRollback=false`).
That preference remains supported; normal updates now preserve any existing
backups. Retained-checkpoint mode (`retainRollback=true`) remains functional and
is explicitly enabled in its migration/rollback tests. Both modes retain
transactional recovery for interrupted writes. No unattended cleanup is used to
make quota tests pass. Personal files, credentials and permissions are preserved.
Unlimited history and arbitrary personal data cannot fit forever on 1 MB;
insufficient space is refused without silently deleting history.

Every stage regenerates the distributable and runs source/packed suites plus
exact previous-stage upgrade/checkpoint rollback under a conservative
1,000,000-byte disk model with minimum 512 bytes per file/directory and a
100,000-byte personal-data witness. Failed writes, saturated disk refusal,
interrupted staging/backup/live installation and graphic failure/text rescue
are exercised by isolated automated tests. These are offline tests, not a claim
that Minecraft was run. Use the in-game procedures in each stage document.

For a large jump from an older installation, do not assume the whole change set
fits with all existing backups. If the pinned latest installer refuses space,
use the verified small stages in order and reboot between each. These commands
are for the ordinary CraftOS shell, not the MintCraftOS built-in Terminal:

| Stage | Pinned installer |
| --- | --- |
| 0.18.64 | `wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/d24a9344256adf0e088cae87f02e3ae4f2e173c7/install.lua` |
| 0.18.65 | `wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/7eb2fca239812f1c7a1715fcaf4c3b86a5873503/install.lua` |
| 0.18.66 | `wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/d525aea3baedb77c3a1db32eda8cc5d7e510608f/install.lua` |
| 0.18.67 | `wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/c8cefeffab1617b8b2ac75653bff6db2e5cbfbb4/install.lua` |
| 0.18.68 | `wget run https://raw.githubusercontent.com/commandant-x/MintCraftOS/6990e4cb0f4e5334e0d0e4e50f10d52fa57e0718/install.lua` |

Then check Update for the current release. Existing extra history/data can still
make an individual stage too large; inspect Storage and preserve/archive data
before any explicitly chosen cleanup. Do not delete recovery directories or
protected snapshots to bypass a failed preflight.

## Final automated verification

154 Lua suites passed against source and packed runtime. The packed runtime's
153 Lua chunks compile. The unchanged expensive production password vectors and
Minecraft-only fixtures are excluded from this fast regression run.

The conservative 1,000,000-byte fixture (512-byte minimum per file/directory)
installs 152 Lua files and uses 839,539 bytes including a 100,000-byte personal
file. The exact 0.18.68 to 0.18.69 upgrade with retained rollback peaks at
894,845 bytes; interrupted backup/live writes restore the previous version.
The explicit history-purge fixture peaks at 867,833 bytes, and a separate default
upgrade verifies that existing checkpoints are preserved without explicit purge.
These are isolated fixture measurements, not guarantees for arbitrary user disks.

## In-game acceptance, not executed here

Use disposable copies. Verify fresh enrollment, protected legacy/custom accounts,
lock/reboot, same-user window retention and cross-account isolation. Compare
credential/permission records and personal-file checksums locally before/after
update and opt-in rollback, without publishing secrets. Exercise all 16 native
clients at supported scales, text rescue, extended colours and maximum physical
resolution; compare real service/render metrics for Stable/Balanced/Performance.
Copy ordinary text across clients and verify session/secret-field isolation.

Exercise interrupted/saturated installations and graphics failure only on copied
disks. Test real wired radars, API/manual coordinates and native setup. On an
isolated physical aircraft, verify each burner/direction/manual/rescue action,
optional limits (zero disabled), STOP/F10, receiver loss, stale/future telemetry,
wrong vehicle, closed owner and revoked permission. Never infer physical success
or metre-precision from software acknowledgement or offline model fitting.

## Preparation boundary

The common code is ready for progressive ORACLE/ATLAS/SYNAPSE/WARROOM/ASTRAL work.
It does not claim completed fusion, terrain scanning, mission planning/execution,
a new supervision app or a working Cosmonautics integration. Those are future
modules built against the real-source contracts after this hardening delivery.
