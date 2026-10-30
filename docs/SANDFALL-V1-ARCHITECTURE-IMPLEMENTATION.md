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

Run must not simply unpause a mutable authoring document: **freeze a revision and construct a clean session**. At the first successfully completed simulation tick, clear/invalidate the pre-Run Edit history. Pause, rate changes and reentering Run do not resurrect it. Only an explicit **Reset & Edit** produces a new tick-zero authoring session and **new empty undo history**.

Undo transactions in Edit restore **authored** cell material ID, state bytes and temperature, object definitions and affected presentation metadata; they MUST NOT compute inverse chemistry, undo Rapier contact caches, rewind physics or transplant an old solver state into the present tick. One pointer stroke is a single transaction. The history is not stored in the portable project archive. Edit MAY reconstruct static native/render previews but MUST execute **zero native and Rapier simulation ticks**.

When Run is paused even before its first tick, its Undo/Redo controls remain disabled because it is not Edit. Invalid UI actions must also be refused by the command handlers. The first-tick cutoff is a semantic safety fence, not merely a greyed button.

## 4.2 Reset and promotion

**Reset** rebuilds the frozen initial scene (material tuple payload, object positions/velocity, solver options, queued-events baseline, masks, collider readiness and initial tick). Gallery may autoplay again after readiness; explicit **Reset & Edit** stays paused in Edit. It never depends on reversing chemical/thermal changes.

To satisfy the selected separate Edit/Run workflow, a future v1 **Apply Interventions to New Draft** action MAY deliberately promote eligible **declarative edits**. It MUST take the frozen initial definition, replay approved paint/object edit commands at tick 0 into a **new** authoring revision, show a preview/conflicts, and require confirmation. Runtime side effects, time-dependent physics outcomes and unreconstructible commands are **not** promoted. The new run may behave differently; no trajectory or continuation identity is implied. Direct “save this evolved world as initial state” is not silently substituted.
