# SF-M0 ordinary Web input and rendering — 30 October 2026

**Disposition:** the original coordinate/input blocker is reproduced from its
retained evidence and corrected in the browser harness. The unchanged, verified
compatibility export passes a local real-Chrome run. Exact committed CI results
are recorded below when available. **PR #2 remains draft and unmerged.**

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

Pending the first push of this correction. Record actual harness commit, run,
job and artifact IDs here after terminal results; do not treat queued jobs or
draft workflow skips as passes.

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

**Threaded Web:** no new source-matched threaded build/browser matrix was run in
this checkpoint. Cross-origin isolation in a one-worker compatibility run is
not threaded acceptance. **Human visual acceptance:** outstanding; a person
must review scene legibility and pacing before exhibition qualification.

After the executable ordinary-Web CI gates pass, proceed with the bounded
[SF-M1 host/input-cut plan](../SF-M1-HOST-INPUT-CUT.md). Full MZPaint authoring and
history remain SF-M2, generalized sixteen-body authoring SF-M3, and the portable
`.sandfall` ZIP project archive SF-M4. No broad SF-M1 implementation is part of
this correction. **The owner's PR #2 draft/unmerged hold remains in force.**
