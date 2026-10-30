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
SF-M1.** The new work is intended as a separate stacked draft PR.

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
passed. Final source/build/browser receipts will supersede this provisional
qualification section without changing the recorded failures.

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
twelve focused native executables with their actual logs/input hashes.
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

**Fresh export and complete ordinary-browser qualification remain pending.**
Source implementation and local lifecycle PASS do not close those gates.

## Explicit remaining scope and inherited limitations

Compatibility Web, threaded Web, native tests, ordinary browser rendering and
human presentation acceptance remain separate lanes. This change qualifies
neither a threaded deployment nor human exhibition feel. It retains the
three-body fixture and makes no sixteen-body generalization claim.

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
