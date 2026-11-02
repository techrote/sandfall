---
title: Sandfall v1.0 candidate release notes — unpublished draft
status: Current
document-kind: audit
scope: Candidate features, delivery contract, evidence limits and unfilled final artifact identities
canonical-for: []
last-reviewed: 2026-11-02
related-documents: [SF-M5-RELEASE-LEDGER.md, SF-M5-WEB-QUALIFICATION.md, SF-M5-HUMAN-ACCEPTANCE.md, SANDFALL-PROJECT-FORMAT.md, SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md]
---

# Sandfall v1.0 candidate — draft release notes

**Unpublished and untagged. This draft is not a v1.0 release announcement.**
The candidate decision is **NO-GO**. D01 and A01/A02 exact-head qualification and repeated Web-profile measurements have passed, but final combined D02/R01 qualification, source-bound release artifacts and genuine human Gallery acceptance remain open.
The [release ledger](SF-M5-RELEASE-LEDGER.md) owns the exact evidence and current
integration state. Publication or a v1.0 tag requires separate explicit owner
authorization after those gates are resolved.

## What the candidate contains

Sandfall is a zero-player material and rigid-body sandbox. You author an
initial arrangement, run the native material simulation with coupled Rapier
boxes, observe its behavior, and reset or prepare another initial project.
There is no human/AI actor motor, movement, weapon or jetpack authority.

- **Separate Edit and Run.** Edit stays at tick zero. Material/state/temperature
  tuples, brush footprints, fill, selection and object edits participate in
  exact authored Undo/Redo. Run freezes the authored initial document; the
  first advancement of either solver retires its history, including partial
  coupled failures. Pause or speed changes do not restore that history.
- **Fixed-step physical execution.** Pause stops advancement and Step requests
  one fixed 1/60-second update. The five 0.25×/0.5×/1×/2×/4× presets change
  pacing. Native materials evolve through their actual rules, and native
  contact/displacement feedback acts on real main-thread-owned Rapier bodies.
- **A stable-ID workshop with sixteen-body capacity.** Author, inspect, edit,
  duplicate, delete, save, reconstruct and reset 0–16 coupled boxes. A
  seventeenth body refuses before mutation. A passive subject is an ordinary
  uncontrolled box within the same capacity.
- **Truthful session state.** In Run, Pristine tracks intervention provenance;
  natural solver evolution can remain Pristine. Accepted physical
  interventions make Modified sticky. Fault exposes partial effects and actual
  solver counters without pretending that a failed coupled tick rolled back.
  Reset reconstructs initial cells and body definitions, including velocities.
- **Portable projects and separate Run evidence.** `.sandfall` is an ordinary
  ZIP containing a structured `project/` folder. The staged loader checks
  bounded input, schema, hashes, materials, policies and object parameters
  before replacing the old session. Independently authored ZIP/folder
  interoperability and actual browser upload/download are retained.
- **Seven curated Gallery scenes.** Gravity Cascade, Fluid Messenger, Passive
  Subject Ride, Endless Kinetic Loop, Intervention Workshop, Time Controls and
  Sandfall 16-Body demonstrate the existing material/object mechanisms. Their
  machine receipts include physical feedback, motion and reset evidence.
  Human exhibition acceptance remains pending.

