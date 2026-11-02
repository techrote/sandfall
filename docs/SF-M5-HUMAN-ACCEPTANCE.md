---
title: SF-M5 D02 — Human Gallery acceptance
status: Current
document-kind: contract
scope: Executable seven-scene human protocol, candidate-bound review records and explicit pending acceptance
canonical-for: [sandfall-human-exhibition-acceptance]
last-reviewed: 2026-11-01
related-documents: [SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md, SF-M4-PROJECTS-EXHIBITIONS.md, SANDFALL-PROJECT-FORMAT.md]
---

# SF-M5 D02 — Human Gallery acceptance

**Human acceptance is pending.** This document, its validator and its empty
record prepare a review; they contain no human verdict. The
[v1 specification](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#112-evidence-and-publication-wording)
requires genuine human presentation acceptance. Agent image inspection,
automated browser passes and generated screenshots cannot supply it.

The protocol covers the seven existing entries in
[Gallery](../godot/scripts/sandfall/gallery.gd), with their existing
[authored definitions](../godot/scripts/sandfall/scene_definitions.gd).
It changes no scene, UI, solver or acceptance oracle. Machine physics, archive,
worker, performance and full M4 qualification remain independent release gates.

## 1. Prepare a reviewable candidate

The integrating owner prepares an immutable candidate export and its applicable
successful A02/M4 browser receipts. Include D01 measurements so the reviewer
can see requested versus achieved speed and the actual test device. A shared
runner or software-rendered measurement does not establish responsiveness on a
human reviewer's different device.

Use **Compatibility Web** for the mandatory public-delivery review. Record the
actual browser product/version, user agent, platform, URL, native worker request
and observed count. The established viewports are **800×450 DPR1** and
**640×400 DPR2**. Review one exact configuration per record; additional viewport,
browser or threaded results get separate records. The machine matrix must keep
both established viewports. A human result on one configuration has only that
scope. A threaded review must also have actual secure-origin/isolation and
worker evidence; it cannot replace compatibility acceptance.

The final integrated A01 export verifier supplies the candidate identity:

```sh
python3 tools/sandfall/sf_m5_verify_web_artifact.py \
  --web-root "$SF_M5_WEB_ROOT" --expected-build-sha "$SF_M5_CANDIDATE_SHA" \
  --profile compat --output "$SF_M5_CAPTURE_ROOT/artifact-verification.json"
```

The builder below retains the complete exported directory under `candidate/`
in a **new** review bundle, including `SHA256SUMS`, engine/PCK/native/Rapier
assets and notices. Keep the capture directory separate from that destination;
do not precreate the bundle. Preserve
the original verifier, browser, download and image files unchanged. Their
relative locations may change when copied into the bundle; their bytes may not.

For each scene, reuse the existing isolated Gallery capture mode on the exact
candidate. For new captures, supply the **same M5 verifier file** to the browser harness. Each
invocation needs its own clean browser process/profile and terminal capture;
the existing M4 CI lifecycle is the reference. For example, after starting
that isolated browser and the candidate static server:

```sh
node tools/sandfall/sf_m4_browser.mjs \
  --port 9231 --url 'http://127.0.0.1:8040/?test=1' \
  --verification "$SF_M5_CAPTURE_ROOT/artifact-verification.json" \
  --scenario gallery --gallery-entry fluid_messenger \
  --width 800 --height 450 --dpr 1 \
  --output "$SF_M5_CAPTURE_ROOT/fluid_messenger/browser.json" \
  --screenshot "$SF_M5_CAPTURE_ROOT/fluid_messenger/browser.png" \
  --download-dir "$SF_M5_CAPTURE_ROOT/fluid_messenger/downloads"
```

Repeat with each registered scene ID below. Do not reuse a screenshot across
scenes or resume state-changing input in a process after terminal capture has
begun. Keep failed captures and original receipts. A failed machine receipt is
not a suitable passing human-review packet. These generated materials are
visual/provenance aids: the human must also run and interact with the candidate.

Keep one stable candidate server URL for all seven captures while giving each
scene its own browser process/profile. The generic M5 CI runner allocates an
ephemeral HTTP port per invocation; its receipts retain those actual URLs.
This record's single environment must match every scene. Use a persistent
server for packet captures instead of changing receipt URLs after execution.
Current-candidate portraits already produced by the full M4 workflow may be
reused with their **original M4 verifier and original browser receipt digest**.
Retain each original verifier as `SCENE/artifact-verification.json` and supply a
separate passing M5 verifier for the identical delivered candidate. The packet
requires equality of source commit, complete project identity (including tree,
native and Rapier hashes), profile, pins, logical viewport, manifest digest and
the complete artifact path/hash/size inventory. Both verifiers must report no
build-sensitive source drift. The M5 startup contract must match the actual
retained file and all runtime assets. Different tools-only verifier harness
commits remain explicitly recorded in their original receipts. The browser
receipt continues to bind the original M4 verifier SHA; no receipt is rewritten
to claim that the browser consumed an M5 verifier. This combines the existing
browser execution with the additional M5 contract check for the same bytes.
An M4 verifier alone, a historical source or any changed inventory refuses.

The [Web contract](SF-M5-WEB-QUALIFICATION.md) requires HTTPS or a loopback
secure origin for **both** pinned Godot profiles. Compatibility needs no
COOP/COEP headers; threaded execution additionally requires isolation.

After the seven captures exist under `SCENE/browser.json`, `SCENE/browser.png`
and `SCENE/downloads/gallery-SCENE.sandfall-run.json`, prepare a new immutable
review bundle with the actual platform of those browser runs:

```sh
python3 tools/sandfall/sf_m5_human_packet.py \
  --web-root "$SF_M5_WEB_ROOT" \
  --verification "$SF_M5_CAPTURE_ROOT/artifact-verification.json" \
  --captures-root "$SF_M5_CAPTURE_ROOT" \
  --platform "$SF_M5_CAPTURE_PLATFORM" \
  --output "$SF_M5_REVIEW_BUNDLE"
```

The builder copies the verified candidate, manifest, M5 verifier, any original
per-scene M4 verifiers and seven byte-identical browser/image/download sets. It checks their complete
machine bindings and writes `review.pending.json`, `packet-validation.json`
and `packet-build.json`. **Exit 2** means the machine packet is consistent and
the human review remains pending. Every reviewer/criterion/note/decision/
attestation field stays null or pending. Existing output directories refuse;
a failed new preparation retains its original inputs and failed build receipt.
The input candidate directory must contain exactly the verified assets and
manifest, all regular nonsymlink files, both before and after copying. Both
observed inventories are retained. Unlisted files cannot be silently filtered
away to produce a successful packet.
Candidate hashes, changed runtime bytes, historical candidate identities, mismatched
browser conditions and incomplete scene evidence cannot receive a machine
packet success. Reader tests use explicitly synthetic data and are not actual
candidate captures.

## 2. Execute the human review

A real person opens the candidate in the recorded browser, URL and viewport.
Do not substitute a screenshot viewer for live interaction. If the person's
conditions differ from the packet, prepare matching browser evidence and a
separate record rather than copying an earlier environment label.

For every entry, start from the authored initial state, select ordinary **1×**
pacing, and observe the declared self-running behavior. Record actual initial
and final ticks, elapsed wall time, visible behavior and any delay in the notes.
The existing machine reference uses 600 actual ticks; wall seconds are not a
substitute for simulated ticks. The review judges whether causality and timing
are understandable under the measured conditions, without assuming 60 FPS.

Use **Exhibitions**, search by title, launch the scene, and find the time and
navigation controls without undocumented assistance. Pause, Step once, resume,
and try Reset. **Reset & Edit** exposes the authored tick-zero arrangement;
Gallery **Reset** restarts the pristine presentation. Compare the initial
arrangement and labels, then run it again. Navigate to another entry and back.
Check that modal/focus changes leave no unwanted drawing or held input. If an
action stalls or refuses confusingly, record the exact action and visible
message; do not hide it with repeated blind clicks.

| Entry ID / title | Scene-specific observation and interaction |
|---|---|
| `gravity_cascade` — Gravity Cascade | Distinguish falling Sand, ledges, Water and three independent boxes. Follow the gravity-driven sequence into the contained basin. Check that body outlines remain visible against moving material. |
| `fluid_messenger` — Fluid Messenger | Identify the uncontrolled messenger and the surrounding liquid. Watch its displacement and decide whether the liquid/body interaction is visually understandable. The accompanying receipts supply real feedback/motion evidence; human appearance alone does not prove the solver mechanism. |
| `passive_subject_ride` — Passive Subject Ride | Identify the gold-ringed passive subject among three bodies, follow its route and check viewport containment. Confirm that labels communicate the absence of steering. Reset must restore the original subject and arrangement. |
| `endless_kinetic_loop` — Endless Kinetic Loop | Observe three separated rotating boxes. The label must make the idealized zero-gravity, zero-damping initial motion understandable. Judge continuity and legibility without mistaking the authored initial angular velocity for an active motor. |
| `intervention` — Intervention Workshop | Make one deliberate material or body intervention. Locate the sticky **Modified** state, use Reset, and recognize the restored **Pristine** presentation. Check that **Save frozen** and **Evidence** labels do not imply a saved live continuation. |
| `time_controls` — Time Controls | Locate and use Pause, one Step and all five 0.25×/0.5×/1×/2×/4× presets. Judge feedback and responsiveness, including visible slowdowns. Exact fixed-dt/counter assertions remain in the machine receipts. |
| `sixteen_body` — Sandfall 16-Body | Follow the full group into the Water basin and inspect overlaps/body outlines. Try the **Objects → Box** creation tool once at capacity; the refusal must be clear and the scene undamaged. Check Reset and navigation after the refusal. |

At the smaller established viewport, pay particular attention to title/status
wrapping, tool discoverability, overlaid text and the complete body bounds.
Record actual clipping or obstruction, with a source-bound image. Cosmetic
preferences may be notes; a reproducible defect that prevents understanding or
operation is a failed criterion. Do not redesign Gallery content during review.

For each scene, the person explicitly records `pass` or `fail` for all seven
criteria. `null` means unreviewed and cannot qualify a submitted record.

| Record criterion | Human question |
|---|---|
| `visual_legibility` | Can materials, physical objects, subject and relevant movement be distinguished? |
| `interaction_navigation` | Can the reviewer discover the intended controls, move between entries and recover from menus/focus changes? |
| `labels_viewport` | Are titles, overlays, state labels and important objects readable and contained in the actual viewport? |
| `physical_causality` | Does the observed motion communicate the scene's declared physical cause and effect? |
| `pacing_responsiveness` | Are time controls responsive and requested/achieved pacing understandable, including any slowdown? |
| `reset_presentation` | Does reconstruction restore the authored initial arrangement and allow a repeatable presentation? |
| `errors_refusals` | Are unexpected errors/stalls absent and intentional refusals precise, understandable and nondestructive? |

## 3. Record the human decision and bind the evidence

Create an empty record with:

```sh
python3 tools/sandfall/sf_m5_human_review.py template \
  --output "$SF_M5_REVIEW_BUNDLE/review.json"
```

The committed [pending record](../tools/sandfall/sf_m5_human_review.pending.json)
has no candidate, reviewer, judgment or attestation filled in. The
[closed schema](../tools/sandfall/sf_m5_human_review.schema.json) specifies every
field. An agent may populate **machine-observed** candidate/environment and
file-reference fields; it must leave human names, findings, decision and
attestation unfilled until that person actually supplies them.

File references contain `path`, `sha256` and `bytes`; all paths are canonical
relative paths inside the retained bundle. `candidate.verification` names the
passing verifier file. `candidate.artifact_directory` names the copied export.
Source commit/tree/profile come from its exact identity. Environment values
must match the original isolated browser receipts, without changing those
receipts to fit a new review. Each scene references its own browser JSON,
completed PNG capture and downloaded Run-evidence JSON.

Before any human fields are supplied, validate a complete machine-populated
pending record with:

```sh
python3 tools/sandfall/sf_m5_human_review.py packet \
  --record "$SF_M5_REVIEW_BUNDLE/review.pending.json" \
  --bundle-root "$SF_M5_REVIEW_BUNDLE" \
  --output "$SF_M5_REVIEW_BUNDLE/packet-validation.json"
```

This command performs the same candidate, scene, image, download and condition
checks without inventing a reviewer or verdict. It requires all human fields
to remain empty and returns **2**, `machine-evidence-bound-human-pending`.
The basic `validate` command still returns `pending-human-review` for an
uncompleted template; that result alone does not verify its machine evidence.

The reviewer supplies their name or stable review identity, UTC `reviewed_at`,
live-browser mode, per-scene findings and concrete notes. An overall `accept`
requires every criterion to pass. Any failed criterion requires `reject` and
retained explanation. Unfinished work stays `pending`, with a null decision.
When the person has completed all findings, set status to `submitted` and
compute the complete payload digest:

```sh
python3 tools/sandfall/sf_m5_human_review.py digest \
  --record "$SF_M5_REVIEW_BUNDLE/review.json" \
  --bundle-root "$SF_M5_REVIEW_BUNDLE" \
  --output "$SF_M5_REVIEW_BUNDLE/signing-request.json"
```

This verifies all evidence and returns **exit 2**, explicitly awaiting the
human statement. The external statement must contain these three separate
lines, with the reviewer's actual name and returned digest:

```text
I personally ran and reviewed all seven Gallery scenes in the recorded browser conditions.
Reviewer: <actual human review identity>
SF-M5 review payload SHA-256: <record_payload_sha256 from signing-request.json>
```

The person supplies that statement through an identifiable original user
message, review comment or signed file. Preserve its exact text and origin
locator; fill `attestation` with that origin and the statement's file reference.
Do not manufacture the statement from an agent's assessment. The digest covers
the source, conditions, evidence and all findings; only the external attestation
locator/hash is excluded to avoid a self-hash cycle. Any later change to findings
or evidence requires a new human-bound statement.

```sh
python3 tools/sandfall/sf_m5_human_review.py validate \
  --record "$SF_M5_REVIEW_BUNDLE/review.json" \
  --bundle-root "$SF_M5_REVIEW_BUNDLE" \
  --output "$SF_M5_REVIEW_BUNDLE/validation.json"
```

| Outcome | Exit / meaning |
|---|---|
| `pending-human-review` | 2; no human acceptance |
| `machine-evidence-bound-human-pending` | 2 from `packet` or the builder; complete machine/file bindings, every human field still empty |
| `evidence-bound-awaiting-human-statement` | 2 from `digest`; no human acceptance |
| `invalid-review-record` | 1; incomplete/inconsistent evidence or absent/incorrect attestation |
| `complete-rejected-human-record` | 1; complete explicit human rejection, retained as negative evidence |
| `complete-accepted-human-record` | 0; record/file consistency is complete; the owner must authenticate the original human source |

The validator deliberately reports `human_origin_authenticated: false` and
`release_ready: false` in every case. Software cannot prove that a JSON author
is a person. The integrating owner must verify that the attestation actually
came from the named human and record that association in R01. Copying a
synthetic unit fixture or writing `kind: human` does not meet D02.

## 4. Preservation and release disposition

Keep the original human response, review record, validation output, all seven
browser/image/Run-evidence sets, exact candidate export and verifier receipt
together. Retain D01 measurements and any rejected review alongside subsequent
corrections. A new source/runtime/hosting/browser condition needs an explicit
review-scope decision and fresh applicable machine evidence; do not silently
move the old human verdict to new bytes.

Run the validator's synthetic refusal tests with:

```sh
python3 -m unittest tools.sandfall.test_sf_m5_human_review -v
```

Those tests validate the record reader only. They are neither browser execution
nor human acceptance. Until a genuine review and authenticated original verdict
exist, D02 remains an explicit owner-dependent outstanding gate. Machine-verifiable
engineering can continue. A recorded human acceptance also cannot waive failed
physics, archive, worker, provenance, performance or exact-head release gates,
and it does not authorize a v1.0 tag or publication.
