# SF-M0 — Browser timeout and imported-CI provenance, 2026-10-30

**Status: Original 240-second run failed; a separately source-matched frozen-artifact 600-tick browser requalification subsequently PASSED. Exact-latest-HEAD Web rebuild, full release/provenance clearance and PR merge remain separate gates.**

## Actual retained browser evidence

Original exact-source run: [GitHub Actions #41108783470](https://github.com/techrote/sandfall/actions/runs/41108783470), at Sandfall commit
**5a2f6868aa8dbcb10febc6d3af2a2debfa246c18**. Artifacts: **13004085194**,
name **sandfall-sf-m0-compat-web**, SHA-256 of artifact ZIP
**c329b402795cfaca1c1cdfc0ed7be30d6a2d543ef0815c37517a1a68beed90e4**.
Retained files: exported Godot files, build-info.json, SHA256SUMS, browser.json,
browser.png, chrome.log, http.log and web-reconciliation.json. This is a
source-matched *export artifact* and actual browser startup, not an accepted
600-tick physical result.

### Proven observations

1. **Compilation/export passed** at source 5a2f686: native no-thread WASM SHA-256
   **26b9f8dfd35a82692ecdb716aa688dd8f485ab10174fe4526c8cfe9a43729185**,
   4,245,483 bytes, Godot 4.7 stable, Emscripten 4.0.20, Rapier 0.35.2 compatibility
   WASM SHA-256 **5ff6933670c1377c24dcbac30d67758a307165eacdcbd33b25bf01669577c4c2**.
   All expected exported files existed and the published build-info source SHA matched.
2. Real HeadlessChrome 156 on Linux reached Godot 4.7 and WebGL 2.0 startup. Captured
   console events include **PHYSICS ENGINE 2D: Rapier2D v0.35.2**,
   **WEB_RAPIER_PROBE {"ok":true, "reason":"Manual-step/CCD probe passed"...}**,
   **WEB_CPP_EXCEPTION_PROBE true**, and **WEB_DEMO_READY ... COMPAT · 1 WORKERS · RAPIER2D**.
   The capability/backend did **not** fail to register.
3. HTTP log shows **200** for page, index.js, PCK, base and side WASM, native side WASM,
   Rapier WASM and audio worklets. Cross-origin isolation was **true** in the captured
   browser metadata.
4. The CDP harness timed out before any terminal **WEB_RAPIER_TEST** / DOM
   **rapier_test** result. Its screenshot displayed **PHYSICS PIT** and a black viewport,
   with the in-app status showing **tick 0** at capture. This locates the unproven
   behavior *after* bootstrap, but does not isolate the exact stalled function.
   The test explicitly disables ordinary _process() and _physics_process()
   dispatch and manually advances the host; an unupdated rendering viewport in
   this diagnostic is **not itself evidence** that normal gameplay rendering is black.
5. The initial CDP harness only published a final state after the full 600-tick
   coroutine. Its **state=null** after timeout was wrongly expanded into several
   apparent startup failures. The **startup proof above supersedes that diagnostic
   interpretation**, but the 600-tick physical acceptance remains failed/unproven.

### Probe-only corrective work

- Add read-only SF-M0 **phase and tick progress** to the opt-in
  godot/scripts/web_rapier_probe.gd: before/after Physics Pit selection,
  hard-terrain collider-drain progression, before/after first and every
  twentieth native/Rapier step, save/restore and final cleanup.
- Update tools/sandfall/sf_m0_browser_probe.mjs to capture these phases, bound
  individual CDP calls, and distinguish confirmed startup from missing terminal
  native-body evidence; report last observed phase/tick without guessing.
- **Do not** weaken 600 actual ticks, positive native contacts/displacement,
  pause safety or save/reset requirements; do not mark green on startup-only evidence.
- Candidate rerun: SF-M0 compatibility Web qualification workflow on the new exact
  branch HEAD. Its actual outcome must be recorded separately after publication.

## Documentation checkout failure and inherited negatives

The imported CyberSand **.github/workflows/documentation.yml** tried to check out
companion-workspace commit **6a58311982941b75f46e22109a0829e5acb83c7e**
from the **Sandfall** repository, giving GitHub "upload-pack: not our ref".
This is a checkout error, *not* a failed source/provenance test result.

Sandfall's active documentation workflow is changed to check out the **actual
Sandfall PR head** with full history and then run independent source ancestry,
CI provider-policy and strict reconciliation. The immutable CyberSand parent
retains the original workflow and all its history.

The original documentation checker retains **six missing-workspace references**
(Q01 SOURCE-PROVENANCE.json, Q04 WEB_THREADING.md, Q28/Q29 tools/dev.py and
docs/LOCAL_DEVELOPMENT.md, Q30 validation/browser-results.json).
The original repository provenance check also retains **eight stale Linux/Windows
desktop source-input digests**. Sandfall's narrow, exact-error allowlist:
tools/sandfall/sf_m0_reconcile.py. It executes the real inherited checker and
records **the complete failure output**; it does **not** fabricate missing files,
rewrite source hashes, claim that desktop binaries are fresh, or remove those
negative observations. A new/changed/unexpected error must fail.

The full source-native make test on run #41108783470 made substantive passing
progress but exited **124** when its **900-second timeout** expired. This is
**incomplete coverage**, not a negative native assertion and not a pass.
The subsequent workflow enlarges the timeout separately; its exact-head result
is still required.

## Outstanding gates and no-merge rule

- Fresh, phase-instrumented browser proof and actual 600 coupled ticks.
- Strict PR-head documentation workflow with attached original checker failures,
  and source/native checks with completed or correctly scoped coverage.
- Review browser screenshot, commands, CPU/renderer constraints, body and collider
  outcomes as actual evidence, not inference.
- PR #2 stays **DRAFT / UNMERGED** until exact-head CI and actual browser/manual
  qualification justify promotion.

## 2026-10-30 — Actual 600-step progress vs original wall-clock budget

On [SF-M0 run #41111665444](https://github.com/techrote/sandfall/actions/runs/41111665444), source **98722560be89ccc3ab84eb3d526c5dde99c5cab0**, the compatibility Web export and native/Rapier startup checks succeeded. Actual browser CDP phase markers recorded simultaneous advancement of native and Rapier state from tick 41 through **tick 541 / Rapier steps 541**. The final record at elapsed **235,834 ms** was phase **tick-after** at loop index 540, with **pending_colliders=0**, **rapier_initialized=true**, **paused=false** and **menu_open=false**. No stop in physics progress was demonstrated; the **240,000 ms browser harness deadline** truncated the test before the required 600 ticks, and screenshot capture also timed out while the renderer was busy. Artifact: **13003989008**, ZIP SHA-256 **d6596493e321329bd49ae3e13cd72b4cc93fb20711d639dde16a3f2611dfbd51**.

**Corrective action:** increase the browser harness wall-clock deadline to **720,000 ms** (12 min), retain its 90-second no-progress watchdog, and leave the **600 actual native+Rapier ticks, body/terrain contact, positive displacement, pause, save/import and reset proof requirements unchanged**. A changed timeout **does not count as passing evidence**. Await exact-head terminal browser results.

The inherited complete native `make test` suite separately timed out on prior 900-second runs while producing passing subgroup results. Extending its independent fixed bound to 2400 seconds is not a test bypass; a complete exit-0 is still required to claim full-suite acceptance. Scoped native smoke [run #41111311098](https://github.com/techrote/sandfall/actions/runs/41111311098) passed on the separately scoped triage branch and is **not** a substitute for the full run at this branch head.

The strict Sandfall documentation/reconciliation check had already passed at **4d3e7f4b8e592a363d3bbccfc22ede3404ab2026** ([run #41111990171](https://github.com/techrote/sandfall/actions/runs/41111990171)), retaining all six missing-workspace references and eight historical desktop runtime/source digest mismatches. The user has prohibited merging PR #2 while browser qualification remains red.

## 2026-10-30 — Exact preserved Web binary passes the full 600-step browser fixture

**Successful independent browser retest:** [Actions run #41115365746](https://github.com/techrote/sandfall/actions/runs/41115365746), workflow source **761ad79b000df6ee3d185e2238160c4d75bcf12b**. The runner downloaded **immutable previously built Web artifact #13003989008** from failing [run #41111665444](https://github.com/techrote/sandfall/actions/runs/41111665444), verified its archive SHA-256 **d6596493e321329bd49ae3e13cd72b4cc93fb20711d639dde16a3f2611dfbd51**, and checked every one of **18** exported SHA256SUMS entries. Original Web export was constructed from source **98722560be89ccc3ab84eb3d526c5dde99c5cab0** (Rapier2D v0.35.2; compatibility/one worker). Retest did **not** rebuild or silently relabel that binary as latest-HEAD output.

**Actual HeadlessChrome 156 / Linux / Web runtime observations:**

| Proof | Actual observation |
|---|---|
| Browser, Rapier WASM, native C++ capability and exception preflight | All six startup flags true |
| Full coupled physics fixture | `rapier_test.ok: true`; 600 of 600 native/Rapier steps |
| Native material/body contacts | **106,717** |
| Native material displacements | **149** |
| Maximum floor-body centre Y | **160.317276**, below admitted limit **161.0** |
| Pause/menu / save-import / reset fixtures | No reported failures; complete fixture returned `failures: []` |
| Thread profile | Compatibility, **one native worker** |
| Wall-clock progress | SF-M0 completion phase at **210,288 ms**; terminal evidence retained |
| Result artifact | [#13004833328](https://github.com/techrote/sandfall/actions/runs/41115365746/artifacts/13004833328); SHA-256 **8b4736759f8f8859bcdde625239255a2c2bccb76dee9d122a7867cce5de7460b** |

This **decisively demonstrates the original red Web result was caused by an insufficient 240-second harness budget on a slow software-rendered browser**, not by a physics deadlock in that exact binary. The retest retained the 600-tick, positive-coupling and save/restore acceptance tests, with the unchanged 90-second no-progress guard. The result does **not** prove a new binary built at subsequent Sandfall commits, a visual pixel-appearance gate, threaded Web, 16-body capability or full cross-platform determinism.

**Native:** The previously unfinished [run #41111665444](https://github.com/techrote/sandfall/actions/runs/41111665444) later reported **164 native tests passed**, full native job success, on source **98722560be89ccc3ab84eb3d526c5dde99c5cab0**. The workflow overall remained red only because its prior 240s browser job failed. In retest #41115365746, the **current-head scoped native smoke passed** separately; it cannot substitute for the complete native suite at a newer exact HEAD.

**Docs:** Active Sandfall documentation/provenance passed on [run #41111990171](https://github.com/techrote/sandfall/actions/runs/41111990171) and later heads, under the explicit six inherited absent-workspace and eight stale desktop-runtime error reconciliation. They were recorded, not rewritten as historical passes.

**Hold:** PR #2 stays draft/unmerged, and the new source-built Web workflow with the corrected wall-clock budget is independently required for latest-source qualification. Do not promote a source-matched frozen artifact result into a stronger release or physics claim.
