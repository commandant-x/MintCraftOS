# NEXUS 0.4: resilient observation and alerts

Deploy still has Automate and Pause, and boot waves still have no intentional
inter-start delay. This increment extends supervision, not physical machine control.

## Observation leases

Queued/sent observe jobs are abandoned if their assigned agent has no heartbeat
for 15 seconds or stops advertising the endpoint. The old job ID is marked failed,
and the read-only observation can be assigned to another online authorized agent
that advertises the same endpoint. Late results for the released ID are ignored.
Non-observation missions are not reassigned by this mechanism.

Assignment owner and sample producer are tracked separately. A new assignment
does not relabel an old producer's sample as fresh. Totals exclude failed reads,
offline sample producers and samples older than the configured limit, using the
earlier of measurement timestamp and MASTER receipt time. Removed, unassigned
endpoints with no activity for five minutes are evicted to free the 128-slot registry.

## Alerts and rules

Alerts shows current conditions and recent transitions. Acknowledge all persists
acknowledgements, but does not suppress other/new conditions. Notifications and
logs are generated on transitions, not every redraw or timer tick. An acknowledged
condition that resolves and later returns is a new unacknowledged alert.
A five-second startup grace allows heartbeats to arrive. Bursts of more than three
new conditions produce a summary notification, while individual entries stay in
Alerts. Samples saved by older versions without producer identity are refreshed
before inclusion in totals.

Monitoring exposes global read-only thresholds, persisted at
/system/config/nexus-monitor.cfg:

- Offline alert: 15 seconds, configurable 5..120. Observation lease expiry remains
  fixed at 15 seconds, independent of this notification threshold.
- Stale sample: 60 seconds, configurable 10..300.
- Energy low: 10 percent of reported capacity.
- Internal disk free low: 5 percent, if numeric free/capacity are available.
- Inventory occupied slots high: 90 percent. This is slot occupancy, NOT a claim
  that every stack is full. Partial scans do not trigger this condition.

Capacity alerts use a two-percentage-point recovery band to avoid oscillating
notifications. Missing measurements do not falsely resolve an existing threshold
alert. Disabling alerts clears conditions as disabled; removed endpoints are marked
removed, not recovered. Pause stops new observation/monitoring work but retains
the last alert state and does not cancel an already-issued peripheral operation.

The bounded journal /var/nexus/alerts.cfg retains up to 192 active conditions and
64 transitions. The UI explicitly indicates truncation. This is not an unlimited
audit archive. Corrupt or invalid saved rules fall back to validated defaults.

No redstone write, item transfer, fluid transfer or industrial control method is
invoked by these rules. Industrial actuation still needs a separate explicit mapping
and approval workflow; automatic monitoring is not a flight or safety controller.
