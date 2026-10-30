---
title: Sandfall v1 — Architecture, UI/UX and Implementation Specification
version: "1.0"
status: "Approved design contract; implementation pending"
owner_decisions_date: "2026-10-30"
upstream_repository: "techrote/cybersand"
upstream_commit: "1d376fb38ff5df83691e468baa0639270a5f40e6"
reference_repository: "techrote/specdocz"
reference_commit: "039008723172a951c7694079cd06c7a2ea137d40"
---

# Sandfall v1 — Architecture, UI/UX and Implementation Specification

**Status:** Approved requirements for implementation, NOT an assertion that Sandfall features are built or qualified. **MUST** = mandatory, **SHOULD** = default requiring an explicit exception to depart, **MAY** = optional. The milestone plan distinguishes initial bootstrap from full v1 acceptance.

**Purpose:** A browser-first, interactive, zero-player CyberSand exhibition and editor. “No input” applies **only to player/actor locomotion and action controls**. Painting, object spawning/manipulation, simulation time, camera, and all UI controls remain available.

## Contents

1. **Authority and owner decisions** — Immutable references, source precedence and all twelve selections plus clarifications.
2. **Product, entry points and scope** — Gallery/Sandbox workflows, passive subjects and zero-player classifications.
3. **Architecture and simulation ownership** — Authoring authority, native cell/Rapier boundaries, UI composition and tick sequencing.
4. **Edit/Run lifecycle and undo** — Mode transitions, first-tick history cutoff, reset and safe promotion of interventions.
5. **MZPaint-tailored painting and UI** — Precision-first material tools, cosmetic layering, input and presentation policy.
6. **Rapier objects and sixteen-body scope** — Editable boxes, passive subjects, dynamic coupling and capacity qualification.
7. **Time, camera and input** — Fixed physics steps, five speed presets, viewport independence and focus safety.
8. **Golden runs and zero-player demonstrations** — Pristine/Modified identity, journals, demo classes and replay evidence.
9. **Portable .sandfall projects** — Standard ZIP containing a project folder, schema, integrity and transactional import.
10. **Web packaging and performance** — Frozen dependencies, compatibility/threaded builds and truthful targets.
11. **Acceptance and evidence** — Browser/physics/editor/ZIP tests, negative cases and scientific limitations.
12. **Implementation sequence and source map** — Dependency-ordered delivery and reuse of exact CyberSand files.
13. **Deferred work and revision control** — Explicit non-goals and decisions requiring new owner authority.

---

# 1. Authority and owner decisions

## 1.1 Pinned sources and precedence

