---
title: SF-M3 — Dynamic Rapier workshop and stable object history
status: Current
document-kind: contract
scope: Implemented zero-to-sixteen object authoring and coupling; execution qualification is separately source-pinned
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SF-M2-AUTHORING-HISTORY.md, audits/2026-10-31-sf-m3-rapier-workshop.md]
---

# SF-M3 — Dynamic Rapier workshop

The [approved v1 specification](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md)
remains the product authority. This contract extends the existing SF-M2
document, session and Godot Control editor. It does not replace the native
solver, introduce an actor controller or implement portable project archives.
The [dated audit](audits/2026-10-31-sf-m3-rapier-workshop.md) separates source,
native/Godot, actual browser and platform evidence. **The SF-M3 pull request
must remain draft and unmerged.** Dependency integration is separately owned.

## Stable logical objects and supported units

`SandfallRapierObjectRegistry` owns copied version-1 logical box definitions.
Stable string IDs and positive creation-order integers identify objects.
Neither a Rapier RID nor a native sampling-array position is a project ID.
Canonical order is ascending creation order; duplicate IDs/orders and unknown
settings refuse. Existing live objects cannot change their creation order.
The application allocator never reissues an observed ID during its lifetime,
including after deletion, undo, reset or a partial failed spawn. Undo/redo and
reconstruction may restore the same existing logical identity.

Every graph is fully validated before physical mutation. Its maximum is **16
objects**, including any box marked as a passive subject. A passive subject is
metadata on the same uncontrolled box; it has no player or AI motor.

| Field | Accepted representation and bounds |
|---|---|
| Schema and shape | Version 1; `box` only |
| ID and name | ID: 1–64 ASCII letters/digits/underscore/hyphen; optional name: at most 128 characters, no NUL |
| Creation order | Unique positive integer, at most 2,147,483,647 |
| Position and dimensions | Native cell/Godot pixel coordinates; finite size 1–256 on each axis; entire rotated initial box within the 1024×1024 domain |
| Rotation | Radians, −2π through +2π; inspector uses degrees |
| Linear velocity | Cells per second; each component −4096 through +4096 |
| Angular velocity | Radians per second, −100 through +100; inspector uses degrees per second |
| Mass | Godot/Rapier mass units, 0.001 through 1,000,000; no SI calibration claim |
| Friction and restitution | Finite scalar, 0 through 1 |
| Linear/angular damping | Finite scalar, 0 through 100 |
| Gravity scale | Finite scalar, 0 through 4 |
| Fixed, frozen and passive subject | Strict Boolean values; fixed/frozen use the supported static freeze mode |

`logical_representation()` emits a copied `{schema_version, objects}` structure
with numeric two-element arrays for vectors. `reconstruct_logical()` performs
version/type/range/capacity validation before returning canonical definitions.
This internal representation is available to SF-M4. It is **not** a `.sandfall`
file, ZIP importer, trajectory save or physics-cache serialization.

## Physical ownership, coupling and retirement

`SandfallSimulationHost` remains the exclusive main-thread owner. At a safe
command boundary, `apply_object_graph()` validates the complete candidate and
the object revision/tick lease, allocates changed bodies before mutation and
preserves unaffected bodies' RIDs, evolved poses and velocities. A mass-only
change does not move an evolved body. Explicit Run pose/velocity fields are
applied even if their requested value equals the original logical definition.

Retirement clears prior native occupancy and samples, detaches old colliders,
rebinds the bounded ordered graph and frees retired nodes/RIDs. The bridge's
sampling-serial fence prevents feedback from the old dense slot assignment
being delivered to its new occupant. Required hard-terrain collider readiness
and zero-step occupancy publication complete before success. If a failure
occurs after actual installation, the host retains the real partial graph,
enters Fault and refuses further ticks; it does not claim rollback.

Packed native input retains the existing 11-float record and result ABI.
Sampling slots 1…N map explicitly to stable project IDs in the bridge/registry.
The native parser's existing 64-record envelope is unchanged; Sandfall admits
at most sixteen. The existing physics engine is retained. The narrow native
addition is a candidate-only `World::restore_physical_state_with_transient_obstacles`
factory, bounded to 1,048,576 cells. `CyberDemoBridge.import_physical_state`
accepts an optional packed-body argument while preserving its two-argument
binding. It uses the same box raster geometry as ordinary publication and
installs copied transient masks without changing saved cells, clock or scheduler.
Normal live mask updates retain their activity-wake behavior.

Tick order stays terrain readiness → eligible prior cellular feedback once →
one manual Rapier step → packed body samples/native occupancy → one native
tick → copied render publication, at fixed **1/60 second**. Zero objects is a
valid inactive graph: native materials continue, coupling is empty and Rapier
performs **zero additional steps**. Cumulative Rapier counters survive live
transitions through zero; a fresh Reset starts both counters at zero.
A fresh empty host also defers the behavioural Rapier capability probe, which
otherwise performs 24 isolated physics steps. The first fully validated
nonempty candidate requires that real probe before installation.

