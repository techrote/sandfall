# SF-M0 ordinary Web input and rendering — 30 October 2026

**Disposition: SF-M0 executable compatibility-Web gates PASS.** The ordinary
input/rendering blocker is resolved at
`86f4c942bdd0e917d2edd74f5a872f8ae0806aa6`: both the original 800 × 450 / DPR 1
and additional 640 × 400 / DPR 2 cases passed genuine input, normal simulation
advancement and actual-world screenshots. Focused native and narrow provenance
checks passed at that exact commit. Original full-native and coupled-fixture
evidence remains bound to unchanged build `63527569...`, not relabelled as a
new build. All original and intermediate failures remain retained below.
Threaded Web, stale desktop execution, human exhibition review and the new
Sandfall host retain their separate unqualified dispositions.
**PR #2 remains draft and unmerged.**

## Live reconciliation and authority

At continuation start, main was
`34e9f9e30ebf9fde65565993f55dde571514ec93`; draft PR #2 and branch
`sf-m0/source-import-20261030` were at
`5f937b91f396fa8b4cf2beceede1f86de3be9262`. No submitted reviews, unresolved
review threads, competing current owner or newer running qualification was
present. The independent historical `sf-m0/browser-triage-20261030` branch was
unchanged at `4c5fe409dfed2ca9a35dfae4f42b81697cb90580`.

The active authority is [root AGENTS](../../AGENTS.md) and the
[Sandfall v1 specification](../SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md).
CyberSand-specific owners and programmes below the imported guide are historical
technical context, not Sandfall work assignments.

- Actual two-parent import: `b48214da1935519002a6c4bfc6d7f465eb4a3eab`;
  second parent `1d376fb38ff5df83691e468baa0639270a5f40e6`;
  frozen ancestor tree `97eb0f4eeedde9bbe8b83047ca45c82d8a377d66`.
- The import differs from the ancestor at exactly the five documented
  Sandfall-specific paths. Original Git object identities remain unchanged.
- Pinned specdocz revision was re-read:
  `039008723172a951c7694079cd06c7a2ea137d40`, tree
  `78aa2ee179dea90957c4b14a89994f7e6faa4b63`.
- Successful Web/native build source remains
  `6352756931c58e702eb5c15c05d44515091274b2`. No native, Godot, vendor,
  Web staging, build-profile, dependency or packaged input changed for this
  harness correction. The export is **not relabelled as a newer build**.

## Original negative evidence and coordinate diagnosis

