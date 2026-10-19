# 0.18.37: Native Services And Serialized Control

## Changes

- Services is a native pixel list with measured service states, autostart,
  protected markers, worker PID where available, last-success/error details,
  scrollbars and keyboard navigation. Compact clients have a full inspector.
- Health/status collection happens during refresh, not drawing. Both native
  and compatibility drawing use cached rows. No invented CPU/RAM/network data.
- Stop/Restart have a native confirmation bound to the selected service name.
  Protected/busy controls are disabled. Shrinking below the supported layout
  clears the confirmation so Enter cannot execute an invisible dialog.
- ServiceManager.requestAction(actor, action, name) now owns UI control. One
  request may be queued/running globally; additional requests are rejected,
  not silently retried. controlStatus() exposes its cached state/result.
- Live owner and services.control permission are checked on submission and
  immediately before execution. A restart rechecks before its start phase.
  Queued work from a dead owner or an owner with all windows closed is refused.
- The raw-event command worker belongs to the manager, not the Services app.
  Closing the app cannot kill a transition already in progress. A begun stop
  or start can finish; a restart does not start again after owner/permission
  loss. Results are logged and targeted to the requesting process ID.
- Per-service coroutine locks also protect direct internal start/stop calls
  while a transition yields. The entire restart holds the lock. Refused stops
  never proceed to start. deviced/notifd/logd/securityd cannot be stopped or
  restarted through the control interface. Flight/Combat keep their own rescue
  and active-output refusal rules, with no force-kill or automatic retry.
- Losing the command worker while busy exposes an uncertain state and blocks
  new requests. It does not claim rollback or recreate an uncertain command.
- Failed startup cleanup and exceptions during stop mark the service uncertain.
  Starting again is refused until explicit cleanup succeeds. A failed stop is
  not mistaken for an idempotently successful start of an already-started flag.

## Validation

98 fast Lua 5.2 suites and syntax checks pass. New fixtures cover permission
revocation, queued owner/window closure, in-flight owner closure, refusal,
global concurrency, internal start/stop locking, exception cleanup, worker loss,
protected controls, confirmation binding and hidden-dialog resize behavior.

Visible isolated CraftOS-PC exercises eight apps and an actual yielding test
service through native confirmation. Closing Services during its stop does not
abandon that operation. The fixture does not operate flight/fire peripherals.
Native computer and source-isolated CC Terminals transport tests use the installed
CC Graphics ROM window implementation. Framebuffers are inspected. Unit-test
permission mocks cover revocation scenarios; the emulator exercises the existing
fresh-install security policy, not every real-world account configuration.

## Migration And Remaining Limits

Install the pinned release and reboot. No config, logs, profiles or mods are
reset. The text Services client uses the same serialized request interface.
All application migrations and broader ASCENDANCY requirements remain tracked
in ASCENDANCY.md; this is not the complete Graphics 2.0 release.

Async execution is cooperative, not preemptive. Non-yielding addon code can still
block Lua, and a transition which yields forever remains pending. There is no
unsafe timeout/retry pretending to undo partially applied service actions.
Killed in-flight internal transitions retain their lock for inspection/recovery;
they are not assumed complete. Software recovery cannot guarantee outputs on a
frozen or powered-off computer. Actual in-game validation remains required.
