---
title: SF-M4 projects and exhibitions — implementation and qualification audit
status: Current
document-kind: audit
scope: Fresh dependency reconciliation, implemented SF-M4 source, development negatives and exact-head evidence ledger
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../SF-M4-PROJECTS-EXHIBITIONS.md, ../SANDFALL-PROJECT-FORMAT.md, ../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md]
---

# SF-M4 implementation and qualification — 31 October 2026

## Fresh dependency reconciliation

Live GitHub state selected `sf-m4/projects-exhibitions-20261031` from SF-M3
`0dd5d0606c92b37d3abbf6e252eae9977c1807bd`, tree
`c1663082f6c95303408df170688105a1641e4d4a`. PR #5 was open, draft and unmerged,
with exact-head engineering COMMENT review `5721877922`. Its complete dedicated
run `41180156260` had ten successful jobs. Its generic Documentation/provenance
run `41180159023` remained failed; generic Native/GDExtension/Water draft checks
were skipped. Those are dependency results, not newly executed SF-M4 checks.

`main` was `4a01a00d1f457576e1d911ef08c45b4c0aaf3347`, tree
`614f0c59efb410c2054606270f402ee71d9c68a6`. The separately authorized dependency
owner had merged PR #2 at 08:01:44 UTC (`b9c2a295…`), PR #3 at 08:02:18 UTC
(`757a87fb…`) and PR #4 at 08:02:41 UTC (`1acc1874…`). The final main change was
an AGENTS hold reconciliation. SF-M3 remained outside main, so an SF-M4 PR
against its verified development branch isolates this milestone's review diff.
No dependency ref is moved by this task. Frozen CyberSand ancestor
`1d376fb38ff5df83691e468baa0639270a5f40e6`, tree
`97eb0f4eeedde9bbe8b83047ca45c82d8a377d66`, remains unchanged.

The first checkout needed recovery from a restricted-network LFS smudge
failure. It was a fresh, unmodified task checkout, restored at the exact chosen
head with smudge deferred, followed by an explicit LFS fetch/checkout. Eighteen
actual runtime payloads were materialized. Original download/permission errors
are retained; no pointer is called an executable runtime. The task has one
independent worktree and no competing SF-M4 branch/PR at the initial audit.

## Source and ownership changes

The [milestone contract](../SF-M4-PROJECTS-EXHIBITIONS.md) and
[format reference](../SANDFALL-PROJECT-FORMAT.md) describe the concrete source
interfaces, bounded format, staged replacement, same-document presentation
history, curated physics scenes, distinct run evidence and confirmed
declarative promotion. Native C++ and GDExtension interfaces are unchanged from
the reviewed SF-M3 restoration implementation. Rapier remains main-thread owned
with fixed 1/60-second steps and unchanged packed coupling ABI.

Candidate project setup now has a private `World2D`/SubViewport. All material,
body, collider/readiness and copied-document validation precedes old-owner
retirement. Actual candidate failures and repeat setup/discard tests check old
native payload, RIDs, authored data, mode, epochs and counters. Damping uses an
explicit total coefficient in the Sandfall host; the inherited legacy
construction remains unchanged and its physical oracle is still required.

## Development evidence, not final-commit qualification

A freshly compiled local Linux extension has SHA-256
`3ee1edd373c40a6299aecb66598fda9055d0bb1788355d97d033f716650722cc`,
4,311,496 bytes. Inputs used pinned Godot
`4.7.stable.official.5b4e0cb0f`, godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1. Development staging
records exact script hashes and dirty source paths separately from the final
commit. Original desktop payloads did not provide accepted native tests.

The first project integration pass completed 421 assertions over the capacity
matrix, frozen Save/evidence and atomic malformed/readiness refusal. The first
promotion integration pass completed 84 assertions over mixed presentation,
object and thermal tuples, capacity accounting, preview cancellation and exact
new-draft reconstruction. Retained session and 1,779-assertion object suites
passed after physics-space isolation; the later damping correction requires
their own rerun. These counts identify those particular development passes.

The codec pass initially reached 161 checks/81 negative cases, then added
malformed DEFLATE cases and strict external ZIP interchange. Earlier failures
for internal StringName keys, JSON integer/float normalization and externally
corrupted CRC streams remain in development logs. Fixes preserve strict
external JSON/string keys, canonical integer dimensions and full hostile-input
coverage. Godot's expected decompression diagnostic is retained and bound to
specific refused negative fixtures; unrelated errors are still failures.

Independent Python `zipfile` reads the emitted 0/1/3/8/16-body archives, verifies
inventory/digests and re-encodes edited folders for Godot to import. The first
interchange suite passed 78 assertions over five edited capacity archives and
fourteen hostile cases. Its original error-bearing CRC log is preserved.