| Input | Immutable pin | Role |
|---|---|---|
| [CyberSand](https://github.com/techrote/cybersand) | **1d376fb38ff5df83691e468baa0639270a5f40e6** (2026-10-25) | Engine/Web/Rapier reference, not moving main |
| [MZPaint](https://github.com/techrote/specdocz/tree/039008723172a951c7694079cd06c7a2ea137d40/uiuxs/mzpaint) | **specdocz 039008723172a951c7694079cd06c7a2ea137d40** | Reusable normative UI/UX contract, tailored for Sandfall |
| **mzpaint-implementation-spec.md** | Same specdocz pin | Nonmandatory implementation pattern library |
| [Zero-Player Level study](https://github.com/techrote/specdocz/tree/039008723172a951c7694079cd06c7a2ea137d40/gametypes/zeroplayerlevel) | Same specdocz pin | Research reference; only explicitly adopted requirements are normative |
| [Sandfall](https://github.com/techrote/sandfall) | Project-specific files/decisions | Owner of this contract and new implementation |

The newer specdocz commit **586381fda63821a3a96df425d51244e52eb58988** did not alter these two referenced directories; the previously agreed **0390087** pin is retained. Do not silently track subsequent main revisions.

Precedence: applicable safety, security, licence and proven engine ownership constraints; explicit Sandfall owner decisions; **this project-specific spec**; MZPaint reusable specification; adopted implementation patterns; non-normative zero-player research. Disagreements must be resolved in an explicit Sandfall change record rather than by pretending that a general UI reference supersedes physics contracts.

## 1.2 Final owner decision ledger

| ID | Owner selection | Sandfall requirement |
|---|---|---|
| SF-D01 | 1A | **Separate Edit and Run**; Run interventions are temporary, with explicit safe promotion to new authored state |
| SF-D02 | 2B | **Optional passive subject**, moved by the world, not a human/AI locomotion controller |
| SF-D03 | 3B | **Gallery autoplay** after readiness; editor/Sandbox starts **paused** |
| SF-D04 | 4A | **Precision-first painting**, with palette, brushes, erase, fill, lines, rectangles, picker, selection and Edit history |
| SF-D05 | 5A | **Layered hybrid**: semantic material mutations plus a separate decorative/presentation layer; seeded material spray allowed |
| SF-D06 | 6A | **Canvas-first UI**, collapsible left tools, contextual right inspector, bottom time/status |
| SF-D07 | 7A | **Basic Rapier editor**, box spawn/move/rotate/resize and mass, friction, restitution, damping |
| SF-D08 | 8B | Qualify **16 simultaneous coupled bodies** (passive subject counts if Rapier-backed) |
| SF-D09 | 9A | Pause/one-tick Step plus **0.25×, 0.5×, 1×, 2×, 4×** pacing with unchanged fixed dt |
| SF-D10 | 10A revised | **.sandfall is an ordinary ZIP file containing the structured project folder** of option B |
| SF-D11 | 11A clarified | **Undo/redo is Edit-only at tick zero; one completed physics tick invalidates history for that run** |
| SF-D12 | 12A | **Gallery + Sandbox**, curated searchable demos and a blank authoring canvas |

These are design obligations even when implemented in later v1 milestones. Do not weaken SF-D10 by inventing a proprietary archive wrapper, or SF-D11 by applying inverse edits to evolved chemical/thermal state.

# 2. Product, entry points and scope

## 2.1 Gallery and Sandbox

**Gallery** lists curated demos by physics mechanism/material/complexity. Launch builds the complete initial material state, Rapier space and hard-terrain colliders; only after readiness does it autoplay. The viewer retains paint, erase, camera, pause, step, speed, spawn, inspect, delete and reset. A modifying operation switches the run to **Modified** but never disables those tools.

**Sandbox** opens a blank or selected template in **Edit at tick 0, paused**. Author materials and objects, save the project, then select Run to freeze and simulate a revision. The UI must clearly show mode, tick, and whether the run is pristine or modified. A fresh editor launch does not secretly tick the simulation.

## 2.2 Demonstration classes

- **zero_input:** a passive subject can reach a goal or a physical outcome with neutral/absent actor controls.
- **kinetic_sandbox:** the material/rigid-body world itself is the subject; no win condition is necessary.
- **triggered_automatic:** an openly disclosed one-shot initiation, then a no-control sequence.

A passive subject is an identifiable, uncontrolled physical token/box/body; it MAY be rendered as a character-like figure but MUST NOT acquire movement/jetpack/weapon/other actor-input authority. Human-driven or AI-driven motor actors are **not** v1 zero-player modes. “Press Forward / hold-right”, hidden scripted steering and purely cinematic pose teleports must not be mislabeled zero-input physics. Declared environmental triggers are allowed; claimed real material/rigid-body contacts must actually arise from the solver.

Authoring, camera, decorative annotation, menus and time manipulation are **not** actor inputs. The input gate must enforce this before forwarding to inherited engine controls, not just hide the old buttons.

## 2.3 Core workflow

1. Launch Gallery (autoplay when ready) or Sandbox (Edit, paused).
2. In Edit, alter an initial material/body definition with exact tools and undo.
3. Run freezes an **immutable authored revision** and constructs a fresh World/Rapier session.
4. Observe freely or intervene with physical edits. Accepted interventions mark Modified and are journalled.
5. Reset reconstructs the immutable authored initial state (not a selected live snapshot).
6. **Reset & Edit** explicitly discards the evolved run and returns to tick-zero authoring with a new history.

# 3. Architecture and simulation ownership

## 3.1 Logical components

~~~text
Godot Control UI / SandfallToolRouter
  ├── Gallery, materials, brush tools, object inspector, time/status
  ├── SandfallAuthoringDocument (authoritative editable initial state)
  ├── SandfallSessionController (Edit/Run/Modified/Fault, ticks)
  ├── SandfallArchiveCodec (ZIP/folder, staged validation)
  └── SandfallRunEvidence (receipts, hashes, interventions)
          │ typed, validated commands at safe ownership boundaries
          ▼
  SandfallSimulationHost (single authoritative Godot owner)
          ├── CyberNativeCellWorld (material IDs, state, temperature)
          ├── CyberRapierPhysicsBridge (real independent bodies)
          └── immutable render snapshots / material shader
                    + independent cosmetic/annotation overlay
~~~

This is a responsibility diagram, not a mandate to duplicate the native engine. The authoritative material World, rules, physical backend and copied render publication are preserved, not imitated in JavaScript.

**Authoring Document** owns initial logical cell tuples, authored object definitions, initial solver/config/seed, camera, optional passive subject, decoration and scene metadata. It does not point into mutable live Rapier RIDs or a live native World.

**Session Controller** owns mode, frozen revision/hash, current generation/tick, speed, pause, pristine/modified/fault state and intervention journal. Retired generation commands must refuse. Browser input and UI buttons invoke this authority; they do not directly mutate Rapier server internals.

**Simulation Host** validates/queues editing and live commands and exclusively sequences material state, Rapier manual stepping, native solver and publication. Native pool threads MUST NOT call Godot/Rapier APIs. Rapier bodies remain independent of stored material; transient body occupancy and native bounded feedback implement coupling.

**Render Bridge** reads copied render data. Material identity controls the native material style mapping; local decorative colour is not a replacement source of material semantics.

## 3.2 Fixed-tick sequencing and failure boundary

Preserve the documented **Web synchronous owner**, including pending static-terrain collider fences. The baseline applies eligible previous native feedback, manually steps Rapier, publishes packed body samples to native coupling, then performs one cellular simulation tick.

The Sandfall host SHALL:

1. Accept validated, generation-matched commands at a defined safe tick/setup boundary and log their order.
2. Refresh/wait for required hard-terrain collider data; do not step a body against known-stale terrain.
3. Apply prior eligible cellular feedback exactly once, manually step Rapier, capture body transforms/velocities.
4. Construct transient occupancy/overlap sample records, then execute one fixed native tick.
5. Publish immutable snapshots and receipts, increment tick identity only after successful complete coupled advancement.
6. On a partial/failing operation enter Fault, cease further ticks and report what happened; never falsely claim cross-solver atomic rollback.

Do not change the solver/coupling order casually during UI refactoring. Native samples, result freshness, valid masks, reset fences and static Rapier collider ownership remain the upstream contracts.

## 3.3 Reuse rule

The current Web entry controller **inherits actor-heavy main.gd** and its Web tick path can still call a sampled player simulation. Sandfall MUST explicitly exclude player movement/action paths from its new host; hiding the HUD is insufficient. Prefer new Sandfall-specific adapters/UI around retained native/Rapier services rather than a bulk source rename. Internal **Cyber*** namespaces can remain during bootstrap for source provenance/backports.

# 4. Edit/Run lifecycle and undo

## 4.1 Modes and permitted operations

| State | Tick | Authored-data mutation | World intervention | Undo/redo |
|---|---:|---|---|---|
| **EDIT** | Exactly 0 | Yes | No independent running world | Enabled for eligible Edit commands |
| **RUN / PRISTINE** | 0 or greater | Frozen | Yes, changes status to Modified | Disabled |
| **RUN / MODIFIED** | 0 or greater | Frozen | Yes, journal accepted actions | Disabled |
| **FAULT** | Current/possibly partial | No | No until recovery | Disabled |

Run must not simply unpause a mutable authoring document: **freeze a revision and construct a clean session**. At the first attempted simulation tick that advances **either** solver, clear/invalidate the pre-Run Edit history, including when the coupled tick subsequently fails. Refuse Run history even before the first tick. Pause, rate changes and reentering Run do not resurrect it. Only an explicit **Reset & Edit** produces a new tick-zero authoring session and **new empty undo history**.

Undo transactions in Edit restore **authored** cell material ID, state bytes and temperature, object definitions and affected presentation metadata; they MUST NOT compute inverse chemistry, undo Rapier contact caches, rewind physics or transplant an old solver state into the present tick. One pointer stroke is a single transaction. The history is not stored in the portable project archive. Edit MAY reconstruct static native/render previews but MUST execute **zero native and Rapier simulation ticks**.

When Run is paused even before its first tick, its Undo/Redo controls remain disabled because it is not Edit. Invalid UI actions must also be refused by the command handlers. The first-tick cutoff is a semantic safety fence, not merely a greyed button.

## 4.2 Reset and promotion

**Reset** rebuilds the frozen initial scene (material tuple payload, object positions/velocity, solver options, queued-events baseline, masks, collider readiness and initial tick). Gallery may autoplay again after readiness; explicit **Reset & Edit** stays paused in Edit. It never depends on reversing chemical/thermal changes.

To satisfy the selected separate Edit/Run workflow, full v1 MUST provide **Apply Interventions to New Draft** for eligible **declarative edits**. This is a later implementation milestone, not permission to modify an evolved World. It MUST take the frozen initial definition, replay approved paint/object edit commands at tick 0 into a **new** authoring revision, show a preview/conflicts, and require confirmation. Runtime side effects, time-dependent physics outcomes and unreconstructible commands are **not** promoted. The new run may behave differently; no trajectory or continuation identity is implied. Direct “save this evolved world as initial state” is not silently substituted.

# 5. MZPaint-tailored painting and UI

## 5.1 Layer authority

Sandfall adopts **MZPaint Layered Hybrid, Precision-dominant**. The primary grid encodes simulation semantics; an overlay encodes cosmetic expression. Neither has permission to reinterpret the other silently.

| Layer | Authoritative payload | V1 editor operations | Solver effect |
|---|---|---|---|
| Material world | Material ID, state_a, state_b, temperature and permitted native-defined state | Pencil, erase, shapes, fill, selection, paste | **Yes** |
| Rapier objects | Stable object ID, box geometry, physical parameters and initial transform | Spawn, move, rotate, resize, inspect/delete | **Yes** |
| Decoration/presentation | Separate annotations/brush marks, colourway, LUT/style | Expressive/cosmetic painting | **No** |
| UI/camera/gizmos | View transform, grid, rulers, hover, selection outline | Pan, zoom, visibility, inspect | **No** |

Painting a blue-looking Water material is **placing the Water category**, not writing arbitrary RGB pixels. Material colour is resolved by its style mapping; changing the palette/LUT must not change materials, temperature or reactions. Material IDs are resolved through the runtime catalogue and checked; paint-slot numbers must never be serialized as IDs. Reserved/invalid materials are refused.

## 5.2 Adopt / Adapt / Reject / Defer table

| MZPaint capability | Disposition | Sandfall v1 behavior |
|---|---|---|
| Semantic palette and “Represents” labels | **Adopt** | Search/filter by material/family, ID, label, usage, and preview |
| Pencil and eraser | **Adopt** | Deterministic cell placement/clearing with path interpolation |
| Circle, square, ratio rectangle footprints | **Adapt** | Reuse CyberSand footprint mathematics; initially 1–32 px, expandable later |
| Lines and rectangles | **Adopt** | Exact endpoints; outlined/filled shapes; preview then one commit |
| Connected-region flood fill | **Adapt** | Match material category, not displayed colour; bounded and cancellable |
| Picker | **Adopt** | Inspect authoritative material/category and state without mutating the world |
| Rectangular selection | **Adopt** | Move, copy, cut, paste, delete using exact cell/state tuples |
| Undo/redo | **Adapt** | Edit-only, zero-tick authoring transactions; first tick invalidates history |
| Airbrush/spray | **Adapt** | If it changes material, record seed and final cell pattern; not nondeterministic redo |
| Painterly decorative tools | **Adapt** | Separate presentation layer, never hidden material writes |
| Grid, rulers, cursor coordinates, zoom | **Adopt** | Accurate cell coordinates, dimensions, zoom and selection readout |
| Colourways / LUT restyling | **Adapt** | Global presentation only; do not alter simulation identity |
| Arbitrary RGB direct-write to semantic grid | **Reject** | Use separate decorative layer |
| Glyph/ANSI/plain-text as full simulation save | **Reject** | Cannot preserve materials, thermal state or object semantics |
| Lasso, skew, arbitrary resize and rich shape library | **Defer** | Not part of the first precise editing surface |
| Automatic raster-image-to-material mapping | **Defer** | Requires explicit semantic classification, provenance and testing |

**First working editor** includes material catalogue, exact brushes, erase, fill, straight lines, rectangles, picker, rectangular selection and valid undo/redo. The hybrid presentation layer must also exist in v1, but can initially provide only a small annotation/expressive brush set.

## 5.3 Mutation and gesture policy

- Tool strokes use exact cell-space coordinates independent of display zoom and aspect-fitting. Pointer-down → drag → pointer-up is **one bounded authoring transaction** in Edit.
- Preview outlines, selection handles and brush cursors are not physics edits. Commit only one validated operation at release (or batch a live stroke through explicit safe command boundaries).
- Cell edit history records the complete resulting affected payload, not just the material ID. A seeded brush also records its exact generated cell positions.
- Flood fill is bounded by world extents and an execution budget; it must not create one expensive Web bridge call for each flooded cell in the completed implementation.
- Writing hard materials schedules terrain collider updates. World/mask/terrain consistency is part of successful command completion.
- The palette can have primary and secondary material slots; erasure is an explicit semantic operation, never the same thing as “background paint”.
- In **Run**, paint, erase and physical tool operations create journalled **interventions** at safe ownership boundaries. They cannot enter Edit history or use Edit undo/redo.
- Cosmetic-only operations remain on their own overlay. They do not change native material hashes or set Modified.
- Invalid/out-of-bounds/empty-effect operations are rejected or reported without pretending that a world mutation succeeded.

## 5.4 Canvas-first layout

~~~text
Top       Sandfall | Gallery / Sandbox | Edit / Run | Open / Save | Reset
Left      Materials | Paint | Shapes | Select | Rapier | Presentation
Centre    Simulation canvas, accurate zoom/pan, optional grid/rulers
Right     Contextual brush/material/selection/object/scene inspector
Bottom    Pristine/Modified | Pause/Run | Step | speed | tick | diagnostics
~~~

Panels are collapsible, and the canvas receives the largest practical area. The UI MUST not paint through a menu, tooltip, modal, inspector drag or window refocus. There is an always-visible indication of **Edit versus Run** and of **pristine versus modified** when applicable. All essential functions are clickable without requiring F-keys, a numpad or PgUp/PgDn; keyboard shortcuts are optional.

Selection, time controls, asset management and metadata must share the same authored document rather than create disparate hidden data models. This is a Godot **Control-node** application UI, not a parallel HTML editor; HTML/JavaScript only provide browser packaging, clipboard/file bridges or other strictly bounded host integration.

# 6. Rapier objects and sixteen-body scope

## 6.1 V1 object model

**Initial supported physical shape: rectangle/box.** Spawn with a box tool and inspect/edit:

- stable unique ID and optional name/passive-subject role;
- position (cells/pixels), width/height, rotation (radians or UI degrees with exact conversion);
- mass, friction, restitution, linear/angular damping;
- initial linear/angular velocity and fixed/frozen state when supported by the bridge;
- selection, duplicate, delete, move, rotate, resize in Edit;
- safe live object creation/removal/property edits in Run as **Modified interventions**.

Physical dimensions/values must be finite and within explicitly declared engine bounds. A passive subject represented as a Rapier box is a normal physical body with visual metadata, **not** a player motor. Shape generalization and joints are not part of v1.

## 6.2 Sixteen-body qualification is not inherited automatically

**16 simultaneously coupled Rapier bodies** is a user-chosen v1 goal. The pinned Web demonstration is structured around **three** built-in Physics Pit bodies and several three-slot assumptions in its scene, shaders and save codec. The native packed coupling parser may admit more records, but that does not establish whole-host rendering, round-trip persistence, performance or lifecycle correctness at sixteen.

Required generalization:

1. Dynamic object registry with stable IDs, creation order and correct pending-deletion fencing.
2. Bridge initialization and reconfiguration for **0–16** bodies, with proper RID/Node retirement.
3. Full sampling, native transient occupancy, bounded feedback and result mapping for all admitted IDs.
4. Rendering not capped by three fixed body shader parameters.
5. Initial project ZIP serialization, import, reset and identical initial-pose restoration for the full set.
6. Actual Web browser tests with **0, 1, 3, 8 and 16** bodies and body/body + body/material interactions.
7. Explicit, atomic rejection of body **17**, duplicate IDs and bad mass/shape/transform, with the old World preserved.

The native code's larger sample-record capacity is **not** a promise of more than 16 supported project objects. Current limitations (rectangular native mask, bounded sweep and penetration, capped reactions, non-exact torque/fracture) remain disclosed. The body is never stored as painted cells.

## 6.3 Live object changes

When Run is active, user changes are validated commands applied only between complete simulation steps. Live resizing/reconfiguration must rebuild the appropriate Rapier collider and transient native occupancy without a stale sample or a simultaneous solver write. Deletion retires objects and prevents ghost feedback. Successful commands mark **Modified**; refused commands leave the active body graph unchanged.

The UI may show passive subjects using a decorative icon or skin, but their physics comes from the body and real environment. No automatic steering controller is attached.

# 7. Time, camera and input

## 7.1 Physics time

**Fixed dt = 1/60 s.** Supported pacing: **0.25× / 0.5× / 1× / 2× / 4×**, plus Pause and Single Step. Pacing changes how many fixed coupled ticks are executed per wall-clock interval; it must not change native dt, Rapier dt, gravity or solver constants.

- Pause: **0** native ticks and **0** Rapier steps.
- Step: exactly **1 complete native tick**, and exactly **1 Rapier step when a Rapier bridge is active** (otherwise no Rapier step), or a reported failure/refusal; remain paused.
- Runtime speed: count actual completed ticks, not just callbacks. Do not silently drop ticks to claim 4× speed.
- Under load, bound the backlog, report effective speed/owed ticks and degrade transparently.
- Scene triggers, clocks and procedural events use simulation ticks, not frame number or wall-clock time.
- Decorative animation may be presentation-time-driven if it cannot feed back into the physics or invalidate reference captures.

A simulation-speed change is not in itself an intervention when the fixed-step state sequence remains unchanged. Real-time rendering may diverge from requested speed; report that honestly.

## 7.2 Camera and simulation region

Pan, zoom, presentation quality, ruler/grid controls and viewport changes are observation tools and should **not** mark a run Modified. However, the upstream engine has interest-region scheduling: **camera motion must not secretly change what gets simulated** during a qualified Golden Run. Freeze or explicitly author the scene's simulation-interest region independent of camera; if an alternative policy is used, qualify and disclose it as outcome-affecting.

No actor movement/action bindings may be processed by the Sandfall host. A viewport input router exclusively distinguishes drawing, object tools, camera and UI, and clears held gestures on blur, modal opening, navigation and mouse release. A retained legacy GDScript controller must not move an invisible player behind the scenes.

# 8. Golden runs and zero-player demonstrations

## 8.1 Identity and modification

A pristine run binds an immutable **authored scene digest** and identity: material/thermal initial payload, Rapier initial definitions, world config, seed, ruleset/native build, Rapier version/runtime hash, fixed timestep, generated events and interest-region policy. The actor-control trace is absent or all-neutral.

**PRISTINE** persists while the scene advances naturally. The first *accepted* physical or material intervention transitions to **MODIFIED**, a sticky state until Reset. Cosmetic-only changes and truly physics-independent camera/time pacing do not mark Modified. No silent return to pristine is allowed after a successful intervention.

The Run journal records **tick**, stable sequence number, generation, command class, validated parameters, accepted/rejected result and source identity. This is provenance/evidence, **not** proof that complete Rapier/native continuation can be reconstructed from an arbitrary mid-run snapshot.

## 8.2 Demonstration suite

| Reference | Real behavior to demonstrate |
|---|---|
| ZP-P01 Gravity Cascade | Gravity-driven chain using native cells/Rapier boxes |
| ZP-P06 Fluid Messenger | Native liquid pushes/moves a real Rapier box; no scripted body teleport |
| Passive Subject Ride | Optional uncontrolled subject carried through an authored sequence |
| ZP-P10 Endless Kinetic Loop | Bounded autonomous ongoing scene; stable resource metrics |
| ZP-FX-06 Intervention | Paint or spawn during a pristine run, mark Modified, Reset reproduces initial state |
| ZP-FX-07 Time Controls | Pause zero ticks, Step one full coupled tick, fixed-dt speed presets |
| Sandfall 16-Body | Full dynamic list, rendering, coupling, safe reset and predictable cap refusal |

A curated Gallery entry must produce visible self-running behavior, not just an inert map with an autoplay camera. An authored finale/loop can carry metadata and presentation cues, but the claimed physical cause-and-effect must be observable from actual simulation state.

## 8.3 Evidence levels and determinism

Qualify separately:

- **Source-matched local reproducibility:** recorded source/runtime, seed, initial state and commands produce the supported local outcome in repeated actual runs.
- **Cross-browser outcome equivalence:** differences may exist, but declared outcome criteria and tolerances are met on named browser/profile targets.
- **Bitwise whole-stack replay:** only claim when full native cell, Rapier, Godot host state and command order have actually been proven bit-identical.

CyberSand's **CYSD1** finite-level format omits native continuation/epochs, queued events and Rapier caches. Native and Rapier subsystem determinism does not automatically establish a complete cross-browser guarantee. Retain raw checks, failure evidence, negative runs and precise limitation statements.

# 9. Portable .sandfall projects

## 9.1 Ordinary ZIP containing an editable folder

**.sandfall is a standard ZIP archive**, not a custom binary wrapper. Renaming it to **.zip** MUST allow extraction with ordinary ZIP software. Its contents are the same structured **project folder** a developer could inspect/edit locally; no proprietary archive reader is needed to examine the files. A browser ZIP load/save API is required for normal use. Directly opening an unpacked folder MAY be added as a developer convenience.

Proposed stable v1 layout:

~~~text
example.sandfall        (ordinary ZIP; may also have .zip extension)
  project/
    manifest.json       version, project identity, paths, SHA-256 file digests
    scene/
      scene.json        kind, initial settings, seed, camera, interest, events
      objects.json      up to 16 initial Rapier box definitions
    world/
      cells.bin         exact initial material tuples, row-major
    presentation/
      style.json        themes/LUT/material-style choices (not material IDs)
      annotations.json  optional non-physical decoration
    assets/             optional local images and other safe assets
    README.md           optional human-authored project notes
~~~

**ZIP DEFLATE** provides file-entry compression, including for the binary cell asset. Do not add redundant nested compression without a documented schema revision. The extracted folder's JSON is human-readable; **cells.bin** is documented binary simulation data, not pretending to be editable text. File paths are relative within **project/**, never absolute.

## 9.2 V1 archive data contract

- **manifest.json** requires discriminator **sandfall-project**, schema version **1**, project title/identifier, referenced scene path, content versions, exact Sandfall/app and engine-source identities, and SHA-256 digest for each other required file. No manifest-self-hash cycle.
- **scene.json** records scene kind (zero_input/kinetic_sandbox/triggered_automatic), authoritative **1024×1024** size, fixed 60 Hz, scene seed, supported solver options, authored interest policy, initial camera/start behavior, environmental triggers, optional passive-subject ID, loop/milestone expectations and source identity.
- **cells.bin** represents the **initial** logical material world, not an arbitrary running-world continuation. V1 candidate format is **five bytes per cell**: material ID u8, state_a u8, state_b u8, signed temperature i16 little-endian, row-major, exactly **5,242,880 bytes** for 1024² cells. This logical payload mirrors the relevant CyberSand finite-level encoding, not the eight-byte in-memory native Cell ABI. Additional required initial solver fields/sidecars MUST be versioned or rejected before promoting this candidate to the implemented schema.
- **objects.json** has a versioned object array of zero to sixteen, with stable unique IDs, type=box, dimensions, transform, initial velocity, physical parameters and passive-subject designation. Use explicit units and finite-number validation.
- **presentation/** may store decorations and colour styles but never silently overwrite authoritative material/body state.
- **assets/** must be self-contained within the project. Missing external URLs cannot become hidden startup dependencies.

**The intended meaning of Save .sandfall is Save Authored Initial Scene.** In Edit it saves the current draft. During Run it may save the last frozen authored draft with a clear label, but it MUST NOT quietly package live chemical/thermal evolution, pending events or Rapier contact caches as if they were authored initial state. Optional **Export Run Evidence** creates a distinct evidence artifact, not a .sandfall project with fabricated replay guarantees.

## 9.3 Import, export and failure rules

The archive importer MUST:

1. Stage and inspect ZIP entries without changing the current scene.
2. Enforce one normalized project root, reasonable entry-count and expanded-size limits, and prevent **zip-slip**, absolute/parent-traversal paths, symlinks, duplicate case-folded paths and suspicious compression ratios.
3. Accept only documented data/asset types; no executable project scripts may run from the archive.
4. Check schema/version compatibility, required paths, length and SHA-256 digests; reject invalid/missing material IDs, bad cell payloads, nonfinite physics values, duplicate object IDs, more than sixteen bodies and unsupported solver settings.
5. Validate the fully reconstructed candidate World/Rapier graph before committing the replacement.
6. On any parse, native, asset, Rapier or readiness failure, preserve the previous authored document and running scene; report the precise refusal.
7. On success, install an immutable authored scene at tick 0 with the correct startup policy.

Conservative initial limits: at most **256 archive entries** and **128 MiB expanded total**; per-asset and compression-ratio limits must be fixed in the loader implementation and negative tests. The fixed initial world file always has its exact-size requirement. Import cannot pretend that a SHA-256 hash makes attacker-provided scripts safe.

Logical-file serialization SHOULD be canonical enough for comparable scene hashes: deterministic JSON property/key order, stable IDs, fixed binary endianness, no machine-specific paths. ZIP timestamp/compression byte equality is not required unless explicitly tested. An extracted folder and its ZIP representation must round-trip to the same logical project.

# 10. Web packaging and performance

## 10.1 Frozen bootstrap toolchain

Baseline source files already pin:

| Component | Initial exact version/identity |
|---|---|
| Godot | **4.7.stable.official.5b4e0cb0f** |
| Rapier2D | **0.35.2**, single-precision, vendored lock and Web WASM |
| godot-cpp | **101ae38034304346a46ea9ea84ae156d3e860496** |
| Emscripten | **4.0.20** |
| SCons | **4.10.1** |
| Fixed simulation | **60 Hz**, initial **1024×1024** World |

These are **build-input pins**, not proof that any Sandfall build has been produced. Native binaries/LFS pointers must be restored and hash-verified; retained upstream build manifests and license notices must remain accurate. Changing source or registered build inputs requires new matching artifacts.

## 10.2 Web profiles

- **Compatibility Web (mandatory):** native cellular engine with one worker, Rapier included, Godot synchronous owner. Distribute as ordinary static Web content with correct MIME/complete WASM/PCK assets. This is the default public build.
- **Threaded Web (additional):** separate source-matched export with native worker pool. Requires cross-origin isolation (COOP/COEP) on a secure host. Qualify it separately; do not promise that every static host can run this profile.

The upstream **tools/build_web.py** stages a separate **web_main.tscn**, compiles with pinned Emscripten/godot-cpp, checks Rapier WASM hashes and packages runtime provenance. Retain and adapt it rather than silently substituting a cellular-only Web export.

The Web host must truthfully display Rapier availability, worker profile and startup/refusal errors. Never claim a compliant build if the downloaded Rapier Web module is missing or mismatched.

## 10.3 Performance policy

**60 Hz is the design physics rate, not an unconditional 60 FPS claim.** Report actual tick rate, requested/achieved speed, native tick p50/p95/max, Rapier step and collider build time, active body count, render patch bytes and frame/backlog samples. Under pressure, preserve fixed-step physics and disclose slowdowns; do not silently weaken materials/coupling or lower the sixteen-body cap.

The sixteen-body target requires actual representative benchmarks and normal Web interactions on compatibility and threaded profiles, with browser/device details. Benchmark thresholds can be chosen after establishing source-matched measurements; benchmark results must not be invented in the spec.

# 11. Acceptance and evidence

## 11.1 Executable test matrix

| ID | Contract to test | Passing behavior |
|---|---|---|
| SF-T01 | Source import / Web boot | Preserved upstream history, pinned dependencies/runtime manifests, actual compatibility Web launch |
| SF-T02 | Zero actor input | No steering/jump/action ingestion; passive body moves only through environment; focus/modal input gates are effective |
| SF-T03 | Edit at tick 0 | Material/thermal state, deterministic footprints, fill/selection and object edits; exact undo/redo with zero physics ticks |
| SF-T04 | First-tick history fence | Any first advancement, including a partial failed coupled tick, invalidates history; pausing/changing speed does not restore; Reset & Edit starts empty history |
| SF-T05 | Paused/Step/speed | Paused = zero coupled steps, Step = exactly one fixed dt, speed presets change pacing but not state-update dt |
| SF-T06 | Pristine → Modified → Reset | Accepted material/body/solver edit marks Modified; camera/style-only does not; reset restores initial hashes/body poses |
| SF-T07 | Rapier body capacity | 0/1/3/8/**16** boxes render, sample, collide, save/load, reset and retire; 17 refuses atomically |
| SF-T08 | Actual fluid/body coupling | Fluid Messenger moves a real Rapier box through native physical feedback, not scripted position |
| SF-T09 | ZIP-of-folder round-trip | .sandfall readable as ZIP, folder editable, JSON/binary logical identities/hash verified after import/export |
| SF-T10 | Hostile input refusal | Path traversal, invalid ZIP/bomb, wrong digest, bad material, unsupported schema/policy, 17 bodies, invalid mass do not replace old session |
| SF-T11 | Browser/profile coverage | Actual browser Rapier WASM/native tick, source-bound compat; threaded Web separately tests isolation and worker counts |
| SF-T12 | Scientific/evidence integrity | Exact source/engine/runtime, seed, command trace, failed checks and limits retained; no unsupported determinism claims |

SF-T03–T06 MUST include representative **chemical/thermal** changes, not just inert Sand. A passing pause/undo test on an empty world would not justify the provenance constraints chosen by the owner.

## 11.2 Evidence and publication wording

Every claimed qualified demonstration has source commit, native/Web/WASM hashes, browser/platform, simulator settings, authored scene hash, initial body list, tick/time mode, actual neutral/absent actor-control trace, ordered user/environment event log, physical outcomes and negative evidence. Captured video is presentation evidence, **not** a substitute for internal simulator receipts.

Use distinct labels such as **locally replayable**, **cross-platform outcome-qualified**, and **bitwise deterministic**, each only where actual runs establish the relevant claim. Keep historical negative evidence and known engine approximation limits. A successful Godot headless test does not alone establish browser execution. Require at least one human review of a Gallery scene's legibility and pacing before calling it exhibition-qualified.

# 12. Implementation sequence and source map

## 12.1 History-preserving import

Sandfall currently starts as two README-only commits. Import the **exact** CyberSand ancestor through an **unrelated-history merge preserving both histories** (or equivalently history-preserving mechanism), not by copying a moving latest-main snapshot. Keep source provenance, .gitattributes/LFS, licenses, native receipts and tests.

**Windows file-name trap:** Sandfall originally used **readme.md** while upstream uses **README.md**. Resolve the case-only collision before the merge; this spec's accompanying Sandfall README normalization is intentional. Any normal exact-path README content conflict during the later source merge must be resolved deliberately.

Do not mass-rename internal **Cyber*** symbols at bootstrap, and do not auto-merge later CyberSand PLAY/player branches. Backport only independently reviewed fixes that Sandfall needs.

## 12.2 Ordered implementation milestones

**SF-M0 — Source/build/provenance.** Exact ancestor history import, dependency and LFS audit, compatibility Web export and actual native/Rapier startup proof. Existing upstream tests unchanged.

**SF-M1 — New host/application shell.** Separate Sandfall scene and Godot Control UI, no actor input/motor, Gallery/Sandbox entry, camera, Run/Pause/Step/Reset, source-matched native+Rapier coupled tick. Use reference Web controller only until replacement is proven.

**SF-M2 — Authoring and state boundaries.** Immutable initial document; Edit/Run, pristine/modified/fault; material catalogue; brush/erase/fill/lines/rectangles/picker/selection; exact Edit history and mandatory first-tick undo cutoff; safe mutation queue.

**SF-M3 — Dynamic Rapier workshop.** Box editor/inspector, stable IDs, generalized 0–16 coupled objects including shader/render/save and actual Web qualification, overflow refusal.

**SF-M4 — Project files and exhibitions.** .sandfall ZIP project-folder codec, staged load/save, presentation overlay, curated Gallery, optional passive subject, Golden Run evidence and **explicit, safe initial-state promotion** of reconstructible interventions.

**SF-M5 — Release qualification.** Full browser compatibility + threaded matrix, chemistry/thermal history/refusal, 16-body stress, Fluid Messenger, archive attack cases, exact-head artifacts and human presentation checks.

M0/M1 are intentionally narrower than complete v1. The owner decisions in §1 are full v1 requirements; shipping a narrow early demo must not be called full v1 qualification.

## 12.3 Upstream-to-Sandfall code map

| Pinned CyberSand source path | Reuse/modify responsibility |
|---|---|
| **tools/build_web.py**, **godot/web_main.tscn** | Adapt checked Web export to new Sandfall entry scene |
| **godot/scripts/web_demo_controller.gd** | Reference synchronous tick, native painting, Rapier ownership and reset; remove inherited actor behavior in new host |
| **godot/scripts/main.gd** | Retain material brush/render/coordinate logic as safe modules; do not inherit player-input authority into public controls |
| **godot/scripts/web_demo_menu.gd** | Replace with canvas-first Sandfall Control surface |
| **godot/scripts/rapier_physics_bridge.gd** | Keep manual-step/lifetime/coupling contract; support dynamic 0–16 object registry |
| **godot/scripts/demo_worlds.gd** | Reuse relevant authored demo recipes, recast as versioned scene definitions |
| **godot/scripts/demo_save_codec.gd** | Legacy level format example only; not a general .sandfall authoring/continuation codec |
| **godot/native_extension/cyber_native_cell_world.cpp** and **native/src/world.cpp** | Preserve authoritative state/masks and tests; change only under separately justified native evidence |
| **godot/third_party/rapier2d.lock.json** | Pin Rapier binary and Web source identity |
| **godot/tests/test_web_rapier.gd**, **godot/scripts/web_rapier_probe.gd** | Preserve current three-body evidence; add Sandfall sixteen-body/undo/ZIP tests |

New logical modules: **SandfallAuthoringDocument**, **SandfallSessionController**, **SandfallToolRouter**, **SandfallRapierObjectRegistry**, **SandfallArchiveCodec**, **SandfallGallery**, **SandfallRunEvidence**. Actual filenames may vary if interfaces and tests implement the same boundaries.

# 13. Deferred work and revision control

**Deliberately deferred:** controllable or AI-driven actors, gamepad player inputs, circle/polygon/capsule native contour coupling, physical joints/large assemblies, arbitrary rewind/timeline scrubbing, exact mid-run state continuation, cross-platform bitwise guarantees, touch/mobile-first UI, automated level optimization, mass dependency upgrades, raster imports interpreted as materials, hosted user accounts and collaboration.

**Nonblocking tuning:** exact visual style, panel proportions, expanded brush ranges, cosmetic overlays, additional gallery content, material colour themes, reference performance hardware and asset codecs. These can evolve without invalidating this contract so long as semantic/physics boundaries remain intact.

**Requires explicit owner-approved revision:** changing no-player-input scope, separate Edit/Run, first-tick undo cutoff, sixteen-body v1 target, ordinary ZIP-of-project-folder storage, 60 Hz fixed-step contract, solver/Rapier ownership order, or Pristine/Modified semantics. Add an ADR and matching negative tests when such a change is approved.

---

## Current implementation status

This document records **approved design intent**. At the time of authoring, Sandfall has only its bootstrap README and this documentation branch; the CyberSand engine source **has not yet been imported**, and no Sandfall Web, new UI, full archive or sixteen-body qualification is claimed.
