# ASCENDANCY common interfaces — schema 1, 0.18.69

These are implemented interchange/collection primitives for progressive modules,
not five new operational apps. No fabricated map, telemetry, mission executor or
Cosmonautics API is supplied. Major runtimes can be built incrementally against
these interfaces after the hardening stages.

| Consumer | Implemented interface | Deliberate boundary |
| --- | --- | --- |
| ORACLE | `sources.list/read/collect`, observation validation and `contracts.compatible` | Actual cached service data; no unverified averaging/fusion or coordinate guesses |
| ATLAS | `validateMap`, `encodeMap`, `decodeMap` | Persistent schema/bytes, not invented terrain or automatic disk writes |
| SYNAPSE | `validateMission` | Existing verified waypoint-plan validator; no arming/execution |
| WARROOM | `statusFor` | Real readiness/reason/age metadata, not fake dashboard values |
| ASTRAL | Same source/observation availability contract | Cosmonautics has no registered adapter; absence stays explicit |

## Real source broker

`system.ascendancy.sources` provides four explicit, read-only adapters:
`sable.pose`, `avionics.flight`, `vehicle.inventory`, `combat.contacts`.
They read existing service caches, never probe peripherals, start collection
workers, publish messages or command actuators. Collection is explicit and bounded
to 16 source IDs. Existing permissions (`sable.read`, `avionics.read`, `combat.read`)
are checked before the service module/cache is read. A denied/missing/unready,
stale/future, cyclic, oversized or unserializable result has `available=false`,
a reason and no invented payload. An unregistered `astral.cosmonautics` source
returns that same explicit unavailable state, even if a mod might be installed.

Envelopes carry schema/type/source, local collection clock ID, actual observation
time, expiry, collection time, available state and known frame/units/namespace/
vessel/revision metadata. Reading again never renews an observation timestamp.
Payloads and declared units are defensively copied. The copy budget is bounded
in depth, items and text bytes; functions, userdata, metatables, cycles and
nonfinite numbers are refused. A whole collection envelope being available is
not proof that every contact/measurement inside it is fresh/calibrated: original
per-measurement validity, remote freshness and provenance remain in the payload.

Only source-known metadata is propagated. The Sable pose API's positions are
world blocks; no missing world/dimension namespace, heading frame, units or
identity is inferred. Consumers must resolve unknown context from real evidence
or an explicitly verified operator context before spatial fusion/planning.

## Observations, clocks and fusion compatibility

Observations require `schema=1`, `valid=true`, explicit `source/entityId/field`,
`origin` (`observed` or `derived` with parent provenance), `kind`, value and units
where applicable, `clock='local_uptime'`, a clock ID, observed time and expiry.
Position records require finite XYZ, `world` or `body_plot`, block units and a
vessel identity for body plots. Actual zeros are valid; absent coordinates are
never replaced with zeros. Synthetic data is refused.

The local clock ID binds a module/boot instance using computer identity,
available UTC epoch and an opaque instance token. It is an identity tag, not a
cryptographic attestation or a remote-clock conversion. Live observations from a
different boot/computer/domain cannot be treated as fresh. Persisted map records
retain their original clock IDs/time provenance and need not belong to the
current boot; they do not thereby become live observations.

`compatible(a,b,now)` validates both live records and requires the same explicit
world/dimension namespace, known frame, units, entity, field/kind, and matching
vessel ID for body plots. It does not average incompatible readings, transform
unknown body axes, invent confidence or attest a producer's honesty. Future
fusion policies must use real provenance and recheck individual observations.

## Persistent map and mission formats

ATLAS map packets require schema 1, type `atlas-map`, a namespace, world/block
coordinates and a dense list of at most 1,024 valid position observations. Body
plots cannot be saved as world positions without a real transform. Encoding and
decoding validate the schema and are capped at 65,536 serialized bytes. Corrupt
or missing data returns an error, not a fabricated empty map. Explicit empty
maps are representable. The future Atlas storage service must enforce filesystem
permissions and use existing safe-write/free-space checks; these pure format
functions do not write files or bypass permissions.

SYNAPSE mission packets require schema 1, type `waypoint-mission`, world/block
context, namespace, a vessel identity and matching verified waypoint route.
Validation delegates to the existing `navigation.autopilot.validate`, retaining
physical translation/braking verification and clear-route confirmation. Validation
is not authorization or execution: `flightd` still owns live sensor checks,
permissions, arming, actual outputs, STOP and rescue. No major mission planner or
executor is pretended to exist.

WARROOM `statusFor` reports ready/unavailable and known reason/age; unknown clock
age stays absent. ASTRAL can later add a real, permission-checked adapter only
after the actual Cosmonautics API, units, frames and freshness have been verified.
No placeholder orbital position, fuel, hull, orbit or launch command is provided.

## Automated validation

The contract suite uses clearly isolated test fixtures. It verifies permission
revocation before reads, actual cache timestamp preservation, defensive copies,
stale/future refusal, unregistered future adapters without fake values, cycle/
nonfinite/budget behavior, namespace/frame/unit/vessel/boot incompatibility,
persistent map roundtrip with historical provenance, and mission validation
without implicit physical verification or any actuator write. Source and packed
runs accompany the exact previous-release quota/checkpoint migration tests.
