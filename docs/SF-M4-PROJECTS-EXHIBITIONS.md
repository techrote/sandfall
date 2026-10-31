---
title: SF-M4 — Project files and exhibitions
status: Current
document-kind: contract
scope: Portable initial projects, staged replacement, presentation, curated Gallery, run evidence and safe intervention promotion
canonical-for: [sandfall-project-lifecycle, sandfall-exhibitions, sandfall-initial-intervention-promotion]
last-reviewed: 2026-10-31
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SANDFALL-PROJECT-FORMAT.md, SF-M2-AUTHORING-HISTORY.md, SF-M3-RAPIER-WORKSHOP.md, audits/2026-10-31-sf-m4-projects-exhibitions.md]
---

# SF-M4 — Project files and exhibitions

The approved v1 specification §12 defines this milestone as the ordinary
`.sandfall` ZIP codec, transactional project load/save, presentation overlay,
curated Gallery, optional passive subject, Golden Run evidence and explicit
promotion of reconstructible interventions. This contract describes implemented
source. The [dated audit](audits/2026-10-31-sf-m4-projects-exhibitions.md) and its
exact-head PR evidence record own execution claims. SF-M5 retains broad platform,
threaded hosting, performance qualification and human exhibition acceptance.

## Ownership and dependency boundary

The dedicated branch is `sf-m4/projects-exhibitions-20261031`, based on verified
SF-M3 `0dd5d0606c92b37d3abbf6e252eae9977c1807bd` (tree
`c1663082f6c95303408df170688105a1641e4d4a`). SF-M0/M1/M2 were already merged when
this work began; `main` was `4a01a00d1f457576e1d911ef08c45b4c0aaf3347`. SF-M3 PR #5
remained draft/unmerged, so SF-M4 targets its development branch. This task does
not merge or mark either milestone ready, move dependency branches, or import
the unrelated moving CyberSand source.

| Owner | Responsibility |
|---|---|
| `archive_json.gd`, `archive_zip.gd`, `archive_codec.gd` | Bounded data-only parsing, strict schema, exact initial tuples, stable object definitions, logical hashes and ordinary ZIP interoperability |
| `authoring_document.gd` | Copied initial cells/objects/project metadata/presentation; shared chronological Edit history |
| `simulation_host.gd` | Authoritative native World, private `World2D` and Rapier RIDs; candidate construction and complete-owner adoption |
| `session_controller.gd` | Generation/input leases, frozen Save owner, transactional import, Run evidence and confirmed new-draft installation |
| `intervention_promotion.gd` | Pure declarative replay into a copied frozen initial definition |
| `presentation_model.gd`, `presentation_overlay.gd` | Bounded non-physical labels/strokes/themes and passive-subject marking |
| `gallery.gd`, `scene_definitions.gd` | Searchable curated definitions and declared physical outcomes; no scripted actor steering |
| `application.gd`, `browser_file_bridge.gd` | Godot Control workflows and bounded browser file selection/download integration |

Native engine source and the packed coupling ABI are unchanged by SF-M4. The
six-file native restoration correction already reviewed in SF-M3 still requires
fresh native/Web builds. Historical desktop LFS payloads do not qualify that
source. The legacy entry and its 600-tick oracle remain explicit regressions.

## Portable project workflow

**Save authored project** exports the current Edit draft. During Run the label
changes to **Save frozen initial**, and the locked document remains the source
even after native chemistry, body motion or accepted interventions. The archive
contains no undo/redo, native continuation, transient occupancy, pending
feedback, contact caches or reconstructed physics history. **Run evidence**
exports a separate JSON artifact.

**Open project** opens the browser/native file picker, stages a candidate and
shows its identity before **Open Project** confirmation. Generation/input leases
retire stale selection callbacks and confirmations. Cancel, blur, navigation,
modal entry and scene replacement retire drawing gestures. Inspector/modal
Controls consume input rather than forwarding it to material painting.

The [format reference](SANDFALL-PROJECT-FORMAT.md) owns every path, field, unit,
hash and refusal. The default format is one `project/` directory, readable JSON
and exactly 5,242,880 row-major cell bytes: material/u8, state_a/u8, state_b/u8,
temperature/i16 little-endian. Stable logical object definitions use the SF-M3
schema and 16-body cap. The format fixes 60 Hz, the current supported native
policy, authored interest independent of camera, and seed 0 as the reserved
non-procedural baseline. Nonzero seeds and arbitrary runtime triggers refuse;
no unused field pretends to control the native solver.

