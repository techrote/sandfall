---
title: SF-M3 — independent engineering review
status: Current
document-kind: audit
scope: Independent working-tree review, observed development evidence, and pending exact-head qualification
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../SF-M3-RAPIER-WORKSHOP.md, 2026-10-31-sf-m3-rapier-workshop.md]
---

# SF-M3 independent engineering review — 31 October 2026

## Review boundary and independence

This record covers source review and development evidence for the dedicated
`sf-m3/rapier-workshop-20261031` working tree over SF-M2
`32efe3142e557180b1777817f250f342b5b820de`. At this review checkpoint, HEAD is
still that base and the implementation is uncommitted. File digests below
identify the inspected changes; they are not a substitute for a final commit,
fresh binaries, or actual-browser results.

The workshop UI agent independently reviewed the registry, Rapier bridge,
simulation host, native restoration path, authored document and session
controller, which it did not implement. The root integration agent separately
reviewed the application, object controller, overlay and renderer, which the
workshop UI agent implemented. UI-agent inspection of its own code is treated
as self-review. The browser-harness author owns a separate measured-coordinate
and trusted-input review; its final evidence remains pending.

**Disposition at this checkpoint: changes require exact-head qualification.** The
native restore correction has passed source review and development reruns; no exact-head or actual
compatibility-Web acceptance is asserted here. The final integration boundary
is unconditional: **the SF-M3 PR must remain draft and unmerged**, including
after successful qualification. This review does not authorize changes to the
separately owned dependency PRs or their branches.

## Inspected source identities

The following SHA-256 values identify the latest inspected source, including
the narrow native restore correction. A later exact-head review must reconcile
changed files explicitly.

| File | SHA-256 |
|---|---|
| `godot/scripts/sandfall/rapier_object_registry.gd` | `3478006755032fae4f4b111b07e7f3b609d0f6485fe690b523ee622588104c8f` |
| `godot/scripts/rapier_physics_bridge.gd` | `0dd938dcd3ecedac4f7a89ec51f0d43c7c38a0afc581bc601f3997b32d4de043` |
| `godot/scripts/sandfall/simulation_host.gd` | `306ece1f325485a22f2a148af4fce558b85826ec9d4aa1a1cb389b861e211b1d` |
| `godot/scripts/sandfall/authoring_document.gd` | `33a752ab6246858da7ac2bb525b76342d1e7dffed5dd5f25c6430031c0d1074b` |
| `godot/scripts/sandfall/session_controller.gd` | `e32969c0af2085d1c39e90414186927f0bb2880d7ae65308d62b6e83eb968fdb` |
| `godot/scripts/sandfall/application.gd` | `d284d340338988fc02f6dedd5562aa2cbcd858c552b9eeeac74d149682d44b66` |
| `godot/scripts/sandfall/editor_controller.gd` | `ee4df9eaf59c4af2537176107397c48843006be035c232c0522fba6edc6896cb` |
| `godot/scripts/sandfall/editor_overlay.gd` | `e4c92c763a0217aa52e5d24ee4ab4f421e35f5dbfa5edf419ee08d71f8e80046` |
| `godot/scripts/sandfall/world_canvas.gd` | `fd66d2b0077923b36e374cfe76402714c9a183f4c3399cbe57d7fc65c5b59b8f` |
| `godot/tests/test_sandfall_objects.gd` | `be76e9caebc27baf446501af906b7215ea470eb4fa7be559415667beb8d528b0` |
| `godot/tests/test_sandfall_object_history.gd` | `53fea8bb82224162a9ee3c7b4eae1a198f87de690fc041515312ffd15c3d00ea` |
| `godot/tests/test_sandfall_object_input.gd` | `e4ad2efc1ae02a81e9706a86e0f7dd74e01e03892b76ef36479f7b07d27b07a5` |
| `native/include/cybersand/world.hpp` | `767615d9ff0e37c482d1127bb123ce6d66957dff1b094febc1486cd46f33ac8f` |
| `native/src/world_pressure.inc` | `b60823316d813bf712ace04a961bc83e3e00dff110da90b58905bbe9d242ba08` |
| `native/tests/test_world.cpp` | `ae7667e1e3ac2872db457c9ab513e063d017a126c8466a3ea36293a6fda21812` |
| `godot/native_extension/cyber_native_cell_world.hpp` | `0028be999b1a39d584670f8df3e51bab291b367545d7800ae20dc1ec07f614c7` |
| `godot/native_extension/cyber_native_cell_world.cpp` | `113d3eca82d975122cff4cf8733ce6d4c15d2e4ba73fd0ebed2b8d7702c8d23b` |
| `godot/native_extension/cyber_demo_bridge.hpp` | `822171492650882b14fbb36b11436a5d80bc938ad3c1e31ee3b9b3422113ff91` |