These features are mapped to actual production owners and executable tests in
the [v1 matrix](SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md#111-executable-test-matrix),
[workshop contract](SF-M3-RAPIER-WORKSHOP.md),
[project/Gallery contract](SF-M4-PROJECTS-EXHIBITIONS.md) and release ledger.
Their accepted M0–M4 evidence retains its original source; new candidate changes
must pass the applicable exact-head and post-merge gates.

## Saving, evidence and promotion

**Save preserves the authored initial project**, including during an evolved
Run. It is not an exact live-state continuation file. Native transient
occupancy/feedback, Rapier internals and future solver history are outside the
portable initial-project format.

**Run evidence** is separately identified. It records source/runtime identity,
initial project identity, actual ticks and observed physical outcomes, ordered
interventions and the absent actor-control trace. It supports inspection of a
particular execution; it does not promise whole-stack deterministic replay.

**Apply interventions to a new draft** requires an explicit preview and
confirmation. Only supported reconstructible interventions can be promoted.
The result is a new paused tick-zero Edit document, not an automatic promotion
of arbitrary evolved physics. The [format reference](SANDFALL-PROJECT-FORMAT.md)
defines those boundaries and the archive limits.

## Web delivery and hosting

| Profile | Runtime contract | Host requirements |
|---|---|---|
| **Compatibility Web — mandatory delivery** | One native worker, Rapier included, synchronous Godot ownership | **HTTPS or loopback secure origin**; no COOP/COEP or SharedArrayBuffer dependency |
| **Threaded Web — additional delivery** | Existing native worker pool; explicit 1/2/4/6 or `auto` request; configured and participating workers reported separately | Secure origin, COOP `same-origin`, COEP `require-corp`, supported Worker/SharedArrayBuffer capabilities and complete matching assets |

The pinned Godot 4.7 engine requires a secure origin for both profiles. An
actual non-loopback insecure-HTTP compatibility attempt failed in the engine;
its original evidence is retained and the shared preflight now refuses that
host explicitly. Compatibility's real loopback execution passed with isolation
and SharedArrayBuffer unavailable. This distinction is part of the supported
hosting contract.

Serve one complete profile export directory, including its manifest, engine,
PCK, native WASM, Rapier and worker-related resources. Use correct MIME types
and the generated relative resource paths. Missing/corrupt bytes, hash
mismatches, unavailable runtime assets, unsupported worker requests and missing
threaded isolation must give a precise refusal. Silent fallback cannot qualify
the threaded profile.

For a local Compatibility export, run its included server from that export
directory and open the reported loopback URL:

```sh
python3 serve_web.py --directory . --port 8040 --isolation off
```

For the separate Threaded export, use `--isolation on`. The included
`Caddyfile.example` documents a reproducible HTTPS static-host configuration.
Actual public Caddy deployment is unqualified until executed. See the full
[Web qualification contract](SF-M5-WEB-QUALIFICATION.md) for source verification,
worker policy, MIME and negative cases.

## Evidence and current limits

The accepted baseline has an independently reviewed 36-job M4 candidate run
and actual merged-main Native, Linux/Godot, Documentation/provenance and
15-job routine Web qualification. New local scientific work adds five-preset
fixed-dt accounting, chemical/thermal history, repeated owner replacement,
Fluid Messenger controls and selected Golden Run comparisons. Actual browser
chemistry has passed both established viewports on explicitly identified
Compatibility and Threaded source exports. These earlier sources do not
substitute for the final candidate's complete same-source matrix.

Actual browser evidence so far uses **Chrome for Testing 156 on Linux**, with
800×450/DPR1 and 640×400/DPR2. Other browser engines remain unqualified. A
configured native pool does not imply every worker participates in every small
fixture; receipts preserve actual observed counts.

**60 Hz is the fixed simulation-step design, not an unconditional 60 FPS or
achieved-rate promise.** Production measurement machinery records tick rates,
latency distributions, Rapier/collider work, rendering/frame intervals, backlog
and available resource observations. Final repeated browser measurements and
their registered acceptance disposition remain required. Slowdown must remain
visible without changing dt, dropping required physics or reducing capacity.

Selected repeated Linux fixtures are locally outcome-qualified within stated
numerical tolerances. Whole-stack bitwise replay, exact live-state continuation
and cross-browser equivalence are not claimed. Linux internal regression
execution does not establish a published desktop product; optional Windows,
serial-equivalence and stress lanes retain their documented triggers and any
skipped state. A Web-only release does not acquire an optional desktop gate.

The [human review protocol](SF-M5-HUMAN-ACCEPTANCE.md) prepares seven
candidate-bound Gallery receipts and requires a genuine person's live review.
The packet builder and validator leave every human field pending. Technical
image analysis, synthetic reader tests and record consistency cannot supply
that verdict or authenticate its origin.

### Engineering integration checkpoint — 2 November 2026

Accepted main now contains D01 merge `4cb478bc895d6eb7a6506526df9b93cf60c276b2`
and A01/A02 merge `d40c55d3fc15cbbacb3bd158524f791db9f319b8`.
The latter preserves exact qualifying head `ea000324809ae304a20495a139f4dae5ce0fd83f`
and its [71/71-job full M5 pass](https://github.com/techrote/sandfall/actions/runs/41375737208).
Earlier source checkpoints and failed browser receipts remain historical
evidence, not approvals for the current candidate. The combined D02/R01
candidate must be independently qualified at its new source head. Human
Gallery fields remain empty; no tag or release is authorised.
## Candidate artifact and release slots

Guarded main has reached B01 merge `2a9d9d7952f554a12092abf607e63a18b398f930`;
its own post-merge checks remain pending. The later engineering stack includes
published application/build source
`05fb7ee86a592ff4557cdf165e02a478824e4c54` and the later tools-only head
`742b730b855650118acd6b6aa1eaffcf9f3e6a1a`. Their identities remain distinct.
The original full `05fb7ee` workflow failed browser custody and M2 first-control
readiness checks. Narrow independently reviewed tooling corrections have
separate actual execution evidence; current-head CI is still required.
The final integrating owner must fill this table from actual retained outputs
after qualification. No candidate version tag or download URL is invented.

| Release record | Required value | Current status |
|---|---|---|
| Final reviewed source / tree and resulting main | Exact immutable commits and guarded merge | Pending final integration |
| Compatibility candidate package | Download location, bytes, archive SHA-256, complete verifier/manifest and PCK/native/Rapier identities | Pending final candidate qualification |
| Threaded candidate package | Separate download/identity, complete worker assets and qualified hosting/worker scope | Pending final candidate qualification |
| Full CI and runtime receipts | Applicable exact-head and post-merge Native, Linux/Godot, Documentation/provenance, preserved 36-job M4 and M5 profile matrix | In progress; see ledger for each original disposition |
| Performance record | Repeated source-bound measurements, device/browser/workers/duration, distributions/outliers and acceptance disposition | Executed at #12 head; final-candidate disposition pending |
| Human Gallery record | Original genuine human response, bound evidence and owner-verified origin | Outstanding |
| Release/tag authorization | Separate explicit owner authorization | Not granted |

Dependency pins remain Godot **4.7.stable.official.5b4e0cb0f**, Godot Rapier
addon **0.35.2** (its locked `rapier2d` crate is separately identified as
**0.35.1**), godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`, Emscripten
**4.0.20** and SCons **4.10.1**. Candidate packages retain the dependency
licenses, notices and exact runtime provenance. Their final hashes belong in
the completed release record, alongside any remaining limitations.
