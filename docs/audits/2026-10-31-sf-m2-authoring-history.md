---
title: SF-M2 authored initial document, exact history and material tools
status: Current
document-kind: audit
scope: Implementation and source-specific qualification ledger for the bounded SF-M2 editor
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../SF-M2-AUTHORING-HISTORY.md, ../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md]
---

# SF-M2 implementation and qualification — 31 October 2026

## Authority and owner hold

SF-M2 is implemented on `sf-m2/authoring-history-20261031`, stacked draft PR #4. Fresh reconciliation found main `34e9f9e30ebf9fde65565993f55dde571514ec93`, held SF-M0 PR #2 `ea96e062ecc54d24d880a8119cb40cf0461c88ad`, and held SF-M1 PR #3 `ba7add4de9fe8027aaedeff0fa703c1a55fee21e`. Neither held branch is changed, merged or marked ready. Frozen CyberSand ancestor/tree and specdocz pin remain unchanged. The canonical v1 specification governs this cut.

## Source-backed changes

See [implementation boundaries](../SF-M2-AUTHORING-HISTORY.md). New document, tool router/geometry, read-only gizmos and narrow native editing adapter are integrated with the existing host/session/UI. Safe batches preserve actual masks and feedback; no whole-world level import is used for live interventions. Run recreates the frozen logical scene; Edit never advances solvers. Full authored-domain interest is independent of camera. No general body workshop, portable project codec, decorative layer or physical rewind is claimed.

## Development evidence, not final committed qualification

The execution environment initially lacked source/toolchain access. Preparation commit `77f9b28e2ce5654587364bf485722a1c8ff80753` packaged original history, all 18 LFS payloads and pinned build inputs on GitHub-hosted run `41152975325`. Artifact `13023289512`, ZIP SHA-256 `94272c5fdd3d132c0a483a31e8dd2de80df2b0a00c1caeea20529f9b4c532f45`, was downloaded and checked before local work. This fixture is **not** an acceptance gate.

The local development tree (base 77f9 plus unpublished SF-M2 changes) compiled a real native extension with Godot 4.7 / godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` / SCons 4.10.1. Its SHA-256 was `a0dddfd5a9b9eb35331bdb312a3e90a2c04ab5ed3edb2bb1c0f0a3eff58d79dc`. The native core and Rapier bridge remained unchanged. No stale desktop native runtime supplied these tests.

Local execution passed 42 Python tests plus two inherited staging tests, 29 JavaScript oracle tests/groups, the 12 focused native tests plus C-header/lifecycle/settled checks, and the fourteen dedicated-export Godot scripts. The final focused authoring rerun passed **230 checks**; actual Godot UI input passed **17 checks**. These are working-tree development results, **not** a claim of final-SHA or browser execution.

Actual integration covers full signed cell tuples; reversible Edit state; Water normalization/reserved-ID/late-batch refusals; caller aliases; native/doc/input/generation leases; immediate Run history lock; first advancement including actual Rapier1/native0 fault; exact paused Step at 4× pacing; bounded accepted intervention custody; reset; actual Steam-to-Water chemistry and hot Sand transport; exact overlapping selection; 1,048,576-cell fill/undo at zero ticks; and off-camera authored material evolution. Separate model-only capacity tests enforce the 64 MiB history limit. Snapshot/body-occupancy checks demonstrate that the editor read path does not clear masks, revision or feedback.

Review corrected public-patch cost accounting to use private prepared metadata, and filtered palettes to preserve the actual selected material identity. The initial local godot-cpp ownership refusal was an environment setup failure; the exact pinned directory was explicitly trusted and the fresh build rerun. Negative outcomes are not converted into synthetic passes.

## Published exact-source qualification

**Pending at the initial implementation publication.** A fresh compatibility Web/PCK/native build is required because native adapter, Godot and build inputs changed. SF-M1 binaries cannot establish this editor. The separate SF-M2 and unchanged SF-M1 ordinary harnesses must pass both viewport/DPR cases; the legacy600 oracle and narrow provenance reconciliation remain mandatory. Their exact terminal runs, artifact hashes and original negative evidence will be recorded here or in the linked PR #4 engineering review after execution. No skipped lane counts as PASS.

## Explicit limitations

The six missing companion references and eight stale desktop digests remain negative inherited evidence. Threaded Web, unisolated hosting, full platform desktop and human Gallery legibility/pacing remain unqualified. Compatibility evidence will qualify one native worker under the tested COOP/COEP configuration only. Historical SF-M0 164-test results are not newly executed SF-M2 full-suite results. The legacy probe's screenshot deadline remains distinct from ordinary visual qualification. No general full-stack deterministic replay, physics-history undo or .sandfall file format is claimed.


### SF-M2 provenance delta

The unchanged SF-M0 reconciler correctly refuses the new source tree: registering `SandfallEditBridge` changes `register_types.cpp`, adding **two** stale desktop input errors (Windows and Linux) beyond the original **six missing companion references plus eight stale desktop digests**. The SF-M2 reconciler retains that original refusal and permits only those exact two additional errors, after checking the reviewed two-line registration delta against SF-M1, unchanged native core and unchanged runtime payloads/manifests. Six synthetic negative tests refuse unknown/missing/duplicate errors, source or runtime drift and incomplete LFS. This enables a **fresh rebuild only**; it neither repairs nor qualifies the retained desktop binaries. The original M0 allowlist is not widened.