The first Gallery 600-tick matrix found exactly three failures in the intended
undamped loop: Godot combined body damping with its hidden world default.
Replacing the damping mode with explicit authored totals corrected the cause.
The next 106-check matrix passed seven 600/600-tick scenes and a 600-tick
no-Water causal control. Further repeated-run results are recorded with their
exact artifacts; no bitwise trajectory claim follows from those outcomes.
Presentation model checks and actual Godot Control project input passed their
development fixtures. Actual browser input/pixels remain a separate gate.

Other original environmental negatives include the download redirect's HTTP
403 (the pinned GitHub release mirror passed its checksum), restricted local
engine socket initialization, and the first editor import's socket errors.
Authorized isolated runtime execution and task-owned XDG paths resolved the
environment without changing source assertions.

### Reviewed development closure before publication

The final local codec pass has 184 checks and 93 negative cases. Independent
review found an ambiguous empty DEFLATE result and an oversized JSON exponent
conversion; both original false-acceptance probes are retained. Empty-file
admission now checks supported stream encodings before inflation, and exponent
digits are bounded before integer conversion. The strict diagnostic validator
also requires an explicit successful terminal verdict.

At first publication the project suite passed 464 checks, including three failures after two
real temporary bodies/shapes have been allocated. Their RIDs and shapes retire;
the active graph, native payload and document stay unchanged and still step.
It directly reads `PhysicsServer2D.space_is_active` and requires the private
manual space to be inactive for every capacity, including zero bodies. The
then-current promotion suite passed 98 checks, including passive-subject transfer,
copied source provenance and a paint-then-erase cancellation whose final diff
must be empty. External Python ZIP interchange now passes 83 checks and verifies
the exact initial five-byte tuple digest for all five positive capacities.

The repeated Gallery suite passes 189 checks over 15 runs and 9,000 actual
coupled ticks: seven scenes twice and the no-Water causal control. Presentation
passes 18 checks and native Control project input passes 39. These remain local
working-source outcomes, not final-commit Web claims.

The first retained Sandfall Physics Pit rerun after the damping-mode correction
failed its unchanged final-height assertion because its old combined damping
had also been removed. A real pinned-runtime probe measured Godot defaults
0.1 linear / 1.0 angular and identical direct-body-state totals for
COMBINE(0.15, 0.35) and REPLACE(0.25, 1.35). Only Physics Pit's authored recipe
was migrated to those explicit totals. Its unchanged 600/600-tick regression
then passed: first-body centre Y 159.00065612793, maximum Y 160.317276000977,
106,717 contacts, 149 displaced cells, and legacy physical save/restore passed.
Both failed and passing logs remain retained. The other six retained local
Sandfall suites passed, including the 1,779-check object suite and material,
object-history, session and ordinary Control input regressions.

The [independent source review](2026-10-31-sf-m4-independent-review.md) records
cross-author ownership, findings and the exact-head evidence still required.
The initial strict source reconciler also refused a 52,428,800-byte temporary
partial LFS download left by the failed smudge. That exact file and its SHA-256
were quarantined as negative evidence; the unchanged gate then passed with all
18 real runtime payloads. No arbitrary unknown runtime exclusion was added.

### First published head and subsequent review corrections

Draft PR #6 opened against unchanged SF-M3 at implementation head
`838db02a7b1b6ade87973cef0b6ae76b4c1488cd`, tree
`997540b5a56cc16b5eea276f153f610ce6274e52`. Its first dedicated 22-job Actions run
is `41196390818`; that run and its original artifacts remain part of the record.

Exact-head independent review found that a promotion's detailed object preview
serialized the live journal's complete row rather than the actual frozen-state
replay result. A Run-only name/subject change followed by a mass intervention
therefore described metadata that the correctly reconstructed candidate did not
contain. A real five-tick session reproduces the discrepancy at the first head:
116 assertions, one failure. The narrow fix serializes the actual replayed row;
the same 116-check suite passes, including preview/candidate/confirmed-draft
equality. Both original and corrected logs are retained.

Browser review also tightened each upload's trusted change proof to its own
fresh event range and exact filename/size. A prior equal-sized upload can no
longer satisfy a later attempt's proof; explicit negative tests cover stale,
absent, duplicate, untrusted and wrong-file events. Fourteen isolated Gallery
terminal-capture jobs supplement the two unchanged full navigation workloads,
giving 36 jobs in the expanded lane. Each scene/profile completes its real
physics and evidence/input work before its one terminal PNG; no later input
follows capture. These corrections require a fresh source-matched qualification
head; the first run is not relabelled as testing them.