## Material findings and disposition

| Finding | Correction inspected | Verification and remaining limit |
|---|---|---|
| P1: restored bodies could report Ready without native occupancy, allowing material authoring through a body | A restore-only native candidate factory rebuilds the derived mask at the restored Rapier poses before Ready, preserving serialized activity | Independently reproduced; intermediate failures retained. Final fresh-native object suite and unchanged legacy600 now pass both occupancy and byte-exact physical restoration. Exact-head/Web reruns remain required. |
| P1: a Run no-op could mark Modified and journal a physical change | Host reports `changed=false`; session refuses `no_effect` without committing or journalling | Source inspected; mixed-history development suite verifies unchanged graph, status and journal. |
| P1: actual partial object mutation could retain Pristine or a stale accepted receipt | Partial outcome records actual counters/identity, marks Run Modified, enters Fault and retires input/history without claiming rollback | Source inspected; injected post-install failure and Rapier-only first-advance failure covered by the history suite. Fault injection is distinguished from ordinary physical workloads. |
| P1: an ID exposed by a partial spawn could be reallocated after recovery | Allocator advances on actual partial allocation | Source inspected and targeted history regression passed. |
| P2: IDs reconstructed independently of creation order could be reused after deletion | Installation reserves canonical `sf-box-N` suffixes as well as creation order; overflow is bounded | Source inspected; arbitrary ID/order mismatch, reset and exhausted-allocator graph/history invariance are covered. |
| P2: the 1→0→1 transition erased feedback diagnostics | Bridge stores diagnostics enablement separately from current diagnostic-array length | Source inspected; real feedback after zero-body reactivation is tested, not only array size. |
| P2: zero-body setup still invoked a physical Rapier capability probe | Empty scenes defer the probe; the first validated nonempty graph probes before construction | Source inspected; fresh physical suite passes no probe at zero and no probe for an over-capacity candidate refused from zero. |
| P2: accepted logical mass could be below the native parser's 0.001 minimum | Registry and inspector admit mass from 0.001; UI uses Godot/Rapier mass units | Bounds and mass source checks inspected. No SI calibration is claimed. |
| P2: metadata-only edits retired pending physical feedback | Host metadata fast path preserves RIDs, mask, sampling epoch, serials and pending results; session records metadata without a physical intervention | Source inspected; paired unchanged/metadata workloads compare physical state and the next actual feedback application. |
| P2: Edit's initial-body observer could describe an obsolete graph | Session stores a copied accepted zero-tick pose baseline after object edits and history | Source inspected; authored state and observed baseline are compared in the mixed-history suite. |
| P2: inspector rounding could overwrite an untouched vector component | Apply submits dirty fields and preserves untouched position/size/velocity components from exact owned values | Root independently reviewed the fix; genuine Godot input includes the paired-component precision regression. |

The inherited `PhysicsMaterial.absorbent` setting was investigated rather than
assumed to invert the new restitution property. The bridge explicitly installs
positive `BODY_PARAM_BOUNCE`. Actual Rapier drops with restitution 0 and 0.8
respectively settled and rebounded; the latter reached approximately −82.26
cells/s vertical velocity. This was not a remaining defect. Its ordinary drop
test was added to the physics suite.

## Narrow native restoration review

`World::save_physical_state()` serializes each activity block's `active`,
`quiet_ticks` and `next_interaction_tick` in
`native/src/world_pressure.inc`. Ordinary
`World::set_transient_obstacle()` and `clear_transient_obstacles()` call
`keep_cell_active()` and `wake_cell_neighborhood()` in `native/src/world.cpp`.
Those functions intentionally change activity when a live mask changes.
Applying them to a restored mask therefore changes the saved physical payload.

The original diagnostic retained both 6,312,388-byte payloads. It found three
changed scheduler bytes and the resulting 32-byte integrity digest change;
the error was not payload normalization or an arbitrary checksum discrepancy.
`restore-mask-payload-diff.json` retains the byte locations. The correct fix
must install derived occupancy on the restored candidate without waking saved
activity, while keeping pressure caches cold or invalidated and clearing old
body feedback. Ordinary live publication must retain wake behavior.

The inspected correction implements
`World::restore_physical_state_with_transient_obstacles()`, a factory available
only while constructing a fresh restored candidate. It validates mask geometry,
the one-million-cell capacity, exact payload length and bounded slot IDs before
restoration. It installs the derived field and occupied indices, clears
contacts and keeps pressure caches cold, without waking or rewriting saved
activity. A shared raster visitor preserves ordinary geometry and lowest-slot
overlap ownership. Native import strictly parses its optional packed body
records, preserves the old two-argument binding and installs current/previous
samples together after candidate acceptance. There is no new generic option
to suppress wakes during live coupling.

