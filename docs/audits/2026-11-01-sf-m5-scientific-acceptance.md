---
title: SF-M5 B01 local scientific acceptance
status: Current
document-kind: audit
scope: Exact-source Linux scientific tests, fixed-step pacing, repeated owners and local Gallery outcome comparison
last-reviewed: 2026-11-01
related-documents: [../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, ../SF-M2-AUTHORING-HISTORY.md, ../SF-M3-RAPIER-WORKSHOP.md, ../SF-M4-PROJECTS-EXHIBITIONS.md, 2026-11-01-sf-m4-final-reconciliation.md]
---

# SF-M5 B01 scientific acceptance — 1 November 2026

**The five local Linux scientific suites pass at source
`4a3acd91ca7a957a7c78167bfa5f83e6464adc0c`.** This tests-only tranche adds
actual five-preset pacing and repeated physical-owner replacement tests, then
measures the retained Gallery repetitions against declared local tolerances.
The production application, native engine, dependency pins and existing M2–M4
tests are unchanged. Browser, threaded, human and release qualification remain
separate gates in the [normative matrix](../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#111-executable-test-matrix).

## Source and runtime custody

| Identity | Recorded value |
|---|---|
| Accepted merged-main baseline | `ec94dfa50525135375dd6e35d1c5fca55c412544` |
| B01 executable source | `4a3acd91ca7a957a7c78167bfa5f83e6464adc0c` |
| B01 executable source tree | `88d00bb0d67b9fe029e055d99064722a37ac436f` |
| Godot | `4.7.stable.official.5b4e0cb0f`, Linux x86_64 |
| Godot executable SHA-256 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Native artifact source | `ec94dfa50525135375dd6e35d1c5fca55c412544`, reused without native-input changes |
| Native ELF SHA-256 / bytes | `9a6915e508afe25a5ebee5461f6cadb160976320a0f9eb28e13bd7b7534703e3` / 4,326,648 |
| Linux Rapier ELF SHA-256 / bytes | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` / 117,275,416 |
| Staged project.godot SHA-256 | `9a0b17c53052072e57fa11370976fc6987f574b20a1f724396f440fbac1bedb1` |
| Scientific test SHA-256 | `8b6819208d1df0f5384ebee424b7beb20fbb4a078a9f051b2a970b0dafde4d41` |

The native artifact is the actual merged-main Linux build from
[run 41336369405](https://github.com/techrote/sandfall/actions/runs/41336369405),
[artifact 13095587350](https://github.com/techrote/sandfall/actions/runs/41336369405/artifacts/13095587350).
Its archive SHA-256 is
`5f73f3e42ada3a0102fb5053569805f7eea375a68c18e9b914cf3b50fe1301ed`.
The artifact records godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`,
SCons 4.10.1, GCC/G++ 13.3.0 and GNU ld 2.42. Reuse preserves that original
build identity; it is not described as a fresh B01 native compilation.

The existing [Linux Rapier provenance](../../godot/addons/godot-rapier2d/runtime-provenance.linux.json)
pins **addon v0.35.2**, source
`172c66f5a88bf1164c2b8cf2d775ed889edefd75`, with its locked **rapier2d crate
0.35.1** and the accepted cooperative BVH patch. These are distinct version
identities. This work changes neither. Other platform payloads retain their
own accepted provenance.

Execution used Linux 6.18.57 x86_64 / glibc 2.39, an AMD EPYC 9V74 host reporting
nine logical CPUs in the process affinity, and **one actual native worker**.
The stage retains synchronous Godot ownership. Every repository GDScript was
byte-compared with the stage, the checkout was clean, and both ELF payloads
and the Godot binary were checked. Project metadata uses the existing seed 0
policy; Gallery definitions have empty authored event lists. Commands and
fixture construction are explicit in the source tests. The retained application
journals correctly keep their local-unpublished source labels: the enclosing
execution record and staged-byte checks supply this local execution's identity.

## Coverage without replacing accepted tests

| Requirement | Executed source and assertion | B01 disposition |
|---|---|---|
| SF-T03 | [Authoring](../../godot/tests/test_sandfall_authoring.gd): exact five-byte material/state/temperature edits, Undo/Redo, footprints, selection/fill and lease refusals; [objects](../../godot/tests/test_sandfall_objects.gd): exact object graph history | Qualified for this Linux execution; browser input remains A02 |
| SF-T04 | Retained authoring first-tick test and labelled native refusal **after a real Rapier step**; new [scientific](../../godot/tests/test_sandfall_scientific.gd) suite verifies both stacks retire after thermochemical advancement at every preset, and Pause/speed never restore them | Qualified locally, including truthful partial Fault |
| SF-T05 | Four ordinary paused frames, one Step, then 60 paced ticks for every 0.25/0.5/1/2/4 preset; actual native/Rapier counters and undamped real-body motion at 1/60 second | Newly qualified locally |
| SF-T06 | Retained Pristine/Modified, intervention and exact reset tests; chemical conversion and transported hot material; new reset restores authored cell bytes and actual initial poses/velocities at all five presets | Qualified locally |
| SF-T07 | Retained actual 0/1/3/8/16-body coupling and [project](../../godot/tests/test_sandfall_projects.gd) reconstruction; new twelve-owner replacement sequence, real resize/rebuild/Undo, old-body/container retirement and body-17 atomic refusal | Physics/lifecycle qualified locally; render pixels and browser round trips remain A02/M4 evidence |
| SF-T08 | Retained [Gallery](../../godot/tests/test_sandfall_gallery.gd) actual Fluid Messenger impulses and real motion, no-Water stationary control, and passive-subject trajectory containment through 1,200 ticks | Qualified locally |
| SF-T12 | [Reducer](../../tools/sandfall/sf_m5_science_report.py), source/runtime checks, exact commands/log hashes, selected local tolerances, retained original failures and independent review | Local evidence integrity qualified; full release ledger and cross-platform scope remain R01 |

SF-T01/T02/T09/T10/T11 retain their own source and execution owners. This B01
record does not promote headless rendering, local callback injection, archive
parser tests or an export into actual-browser qualification.

## Executed results

All five Godot processes returned exit 0 with one passing terminal receipt
each, no failed checks, no `SCRIPT ERROR`, no `ERROR` and no crash marker.

| Suite | Checks | Elapsed seconds | Result |
|---|---:|---:|---|
| New scientific pacing/lifecycle | 3,460 | 49.881 | PASS |
| Retained authoring | 230 | 15.115 | PASS |
| Retained objects | 1,779 | 41.908 | PASS |
| Retained projects | 931 | 18.353 | PASS |
| Retained Gallery | 203 | 269.908 | PASS |

Elapsed durations describe these test processes on the shared host. They are
not production-browser performance measurements or an FPS claim. D01 owns
that separate measurement contract.

### Chemical, thermal and fixed-step outcomes

The retained and new tests observe real native Steam `(22, 1, 0, 1500)` convert
to Water `(3, 255, 0, 1500)` after one tick. Hot Sand moves into the cell below
while retaining temperature 777. Exact Edit Undo/Redo restores full tuples;
Reset reconstructs the authored chemical/thermal initial state.

Each preset ends at 61 native ticks and 61 real Rapier steps: one paused Step
plus 60 paced ticks. Those 60 ticks require 240, 120, 60, 30 and 15 frame
callbacks respectively. The actual body starts at `(300, 100)`, velocity
`(12, -6)`, angular velocity 0.5, with gravity and damping disabled. Every
preset ends at `(312.197021484375, 93.8996276855469)`, rotation
`0.508332490921021`, with the original velocity and fixed dt `1/60`.
The equal-tick native-cell SHA-256 is identical across all five runs:
`d72582f7398e2cef6eb0a395e868165f5f610423d13e3d6ce900e1f92eb96832`.
Reset restores exact initial cells and body poses/velocities each time.

The original position tolerance remains **0.002 cell**, and the rotation
tolerance remains **0.0001 radian**. An early test incorrectly compared the
accumulated float32 solver position to a double-precision real-valued line,
producing five failed trajectory checks. The corrected expectation models the
pinned solver's arithmetic; it does not widen these tolerances:

1. The pinned [addon physics-world implementation](https://github.com/appsinacup/godot-rapier-physics/blob/172c66f5a88bf1164c2b8cf2d775ed889edefd75/src/rapier_wrapper/physics_world.rs)
   passes the configured dt and solver iteration count into Rapier parameters.
2. Rapier 0.35.1's [island initialization](https://github.com/dimforge/rapier/blob/v0.35.1/src/dynamics/solver/staged_island_solver/init.rs)
   derives four substeps and divides the dt by that count for this fixture.
3. Its [solver worker](https://github.com/dimforge/rapier/blob/v0.35.1/src/dynamics/solver/staged_island_solver/worker.rs)
   integrates positions in each substep. The test requires the configured
   count to remain four and calculates 244 float32 increments over 61 ticks.

That independent arithmetic predicts the observed x/y exactly. The early
negative also exposed `Array` versus `PackedStringArray` comparison at zero
bodies; conversion to equivalent ordinary arrays fixes the test's type error
while preserving the ID/slot values being compared. No production change,
physics observation substitution or hidden retry was made.

### Repeated capacity and actual contacts

The new suite executes `[16, 0, 1, 3, 8, 16]` twice, 120 ticks per owner:
**1,440 native ticks**, **1,200 Rapier steps** and **10,560 native body samples**.
Initial imported velocities are `(2.5, -1.25)` and angular velocity 0.2.
Actual body instances and adopted containers from previous owners are retired;
ownership depth stays one. Nonempty owners undergo a real shape rebuild and
exact Undo before running. The four sixteen-body owners each refuse body 17
without changing native bytes, live body state or logical definitions.

For each 120-tick sixteen-body owner the native observations record 167,031
contacts, 1,558 displacements and 12 actual body/body contact pairs. The
zero-body owners keep Rapier steps at zero and have no bridge/feedback owner.
All nonempty bodies receive exactly 120 native samples. The retained 600-tick
Gallery sixteen-body runs each observe 1,870,280 native contacts, 2,108
displacements and 15 body/body pairs.

### Local Golden Runs and causal control

The reducer registers **Fluid Messenger** and **Endless Kinetic Loop** before
its first measurement: maximum component span at equal 600 ticks must be at
most **1/64 cell** for position, **1/64 cell/s** for linear velocity,
**0.0001 radian** for rotation and **0.0001 radian/s** for angular velocity.
Angles are compared as recorded; modulo arithmetic cannot hide a turn.
All seven retained scenes actually run twice, and the five other scenes report
variance without acquiring an unregistered acceptance threshold.

Every recorded pose component span is **0** between each scene's two runs;
their final native-cell hashes also match. With these two observations the
component sample variance is zero. This is finite local repeatability evidence
with one worker and this runtime, not whole-stack bitwise replay or a
cross-platform/cross-browser equivalence claim.

Fluid Messenger starts at `(240, 185)` and ends at approximately
`(223.100830, 160.341858)` after 600 actual coupled ticks. It records 57,746
native contacts, 2,284 displacements, 590 feedback applications and accepted
impulses approximately `(-3.032007, -1.106571)`. The otherwise matching
no-Water control executes 600 real coupled ticks, stays at `(240, 185)`, and
records zero native contacts, displacement and feedback applications. The
passive subject receives real native impulse and stays within its original
camera throughout the retained 1,200-tick containment workload. No actor motor
or scripted position update supplies these trajectories.

## Reproduction and evidence inventory

At the exact source checkpoint, materialize the pinned LFS Rapier payload and
the identified Linux native artifact, then stage with the existing helper:

```sh
python3 tools/sandfall/sf_m1_stage_native.py \
  --native-library build/sf-m5-b01-runtime/libcybersand_native.linux.x86_64.so \
  --expected-native-sha 9a6915e508afe25a5ebee5461f6cadb160976320a0f9eb28e13bd7b7534703e3 \
  --output build/sf-m5-b01-stage.json
```

Run the five `test_sandfall_{scientific,authoring,objects,projects,gallery}.gd`
scripts separately with the pinned executable and the staged project:

```sh
"$SF_M5_GODOT" --headless --path build/sf-m1-native-project \
  --script tests/test_sandfall_scientific.gd
```

Use writable task-specific `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and
`XDG_CACHE_HOME`; keep each original log, command, source SHA, exit and elapsed
duration in an enclosing execution/CI receipt. The local run retained a
420-second process limit for each suite. Validate the five selected logs:

```sh
python3 tools/sandfall/sf_m5_science_report.py \
  --log build/sf-m5-b01-exact/scientific.log \
  --log build/sf-m5-b01-exact/authoring.log \
  --log build/sf-m5-b01-exact/objects.log \
  --log build/sf-m5-b01-exact/projects.log \
  --log build/sf-m5-b01-exact/gallery.log \
  --project build/sf-m1-native-project --godot "$SF_M5_GODOT" \
  --source-commit 4a3acd91ca7a957a7c78167bfa5f83e6464adc0c \
  --native-source-commit ec94dfa50525135375dd6e35d1c5fca55c412544 \
  --native-sha256 9a6915e508afe25a5ebee5461f6cadb160976320a0f9eb28e13bd7b7534703e3 \
  --output build/sf-m5-b01-exact/scientific-report.json
python3 -m unittest tools.sandfall.test_sf_m5_science_report -v
```

The ten reducer tests pass, including missing/duplicate/failed terminal
receipts, engine errors, numerical divergence, nonfinite observations, missing
repeat, worker/tick mismatch and a false no-Water feedback result. Their
synthetic reader inputs are not physics evidence. Do not feed an entire M4
build log containing expected malformed-DEFLATE diagnostics into this reducer:
these five scientific suites expect no engine errors. The archive validator
keeps its separate precise diagnostic policy.

The local evidence directory is `build/sf-m5-b01-exact/` in the B01 checkout.
It is generated execution evidence, excluded from Git under the repository's
artifact policy. Qualification consumers must preserve these actual files or
rerun the exact source; hashes alone cannot replace absent logs.

| Evidence file | SHA-256 |
|---|---|
| `execution.json` | `787259556ab720fdd3ca4dd08bcd33a3264263de3835653998a11d9f1c55d676` |
| `scientific-report.json` | `e58b6ac47c30658b920a064c04dbb88ace10359da53b9f354ef6bb29058a3b05` |
| `scientific.log` | `7398bc7ed623038af4ab1b6e5215c9c5e4ca60c1a8e610b3aec5780e43196437` |
| `authoring.log` | `9537799c48b97d15f3963548fe374dffa84e5513484393de386db6c1cc8b49f6` |
| `objects.log` | `8e2180b7a71c374393f0e3049c39e101b1789f4477ecdb659e66488d2be77d8a` |
| `projects.log` | `16442fd4d2989ec583ddecc68e76747da67e102db594077a8597d087f5e0f907` |
| `gallery.log` | `009d0d2cc6c549bd0238740599c1f2b36a25e7c961383497f5a5a00a75517dd4` |

Original precommit negatives remain in `build/`: initial user-data-directory
crash `sf-m5-b01-scientific-initial.log`, SHA-256
`f1908aa43a4c3e86a6748ea6000c1b64941da51ee0f5ed80d0a1f553a215fc57`,
and double-precision-oracle/type failure `sf-m5-b01-scientific-01.log`, SHA-256
`31bb2aeaae3a5d98439b5dbaae3b4eed1a3765044f4db693f47a80144fb4dabe`.
These describe development attempts, not a qualified source execution.

The reducer checks present source/stage/runtime bytes and original terminal
receipts. It does not independently prove when arbitrary supplied logs were
executed. Therefore its passing report must remain paired with the enclosing
execution/CI record binding the commands, exact source, runtime and log hashes.
Future integrated heads require their own source-bound execution.

Documentation validation retains the original six missing companion-workspace
references from `check_docs.py`. `sf_m3_reconcile.py` passes fresh-build
admission with exactly 20 expected original repository errors, no unexpected
or missing errors, and unchanged native/runtime/pin checks. Historical M11
integrity passes all 18 records and 28 source hashes. The retrieval evaluation
records 31/32 canonical hits at k; it is a retrieval diagnostic, not a runtime
acceptance test. No historical refusal or desktop qualification is rewritten.

## Independent review and remaining gates

The independent C01 agent reviewed executable commit `4a3acd91` and reported
**PASS, no blocking findings**. It independently ran the ten reducer tests,
examined the original five failed trajectory checks and corrected 3,460-check
run, checked the exact addon/crate arithmetic sources and enclosing command/log
receipt, and confirmed the local-only scope. Its initial execution disposition
was conditional on the remaining retained suites; all five have now completed
as recorded above. Integration still requires the integrating owner's exact
head CI and source review, including any combined A01/D01 application changes.

B01 supplies executable Linux scientific coverage and measured local outcomes.
It does not establish threaded workers, browser thermochemical input/rendering,
Windows desktop, alternate browser engines, human Gallery acceptance, exact
live-state continuation or whole-stack bitwise replay. Existing M4 acceptance
and its full 36-job requirement remain intact. A01/A02, D01/D02 and R01 retain
their respective release gates; this audit does not authorize a v1.0 tag.
