---
title: SF-M1 — dedicated Sandfall host and input qualification
status: Current
document-kind: audit
scope: Dedicated application, neutral solver ownership, bounded Edit/Run lifecycle and fresh Web qualification
canonical-for: []
last-reviewed: 2026-10-30
related-documents: [../SF-M1-HOST-INPUT-CUT.md, ../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, 2026-10-30-sf-m0-ordinary-web.md]
---

# SF-M1 — dedicated Sandfall host and input qualification

## Starting authority and owner hold

This implementation follows the owner's explicit request to create the dedicated
Sandfall entry point, remove inherited actor authority, then provide Gallery,
Sandbox, initial Edit/Run ownership, camera, pause, exact Step, reset and a fresh
Web export. It is on `sf-m1/host-input-cut-20261030`, based on the held SF-M0
checkpoint. **PR #2 remains draft and unmerged; its branch is not advanced by
SF-M1.** The new work is published as separate stacked draft PR #3.

Fresh reconciliation before implementation found:

| Input | Reverified identity/result |
|---|---|
| Sandfall main | `34e9f9e30ebf9fde65565993f55dde571514ec93` |
| SF-M0 / draft PR #2 | `ea96e062ecc54d24d880a8119cb40cf0461c88ad` |
| Exact SF-M0 ordinary/native run | [41133514643](https://github.com/techrote/sandfall/actions/runs/41133514643), terminal PASS for both viewport/DPR cases and focused native checks |
| Exact SF-M0 narrow provenance run | [41133523780](https://github.com/techrote/sandfall/actions/runs/41133523780), PASS with inherited limitations retained |
| Frozen CyberSand ancestor | `1d376fb38ff5df83691e468baa0639270a5f40e6`, tree `97eb0f4eeedde9bbe8b83047ca45c82d8a377d66` |
| Pinned specdocz | `039008723172a951c7694079cd06c7a2ea137d40` |
| Ownership | Only PR #2 open; no competing active SF-M1 branch/review; scope checkpoint posted as PR #2 comment `6534727816` |

The [SF-M0 audit](2026-10-30-sf-m0-ordinary-web.md) retains original failures,
all earlier build identities and the distinct full 164-test native and actual
600-tick legacy browser results. Those historical executions are not relabeled
as tests of the new host.

## Implemented ownership and controls

`godot/project.godot` starts `res://sandfall_main.tscn`. The dedicated
`scripts/sandfall/application.gd` composes a session controller, a neutral
simulation host and a world canvas. It neither derives from the old application
nor loads its player controller. The `FeatureNavigation` autoload is removed
from the project. Retained legacy scenes and tests remain available explicitly.

| Owner | Responsibility and boundary |
|---|---|
| `scene_definitions.gd` | Fresh initial values for Blank, Material Lab and the existing three-body Physics Pit; fixed authored simulation interest |
| `session_controller.gd` | Independent editable/frozen initial values, generation and input epochs, bounded command queue, Run/Pause/Step/reset/fault policy |
| `simulation_host.gd` | Actual native cell world, actual main-thread Rapier bridge, readiness, one fixed 1/60 tick request and copied render publication |
| `world_canvas.gd` | Validated owned RG8 image, material appearance LUT, actual supported body overlays, aspect-fit coordinates and camera only |
| `application.gd` | Godot Controls, explicit P/Escape shortcuts, camera drag/wheel routing and focus/modal/input retirement |

Sandbox enters Edit, paused at native/Rapier tick zero. Run deep-copies the
selected initial recipe and constructs a new live session. Pause never returns
to Edit or restores an earlier editing epoch. Step is accepted only in a ready,
paused Run and is bounded to one pending request: native +1/Rapier +0 with no
bodies, or native +1/Rapier +1 with the supported active bridge. Terrain
readiness can delay the request without consuming it or advancing either solver.

Sandbox Reset reconstructs the frozen recipe in paused Run; Reset & Edit creates
a new paused tick-zero Edit baseline. Gallery starts Physics Pit only after
material/body/collider readiness and autoplays; its Reset repeats that policy.
Fault stops further work and retains actual partial counts if Rapier advanced
before native refusal. No atomic rollback or implemented editing history is
claimed.

All lifecycle and camera actions have clickable controls. P toggles Run pause;
Escape opens/closes the menu. Middle drag and wheel control the camera inside
the measured world viewport. Camera operations never modify native simulation
interest. There is no inherited WASD/Space/jetpack/action forwarding, actor
creation, motor or actor-follow path. The new renderer has no synthetic player
rectangle. SF-M1 has no paint/history command owner yet; those tools remain SF-M2.

Blur/visibility loss pauses Run and retires held input. Modal entry, pointer
exit, reset and fault clear gestures and pending requests. Every queued command
carries both a session generation and an input epoch, so retirement also rejects
commands already copied into a local processing batch. A UI press has its own
epoch lease; an old release after blur cannot activate a button. Refocus requires
a fresh gesture.

## Validation ledger before first fresh export

These are **working-tree** checks, not a claim that a committed Web artifact has
passed. The terminal source/build/browser receipts below supersede this
provisional qualification scope without changing the recorded failures.

The fresh local Linux GDExtension is
`457d714b354f15e2f9a5c8c428e31870473bb71e4e8552367f2c37cc6bc567d4`
(4,215,336 bytes), compiled with GCC 13.3 from the unchanged native sources and
pinned godot-cpp. Tests use Godot `4.7.stable.official.5b4e0cb0f` and verified
Rapier 0.35.2. The stale checked-in desktop extension is never executed.

| Executed local check | Result and scope |
|---|---|
| Neutral backend actual paired run | 600 native / 600 Rapier; 5,220 native moves, 106,717 contacts, 149 displaced cells; PASS |
| Retained floor bound | Maximum first-body Y 160.317276; final floor tolerance PASS |
| Physical continuation fixture | Native payload byte-identical save/restore; body float32 tolerance and source reset PASS |
| Native-only preview/Step | Edit frames remain zero; requested Step +1 native / +0 Rapier; PASS |
| Camera isolation | Actual native physical payload, including serialized simulation region, unchanged; PASS |
| Session lifecycle | Blank/Edit, both Step cases, Gallery readiness, immutable recipe copies, reset, new Edit epoch, pause, stale command, duplicate Step and modal batch retirement; PASS |
| Explicit partial failure negative | Injected native refusal after a real Rapier step retains native 0 / Rapier 1, enters Fault and refuses later work; PASS as a refusal test |
| Render negatives | Empty/truncated/out-of-world RG8 payloads refused; copied snapshot ownership checked |
| Source/artifact verifier and staging | 24 focused Python tests, including 18 source/byte refusals and retained legacy staging; PASS |

The first backend attempt found a real defect: the native constructor refuses
an empty rectangle list. Blank now has an explicit Empty carve recipe. The
failed attempt log is retained separately from the passing rerun. Initial direct
script startup without a Godot import also failed class resolution; the normal
build imports its staged project before tests. No acceptance bypass was added.

## Fresh export and ordinary browser gate

`tools/build_web.py --entry sandfall --profile compat --native-tests` requires a
clean committed build source, pinned dependencies, a newly compiled native WASM
module and fresh Linux test extension. It refuses source SHA overrides,
export-only reuse, missing Rapier, or a HEAD/source change during construction.
The separately available default `--entry legacy` preserves original fixtures.

The Sandfall output includes its staged project and build/runtime identities.
`sf_m1_verify_web_artifact.py` verifies every artifact byte, entry, source SHA and
1280×800 logical layout; the browser harness independently hashes all HTTP-served
bytes before use. `?test=1` only publishes read-only ordinary application values.
No special acceptance scene, mutable command callback or success setter exists.

The dedicated workflow builds both new and retained entries from the same SHA,
executes actual Godot tests and focused C++ regressions, and runs ordinary Chrome
at 800×450/DPR1 and 640×400/DPR2. The ordinary harness requires real pointer/key
delivery, both entry modes, native-only advancement, exact active/inactive Step,
reset identity, 600 coupled Gallery ticks with positive effects, focus/modal/
outside-release negatives and a nonblank screenshot inside the actual world
viewport. Input finishes before the sole terminal screenshot. Raw failure and
success logs, observations, screenshots and hashes are retained by the jobs.

### First committed-source export refusal

The first implementation commit is
`3be1c34c932d3db056dc1974eb7ce5f911f6b125` on
[stacked draft PR #3](https://github.com/techrote/sandfall/pull/3). Its source and
focused-native job passed in
[run 41138966322](https://github.com/techrote/sandfall/actions/runs/41138966322),
job `124348276507`, artifact `13017516804`, ZIP SHA-256
`21a7abacb5c21223024bb87df973e2dbc83a816255f45a4288bc9d4d183cd0c0`.
The artifact contains 42 Python tests, two separate legacy staging tests and
twelve focused native tests with their actual logs/input hashes.
Documentation/provenance passed narrowly in
[run 41139007203](https://github.com/techrote/sandfall/actions/runs/41139007203),
artifact `13017931144`, ZIP SHA-256
`a77b045743bd6cd67a519906192548f8dde1a696448cee9c609dad6d2e175d1b`.

The **fresh export attempt at `3be1c34c` failed honestly before producing its PCK**:
native WASM/Linux compilation and Godot import passed, as did eleven Godot cell
interaction tests, but the inherited material-appearance test hard-coded the old
1920×1080 application viewport. Sandfall and Web staging use 1280×800. The full
failed compile/import/test log is retained at
`evidence/sf-m1-3be1c34c/sandfall-export-and-godot-tests.log` in the execution
workspace; the CI run independently retains its failure artifacts.

The correction moves the unrelated layout assertion to the dedicated application
entry test, where all four 1280×800 dimensions and `canvas_items` are asserted.
Every palette assertion remains: all 132 ID slots, all 256 palette/program rows,
50 flair classes and native material acceptance. No synthetic 1920×1080 project
is substituted for the actual Sandfall project. Changed Godot tests are build
inputs, so a new commit and fresh export are required.

Independent review also found that a cached material hash alone could conceal a
paused input mutation. Browser stability now additionally requires equality of
the live native revision and has a negative test that changes the revision while
leaving the cached hash unchanged. Real legacy keys and left/right world-pointer
events are checked in paused Run as well as Edit. Receipts identify committed
versus working-tree harness files and retain their actual SHA-256 values.

## Terminal qualification at bbe72707

**SF-M1's bounded compatibility-Web executable gates PASS** at
`bbe72707aa679790b66a143a71c09e7f21570993` on
[draft PR #3](https://github.com/techrote/sandfall/pull/3). The complete
[qualification run 41139800406](https://github.com/techrote/sandfall/actions/runs/41139800406)
is terminal SUCCESS. The separately run
[documentation/provenance gate 41139806971](https://github.com/techrote/sandfall/actions/runs/41139806971)
is PASS with the original inherited limitations retained. Neither PR is ready
for review or merged; PR #2's branch remains `ea96e062…`.

| Exact-source job | Result |
|---|---|
| `124351024899` source/native | 42 Python tests, two retained staging tests, 22 JavaScript tests/groups and twelve focused native tests plus C header/lifecycle/settled checks PASS |
| `124351024764` fresh exports/Godot | Fresh dedicated and retained legacy exports; twelve dedicated-entry and ten legacy Godot script invocations PASS; no Godot/SCRIPT errors |
| `124353911141` ordinary 800×450/DPR1 | 54 checks PASS; 623 actual native / 623 Rapier ticks, 5,220 moves, 111,322 contacts, 149 displaced cells |
| `124353911430` ordinary 640×400/DPR2 | 54 checks PASS; 608 actual native / 608 Rapier ticks, 5,220 moves, 108,319 contacts, 149 displaced cells |
| `124353911074` retained special 600-step contract | Functional PASS: exactly 600 native / 600 Rapier ticks, 106,717 contacts, 149 displaced cells; original pause/menu, save/restore and reset checks preserved |

The new-host backend test separately executes **exactly** 600 paired ticks with
5,220 moves, 106,717 contacts and 149 displaced cells, byte-identical native
physical save/restore, bounded body float32 restore, pause and source reset.
Its explicitly injected post-Rapier native refusal retains native 0/Rapier 1,
enters Fault and refuses further advancement. This negative is not presented as
a successful coupled tick. C++ sources, the Rapier bridge and the original
legacy 600-tick fixture are unchanged from the held SF-M0 parent. The full
164-test native result remains historical SF-M0 evidence; it was not rerun or
relabeled as a full SF-M1 suite.

### Ordinary input and actual-world rendering

Both Chrome `156.0.8078.47` runs use the ordinary dedicated application with only
read-only `?test=1` observations. Both runtime and committed harness identities
match `bbe72707`, and all served bytes match the independent verified export.
There are no mutable test commands, direct menu state setters or fabricated
ticks. The build profile is compatibility Web with one native worker.

| Observation | 800×450 / DPR1 | 640×400 / DPR2 |
|---|---:|---:|
| Native-only exact Step | 46→47; Rapier 0→0 | 44→45; Rapier 0→0 |
| Coupled exact Step | Both 41→42 | Both 46→47 |
| Genuine CDP inputs / required trusted DOM deliveries | 124 / 89 | 124 / 89 |
| Maximum pointer delivery error | 0 CSS pixels | 0 CSS pixels |
| Final PNG dimensions | 800×450 | 640×400 |
| Actual world ROI, excluding UI | `[114,686) × [65,385)` | `[66,574) × [58,342)` |
| Bright pixels / quantized colours | 16.02094% / 44 | 17.07125% / 74 |
| Complete run duration | 46.194 seconds | 43.381 seconds |

Real controls prove blank Sandbox/Edit at zero, template selection, a new Run
from frozen initial values, Pause, both Step contracts, Reset and Reset & Edit,
and Gallery autoplay after installation at zero with ready terrain. Four reset
checks per case reproduce initial material hashes/body poses in new generations.
The live native revision remains unchanged through paused legacy keys, primary/
secondary world clicks, camera operations, menu/Continue and focus negatives.

In both runs an old trusted Step-button release actually reaches the focused
canvas after a real hidden-tab interval, with no fresh press, and causes no Step.
Held P echoes after refocus do not resume. Middle-drag, modal and outside-release
negatives clear input and cannot pan or mutate the world without a fresh gesture.
Every input precedes the sole terminal screenshot. Independent PNG decoding
reproduces the ROI statistics, and review visibly confirms terrain, water, sand
and three bodies. These are application rendering checks, not owner human
presentation acceptance or a performance benchmark.

The ordinary application consoles contain no errors, warnings or exceptions;
all 31 HTTP responses per case are 200; CDP polling failures are zero. Chrome
stderr separately retains 22 headless-runner DBus/desktop-service errors per
case. The retained legacy functional harness has three CDP polling timeouts and
a terminal screenshot timeout: **no legacy PNG or new legacy visual PASS is
claimed**. Its functional result is supported by actual terminal counters and
unchanged assertions; the dedicated ordinary matrix supplies visual evidence.

### Export and retained artifact identities

The fresh dedicated CI artifact is
[13017918272](https://github.com/techrote/sandfall/actions/runs/41139800406/artifacts/13017918272),
ZIP SHA-256 `25984cf2a0038878a260e9cace944265da55cddf3d511ca9cd02477fe4700a72`.
It contains exactly nineteen final files plus the original manifest. Downloaded
bytes passed the unchanged strict verifier independently of CI.

| CI export component | SHA-256 |
|---|---|
| `SHA256SUMS` | `2f8db6c9634375d629f944e51d0c862c182836e494b03d20d0b02a220a9a62a4` |
| Native compatibility WASM | `559a466fddff84e809436052a020029c7241d99d412668b80e384966b598a595` |
| `index.pck` | `37bb2ef1adbc94025384e5938432548f8e9e9366a0a8d266cd6cfb496499a622` |
| Godot `index.side.wasm` | `85473bead1cf62c408d034189fae423594c45fef403fc0707a72bb8e2b87a6d2` |
| Rapier compatibility WASM | `5ff6933670c1377c24dcbac30d67758a307165eacdcbd33b25bf01669577c4c2` |

| Retained Actions artifact | ID | ZIP SHA-256 |
|---|---:|---|
| Ordinary DPR1 | `13018738214` | `4c3bd89d80893e8617e3d6ddfb2ba7400113b4fb15a67bb0be4b66e2ac1088cb` |
| Ordinary DPR2 | `13018623172` | `223489026d279fe625edbd816623bfe0532ed63076a1fa203e463e3a7f978204` |
| Legacy 600 contract | `13018698570` | `7fce7a0887b78eb7647a6481b3397a4ab9fc032edaa592fa188aeac842d5a2b7` |
| Build/Godot evidence | `13017888647` | `5c59798919d2747d61ef36c2e2048cc56273ab1c97164bfc5e489d34a9295e72` |
| Source/native | `13017672822` | `7d7100d561345b47051ef9846ddf3c5dd9f8d843d75f3a462d8245796150fce3` |
| Legacy fresh export | `13017533912` | `096f4bf18534e610979b5eb490c059c899fed2f729afab98cfc41d2b7535a8c8` |
| Documentation | `13018587082` | `aba645a5a1d75a169b5863f63664765a9f99923930840e7248f53b98a79937cd` |

Actions artifacts retain thirty days. The repository's
[durable evidence bundle](sf-m1-2026-10-30/qualification-bbe72707/README.md)
preserves both screenshots, complete machine observations, Chrome/HTTP/harness
logs, build/test logs, source/native receipts and negative results. Large JSON
and logs are losslessly gzip-compressed; its manifest checks original bytes and
stored bytes separately. Build binaries remain in their complete downloadable
artifacts rather than being copied into ordinary source Git.

### Local packaging refusals and final review

The successful local build's raw dedicated and legacy directories each exposed
an extra incomplete temporary PCK with a zero directory offset. Its producer
was not established. The strict inventory verifier refused both raw directories;
those refusals, names, hashes, headers and original files remain retained.
For the dedicated local package only, an explicit packaging receipt records a
copy of the nineteen manifest-listed files plus the unchanged original manifest
into a separate directory. All bytes remain identical and the unchanged strict
verifier passes. No local browser PASS is claimed, and the local raw legacy
directory remains inventory-refused. **The clean CI exports and actual CI
browser results are the final qualification authority.**

Independent final source and evidence review found no unresolved blocking
finding. It reviewed command/input epoch retirement, button release admission,
fixed tick order, actual partial-failure counters, camera isolation, immutable
render publication, source-bound exports and both browser traces/screenshots.
Documentation/evidence-only descendants must retain the actual build SHA and
pass source-equivalence checks; they do not retroactively relabel these bytes.

## Explicit remaining scope and inherited limitations

Compatibility Web, threaded Web, native tests, ordinary browser rendering and
human presentation acceptance remain separate lanes. This change qualifies
neither a threaded deployment nor human exhibition feel. It retains the
three-body fixture and makes no sixteen-body generalization claim.

Both compatibility-browser cases used COOP/COEP headers and observed
`crossOriginIsolated=true`; that does not establish threaded execution or
unisolated hosting support. The additional hosting/profile matrix and owner
human visual review remain outstanding. Fresh scoped native/Godot execution
does not establish a new platform-wide desktop qualification.

The six missing companion-workspace references remain: Q01
`../../SOURCE-PROVENANCE.json`; Q04 `../../docs/WEB_THREADING.md`; Q28
`../../tools/dev.py` and `../../docs/LOCAL_DEVELOPMENT.md`; Q29
`../../tools/dev.py`; Q30 `../../validation/browser-results.json`. No absent
workspace file is invented. Eight stale desktop digests remain: Windows and
Linux records for `godot/native_extension/cyber_demo_bridge.hpp`,
`godot/native_extension/cyber_native_cell_world.cpp`,
`godot/native_extension/cyber_native_cell_world.hpp` and
`native/include/cybersand/prepared_world.hpp`. Historical hashes are unchanged;
fresh staging receipts do not reattest those old binaries.

Full MZPaint editing/history is SF-M2, generalized 0–16 object authoring SF-M3,
and portable `.sandfall` ZIP archives SF-M4. The normative v1 design is unchanged.