All central/local ZIP metadata is checked before decompression. Limits are
256 entries, 128 MiB expanded, 16 MiB per PNG, 1 MiB per JSON/README, bounded PNG
dimensions and canonical relative paths. STORE and raw ZIP DEFLATE are supported.
ZIP64, encryption, links, scripts, external URLs, alternate filenames and
unsupported policy/schema/settings refuse. The fixed highly compressible Empty
world has a documented 1100:1 compression ceiling; other entries use 200:1.
Every file has SHA-256 integrity and exact inventory checks. JSON parsing rejects
duplicate keys, excessive nesting, malformed UTF-8 and nonfinite values.

## Transactional reconstruction and physical lifetime

`stage_project()` creates a second native World and a private SubViewport
`World2D`, constructs its object graph, initializes manual Rapier ownership and
finishes terrain readiness without advancing either solver. The old scene stays
fully owned and unchanged during this work. Copied document allocation and
exact initial material projection verification precede the commit.

`commit_staged_project()` retires the old graph only after those checks. It
adopts the complete candidate viewport, native owner, Rapier bridge, RIDs,
colliders, registry and copied publication state. The candidate remains as one
inert container with its solver references relinquished; its physical subtree
stays continuously attached. Reparenting that subtree would detach/rebind Rapier
bodies and lose actual initial velocities in the pinned backend. Shutdown frees
the owned viewport and then the old container, with bounded depth across repeated
imports. It does not rebuild candidate bodies in the old shared space. Failed candidate setup frees only candidate
resources. No claimed rollback hides a partial live mutation; unexpected partial
effects still enter the existing Fault boundary with actual counters.

Zero-body imports have no Rapier steps. Stable IDs and sampling slots retain
their existing separation. Imported 1/3/8/16-body graphs reconstruct initial
positions, velocities and all supported physics properties. Deletion/resize and
Reset retain the SF-M3 feedback/collider fences. Body 17 refuses before scene or
document replacement.

Replacing a Run body preserves every unrequested live pose/velocity component
through later scene-tree frames. The host installs the retained transform in
both the new node cache and PhysicsServer2D before publishing occupancy; a
deferred node notification cannot restore the authored pose. The inherited
internal physical-restore fixture uses the same installer. Old RIDs/shapes
retire, unrelated bodies remain owned, and Reset still uses frozen initial
definitions. This internal fixture is separate from portable projects.

Sandfall body damping now uses Godot's **REPLACE** mode: the authored coefficient
is the total damping, including a genuine zero. Development Gallery tests found
that the inherited combined mode silently added project-default damping. This
correction is confined to the Sandfall host and requires fresh workshop
regressions; legacy body construction is unchanged. Physics Pit explicitly
authors its previous effective totals, 0.25 linear and 1.35 angular. A pinned
runtime probe verified those equal the former 0.15/0.35 body coefficients plus
Godot's 0.1/1.0 defaults. The unchanged 600-tick Sandfall fixture passes after
that narrow recipe migration; new zero-damping definitions remain truly zero.

## Presentation and optional passive subject

Choose **Presentation** beside Materials/Objects for non-physical labels,
strokes, palette themes and visibility. The model admits 128 annotations,
4096 total points, 256 points per stroke, bounded text and RGBA colours. It
cannot write native material IDs, temperatures, object transforms or impulses.
PNG assets are data-only project resources, never executable Godot resources.

Edit presentation changes join the same 512-entry/64 MiB history as cells and
objects. Before/after canonical logical presentation bytes count against its
capacity. Run locks history at tick zero; the first solver advancement retires
all domains, including partial failure. Run presentation is temporary viewing
state, does not mark Modified, and does not replace the frozen Save definition.

A project may distinguish one optional passive subject. Assigning that role
transfers it within one exact object transaction. Duplicating its physical box
creates an ordinary box and preserves the original designation. Deletion and
undo synchronize the scene's subject reference. The subject uses real Rapier
physics and a visual marker, with no actor motor or hidden scripted steering.
The marker encloses the actual rotated, projected body with an exterior gap;
its label remains above that extent so decoration cannot hide the physical box.

## Curated Gallery and run evidence