Host-level reconstruction already replaces Rapier state. Native-import or
terrain-readiness failures therefore enter Fault and return `partial=true`;
they do not claim that the previous whole host was atomically preserved.
Review also corrected a new test fixture before execution: the physical-state
hash includes transient masks, so hash equality requires the source fixture to
carry the same real mask before saving. Byte-for-byte payload equality remains
independent and unchanged. Fresh local C++/GDExtension runs now pass both
assertions, closing this development finding. Exact-head/Web validation remains
a separate required gate.

## Ownership and boundary conclusions

The registry validates complete graphs, sorted creation order, unique IDs,
finite ranges and the 16-body limit before installation. Project identity is
kept out of the float sampling ABI. Bridge arrays and the RID lookup share one
dense slot order; rebind advances its sampling fence beyond the accepted result
age, resets application tracking and removes retired mappings. The host clears
old native samples/occupancy, preserves unaffected RIDs and live motion,
detaches retired bodies before freeing them, and waits for terrain readiness.
An empty graph has no active Rapier bridge step while native ticks continue.
Fixed/frozen bodies use the supported freeze mode and skip physical feedback
corrections. These conclusions are source-specific and are supported by the
targeted physical development tests, subject to the restore finding above.

The document keeps copied logical object graphs and exact cell tuples in one
chronological stack. Prepared candidates have private ownership and a token;
public modifications cannot silently replace the committed graph. Object
history charges both canonical logical graphs against the shared 512-entry,
64 MiB limits. The Run journal charges both graphs and explicit-field payload
against 256 entries and 32 MiB. Admission precedes live mutation. Run locks
history at zero; either solver's first actual advancement retires it, including
a partial coupled failure. Reset & Edit establishes a fresh baseline.

Root's separate UI review confirmed sixteen bounded shader uniforms with an
explicit count, copied aligned IDs/poses/sizes, and matching rotation geometry.
Canvas GUI routing is separated from the inspector's stopping mouse filter.
Object gestures hold simulation, carry generation/input/revision leases and
submit one release transaction. All essential controls are clickable; Sandbox
exposes tools and Edit/Run and Tools visibility labels remain explicit. Root
also inspected the actual OpenGL screenshot showing sixteen distinct bodies.
That screenshot is desktop development evidence, not a Web rendering pass.

## Development evidence inspected

Receipts below are retained under `build/sf-m3-local/` in the development
artifact set. They must be uploaded or otherwise retained with the milestone
evidence; these local filenames are not assertions of CI artifact publication.
Stage manifests bind their source files and native/Rapier payloads.

| Receipt | Observed result | Scope |
|---|---|---|
| `physics-objects-first.json` | Negative: the zero-body Water fixture was already settled | Original test defect retained; corrected workload includes falling Sand. |
| `physics-objects-second.json` | 1,591 checks passed | Earlier physical graph, mapping, capacity and contact tests. |
| `physics-objects-review-fixes.json` | 1,767 checks; three restored-occupancy failures | New assertions correctly exposed incomplete restoration. |
| `physics-objects-restored-mask.json` | 1,767 checks passed | Intermediate native mask-field correction only. |
| `physics-legacy600-restored-mask.json` | Negative: native physical payload did not round-trip byte for byte | Must remain negative evidence; the legacy assertion is unchanged. |
| `physics-legacy600-first.json` / `physics-legacy600-review-fixes.json` | Earlier 600-tick oracle passed | Historical development candidates; they do not qualify the later native correction. |
| `physics-objects-final-review.json` | 1,779 checks passed | Final restore correction, true zero-body probe behavior and all targeted physical review regressions on the fresh native library. |
| `physics-legacy600-final-review.json` | Unchanged 600-tick oracle passed, including exact native payload restoration | 600 completed ticks, 106,717 contacts and 149 displacements. |
| `physics-validation-final-review.json` | Source hashes and local native test identities recorded | New restore factory, retained ACT-004 capacity and pressure exact-persistence tests passed; original negative artifacts remain listed. |
| `history-third.json` | 794 assertions passed | Mixed exact history, copy ownership, no-ops, partial failure, journal limits and first-tick retirement. |
| `history-identity-reserve.json` | 804 assertions passed | Adds reconstructed ID/order mismatch, reset and allocator exhaustion; stage hashes match the reviewed document/session/history sources. |
| `history-restored-state.json` | 804 assertions passed | Same history/session coverage on the final restore-corrected native library; source stage manifest retained. |
| `ui-object-input-third.json` | 34 checks passed | Genuine Godot input, object controls, gestures, staged inspector and capacity. |
| `ui-m2-input-regression-first.json` | 17 checks passed | Retained material-editor Godot input. |
| `ui-final-native-object-input.json` / `ui-final-native-material-input.json` | 34 and 17 checks passed, both processes exited 0 | Fresh restore-corrected library, current application/renderer/history sources; development execution only. |
| `ui-gl-first.json` / `ui-sixteen-first.png` | 31 checks passed and actual image inspected | Godot OpenGL compatibility renderer on llvmpipe; original blocked Xvfb attempt retained separately. |

