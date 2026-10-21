# Permissions and data protection — 0.18.47

This release hardens the trusted MintCraftOS application paths. It retains the
compact source distribution and the server's 1,000,000-byte disk limit.

## Demonstrated problems and fixes

1. **Security provider failures could fail open.** Previously, a missing or
   malformed `securityd` module let the permission gate continue with an app's
   declarations alone. Permission decisions now require an available provider,
   an explicit boolean authorization and the app's own declaration. Provider
   exceptions/malformed responses deny access. A decision is evaluated once;
   authorization errors do not dump provider exception text into logs, and a
   failed log write cannot turn a denial into success.
2. **Read permission exposed security data.** Built-in file readers previously
   treated a generic `filesystem.read` grant as sufficient to read credentials,
   NEXUS configuration keys and retained backups. Reading `/system/config`,
   `/system/security/users.db` (including its safe-save files), `/var/backups`
   and installation/package/restore transaction trees now additionally requires
   `system.security.admin` from both the session and the app. Normalized `..`
   and backslash paths cannot avoid the check. Trusted admin Terminal access
   remains available; Files/Editor do not acquire extra admin declarations.
3. **Terminal path handling differed from Files/Editor.** Terminal reads now
   authorize the resolved target, rather than relying only on the command's raw
   argument. Recursive copies preflight every descendant, before calling `fs.copy`,
   and refuse trees exceeding 4,096 entries. Terminal writes/mkdir/move/restore
   consistently honor protected system paths. File management also protects the
   retained backup tree and active transaction roots/parents against ordinary
   recursive delete/move operations. Authorized backup pruning still uses the
   existing storage service and its checkpoint protections.
4. **Legacy whole-system rollback could revert credentials.** Both the Update
   service and standalone raw Recovery now copy the live `/system/security/users.db`
   into a staged legacy `/system` restore, preserving current credentials, roles
   and stored session state. The historical checkpoint is not modified. Existing
   config preservation and forced text rescue remain in effect.

No passwords, roles, keys, documents or user configuration are automatically
reset. No server/mod settings, sensor frequencies or graphical quality change.

## Validation

- 128 fast Lua suites pass against readable sources and actual packed modules;
- 296 development Lua files and 137 installed chunks compile;
- provider absence, exceptions, malformed authorization, declaration/session
  intersection, normalized sensitive reads, one decision per check, logging
  failure and authorized ordinary reads are covered;
- Terminal integration checks blocked reads/recursive copies before file access,
  legitimate admin reads, protected destinations/checkpoints and normal copying;
- both legacy rollback implementations retain the live user database while
  restoring system code and retaining the original checkpoint;
- the strict 1,000,000-byte allocation test passes with 100,000 bytes of witness
  data: 752,180 installed bytes and 802,951 peak bytes across installation,
  subsequent update and rollback (512-byte minimum per file/directory);
- a separate test using the actual 0.18.46 distributable upgrades to 0.18.47 and
  rolls back with the same 100,000-byte witness data: peak **952,210 bytes** under
  the 1,000,000-byte ceiling. This is distinct from the smaller synthetic next-update
  fixture above. Reproduce with `git show e33ef47:install.lua > /tmp/mintcraft-0.18.46.lua`
  then `lua5.2 tests/compact-disk.lua /tmp/mintcraft-0.18.46.lua`.

The production-cost password-crypto test remains excluded from the fast suite.
Minecraft/NeoForge and CraftOS-PC runtime tests were not executed here.

## Scope and operation

These checks enforce the trusted UI/service policy. They are not a Lua VM sandbox
or encryption at rest. Internal nil/system actors remain trusted; third-party
execution stays disabled. Someone with raw CraftOS shell, unrestricted Lua or
server/filesystem access can access the underlying computer files. Normal personal
files still follow the existing `filesystem.read` grants; this does not introduce
private per-user directories or per-file ACLs. Shared-disk NEXUS manifests and a
complete network protocol audit are outside this patch.

Set an admin password and use guest/locked mode where appropriate through the
existing Settings UI. Update with the pinned 0.18.47 installer URL supplied with
the release. Do not delete checkpoints or disable the free-space check.
For graphical rescue use `/boot.lua --text`; for a prior update checkpoint use
`/boot.lua --recovery`, `rollback`, confirm `RESTORE`, then `reboot`.

See [compact installation](COMPACT-INSTALL.md) for encoding and recovery details.
A rollback to a release before 0.18.47 also restores its older permission policy;
rolling back is recovery, not a guarantee that the older version contains these fixes.
