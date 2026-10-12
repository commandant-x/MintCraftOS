# Browser / Update reliability - 0.18.5

Browser navigation/downloads and Update Check/Apply/Rollback now use owned raw-event
workers, not the window input handler. CC HTTP replies keep their native event
arguments; the OS clock/windows remain responsive while a request is pending.
Closing/crashing/killing the owner also stops its worker. Update cannot queue duplicate
installs. Filesystem installation/rollback is not forcibly timed out halfway through.

HTTP reads close handles even when readAll fails. Native DNS/TLS/HTTP rejection details
are retained. Browser turns request/parser/storage failures into an error page instead
of crashing the window. Malformed saved lists/settings are normalized, tabs are capped
at 16 and the text reader rejects pages over 512 KiB. Browser remains an HTML text
reader, not a JavaScript/HTML5 engine; this release does not restart that larger project.

The automatic version check uses a separate URL query so its event listener cannot
consume/close the response belonging to a manual Check. Update displays live service
status and uses a paginated toolbar on small screens.

## Update storage

Installer protocol 2 plans/validates changes before touching live files. Identical files
are not staged, backed up or rewritten. Update compiles the commit-pinned installer in
memory instead of storing another large installer in /var/tmp. A version mismatch is
rejected before installation. A disk-space preflight returns UPD-DISK with required/free
bytes; existing backups are never automatically deleted to make room.

New Update checkpoints contain only changed OS files, including markers for newly added
code files. Rollback restores those files and removes newly introduced code files;
user home, packages and configuration are preserved. Legacy full backups still work.
Durable installer staging/journal/rollback remains enabled for interruption recovery.

Install this fix using the published pinned wget command once if the current Update app
is broken. Later in-app Apply requires an installer advertising protocol 2; older/custom
installers need a pinned manual installation. Applying an update still requires reboot.

Validation covers simulated delayed HTTP, closed response handles, Browser quick-link
recovery, Check/Apply/rollback, low disk space, and small/large views in isolated CraftOS-PC.
No Minecraft save/profile is touched by these tests. Real-server domain restrictions,
connectivity and available storage remain environmental constraints.