The original fresh Linux native library was SHA-256
`eef74ae10e3a8f6207958ba8c49bfaeb42b405dd9c510b1f4e2340a69b2e74c3`.
The intermediate restored-mask library was
`5312a1bab26e3910cf10d73094a750b9b57a6db9b7c8e4c1554f8c86128edf54`.
Neither qualifies an implementation changed afterward. The development Rapier
Linux payload was
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`;
the Godot 4.7 executable was
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.

The final development UI/history reruns used the freshly built 4,311,496-byte
native library
`ca6a21d28a98e8fad2981b8909932dd6b88dcc032e8e21085d5c30605208e7ef`.
`ui-final-native-stage.json`, `ui-final-native-summary.json` and
`history-stage-restored-state.json` bind their actual staged source and runtime
bytes. During UI testing, only the separate, unexecuted physics test file gained
an additional zero-body refusal assertion; executed UI scripts and application
dependencies remained unchanged. This concurrency is recorded, not hidden by
claiming the entire working tree was frozen.

## Build and provenance gate review

The UI reviewer independently inspected the new M3 reconciler, focused native
runner, shell recipe and negative tests. The reconciler requires the exact
six-file before/after hashes and complete native patch digest
`96f0f6dcb3a9d7eb20d5f924cf378cfc87aadcacb367e42bb431aa84a9618917`,
the expected base tree/ancestry, no untracked or ignored native source,
unchanged inherited gates and unchanged runtime manifests/payloads/pins.
The original M0/M2 refusals remain intact. Its expected 20 checker errors and
18 materialized LFS payloads admit only a fresh build; no stale desktop runtime
is qualified by this classification. An independent recomputation matched the
six-file patch and all source checks.

Review identified that a plain `make` could reuse an existing local binary by
mtime without binding it to compiler options. The M3 runner now forces `make
-B`, retains compiler output, and checks source and runner hashes before and
after each command. It preserves the original twelve exact native filters and
success markers, and executes the new restore test separately with its exact
name/count. The M3 workflow invokes the new source/build runner and uploads its
M3 evidence paths; retained ordinary-browser/legacy execution remains separate.

| Reviewed gate file | SHA-256 |
|---|---|
| `tools/sandfall/sf_m3_reconcile.py` | `1d5f6488a404c76789ab262058b9bf2d784ddef4042666b0076798b69fb5c819` |
| `tools/sandfall/sf_m3_native_smoke.py` | `686dd040a49a937630c29e07f55e03a1f176dfc7ce9e70f338a1b48798be3b5a` |
| `tools/sandfall/sf_m3_ci.sh` | `b92f6afe93e1ddee9d5a329c6276db68b58bef5b7cb0604e75156adc036a67e4` |
| `tools/sandfall/test_sf_m3_reconcile.py` | `6aa01b42b9c78a7198a88f38eb4f695be77762366d56b7efc0cc6a5c0675fcbf` |

## Pending exact-head and browser disposition

Before final qualification, update this review or append an exact-head record
with the implementation commit/tree, reconciled dependency base, changed-file
digests, terminal Actions results and artifact identities. Reinspect the final
native restore implementation, then execute fresh native/GDExtension tests and
the unchanged 600-tick oracle with both immediate restored occupancy and exact
native payload equality preserved.

Both compatibility-Web profiles, 800×450/DPR 1 and 640×400/DPR 2, remain pending
here. Required evidence includes actual 0/1/3/8/16-body workloads, body-17 atomic
refusal, per-body sampling and feedback, body/body and material contact at
capacity, trusted create/select/move/inspector/delete input, lifecycle/history
regressions and decoded pixels within each body's world viewport interior.
Record native/Rapier WASM, PCK, export, browser and harness identities, served
byte verification, source-bound coordinate measurements, logs and screenshots.
Complete input before terminal capture. Preserve every original negative.

Threaded Web, alternate hosting, broad desktop platforms and human exhibition
acceptance are separate, unqualified levels. The internal logical object
representation can be reviewed as an SF-M4 input contract; it does not implement
the `.sandfall` ZIP codec or establish executable SF-M4 dependency readiness
before the remaining SF-M3 gates pass. Successful evidence never authorizes
merging or marking this PR ready for review.
