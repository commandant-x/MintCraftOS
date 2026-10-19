# 0.18.38: Native Task Manager And Measured Charts

## Delivered

- Native Processes, Performance, Renderer and Acquisition views. Process rows
  select by PID, not by visible row index; live/all filtering and inspectors
  preserve permissions, errors, window ID, start timestamp, resume count and
  measured active wall milliseconds. Scheduler lists now expose the actual
  protected flag and raw/structured event mode.
- Native and compatibility kill confirmations remain bound to the selected PID.
  The kill path refreshes and revalidates the target, then calls ctx.kill only.
  Protected/exited targets, stale native snapshots and hidden confirmations
  after resize cannot submit a native kill. No privileged force-kill is added.
- Acquisition moves out of drawing. The owned one-second timer queries process
  metadata, filesystem capacity/free space, Lua heap, cached render statistics
  and instrumented peripheral counters. Actual elapsed time determines rates.
  The timer does not skip samples due to a floating-point clock threshold.
- Graph history retains at most 60 real observations, not invented points for
  missing intervals. Clock reversals reset history; long interruptions break
  curves. Duplicate manual refreshes do not create fake temporal samples.
- Counter decrease, source loss/recovery or pixel-backend replacement creates
  an explicit rate gap and new baseline, including rapid forced-refresh cases.
  Backend generations distinguish same-name replacements even when the new
  byte count already exceeds the old count.
- Unknown, failed, unlimited and inconsistent filesystem/heap values are handled
  without fabricated zeroes or usage percentages. Invalid storage values do not
  produce a progress bar. Read errors are visible; render callbacks perform no
  filesystem, garbage-collector or peripheral acquisition.

## Metric Semantics

- Lua heap is global KiB, not physical/per-process RAM or a RAM percentage.
- Active wall ms is measured around coroutine.resume using UTC timestamps, not
  CPU utilization. Waiting ready processes are live, not continuously executing.
  Clock adjustments can affect that measurement. No aggregate runtime rate is
  derived from retained processes: completed-history eviction is not monotonic.
- Compositor draws/s counts completed compositor calls, including unchanged
  draws. It is not physical display FPS. The charts contribute to these calls.
- Pixel payload B/s counts indexed bytes submitted through drawPixels, not
  compressed transport size, palette/protocol overhead or total network traffic.
- Last successful present ms is the backend's last successful presentation,
  not complete render time or an average. Render errors are shown separately.
- Peripheral counters describe admitted attempts through the instrumented addon
  library. They are not all peripheral operations or network packets. Runner
  time/read fields are last-cycle values; overruns are cumulative.
- Sample intervals and chart axes use CC os.clock uptime seconds. Their clock
  resolution and server-tick behavior are not an independent physical FPS/TPS
  benchmark. A measured zero present duration is not proof of zero rendering cost.
- CPU utilization, physical RAM and aggregate network totals remain explicitly
  unavailable. No unsupported API or invented performance percentage is used.

## Validation And Migration

100 fast Lua 5.2 suites and syntax checks pass. Coverage includes unavailable
and zero metrics, unlimited storage, permission denial, coherent rates, backend
generation changes, rapid reset/recovery, history bounds/time gaps, cache-only
drawing, PID binding, protected/exited/stale targets and resize cancellation.

Visible isolated CraftOS-PC exercises nine apps, automatic sampling, native
keyboard view selection and confirmed kill of an inert isolated test process,
using the installed CC Graphics ROM window implementation. Real measured
framebuffers are inspected; no synthetic CPU/network values are injected.
CC Terminals input remains a source-isolated transport simulation, not an
in-game hardware test. Full in-game validation remains required.

Install the pinned release and reboot. No user config/data/mod reset is needed.
The compatibility Task Manager continues to show all retained process rows when
graphics are unavailable. This increment does not complete the other application
migrations or the full ASCENDANCY goal; see ASCENDANCY.md.