A second independent exact-head probe found an actual import defect missed by
logical-definition equality: reparenting the staged SubViewport detached its
CollisionObject2D bodies from the Rapier space and reset nonzero velocities.
The original body changed from `(12, -7)` linear and `1.5` angular velocity to
zero at adoption. A full pinned-runtime probe found the other initial backend
properties, shapes, RIDs and space unchanged. Synchronizing node velocity caches
alone was tried and failed; that original failure is retained too. Pinned Godot
source confirms that tree exit calls `body_set_space(rid, RID())` and tree entry
rebinds the body.

The correction retains the staged physical subtree continuously in place,
using its emptied candidate node as one inert ownership container. All solver
references transfer to the live host; shutdown retires the viewport and then
the prior container. The expanded project suite passes 531 checks: actual
initial backend velocities at every nonzero capacity, complete initial backend
property/RID/shape/space equality, first-step analytic motion with no damping or
gravity, fixed/frozen stability, and repeated imports/reset with constant holder
depth and retired old holders, plus a real ZIP-imported autoplay Run with history
locked at zero and the same nonzero first-step motion. An independent full-parameter probe passes on
the corrected source. The first test trial also corrected its sampling
observation: `pack_body_states()` deliberately consumes a serial, so the
ownership assertion now reads copied coupling caches without consuming samples.

Actual-browser project fixtures now author nonzero linear/angular velocities
through the visible inspector and compare actual backend poses/velocities after
original import, external JSON editing, promotion and final reimport. Logical
JSON preservation alone cannot qualify this correction. Fresh final-head build
and browser execution remain mandatory.

The first published run completed fresh native/Web exports, the full 165-test
native C++ target, all dedicated Godot tests, independent ZIP interchange, both
SF-M1/M2 ordinary-browser profiles and the unchanged legacy 600-tick browser
oracle successfully. These are exact `838db02` results and do not cover the
subsequent corrections above. The new project/Gallery browser cases failed and
their original logs, receipts and archives are retained. Exact comparisons
exposed observer JSON rounding: a project position was
`239.92532348632812` in the full-precision archive versus `239.925323486328`
in the observer; a Gallery pose showed the same transport discrepancy. The
shared read-only observer now emits full-precision JSON, matching project and
evidence serialization without weakening equality assertions. The zero-body
workload progressed through real import, external JSON editing, frozen Save,
rejection and interventions, then exposed a missing expected-command argument
in its paint-intervention assertion. The harness now explicitly requires
`pencil_stroke` and retains its exact one-cell check. Both fixes require another
actual-browser run from the corrected commit.

Further qualification review at `b2720d359b5b7dddc4fdfbede2f49c13b3fbca0d`
found that native Godot tests sharing a Web export staging directory could merge
the Web-only `sandfall_build_identity.json` into native application provenance.
The independently measured native binary/source records remained correct, but
the application could incorrectly label its native Run receipts with Web WASM
hashes. A real native Control regression preserves this original failure: two
identity assertions fail when a valid Web identity file is present. The loader
now merges that file only on the Web platform; native keeps its existing
native/local provenance. The corrected 43-check Control suite passes and
restores the original Web identity file byte-for-byte. Actual Web execution
continues to require the measured embedded Web identity. This provenance fix
also requires a newly committed source-matched qualification run.

The `b2720d3` browser run also preserved a failure in the retained SF-M2 DPR-2
workload after 70 passing checks. The paused body's requested occupied cell
`[124,135]` had no strict interior integer CSS mouse coordinate at the measured
479-pixel / 480-cell scale. The exact mapper correctly refused before sending
input. This is repaired with one genuine visible Zoom In operation before the
dynamic occupied-cell probe, with paused physical state and simulation-interest
invariance asserted. The same exact occupied-cell refusal and all prior history,
chemistry/input assertions remain; the mapper and its strict interior bounds
are unchanged. This is an explicit, bounded targeting repair to the SF-M2
harness, not a new product default or relaxed acceptance oracle. The original
600-tick legacy oracle and SF-M1/M3 harnesses remain unchanged.

A separate read-only local Linux probe of the exact `b2720d3` ordinary
application completed 1,200 coupled Endless Kinetic Loop ticks with 1,144
checks. At ticks 120, 300, 600 and 1,200, counts stayed at 353 Godot nodes,
3,199 objects, 43 resources and zero orphan nodes; three project bodies/shapes,
257 terrain body RIDs (14 carrying shapes), and 16 terrain shapes remained
unchanged. All sampled IDs/RIDs stayed stable, body centres drifted zero and
angular velocities remained `[1, -1, 1]`. The probe rehashed all 422 staged
source files and retained its exact native/Rapier/probe identities. Static
allocation rose 85,096 bytes including retained probe records, so this is a
bounded resource-count result, not a constant-total-heap or performance claim.
Its initial missing-class-registry startup failure and import repair are kept
as separate instrumentation evidence. Browser and final-head results remain
separate gates.

