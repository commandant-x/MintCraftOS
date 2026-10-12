# Per-computer app selection / 0.18.5

Desktop > Apps opens Settings directly on the Apps selector. Tap a checkbox to
enable/disable an app. Apps remain installed: no user files, app modules or addon
calibrations are deleted. Disabled apps disappear from the desktop/Start/search
and cannot be launched until re-enabled. Settings and the embedded Editor remain
available to avoid losing configuration access or Files text editing.

Presets: Full enables all apps; Pocket enables Terminal, Files, Messenger, Devices,
Settings and Update; Auto detects the CC pocket API. Selecting a preset resets
individual choices, then check/uncheck apps to customize it. Each computer persists
its own profile in `/system/config/profile.cfg`, preserved during OS updates.
Full/Pocket here select applications, not security privileges or mod compatibility.

On small screens (<40 columns or <18 rows), bitmap icons use 4x3 terminal cells.
The grid is bounded and paged with < / >; Apps remains accessible below the grid.
Large screens keep 7x6 icons. Changing terminal/monitor resolution recalculates
the layout without dropping apps. Start and the selector support scrolling/touch
arrows; disabled/integrated apps are still listed in Settings for reactivation.

Navigation/Combat/Messenger/Update services are omitted on reboot when their apps
are not selected. Enabling and launching an app starts its required services.
Disabling an app does not kill open windows or interrupt flight/cannon services:
close the app safely, then reboot to apply the lighter service startup profile.
This selection reduces visible apps/startup work, NOT the installer/disk footprint.

CC pocket detection reference: https://tweaked.cc/module/pocket.html
