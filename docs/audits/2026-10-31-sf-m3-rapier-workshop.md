---
title: SF-M3 Rapier workshop — implementation and qualification audit
status: Current
document-kind: audit
scope: Source-specific SF-M3 development, independent findings and pending exact-head compatibility-Web gates
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../SF-M3-RAPIER-WORKSHOP.md, ../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md]
---

# SF-M3 implementation and qualification — 31 October 2026

## Selected base and branch ownership

Fresh live reconciliation found `main` at
`34e9f9e30ebf9fde65565993f55dde571514ec93` (tree
`cb9d56b50b296160d1b6f01b50674a1d6f6b929d`). PRs #2/#3/#4 remained open at
`ea96e062ecc54d24d880a8119cb40cf0461c88ad`,
`ba7add4de9fe8027aaedeff0fa703c1a55fee21e` and
`32efe3142e557180b1777817f250f342b5b820de`. A separately authorized merge-down
worker had marked them ready and was adjudicating ready-state CI. This task
does not change those PRs or their branches.

The dedicated branch `sf-m3/rapier-workshop-20261031` therefore starts from
verified SF-M2 `32efe3142e557180b1777817f250f342b5b820de`, tree
`ddc2e9b3c7dd30dc10f98a30aa5e50291f4c0d46`, initially targeting
`sf-m2/authoring-history-20261031`. Reconcile the PR base against eventual
dependency integration without silently importing unrelated source. The
frozen CyberSand ancestor and its tree remain unchanged. **SF-M3 stays draft
and unmerged regardless of test outcomes.**

Dependency checks were separately verified: SF-M0 run 41133514643 passed three
jobs, SF-M1 run 41147313140 passed five jobs and SF-M2 run 41164949025 passed seven
jobs. These are historical dependency results, not SF-M3 execution. Existing
ready-state Windows runtime checks initially executed 0/0 because of retained
desktop provenance drift; the dependency worker owns that adjudication.

## Implemented source

The [SF-M3 contract](../SF-M3-RAPIER-WORKSHOP.md) describes the registry,
sixteen-slot bridge/render support, typed object commands, copied internal
logical reconstruction, mixed chronological history, Run interventions and
physical workshop controls. The packed coupling ABI remains unchanged. A narrow
candidate-only native restore factory reconstructs transient occupancy without
waking saved scheduler activity; the adapter's optional packed-body argument
preserves the legacy two-argument binding. Its exact implementation and fresh
binaries are included in the qualification gates; historical desktop payloads
are not evidence for this change.

## Development execution and original negatives

A fresh Linux extension was compiled locally with Godot 4.7,
godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1:
SHA-256 `eef74ae10e3a8f6207958ba8c49bfaeb42b405dd9c510b1f4e2340a69b2e74c3`,
4,301,000 bytes. Isolated staged projects verify that native library and the
pinned Rapier Linux payload; no historical desktop native binary supplies the
accepted development tests. Working-tree receipts retain their local-delta
identity and must not be relabelled as final-head executions.

The first registry/physics suite passed 1,591 assertions after correcting its
zero-body workload to include genuinely falling Sand. The original settled-
Water movement assertion failure remains retained. Sixteen bodies completed
400 native/Rapier ticks with 826,759 contacts, 1,580 displacements and 12 actual
body/body pairs; each body was sampled 400 times and received positive native
feedback. The retained neutral-host 600 oracle passed exactly 600/600 ticks,
106,717 contacts and 149 displacements, including save/restore/reset. Later
review corrections require their own reruns.

Genuine Godot Control input initially passed 34 object-workshop assertions and
the retained 17 material-editor input assertions. Actual llvmpipe rendering
displayed all sixteen bodies with the new shader. The first sandboxed Xvfb
attempt failed to open its display; an authorized retry succeeded. A root
history-test attempt lacked writable Godot XDG directories and crashed before
test execution; the corrected environment uses task-owned data/config/cache
directories. Initial attempts against the historical native payload correctly
refused missing `SandfallEditBridge`. These environment/bootstrap negatives
are retained, not counted as physical acceptance.

