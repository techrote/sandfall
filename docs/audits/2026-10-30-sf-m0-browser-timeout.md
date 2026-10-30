# SF-M0 — Browser timeout and imported-CI provenance, 2026-10-30

**Status: Investigating; original browser qualification FAILED. No full Web/Rapier acceptance, no clean inherited documentation check and no merged PR.**

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