[Run 41121317805](https://github.com/techrote/sandfall/actions/runs/41121317805)
and [artifact 13009056837](https://github.com/techrote/sandfall/actions/runs/41121317805/artifacts/13009056837)
remain failed. The original ZIP SHA-256 is
`f0fca61f8cc5bac06ea5212b56f7f0063f65a5e1b39c11fd27a1f8db3cedb663`.
Its browser JSON, screenshot, Chrome log and HTTP log are retained unchanged in
each new ordinary-Web CI artifact, with an origin/hash receipt.

| Coordinate space | Original source/observation |
|---|---|
| Browser CSS viewport and canvas bounds | 800 × 450; `[0, 0, 800, 450]` |
| Source-staged Godot logical viewport | 1280 × 800 |
| Godot stretch | `canvas_items`, aspect `keep` |
| Fitted Godot content in canvas | 720 × 450, horizontal offset 40 |
| Logical Continue rectangle | `[286, 579, 233, 42]` |
| Correct CSS Continue rectangle | `[200.875, 325.6875, 131.0625, 23.625]` |
| Correct CSS pointer centre | `(266.40625, 337.5)` |
| Original harness pointer | `(403, 600)`, below the canvas |
| Actual world CSS rectangle | approximately `[126, 106.875, 548, 308.25]` |

`CyberWebDemoMenu.test_rects()` publishes logical `Control.get_global_rect()`
values. CDP expects CSS viewport coordinates. The old harness mixed these
spaces. The screenshot independently agrees with the fitted button position.
The pinned builder stages 1280 × 800; Godot's omitted aspect setting defaults
to `keep` in the
[pinned engine source](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/config/project_settings.cpp).

The original Escape events did not establish delivery or focus. The recorded
evidence cannot retrospectively distinguish lost focus from delayed event
processing. The original browser did load every required asset with HTTP 200,
registered Rapier, reported one worker and rejected zero render snapshots.
Its slow software renderer explains delayed acknowledgements, but cannot make
the off-canvas pointer valid. No application input defect was demonstrated.

The original 3.44% bright pixels and 37 colours sampled menu/UI pixels in a
generic screen region. They were **not material-viewport rendering proof**.

## DPR-2 screenshot/input race

The first corrected CI run, `41126992330` at
`476619679b13505e788404e300eb21777636d56e`, passed the original DPR-1 case
but failed the additional DPR-2 case. The latter requested the correct CSS
Continue point `(201.25, 300)`; trusted canvas events arrived at
`(100.625, 150)`. Focus, canvas bounds and DPR were correct. An optional initial
menu surface screenshot had exceeded its 60-second CDP promise deadline, and
the harness then sent input while Chromium's underlying capture remained active.

An independent Chrome **156.0.8078.79** blank-page experiment reproduced the
same effect without Godot. During four of four surface-capture overlaps, the
pointer arrived at half the requested CSS coordinates. Before capture and
after completion it arrived correctly. Four view-capture (`fromSurface:false`)
controls also delivered correct coordinates during overlap. The observed DOM
viewport/DPR values remained unchanged throughout.

The [raw diagnostic observations, original scripts and hashes](sf-m0-2026-10-30/diagnostic-manifest.json)
are committed evidence. These are diagnostic experiments, not Sandfall
acceptance. Chromium's
[current capture implementation](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/content/browser/devtools/protocol/page_handler.cc)
(observed blob `bd840dee1d34d9c23f1f4786e2b4e63995250782`) independently
corroborates temporary emulation changes and restoration on the capture callback;
the installed-runtime experiment establishes the actual behavior here.

The second correction leaves coordinate mathematics unchanged. All genuine
input and pause checks finish before the terminal world screenshot. A guard
forbids subsequent input, and a failed capture cannot launch another overlapping
capture. Acceptance also requires trusted DOM pointer coordinates to match both
intended CSS targets. There is a 900-second phase-wait deadline, a separate
150-second capture deadline and a 1,140-second outer process limit; no assertion
or required tick count is weakened. Failed screenshots remain failures.

At `350d7b9084eb71eb464913b1b4a5ac6d3a516ede`, that sequencing correction
passed genuine DPR-2 Continue/Escape/Continue/P, normal advancement to tick 16
and stable pause at tick 22. Its final surface screenshot then exceeded the
150-second deadline. This is a **capture-only failure**, not a passing visual
result. It does not demonstrate an application input or simulation failure.

The subsequent minimal correction uses `Page.captureScreenshot` with
`fromSurface:false` to capture the actual visible browser view, avoiding the
surface emulation/resize path. It retains the same CSS viewport, DPR, genuine
input sequence, tick contract and world-only pixel thresholds. The actual PNG
dimensions determine the crop scale; a 640 × 400 view capture is not mislabelled
as its 1280 × 800 backing buffer. Full browser version and capture mode are
recorded. Transport cleanup is bounded and fails closed if its deadline expires.

## Correction and executable acceptance

The correction changes the harness, source verifier, tests and CI only:

- Derive the logical viewport from the exact pinned project, export preset and
  literal Web staging replacements. Refuse unsupported stretch/layout values.
- Measure DOM canvas bounds, backing dimensions, browser CSS viewport, DPR,
  visual viewport, focus and active element. Fit logical coordinates into the
  backing image and convert to CSS coordinates. DPR never directly doubles a
  pointer coordinate.
- Require an exact export source/profile/toolchain identity, complete file
  inventory and all SHA-256 values. Refuse relevant committed, staged,
  unstaged or untracked source/build drift. Before navigation, hash the actual
  HTTP-delivered export files and manifest against the verified local receipt.
- Launch `?test=1` only: ordinary `_process`/`_physics_process` ownership remains
  active. Never invoke the test command callback, select `rapier=1`, set menu
  state, alter ticks or mutate application state through JavaScript.
- Send one mapped Continue click and require menu closure. Require at least
  15 real native ticks and positive native material movement. Send real Escape,
  observe the reopened menu and stable ticks, then click Continue again.
- Send real P to pause and require stable ticks before and after screenshot
  capture. Independently observe trusted pointer/key events targeted at the
  canvas. CDP acknowledgement alone cannot pass any application assertion.
- Map the actual published world-content rectangle, inset its border and round
  inward to screenshot pixels. Require a closed menu, no renderer rejections,
  nonblank/varied pixels and no unintended painting by the UI clicks.

The CI matrix covers the original **800 × 450 / DPR 1** shape and
**640 × 400 / DPR 2**, separating CSS, backing and screenshot scales.
Failures retain screenshots/JSON/logs and cannot be converted to success by a
diagnostic intervention. The overall process and individual CDP operations are
bounded; input is sent once so late acknowledgements cannot double-toggle menus.
Screenshots follow all input; a JavaScript/CDP timeout is not cancellation of
an in-flight Chromium capture. The original coupled-fixture and all three failed
browser artifacts are copied unchanged into subsequent CI evidence, with
origin/hash receipts that distinguish preserved executions from the current run.

Regression coverage includes the original offscreen click, both letterboxing
directions, offset canvases, differing DPR/backing policies, screenshot scaling,
clipped/inset/invalid regions, PNG filters/alpha/truncation, and an explicitly
**black world surrounded by bright colourful UI**. The latter must fail the
world pixel oracle. Source-verifier negatives cover corrupt/substituted modules,
wrong source/profile, incomplete manifests and actual build-input drift.

## Actual local qualification

The original successful export was downloaded independently from
[artifact 13004589535](https://github.com/techrote/sandfall/actions/runs/41115189216/artifacts/13004589535).
ZIP SHA-256:
`0a82292331a13b47566c868532a9554801a75b2877b120a9dda29179d40fcc09`.
All **18** exported-file manifest entries matched. Native side-module SHA-256:
`59cb17e512f89f0961871069dbcdc6064034ca671d3e205b1b1a11b46feb62cc`;
Rapier WASM:
`5ff6933670c1377c24dcbac30d67758a307165eacdcbd33b25bf01669577c4c2`.

The first corrected local run used Chrome **156.0.8078.79**, Linux x86_64,
SwiftShader, 800 × 450 / DPR 1, one compatibility worker. It finished in
**197.880 seconds**:

| Actual observation | Result |
|---|---|
| Initial menu | tick 0 |
| First genuine Continue | menu closed; native tick 2 |
| Normal advancement | tick 22 before keyboard/menu checks |
| Escape | menu reopened at tick 24; tick stayed 24 |
| Second genuine Continue | menu closed; tick 26 |
| P pause and capture stability | tick 28, unchanged through capture |
| Final native material movement counter | 25,244 |
| Actual world screenshot interior | x `[128,672)`, y `[109,413)` |
| Sampled world pixels | 55,328; 33.4261% bright; 23.0715% colourful; 476 quantized colours |
| Renderer rejections / unintended paint commands | 0 / 0 |
| Trusted canvas input | two pointer down/up pairs; Escape and P down/up |
| Special Rapier fixture | absent |

The screenshot visibly contains the authored Neon Works structures and material
contents. Automated screenshot inspection is not human exhibition review. This
first local run used a working-tree harness delta over `5f937b91...`; later
source-binding/timeout refinements are qualified by clean committed CI rather
than retroactively attributed to that local run.

Focused native C++ validation ran **12 existing registered tests**, C-header
compilation, the soliding lifecycle executable and settled-region executable.
It covers immutable/concurrent render publication, dirty rectangles/RGBA,
body-mask/contact/barrier semantics, failure publication/recovery and pause.
All commands exited zero; **117 native/Makefile input hashes** remained stable
and matched the full-suite build source. This is focused evidence, not a new
full-suite claim. The historical full job's raw log was independently fetched
and confirms **164 tests passed** at `63527569...`.

## Exact committed CI receipts

### First correction: `476619679b13505e788404e300eb21777636d56e`

| Gate | Terminal result and retained receipt |
|---|---|
| Ordinary 800 × 450 / DPR 1 | **PASS** — [job 124307960792](https://github.com/techrote/sandfall/actions/runs/41126992330/job/124307960792), [artifact 13011307729](https://github.com/techrote/sandfall/actions/runs/41126992330/artifacts/13011307729) |
| Ordinary 640 × 400 / DPR 2 | **FAIL** — [job 124307960289](https://github.com/techrote/sandfall/actions/runs/41126992330/job/124307960289), [artifact 13011023580](https://github.com/techrote/sandfall/actions/runs/41126992330/artifacts/13011023580); capture/input race described above |
| Focused native render/coupling/lifecycle | **PASS** — [job 124307960749](https://github.com/techrote/sandfall/actions/runs/41126992330/job/124307960749), [artifact 13011725580](https://github.com/techrote/sandfall/actions/runs/41126992330/artifacts/13011725580); 12 tests, C-header and lifecycle executables, 117 stable input hashes |
| Documentation/provenance reconciliation | **PASS, narrow scope** — [run 41127001296](https://github.com/techrote/sandfall/actions/runs/41127001296), [artifact 13011037420](https://github.com/techrote/sandfall/actions/runs/41127001296/artifacts/13011037420); all 18 LFS payloads verified, original six/eight failures retained |

The overall ordinary workflow is **failed** at this commit because DPR 2 failed.
Its DPR-1 PASS is genuine: Continue closed the menu, normal advancement reached
tick 20, Escape reopened and held at 22, Continue resumed to 26, and P paused
at 28 through screenshot capture. Native material movement was 25,244; paint
commands and render rejections were zero. All 19 HTTP-delivered export/manifest
hashes and the three executing JavaScript hashes matched the verified receipt.

The DPR-1 actual world interior was x `[128,672)`, y `[109,413)`: 55,328 sampled
pixels, **33.4189% bright**, 23.0462% colourful, **467 quantized colours**.
Screenshot SHA-256:
`04532c2705d37ac3ea552bb38b055f40ca730d977d58913d5a798a1012409b87`.
Browser receipt SHA-256:
`132c387e8c57896eb0d549efb63c196acc3573b70d065bd72c6862ead342ecd6`.

| Artifact ZIP | SHA-256 |
|---|---|
| DPR 1 / 13011307729 | `c1de4b883fa87dac4852acd480ea6bcd5f8485783ba33c95dc66c8d15bab7728` |
| DPR 2 failure / 13011023580 | `e7291cf0c5210813e4bd530e09d75a9328d02fa2b2a1e60da9b639726858f554` |
| Focused native / 13011725580 | `d11947fda17ec6910bc309e9c13e7221c6faf7cb7f026470fd1c029a0e7893f4` |
| Documentation / 13011037420 | `199453cabb63533147dca781c8a36561669378a1b321ca9181a3c3d0c7112fff` |

Each browser matrix job also passed 20 Python regressions (seven reconciliation,
13 artifact-verifier), nine geometry cases, five PNG cases and the CI-provider
policy. The native JSON receipt hash is
`f0de5471d8a474a1016833ecac3a23e055ae980c1cc30b5105e22b1fa73e9816`.
Artifacts have 30-day retention. Skipped inherited draft workflows are not
acceptance passes. This failed checkpoint required the later terminal matrix
recorded below before SF-M1 implementation could begin.

### Capture sequencing: `350d7b9084eb71eb464913b1b4a5ac6d3a516ede`

| Gate | Terminal result and retained receipt |
|---|---|
| Ordinary 800 × 450 / DPR 1 | **PASS** — [job 124314064047](https://github.com/techrote/sandfall/actions/runs/41128785495/job/124314064047), [artifact 13012980278](https://github.com/techrote/sandfall/actions/runs/41128785495/artifacts/13012980278) |
| Ordinary 640 × 400 / DPR 2 | **FAIL** — [job 124314064093](https://github.com/techrote/sandfall/actions/runs/41128785495/job/124314064093), [artifact 13011774471](https://github.com/techrote/sandfall/actions/runs/41128785495/artifacts/13011774471); terminal surface capture timed out after genuine input/tick/pause checks |
| Focused native render/coupling/lifecycle | **PASS** — [job 124314063578](https://github.com/techrote/sandfall/actions/runs/41128785495/job/124314063578), [artifact 13012236542](https://github.com/techrote/sandfall/actions/runs/41128785495/artifacts/13012236542); 12 tests, C-header and lifecycle executables, 117 stable input hashes |
| Documentation/provenance reconciliation | **PASS, narrow scope** — [run 41128795373](https://github.com/techrote/sandfall/actions/runs/41128795373), [artifact 13011992354](https://github.com/techrote/sandfall/actions/runs/41128795373/artifacts/13011992354); original six/eight failures retained |

The DPR-1 run took 204.779 seconds: native tick 24 before keyboard checks,
Escape/Menu stable at 26, Continue to 28, and P paused at 30 through capture.
Material movement was 27,022, with zero paint commands or render rejections.
The actual world interior remained x `[128,672)`, y `[109,413)`: 55,328 sampled
pixels, **33.3990% bright**, **473 quantized colours**. Screenshot SHA-256:
`8c7e364235321457d18736d0ff7c614d904fd3efa1313aaedfbb464c2050a269`;
browser JSON SHA-256:
`3db4f6a60e91367526cb6a3983143316aa98a4940077fdca161605be78d29b56`.

The DPR-2 run took 832.898 seconds and remains **failed**, without a new PNG.
All four trusted pointer events matched `(201.25, 300)`; Escape and P were
trusted and targeted the focused canvas. Continue closed the menu at tick 6;
normal advancement reached 16; Escape held at 16; Continue resumed to 20;
P paused at 22. Material movement was 19,898, with zero paint commands or render
rejections. Capture began only after stable pause, then exceeded 150 seconds.
No post-capture stability or pixel acceptance is claimed. The original JSON,
Chrome/HTTP logs and nested prior evidence are preserved unchanged in subsequent
artifacts, with an explicit original-execution receipt.

| Artifact ZIP | SHA-256 |
|---|---|
| DPR 1 / 13012980278 | `e2850dd27ce91e6c3a682ceef69468607fc9dabceac2033786320624263424f3` |
| DPR 2 capture failure / 13011774471 | `531b8132176a48837c96432235108759f7cf7f8316bb53b6a6237e7d64c852d2` |
| Focused native / 13012236542 | `c0e9c2e1b08b393ac7b3e2ce8ec603e530d9bc1a96d197ca61a91eab6eb63bd0` |
| Documentation / 13011992354 | `d59588eb2429f03cee50b7e91c4fa19bd89adaf6d44cf2bf1014fc83f8769ed1` |

The native receipt SHA-256 is
`36e23ed7821e22e6b7474db27ef38a4ee30af69f0ea55fb43de7638851f4e8a0`.
The overall ordinary workflow is **failed** at this commit. Its view-capture
successor is qualified separately below; the diagnostic blank-page results are
not substituted for an actual Sandfall screenshot.

### Visible-view capture: `86f4c942bdd0e917d2edd74f5a872f8ae0806aa6`

[Run 41131776735](https://github.com/techrote/sandfall/actions/runs/41131776735)
is terminal **SUCCESS**, with all three required jobs passing. No application,
native, Godot, vendor or build input changed. Every tested export byte remains
bound to original source `6352756931c58e702eb5c15c05d44515091274b2`.

| Gate | Terminal result and retained receipt |
|---|---|
| Ordinary 800 × 450 / DPR 1 | **PASS** — [job 124324212099](https://github.com/techrote/sandfall/actions/runs/41131776735/job/124324212099), [artifact 13014080666](https://github.com/techrote/sandfall/actions/runs/41131776735/artifacts/13014080666) |
| Ordinary 640 × 400 / DPR 2 | **PASS** — [job 124324211950](https://github.com/techrote/sandfall/actions/runs/41131776735/job/124324211950), [artifact 13013254801](https://github.com/techrote/sandfall/actions/runs/41131776735/artifacts/13013254801) |
| Focused native render/coupling/lifecycle | **PASS** — [job 124324211665](https://github.com/techrote/sandfall/actions/runs/41131776735/job/124324211665), [artifact 13013905575](https://github.com/techrote/sandfall/actions/runs/41131776735/artifacts/13013905575); 12 registered tests, C-header/lifecycle/settled checks, 117 stable inputs |
| Documentation/provenance reconciliation | **PASS, narrow scope** — [run 41131784531](https://github.com/techrote/sandfall/actions/runs/41131784531), [artifact 13013900438](https://github.com/techrote/sandfall/actions/runs/41131784531/artifacts/13013900438); all six/eight inherited errors retained |

Both browser jobs ran ordinary `?test=1`, with the special Rapier fixture absent,
native/Rapier readiness true and one compatibility worker. They independently
verified all 18 export files plus the HTTP-served manifest, all three executing
JavaScript hashes, correct trusted canvas pointer/keyboard events, zero
unintended painting and zero render rejections. Input finished before capture;
pause remained stable through the final post-capture observation. The same 20
Python, nine coordinate and five PNG regressions passed in both jobs, including
the bright-UI/black-world negative and source-drift refusal cases.

| Actual observation | 800 × 450 / DPR 1 | 640 × 400 / DPR 2 |
|---|---|---|
| CSS canvas | 800 × 450 | 640 × 400 |
| Canvas backing | 800 × 450 | 1280 × 800 |
| Actual visible-view PNG | 800 × 450 | 640 × 400 |
| Continue delivered to CSS centre | `(266.40625,337.5)` | `(201.25,300)` |
| First Continue / normal advancement | tick 6 / **18** | tick 4 / **24** |
| Escape menu pause | tick 20, stable | tick 26, stable |
| Second Continue / P pause | tick 22 / **24**, stable through capture | tick 28 / **30**, stable through capture |
| Native material movement | 21,682 | 27,022 |
| Actual-world screenshot interior | x `[128,672)`, y `[109,413)` | x `[79,561)`, y `[97,367)` |
| Sampled world pixels | 55,328 | 43,470 |
| Bright world pixels | 18,486 — **33.4117%** | 15,342 — **35.2933%** |
| Quantized world colours | **470** | **525** |
| Harness duration | 188.001 s | 548.848 s |

CDP and CLI identify the CI browser as **Chrome 156.0.8078.47**, revision
`1d17a2e2ee147bb7d6ae2ab6abdb3a2510c17775`, with SwiftShader/ANGLE.
This is distinct from local diagnostic Chrome 156.0.8078.79. Both screenshots
use `Page.captureScreenshot` with `fromSurface:false`. In particular, the DPR-2
640 × 400 PNG is scored at its actual dimensions, without confusing its scale
with the 1280 × 800 backing buffer.

Independent review decoded each PNG with Pillow, recalculated the world crop
and pixel counts, inspected the actual image, checked trusted input/transition
observations, and compared source and executing-harness hashes. Both passed.
The current artifacts also retain 4 original-failure files, 14 first-DPR2-failure
files, 34 second-DPR2-failure files and 4 original coupled-fixture files; every
retained member was compared byte-for-byte with its earlier independent download.

| Artifact ZIP | SHA-256 |
|---|---|
| DPR 1 / 13014080666 | `ef66000cff7d4d887156c63e6e3e6803759c4a512f2dbe298c3f5d56a3b658f3` |
| DPR 2 / 13013254801 | `f500e6df4eb2c17dc40c3871615518f753881073e5597260041c669ae1377ab4` |
| Focused native / 13013905575 | `99efee0765c495d606c5486c9a9ac5165783743d8507e955ad04db202bf0cc67` |
| Documentation / 13013900438 | `024c552c113dcb0fac12f0633f99687a8b30ca37d7c6f8ef9de2f8b2e5bccf0a` |

| Retained raw file | SHA-256 |
|---|---|
| DPR-1 browser JSON | `df83e16f86c33d234a91999ecbfba556ef79c217b44c39ae53fc7e2c174955fd` |
| DPR-1 screenshot | `e4dd0611a69c8380e0445cf9daa7901d2254b0f14b5eaed4cdff86e184bb950e` |
| DPR-2 browser JSON | `fbfbdfa6941f608c9037b9b02e335444d1d808efc672f0f853cf875afbc9c4b9` |
| DPR-2 screenshot | `d57ceb2eeca97e8bd51aff10a14191090c0dc28393960dbaed46a80f70b4428f` |
| Focused native receipt | `5ef54718f7d29a3429452e46502595f7be18fb7b2313f49fa253fd38a7cdf78f` |
| Documentation receipt | `b3adc0329da528930e833344dbae36eb8a182c4b815b7d275e6362e7cb53a2f4` |

### Durable evidence and substantive review

The [committed evidence manifest](sf-m0-2026-10-30/qualification-86f4c942/manifest.json)
indexes selected raw receipts, Chrome/HTTP and workflow logs, original full-native
log, positive screenshots and all three browser failures. The files are copied
byte-for-byte; their original execution/source identities and SHA-256 values
remain explicit. This selected evidence remains in Git independently of Actions
retention: current ordinary/focused-native/documentation artifacts use 30 days;
the original Web/full-native artifacts use 14 days. Raw evidence disables Git
line-ending conversion so its byte hashes survive cross-platform checkout.
Inspect the actual
[DPR-1 screenshot](sf-m0-2026-10-30/qualification-86f4c942/ordinary-dpr1/browser.png)
and [DPR-2 screenshot](sf-m0-2026-10-30/qualification-86f4c942/ordinary-dpr2/browser.png).

The complete runnable export is not embedded in this selected evidence bundle.
The artifact-reuse workflow depends on the original Web artifact: after its
14-day retention expires, rerunning requires a new source-matched compatibility
export and reviewed updates to the pinned artifact/source/hash references.
Receipts or screenshots alone cannot replace that runnable export. SF-M1's new
host already requires a fresh application export regardless of this expiry.

One supplementary local view-capture diagnostic lost its owning process
sessions before producing a terminal receipt or image. Its retained interruption
receipt reports that incomplete result and the unproven termination cause; it
is not counted as acceptance. The committed CI matrix above supplies the actual
terminal qualification.

Substantive review found no blocking defect in the geometry, actual-world pixel
oracle, source/HTTP verifier, capture ordering, fail-closed cleanup, native
evidence or SF-M1 plan. The review independently checked all 117 native source
hashes and command logs, the unchanged 600-tick fixture files, exact six/eight
provenance limitations, and both new ordinary-browser results. Review does not
lift the owner hold or substitute for a human exhibition review.

## Remaining qualification boundaries and next milestone

The full native suite and original **600 native + 600 Rapier ticks** remain
source-qualified by
[run 41115189216](https://github.com/techrote/sandfall/actions/runs/41115189216).
Its 106,717 contact observations, 149 displacements, pause/menu, save/restore and
reset assertions remain unchanged. The ordinary scene has no active Rapier
bodies; its backend availability does not replace the coupled three-body test.

The six missing companion-workspace references and eight stale desktop
source/runtime digests remain explicit inherited failures. The narrow
reconciliation is permission to qualify a fresh source-matched Web build; it
does not qualify those desktop binaries. No missing files or historical hashes
were fabricated or rewritten.

**Threaded Web:** not executed or qualified in this checkpoint; no environmental
impossibility is claimed. The outstanding gate is an exact-source threaded
export with pinned modules/templates, secure COOP/COEP deployment, actual
cross-origin isolation and worker-policy observations, coupled 600-tick
acceptance, ordinary input/rendering, and retained hashes/logs/screenshots.
Cross-origin isolation in a one-worker compatibility run is not threaded
acceptance. The complete v1 profile matrix remains SF-M5.

**Human visual acceptance:** outstanding; a person must review a Gallery scene's
legibility and pacing before exhibition qualification. Record source/export,
scene, browser/device, reviewer/date and disposition. Automated screenshot
inspection and the inherited bootstrap do not establish final Gallery acceptance.

The executable ordinary-Web CI gates have passed at `86f4c942...`; proceed with the bounded
[SF-M1 host/input-cut plan](../SF-M1-HOST-INPUT-CUT.md). Full MZPaint authoring and
history remain SF-M2, generalized sixteen-body authoring SF-M3, and the portable
`.sandfall` ZIP project archive SF-M4. No broad SF-M1 implementation is part of
this correction. **The owner's PR #2 draft/unmerged hold remains in force.**

## Subsequent SF-M1 implementation handoff

After the owner explicitly requested implementation, the separate stacked
[draft PR #3](https://github.com/techrote/sandfall/pull/3) implemented the dedicated
Sandfall entry and removed inherited actor/launcher authority. At
`bbe72707aa679790b66a143a71c09e7f21570993`,
[run 41139800406](https://github.com/techrote/sandfall/actions/runs/41139800406)
passed fresh dedicated/legacy exports, native/Godot tests, both ordinary-browser
input/rendering cases and the unchanged special 600-tick functional contract.
The [SF-M1 audit](2026-10-30-sf-m1-host-input.md) owns that later source, artifact,
scope and failure ledger. It does not relabel any SF-M0 binary or test result.
The held SF-M0 branch remains `ea96e062ecc54d24d880a8119cb40cf0461c88ad`, and
**PR #2 remains draft and unmerged**. Human visual and additional profile/hosting
qualification remain separate from these executable gates.
