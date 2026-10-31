# Sandfall

**Status: SF-M0/M1/M2 have bounded compatibility-Web qualification; their
[dependency merge-down](https://github.com/techrote/sandfall/pull/2) is separately
owned. SF-M3 implements the stable-ID 0–16-body Rapier workshop on
`sf-m3/rapier-workshop-20261031`. Its exact-source browser qualification is tracked
in the [dated audit](docs/audits/2026-10-31-sf-m3-rapier-workshop.md).
The SF-M3 PR remains draft and unmerged.**

Sandfall is a Web-native, interactive, **zero-player cellular + Rapier physics exhibition and editor** derived from CyberSand. “Zero-player” removes player/actor movement and action controls, **not** painting, object creation, time control or camera interaction.

The normative v1 project-specific contract is:

**[Sandfall v1 — Architecture, UI/UX and Implementation Specification](docs/SANDFALL-V1-ARCHITECTURE-IMPLEMENTATION.md)**

It fixes the agreed design: separate **Edit / Run** modes; Gallery autoplay and paused Sandbox; MZPaint-derived precision-first material editing with a separate decorative layer; optional passive subjects; sixteen coupled Rapier boxes; fixed-step 0.25×–4× pacing; pristine/modified run provenance; and **undo/redo only in Edit at tick zero**. After a simulation tick, no physical-history undo is attempted. Reset returns to an authored initial state.

Portable **.sandfall** files are ordinary **ZIP archives containing a structured project folder** with human-readable JSON definitions and separate material/asset data, not an opaque proprietary save format.

## Pinned provenance

| Source | Immutable baseline |
|---|---|
| CyberSand upstream | [techrote/cybersand @ 1d376fb38ff5df83691e468baa0639270a5f40e6](https://github.com/techrote/cybersand/tree/1d376fb38ff5df83691e468baa0639270a5f40e6) — 2026-10-25 |
| UI/UX reference | [specdocz MZPaint @ 039008723172a951c7694079cd06c7a2ea137d40](https://github.com/techrote/specdocz/tree/039008723172a951c7694079cd06c7a2ea137d40/uiuxs/mzpaint) |
| Experience research | [specdocz Zero-Player Level Design @ same pin](https://github.com/techrote/specdocz/tree/039008723172a951c7694079cd06c7a2ea137d40/gametypes/zeroplayerlevel) |

## Engineering evidence and next step

The exact CyberSand history is imported. A source-matched compatibility Web
export and 600-tick native/Rapier fixture passed, as did the full 164-test native
suite. The ordinary browser blocker is resolved at `86f4c942...`: both
800 × 450 / DPR 1 and 640 × 400 / DPR 2 passed real Continue/Escape/P input,
advanced at least 18 / 24 normal native ticks and captured visible material
content within the actual world viewport. Exact CI receipts, durable raw
evidence, original failures and remaining qualification boundaries are in the
[dated ordinary-Web audit](docs/audits/2026-10-30-sf-m0-ordinary-web.md).

The dedicated `godot/sandfall_main.tscn` now owns Gallery/Sandbox, separate initial
Edit/Run state, camera, pause, exact Step and reset without inherited actor or
launcher authority. See the [SF-M1 milestone](docs/SF-M1-HOST-INPUT-CUT.md) and
[dated implementation/qualification audit](docs/audits/2026-10-30-sf-m1-host-input.md)
for current source, executed checks and fresh-export identity. The ordinary
800×450/DPR1 and 640×400/DPR2 runs pass 54 checks each, including real UI/focus
input, exact Step/reset, at least 600 actual coupled ticks and visible world
screenshots. The retained legacy
scene is used explicitly for historical regression contracts. Threaded Web,
human exhibition review and the portable archive retain their separate gates.
These SF-M1 results predate the later editing and object-workshop source.

The [fresh Web export at bbe72707](https://github.com/techrote/sandfall/actions/runs/41139800406/artifacts/13017918272)
contains the runnable application and its SHA-256 manifest. After extracting it,
serve the directory over HTTP with `python3 serve_web.py --directory . --port 8040`
and open `http://127.0.0.1:8040/`. Gallery autoplays after readiness; Sandbox
starts in Edit at tick zero. Run, Pause, Step, Reset, Reset & Edit and camera
controls are clickable; P toggles pause, Escape opens the menu, and middle drag/
wheel control the camera. No painting/history or arbitrary object-authoring UI
is claimed in this initial host cut.

## SF-M2 material authoring

The [SF-M2 implementation](docs/SF-M2-AUTHORING-HISTORY.md) adds copied initial documents, exact signed material/state/temperature transactions, one-gesture history, complete first-tick history retirement and bounded journalled Run interventions. The Control sidebar provides catalogue/search, pencil/erase, circle/square/ratio footprints, lines/rectangles, picker, cancellable category fill and exact selection copy/cut/paste/move/delete. Grid/rulers and camera remain presentation-only. Reset restores the frozen design; Reset & Edit starts a new empty undo history. Pacing preserves fixed dt.

[The dated audit](docs/audits/2026-10-31-sf-m2-authoring-history.md) separates development results from exact-SHA native/Web/browser qualification and retained failures. The SF-M1 export linked above predates these tools and cannot demonstrate SF-M2. The [fresh SF-M2 export and full qualification run](https://github.com/techrote/sandfall/actions/runs/41163426571) pass at `533a3de6352074f0cd68faca94417e80f041080e`; use its `sandfall-sf-m2-fresh-web` artifact, not the older SF-M1 package. After extraction, run `python3 serve_web.py --directory . --port 8040`. Open Sandbox, then Tools, to edit the initial scene. Undo/Redo are Edit-only; after Run, Reset & Edit restores a new editable baseline with empty history. The durable evidence manifest and original failures are linked in the dated audit.

## SF-M3 physical workshop

The [SF-M3 contract](docs/SF-M3-RAPIER-WORKSHOP.md) extends the same authored
document and chronological history with stable-ID boxes, physical parameters,
initial velocities, copied reconstruction and safe Run interventions. Sandbox
shows the tool panel; choose **Objects** for Box, Select, Move, Rotate or Resize.
Selection handles and the right inspector provide precise geometry and physics
editing. Inspector values are staged until **Apply**. Duplicate/Delete and
Undo/Redo are clickable. **Tools: shown / Tools: hidden** states visibility.

All sixteen admitted boxes use the actual Rapier/native coupling and renderer;
the seventeenth refuses before mutation. Zero boxes is a valid native-only
scene. Reset reconstructs authored IDs, properties and velocities; Reset & Edit
starts empty history. The [dated audit](docs/audits/2026-10-31-sf-m3-rapier-workshop.md)
distinguishes local native/Godot results from mandatory source-matched browser
physics, trusted input and individual object pixels.

**Next after SF-M3's executable gates:** SF-M4's portable project codec,
presentation, curated Gallery and explicit intervention promotion. Human visual
acceptance, threaded/unisolated hosting and broad desktop qualification remain
separate. The internal logical object representation does not implement the
`.sandfall` ZIP format.

This root filename is deliberately **README.md**, matching normal Git conventions and avoiding the prior **readme.md / README.md** case conflict on Windows during upstream import.