Run `41197945514` finished with 34 of 36 jobs successful. Fresh native/Web
builds, the 165-test full native target, all ten project-file browser jobs,
both full Gallery navigation workloads, retained SF-M3 capacity workloads and
the unchanged legacy oracle passed their then-current checks. The two job
failures were the SF-M2 CSS-cell precondition above and Fluid Messenger at
800×450: its fixed-radius passive marker crossed the red body interior,
leaving only 70 of 90 required body-colour samples. The marker now encloses the
actual rotated, projected body corners with an exterior gap; its label sits
above that extent. The strict 0.8 body-colour threshold is unchanged.

Independent inspection also found defects in artifacts whose old job checks
were green. All eight nonzero project cases showed a mass-only intervention
restoring the body's authored pose on the next idle frame. A newly attached
CollisionObject2D retained its initial node transform while the host had only
written the evolved pose into PhysicsServer2D; the deferred node notification
then overwrote the backend. Native occupancy still described the evolved pose,
making the discrepancy physical, not cosmetic. The host now synchronizes the
node transform before installing the backend state. The same correction is
used by the internal physical-restore path, where an independent probe found
the same issue. Original moving and sleeping restore probes, failures and
corrected results are retained. The expanded 931-check project suite covers
mass/material-parameter/size changes across four idle frames, retained poses
and velocities, retired RIDs/shapes, unchanged unrelated bodies, native
occupancy, next-step continuity, explicit transforms, exact internal native
payload restoration and Reset & Edit. Browser cases now require the evolved
pose/velocity of every body to survive a mass-only Apply and three later frames.

Both Passive Subject Ride terminal images also showed a partly clipped subject
after the original 600-tick cutoff, despite enough remaining body-core pixels
to pass. A real hard-material ceiling now joins that scene's basin walls;
there is no motor or scripted pose correction. Every M4 terminal capture now
requires all rotated body corners inside the measured world viewport before
the existing pixel oracle runs. Applying that new oracle to the 26 retained
M4 captures accepts 24 and rejects exactly those two original Ride images.
These independently discovered defects prevent treating the prior green job
receipts as completed milestone acceptance. All corrections require the next
exact-head build and browser matrix.

The first local attempt at the added per-tick Ride containment assertion
reported three failures because its measuring helper passed a logical size
array to Godot's `Vector2` constructor. The script diagnostics and original
failed result are retained. The helper now reads the two numeric components
explicitly, with the same geometric bounds. A partial subsequent full run was
stopped in favour of the focused 1,200-tick trajectory check; it is not a pass.
The complete revised 203-check, 16-run Gallery suite remains an exact-head CI
gate. Independent review also tightened the mass-only browser oracle: only the
selected body's transition from sleeping to awake may differ, while every
unrelated body's sleeping state remains exact.

## Exact-head publication and independent review protocol

The branch-scoped `sf-m4-web.yml` is the milestone qualification lane. It uses
fresh native and Web builds, terminal full native/source jobs, dedicated Godot
tests, independent ZIP interchange, both compatibility browser profiles,
retained SF-M1/M2/M3 browser regressions (with the documented genuine-zoom
targeting repair in SF-M2) and the unchanged legacy 600-tick
physical oracle. Build/PCK/runtime/harness hashes and all original negative
outputs are retained. Source-scoped review checks staged ownership, archive
parser/lifecycle, copied-data history, promotion, genuine browser inputs,
pixel assertions and provenance separately.

**This committed checkpoint does not claim an as-yet-unexecuted final-head CI
result.** The final draft PR description and an exact-head COMMENT review append
the terminal source SHA/tree, base, Actions jobs, artifact hashes, actual browser
receipts, independent findings/fixes and remaining gaps. Keeping that terminal
ledger on the unchanged tested commit avoids a documentation-only commit that
would otherwise create a new untested claimed head. Material source corrections
must be committed and their affected gates executed again. Original failed runs
remain addressable rather than replaced by the final green record.

## Preserved limitations and downstream readiness

The unchanged strict SF-M3 reconciler admits only the already-reviewed native
patch and exact historical provenance discrepancy set for a fresh build.
The generic Documentation/provenance checker is not rewritten to hide its six
missing companion-workspace references and stale historical desktop inputs.
Fresh CI Linux/Godot and compatibility-Web results do not re-attest those old
desktop binaries. The archive only supports declared data/policies/assets;
unsupported procedural seeds, event programs and executable resources refuse.

Threaded Web, alternate/unisolated hosting, broad desktop release certification,
cross-platform bitwise replay and human exhibition legibility/pacing are not
established by this milestone. SF-M5 owns the remaining release matrix. Both
SF-M3 and SF-M4 remain draft and unmerged. No result authorizes changing that
integration boundary.
