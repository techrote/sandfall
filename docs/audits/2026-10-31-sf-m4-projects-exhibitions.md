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

The latest project suite passes 464 checks, including three failures after two
real temporary bodies/shapes have been allocated. Their RIDs and shapes retire;
the active graph, native payload and document stay unchanged and still step.
It directly reads `PhysicsServer2D.space_is_active` and requires the private
manual space to be inactive for every capacity, including zero bodies. The
latest promotion suite passes 98 checks, including passive-subject transfer,
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

## Exact-head publication and independent review protocol

The branch-scoped `sf-m4-web.yml` is the milestone qualification lane. It uses
fresh native and Web builds, terminal full native/source jobs, dedicated Godot
tests, independent ZIP interchange, both compatibility browser profiles,
unchanged SF-M1/M2/M3 browser regressions and the unchanged legacy 600-tick
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