The restore-factory implementation was then freshly compiled to Linux native
SHA-256 `ca6a21d28a98e8fad2981b8909932dd6b88dcc032e8e21085d5c30605208e7ef`,
4,311,496 bytes. Against that binary, the current object-history suite passed
804 assertions, object Control input passed 34 and retained material Control
input passed 17. The final object/physics suite passed 1,779 assertions, including
immediate restored occupancy, strict two-/three-argument import compatibility,
metadata feedback equivalence, true deferred zero-body probing and real rebound.
The unchanged coupled oracle again completed 600/600 ticks, 106,717 contacts,
149 displacements and byte-exact physical save/restore. The newly compiled native
restore regression and retained body-capacity/pressure-persistence regressions
also passed. Stage manifests bind the executed scripts; these are still working-
source development receipts, not committed Web/browser results.

## Independent findings and corrections

Separate reviewers inspected source they had not implemented. Initial material
findings included:

- Run no-op changes incorrectly marking Modified and journalling success.
- Partial physical failure retaining Pristine and a stale accepted receipt.
- Potential ID reuse after a partially installed spawn and recovery.
- Missing body-occupancy publication after internal physical restore.
- Feedback diagnostics lost after transitioning through an empty graph.
- Minimum logical mass below the native parser's 0.001 minimum.
- A stale Edit initial-body observer and insufficient per-body browser
  feedback/stale-release trusted-delivery assertions.
- Reconstructed allocator IDs whose numeric suffix differs from creation order
  could otherwise be reissued after deletion; the allocator now reserves both.

Fresh reconstruction qualification exposed an additional native boundary:
the restored World lacked its transient occupancy field. Allocating that field
and republishing masks passed 1,767 object assertions, but the unchanged legacy
oracle detected scheduler-byte drift because ordinary publication wakes blocks.
Both the positive object result and the negative legacy result are retained.
Restore-specific occupancy reconstruction must preserve the serialized cells,
clock and scheduler, while normal live publication must retain its wake behavior.

The [independent review](2026-10-31-sf-m3-independent-review.md) identifies
author/reviewer ownership and source hashes. Exact mixed history and allocator
reservation/exhaustion passed 804 assertions on the development source. The
zero-body review also found that an unconditional capability probe performed 24
isolated Rapier steps; an empty host now defers that probe until the first
validated nonempty graph, with explicit inactive-state observations.

Each finding requires a concrete correction and targeted regression. Actual
restitution was independently measured: the bridge writes the intended
positive parameter, and a 0.8 restitution body rebounds; the inherited
PhysicsMaterial absorbent flag does not override that explicit server value.
Final review disposition belongs to the exact tested source and evidence,
not this preliminary finding list.

The separate SF-M3 source admission preserves the original M0/M2 refusals and
admits only the independently reviewed six-file native/adapter/test patch.
The generic checker still reports exactly 20 errors: six absent companion
references, eight inherited stale desktop inputs, two SF-M2 registration inputs
and four new World-restore inputs. All 18 LFS payloads remain materialized and
unchanged. Fresh native and Web execution is mandatory; this admission does not
qualify an old desktop binary. The inherited 12 focused native test filters
remain intact, with the new restore regression additional to them and a separate
full native suite in Actions.

## Exact-head qualification ledger

**Pending at initial publication.** The dedicated workflow must freshly build
the committed source, execute all applicable source/native/Godot gates, both
browser profile matrices and the retained regressions. Record terminal run,
artifact and source identities here or in a subsequent exact-head PR review.
An export, headless test, local GL screenshot or helper-unit pass alone is not
actual-browser acceptance. No SF-M3 completion or SF-M4 executable dependency
readiness is claimed until the required gates and independent review pass.

## Remaining scope boundaries

Compatibility Web uses one native worker and the tested COOP/COEP server.
Threaded Web, alternate/unisolated hosting, broad desktop and human exhibition
acceptance remain unqualified. No portable `.sandfall` ZIP codec, presentation
overlay, full Gallery programme, Golden Run or intervention promotion is
implemented. The separately owned dependency merges and production workflows
are untouched; the new SF-M3 qualification workflow is branch-scoped.