The searchable Gallery adds Gravity Cascade, Fluid Messenger, Passive Subject
Ride, Endless Kinetic Loop, Intervention, Time Controls and Sandfall 16-Body.
Each is a copied initial definition. Readiness precedes autoplay; Reset restores
the same initial definition. The loop uses undamped, zero-gravity physical
rotors with fixed initial angular velocity, not per-frame pose animation.

Fluid Messenger and Passive Subject Ride place an uncontrolled zero-gravity
body in native Water. Tests require actual native feedback and motion; the
matching no-Water control remains stationary. Sixteen-body scenes require real
sampling, body/body contact and native feedback, not only array length.
Passive Subject Ride has a hard-material ceiling joined to its basin walls so
the rising subject stays physically contained inside the initial view. Tests
track its full rotated extents through 1,200 ticks; no scripted pose or camera
change substitutes for that enclosure.

`run_evidence()` records the exact eight-field source/runtime identity,
canonical authored logical/physical digests, initial material digest and body
definitions, fixed dt, interest/seed policy, actual tick counters/body poses,
native feedback and contacts, absent actor-control trace, ordered interventions
and bounded accepted/refused diagnostic events. Event eviction is explicit;
the receipt does not claim a complete trace when records were dropped.

A pristine evidence export is a candidate Golden Run record. Repeated local
outcomes, browser/profile outcomes and human exhibition acceptance are separate
claims. Source/native/Rapier identities accompany each actual result. No
bitwise whole-stack replay, arbitrary continuation, cross-browser identity or
human approval is implied by generating JSON or a screenshot.

## Apply interventions to a new draft

The command starts from the **frozen initial** tuples and object definitions.
It replays explicit pencil/erase/line/rectangle/selection-erase tuples and
stable-ID object spawn/duplicate/delete/property commands in journal order.
Complete admitted material footprints are retained, including cells already
equal in the live world. Both changed and complete-command tuple/index payloads
count against the existing 256-entry/32 MiB intervention limit before mutation.

Runtime-dependent flood/selection copy/move commands and unknown commands are
excluded with explicit reasons. Missing IDs, unsupported values or conflicting
object graphs block the candidate. Preview reports eligible/excluded operations,
initial cell/object changes and candidate digest. **Create new Edit draft** is
required; cancellation, epoch change, additional interventions or further ticks
retire the preview token. Confirmation uses the same staged import path, creates
a new paused tick-zero Edit generation and empty history, and preserves stable
IDs and initial velocities. It never copies evolved cells, heat, body velocity,
solver caches or an old physical snapshot. The new Run may behave differently.

## Qualification gate

The branch-scoped SF-M4 workflow builds fresh native, Godot and compatibility-Web
artifacts from the tested commit. It runs the full native suite, retained
SF-M1/M2/M3 and legacy tests, new archive/import/promotion/presentation/Gallery
tests, independent Python ZIP interchange, both ordinary browser profiles and
actual project-file workloads for 0/1/3/8/16 plus 17-body refusal. Genuine CDP
input uses source-bound settled Control geometry, trusted DOM delivery and
actual viewport pixels. Upload/download bytes and every portable file digest
are independently checked. Each upload's current trusted file-change event is
bound to a fresh event-index range and exact filename/size. Separate terminal
capture jobs cover every Gallery entry in both profiles, while the complete
Gallery navigation workloads remain intact. No further input follows the start
of a screenshot capture, as required by the inherited browser contract.
All rotated body corners must be inside the measured world viewport before the
unchanged strict body-colour pixel oracle runs. Mass-only Run edits are checked
again after fresh idle frames. The retained SF-M2 occupied-cell refusal uses a
real Zoom In operation to guarantee the same cell has an interior integer CSS
mouse coordinate; its mapper and physical/history assertions remain strict.
Native Godot tests sharing the Web staging directory ignore the embedded
Web-only identity; measured native custody and compatibility-Web identities
remain separate.

Malformed DEFLATE can make Godot's own bounded decompressor emit the precise
`Decompression failed.` diagnostic before returning refusal. That original
diagnostic is retained. Tests admit it only inside a hash-bound, named negative
case with the expected refusal and unchanged retained state; additional,
unmatched or script errors remain failures. This is not a general error allowlist.

Threaded Web, alternate hosting, broad desktop release qualification and human
Gallery legibility/pacing remain SF-M5 or separately authorized evidence. The
draft SF-M4 PR is not a full-v1 release declaration.
