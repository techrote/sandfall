---
title: SF-M1 — Sandfall application host and input cut
status: Planned
document-kind: design
scope: Bounded next-milestone tasks and acceptance after SF-M0 executable qualification
canonical-for: []
last-reviewed: 2026-10-30
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, audits/2026-10-30-sf-m0-ordinary-web.md]
---

# SF-M1 — Sandfall application host and input cut

**Preparation only.** This plan decomposes SF-M1 from the
[approved Sandfall v1 specification](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#122-ordered-implementation-milestones).
That specification remains the architecture and product authority. This file
does not change its owner decisions, introduce a second architecture, or claim
that the new host has been implemented or qualified.

**PR #2 remains draft and unmerged under the owner hold.** A completed executable
SF-M0 checkpoint does not authorize marking it ready, merging it, or claiming
full v1 or exhibition acceptance.

## Authority and starting checkpoint

| Input | Exact identity and use |
|---|---|
| Frozen CyberSand ancestor | `1d376fb38ff5df83691e468baa0639270a5f40e6`; preserve the engine, ancestry, dependency pins and historical evidence |
| Frozen ancestor tree | `97eb0f4eeedde9bbe8b83047ca45c82d8a377d66` |
| Sandfall history-preserving import | `b48214da1935519002a6c4bfc6d7f465eb4a3eab`; its second parent is the frozen ancestor |
| Sandfall approved-spec main checkpoint | `34e9f9e30ebf9fde65565993f55dde571514ec93`; historical orientation, reverify current main |
| SF-M0 starting branch checkpoint | `5f937b91f396fa8b4cf2beceede1f86de3be9262` on `sf-m0/source-import-20261030`; this is not a promise of the next execution's HEAD |
| Existing compatibility-Web build | `6352756931c58e702eb5c15c05d44515091274b2`; retain its own source identity when reusing verified bytes |
| MZPaint and zero-player reference | specdocz `039008723172a951c7694079cd06c7a2ea137d40`; roles and adopted requirements remain as defined in the Sandfall specification |

At preparation time, the corrected local ordinary-browser check has exercised
the unchanged verified compatibility export successfully through genuine input
and visible world rendering. Publication and terminal checks at the final
SF-M0 branch head are still a prerequisite to implementation. The
[dated SF-M0 audit](audits/2026-10-30-sf-m0-ordinary-web.md) owns the detailed
PASS/FAIL ledger, artifact hashes and later disposition; this plan does not
promote a local result into an exact-head CI result.

Before starting implementation, freshly reconcile live main and development
heads, open PRs, competing owners, reviews, repository instructions, complete
SF-M0 terminal results and retained artifacts. Require the ordinary-Web gate to
be resolved: actual native/Rapier startup, genuine Continue input, at least 15
normal ticks and a nonblank actual-world screenshot region. Preserve the
600-tick coupled fixture, native-suite scope and all historical failures.

If source equivalence no longer holds, rebuild and requalify the affected
artifact. Keep the six missing companion-workspace references and eight stale
desktop digests explicit. Threaded Web, stale desktop execution and human
exhibition review retain their separate dispositions. A draft workflow skip is
not runtime evidence. SF-M1 implementation must not depend on merging PR #2.

## Bounded implementation tasks

Complete these dependency-ordered tasks as small reviewable changes. Proposed
new filenames are organizational suggestions; observable ownership and acceptance
are the contract.

### SF-M1-A — Dedicated scene and neutral host

Create a dedicated Sandfall Godot entry scene, for example
`godot/sandfall_main.tscn`, with Sandfall-specific host/UI scripts. Adapt the Web
staging entry selection in `tools/build_web.py` to export that scene. Keep the
inherited host available as a reference and for retained historical tests.

The new scene must not inherit `main.tscn` with its actor controller or derive
its host from `main.gd` / `web_demo_controller.gd`. Compose the retained native
world, immutable render publication and main-thread Rapier bridge through
neutral services. Extract only the camera/render/coordinate functionality
actually needed; avoid a broad rename or native-engine refactor.

**Accept when:** the exported application reaches the dedicated scene, exposes
native/Rapier readiness and source identity, displays real material output, and
contains no inherited player/controller node or player-specific autoload path.
Startup failure must remain visible and prevent advancement.

### SF-M1-B — Remove actor authority and define input ownership

Remove actor creation, player simulation, movement/jetpack/action ingestion,
actor-follow defaults and actor motor calls from the Sandfall host. A hidden
HUD or an unused key binding is insufficient. Preserve camera and application
controls; a key may control the camera only through that explicit authority.

Route pointer/keyboard input through the active canvas or UI owner. Consume
menu/modal interactions before world tools. On blur, visibility loss, modal
entry, release outside the canvas, reset or fault, clear held keys, pointer
buttons, pending gestures and any queued input belonging to the retired
session. Refocus must require a fresh gesture and must not replay a held action.

**Accept when:** source and runtime checks show no player motor or sampled-player
tick path; genuine browser legacy movement/action events cannot move an actor
or mutate world state through inherited controls. Camera actions still work.
Focus/modal/drag-release negatives produce no paint-through, stuck button,
repeated step or stale-session action. Use explicit state observations and
real browser events rather than a diagnostic setter.

### SF-M1-C — Gallery, Sandbox and initial Edit/Run ownership

Provide minimal Godot Control entry choices and a clearly visible mode/tick
indicator. Gallery selects a fixed initial scene, constructs materials and any
existing supported Rapier bodies, completes collider readiness, then enters Run
and autoplays. Sandbox opens a blank or selected initial template in Edit,
paused at tick zero. The initial scene definition and live run state must have
distinct owners even before the full SF-M2 authoring document is introduced.

Run freezes the selected initial revision for that session; it must not silently
continue mutating the editor's initial definition. Returning to an editable
baseline is an explicit Reset & Edit. No undo/history support is claimed in
SF-M1. Its mode handlers must leave no path that resurrects old Edit history
after any solver has advanced, including a partially failed coupled tick.

**Accept when:** repeated startup/readiness observations show zero native and
Rapier ticks in Sandbox/Edit, Gallery starts only after readiness, and Run,
Reset and Reset & Edit choose the documented state. A partial setup failure
cannot autoplay a half-installed scene. Both entries work through real UI input.

### SF-M1-D — Camera and bounded simulation lifecycle

Preserve the specification's
[fixed-tick sequencing and failure boundary](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#32-fixed-tick-sequencing-and-failure-boundary):
terrain readiness, eligible prior feedback, one manual Rapier step, body samples,
one native tick, then copied render publication. Keep the fixed step at 1/60 s.
This task adds no asynchronous Web solver or new body-capacity claim.

Expose camera pan/zoom, Run/Pause, exact Step, Reset and Reset & Edit through
clickable controls without requiring function keys, a numpad or PgUp/PgDn.
Step is a Run operation while paused; an Edit command must not secretly step
physics. Fault stops future advancement and clears pending input/step requests;
do not claim atomic rollback after one solver has already advanced.

**Accept when:** pause leaves both solver counts unchanged across normal browser
frames; one accepted Step adds exactly one native and one Rapier step; a held
or repeated key does not create unintended extra requests; camera-only changes
do not alter physics state. Reset reconstructs the source-defined initial
material payload and body poses at tick zero with cleared pending feedback,
masks and input, then follows the entry's readiness/start policy. Reset & Edit
always remains paused. Fault/refusal cases retain their actual outcome.

### SF-M1-E — Source-matched Web regression and review

Build a new compatibility export from the exact new host commit. A changed
Godot scene/script/PCK or build input requires new application export evidence;
the SF-M0 binary cannot demonstrate the replacement host. Record whether native
sources changed, and execute the corresponding native tests/build gates.

Retain the existing three-body 600-tick contact/displacement, pause, save/restore
and reset oracle. Add host-specific tests for actor absence, both entry modes,
input ownership, readiness, exact Step and reset/fault boundaries. Where the
legacy oracle depends on its old host, preserve that result and add an honest
new-host coupled test; do not silently weaken assertions while porting it.

Run the ordinary browser path with source-bound canvas/viewport geometry,
trusted real input observations and actual-world screenshot analysis. Exercise
the small viewport and a distinct aspect/DPR case to retain the SF-M0 coordinate
regression. No test may directly close the menu, increment ticks or set success.

**Accept when:** exact build/source and artifact hashes, browser/profile details,
machine-readable results, Chrome/HTTP logs, screenshots and negative cases are
retained; required tests finish with terminal results; an independent substantive
review checks the actual source and evidence. Record threaded and human visual
limitations separately. Do not mark PR #2 ready or merge it during this work.

## Scope boundaries and handoff

| Later milestone | Work deliberately left there |
|---|---|
| SF-M2 | Full MZPaint material tools, immutable authoring document, exact Edit transactions/history and complete first-tick history tests |
| SF-M3 | Generalized object registry, complete box editor/inspector and qualified 0–16 coupled bodies with overflow refusal |
| SF-M4 | Portable `.sandfall` ZIP-of-`project/` codec, staged import/export, expanded exhibitions, optional passive subject and intervention promotion |
| SF-M5 | Full compatibility/threaded matrix, chemistry/thermal history and refusal coverage, 16-body stress, Fluid Messenger and human presentation qualification |

The recommended next implementation task is **SF-M1-A and SF-M1-B as the first
bounded host/input change**, after the fresh SF-M0 prerequisite check. Record
its exact source and acceptance before expanding into the Gallery/Sandbox and
lifecycle tasks. The milestone handoff must distinguish implemented behavior,
executed tests and remaining gates; a new entry scene alone is not SF-M1
completion, and SF-M1 completion is not full v1 qualification.
