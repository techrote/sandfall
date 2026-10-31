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

**Bounded SF-M2 compatibility-Web executable acceptance passed at
`533a3de6352074f0cd68faca94417e80f041080e`.** The initial publication at `3a008a55`
was not acceptance. The fresh build, actual native/Godot scripts, separate SF-M2
and retained SF-M1 ordinary-browser matrices, legacy600 and strict provenance
were re-executed in [run 41163426571](https://github.com/techrote/sandfall/actions/runs/41163426571).
All seven jobs are terminal SUCCESS. The evidence-custody publisher refuses to
publish this section unless that exact source/run is successful. The complete
raw receipt inventory is retained in
[sf-m2-2026-10-31/qualification-533a3de6/manifest.json](sf-m2-2026-10-31/qualification-533a3de6/manifest.json).
Later documentation commits retain their own source identities; their exact-head
results belong in PR #4's final engineering review, not retroactively in the
original build receipts. No skipped lane counts as PASS.

The suite includes 48 Python tests plus two legacy-staging tests, 38 JavaScript
tests/groups, twelve focused native tests plus C-header/lifecycle/settled checks,
fourteen dedicated Godot script invocations and ten retained legacy invocations.
The authoring script performs 230 assertions; the actual Godot UI-input script
performs 17. These are assertions, not 247 separate test processes. Native core
and the Rapier bridge remain unchanged, but the new native edit adapter and
registration were freshly compiled. The historical 164-test SF-M0 full native
result is not relabelled as a newly executed full SF-M2 suite.

## Explicit limitations

The six missing companion references and eight stale desktop digests remain negative inherited evidence. Threaded Web, unisolated hosting, full platform desktop and human Gallery legibility/pacing remain unqualified. Compatibility evidence qualifies one native worker under the tested COOP/COEP configuration only. Historical SF-M0 164-test results are not newly executed SF-M2 full-suite results. The legacy probe's screenshot deadline remains distinct from ordinary visual qualification. No general full-stack deterministic replay, physics-history undo or .sandfall file format is claimed.


### SF-M2 provenance delta

The unchanged SF-M0 reconciler correctly refuses the new source tree: registering `SandfallEditBridge` changes `register_types.cpp`, adding **two** stale desktop input errors (Windows and Linux) beyond the original **six missing companion references plus eight stale desktop digests**. The SF-M2 reconciler retains that original refusal and permits only those exact two additional errors, after checking the reviewed two-line registration delta against SF-M1, unchanged native core and unchanged runtime payloads/manifests. Six synthetic negative tests refuse unknown/missing/duplicate errors, source or runtime drift and incomplete LFS. This enables a **fresh rebuild only**; it neither repairs nor qualifies the retained desktop binaries. The original M0 allowlist is not widened.

## Browser failure adjudication and correction

[Original exact-source run 41158379128](https://github.com/techrote/sandfall/actions/runs/41158379128)
remains **FAIL**. Build/Godot, source/native, both retained SF-M1 browser profiles
and legacy600 passed, while both new editor profiles rejected the first stroke:
twelve changed cells instead of the required eleven. The complete original
browser observations, failure PNGs and Chrome/HTTP logs are retained unchanged.

The source-verified Godot runtime consumes `pointermove` for motion and legacy
`mousedown`/`mouseup` for buttons. Fractional browser coordinates survived motion
but were quantized in button events: the intended starting cell moved left in
DPR1 and up in DPR2. `eeac43e98a617b81c2d77ff44e5392ce7de02559` chooses an integer
CSS coordinate strictly inside the requested material cell, refuses cells with
no addressable interior rather than painting a neighbour, and checks trusted
legacy button delivery as well as read-only Godot gesture endpoints. This is a
harness correction, not a change to application mutation semantics.

[First focused repair 41162500529](https://github.com/techrote/sandfall/actions/runs/41162500529)
remains **FAIL**. DPR1's stricter endpoint assertion sampled a stale motion
preview. DPR2 completed the editing/lifecycle sequence but its final input audit
rejected legitimate text-field input through Godot's own IME. `533a3de6` awaits
actual endpoint acknowledgement, rather than assuming that a fixed number of
frames acknowledges an input. Only explicitly designated text-field keyboard
events may target a focused, contenteditable `DIV.ime` sharing the canvas parent.
Other keys and all pointer operations remain canvas-only. Negative tests reject
arbitrary DIVs, unfocused/untrusted events, stale endpoints and unaddressable
cells. Exact mutation counts, tuples, thermal values and history expectations
were not weakened. No diagnostic setter or synthetic success callback exists.

## Independent immutable-artifact browser qualification

[Focused run 41162933990](https://github.com/techrote/sandfall/actions/runs/41162933990)
is terminal **SUCCESS**. It executed committed harness `533a3de6` against the
original, strictly verified `3a008a55` Web export. All application/build-sensitive
inputs were unchanged. This reuse is separately identified from the fresh
`533a3de6` export above; no old binary has been relabelled.

| Observation | 800x450 / DPR1 | 640x400 / DPR2 |
|---|---:|---:|
| Ordinary editor checks | 77 PASS | 77 PASS |
| Final actual native / Rapier ticks | 617 / 617 | 643 / 643 |
| Contact observations / displaced cells | 110119 / 149 | 115327 / 149 |
| Actual CDP commands / distinct required trusted deliveries | 330 / 257 | 330 / 257 |
| Maximum observed pointer-coordinate error | 0 CSS px | 0 CSS px |
| World ROI (exclusive upper bounds) | x[114,686), y[65,385) | x[66,574), y[58,342) |
| Bright samples / all samples | 9792 / 61120 | 8243 / 48280 |
| Quantized world colours | 44 | 75 |
| Full harness duration | 63.996 seconds | 96.486 seconds |

All five executing harness/helper hashes match the source. All twenty served
file identities match the independently downloaded export. Separate Pillow
PNG decoding and aspect-fit calculations reproduce the measured ROI and pixel
statistics. The PNGs show terrain, water, sand and three real body positions;
all input precedes the sole terminal capture. There were no ordinary application
console errors or CDP polling failures. Headless desktop-service/DBus messages
remain in the original Chrome stderr and are not hidden or labelled application
errors. This is automated visual evidence, not owner human acceptance.

The two passing browser ZIPs are artifacts `13027163779` and `13028231557`, with
SHA-256 `83bd5771b8b3bda4beb6dd9eb8c4e113f6cfe3e44f7d1779cb1c90abfa43bd06` and
`e20af3fff24dfcb7a2341dedd5622ee5f2224d1fdd32d725e62ba810c2f7dc58` respectively.
The source-custody artifacts independently bind the reviewed patch, exact source
commit/tree and unit-test logs. The durable manifest records all retained
original bytes and any lossless gzip storage separately.

## Fresh local native cross-check and limits

A separate fresh native build at `eeac43e9` passed authoring, actual Godot input,
session and backend scripts with Godot `4.7.stable.official.5b4e0cb0f` and pinned
godot-cpp/SCons. Native SHA-256:
`02549245e501e44e1a05e88443aa278e6da89c874aae007b5e1bb6003e82fe43`.
This is separate local-native evidence, not a local browser run. Local Chromium
policy blocked navigation; those attempts remain unqualified. No browser policy
was disabled to manufacture acceptance. The actual browser authority is the
GitHub-hosted execution above.

The legacy600 probe supplies functional pause/save/restore/reset evidence, not
ordinary editor input. Its original `3a008a55` run completed 600 paired ticks,
106717 contact observations and 149 displaced cells, but timed out at screenshot
capture. The unchanged probe's raw logs retain such polling/capture limitations;
no missing legacy PNG is counted as visual PASS. Ordinary browser lanes supply
separate successful screenshots.

## Disposition and next milestone

SF-M2's implemented document/history, exact material tools, state boundaries and
bounded compatibility-Web gates are complete in the stacked draft. This is not
full v1 release qualification, merge permission or owner visual acceptance.
PR #2/#3 remain untouched and PR #4 remains draft/unmerged. The next engineering
cut is **SF-M3: stable object identities and a generalized 0-16 Rapier-box
registry/workshop**, with qualified coupling/rendering/reset and atomic refusal
of body 17. Archive/presentation/exhibition work remains SF-M4; threaded,
unisolated-hosting, platform and human gates remain explicit.