The render canvas consumes copied body transforms and dimensions through
sixteen bounded shader slots plus an explicit count. It draws independent
physical objects over native materials; object edits never paint permanent
material cells. Renderer receipt IDs/count must agree with the physical owner.

## One chronological authored history

`SandfallAuthoringDocument` stores both sparse exact material patches and exact
before/after object graphs in the same ordered stacks. A drag is one prepared
transaction. Object history preserves IDs, order, metadata, geometry, all
physics parameters and initial velocities. Public snapshots and prepared
payloads are copies; private candidates are compared again before commit.

The shared limits remain **512 entries and 64 MiB logical payload**. Material
transactions retain their existing index/before/after tuple accounting. Object
transactions charge the canonical UTF-8 logical JSON byte lengths of both
complete graphs. Allocation overhead is separate. A new edit drops redo only
after acceptance; refusal does not discard history. Capacity is checked before
the native or Rapier owner mutates.

Edit requires zero native and Rapier ticks. Run locks history immediately,
including while paused at tick zero. The first actual advancement of either
solver retires both stacks, including Rapier-only partial advancement. Pause,
pacing and Reset never resurrect them. **Reset & Edit** constructs a fresh
zero-tick baseline with empty history. Object undo reconstructs authored
physical definitions; it never reverses chemistry or Rapier solver caches.

## Run interventions and fault outcomes

Object commands share the existing bounded queue with material edits. There
can be one pending mutation across both domains. Admission checks mode,
generation, input epoch and document/object revision. Blur, modal entry,
session replacement and Fault retire queued commands and unfinished gestures.

Accepted physical Run changes make Modified sticky and append one intervention
record containing source identity, generation, tick, stable ID, before/after
logical graphs and explicitly requested fields. The unchanged journal limits
are **256 entries and 32 MiB logical payload**. Object journal cost includes
both graphs and the canonical explicit-field payload. Rejections and physical
no-ops leave the graph, Modified status and journal invariant.

Name/passive-subject metadata-only changes preserve RIDs, pending feedback,
sampling serials and physical state. They receive a bounded diagnostic entry
without consuming the physical intervention journal or marking Run Modified.
In Edit the same metadata remains part of exact chronological object history.

A real partial Run mutation enters Fault, reports `accepted=false, partial=true`
with actual solver counters and object identity, and reports the run as
Modified. It creates no fictitious successful intervention. The diagnostic
journal records the partial outcome. An ID already exposed by that partial
graph is retired from future allocation.

Reset reconstructs the frozen authored cell tuples and object definitions,
including initial velocities, with fresh masks/colliders and cleared feedback.
The retained internal physical snapshot path reconstructs transient body
occupancy after restore while preserving the saved native scheduler state.
It remains a regression interface, not full deterministic continuation or
the future portable codec.

## Workshop controls

Sandbox opens Edit with the tools visible. **Tools: shown / Tools: hidden**
states panel visibility; **Materials / Objects** selects the tool family.
Object tools are Box, Select, Move, Rotate and Resize. Selection handles provide
rotation and resizing; the stable-ID list, Duplicate, Delete and Clear are
clickable. A preview remains nonphysical until release.

The contextual right inspector has Shape, Physics and Motion pages. Numeric
values and metadata are staged until **Apply**, producing one transaction.
Only changed fields are submitted; changing one vector component preserves
the untouched component at full precision. Run inspectors use observed live
pose/velocity for unedited components. Inspector interaction cannot paint
through to the canvas. All essential operations have visible controls.

## Qualification gates

The dedicated `sf-m3-web.yml` workflow builds a fresh native extension and
compatibility Web export from its exact committed source. It runs the retained
native/Godot tests plus registry/physical, mixed-history and genuine Godot input
suites. Both 800×450/DPR1 and 640×400/DPR2 browser profiles run real workloads
for 0, 1, 3, 8 and 16 bodies and body-17 refusal. Retained SF-M2/SF-M1 browser
lanes and the unchanged legacy600 oracle run separately.

Browser acceptance requires real trusted events, source-bound measured
coordinates, logical and actual physical observations, per-body sampling and
feedback, body/body contacts at capacity, exact refusal/reset/history and
independently decoded pixels inside every body's world-space interior. Input
finishes before the terminal capture. Export identity, served bytes, harness
hashes, original negative results and screenshots are retained.

Threaded Web, alternate hosting, broad desktop and human exhibition acceptance
remain separate gates. Historical full-suite successes retain their source
identities. The separate SF-M3 admission gate pins the complete reviewed native
delta and retains the original M0/M2 refusals. Its exact 20 checker errors are
six missing companion references, eight inherited stale desktop inputs, two
SF-M2 registration inputs and four new World-restore inputs. No runtime manifest
is rewritten and no stale desktop binary is qualified. SF-M4 project files, presentation, Gallery
expansion, Golden Runs and intervention promotion remain out of scope.
